# Handling — RW-1920 [UMA] Implement backend APIs for the UMA feature set

## Type
feature

## What was wanted
Port Tether Wallet's UMA surface to the Rumble side. Per the agreed spec
(`final-spec.md`) and Alex's steer, the username is the immutable Rumble
identity (issued at registration, carried in the auth token), so the
username-management endpoints fall away. Net scope: `GET /api/v1/wallets` and
`POST /api/v1/wallets` return a `uma{}` config block for the user wallet.

## Scope decision
`final-spec.md` contradicts itself: the "Final endpoint set" table scopes the
work to `POST /wallets` + `GET /wallets` returning `uma{}` (suggest/check
dropped, PATCH username dropped), while a prose line also mentions porting
`lnurlp-by-username`. The lnurlp-by-username port was treated as **out of
scope** because:
- it is not in the ticket's API table (only suggest/check + POST/GET/PATCH
  wallets are),
- it is incompatible with the spec's own "nothing stored" decision: it needs a
  backend `username -> wallet` lookup, but usernames live only in Rumble's token
  and are not persisted here,
- Rumble's `/.well-known/lnurlp/:sparkIdentityPubkey` already resolves on the
  spark pubkey and is left untouched.

So this is a storage-free change: `uma{}` is config-derived, and GET/POST
`/wallets` only ever return the authenticated user's own wallets, so the
username for those is exactly the caller's token `preferred_username`. No
HyperDB schema change, no ork/data-shard change, no version fan-out.

## Change
All in `rumble-app-node`:
- `workers/lib/utils/uma.js` (new) — `buildUmaConfig(ctx, req)` returns
  `{ domain, minSendable, maxSendable, defaultSettlementLayer }` (config with a
  request-host fallback for `domain`, and TW-matching defaults: minSendable
  1000, maxSendable Number.MAX_SAFE_INTEGER, defaultSettlementLayer
  'lightning'). `decorateWalletWithUma(ctx, req, wallet)` attaches `uma` (and
  the immutable `username` when the token carries it) to `type === 'user'`
  wallets only, skipping failed-create entries (`status >= 300`).
- `workers/lib/server.js` — `applyUmaToWalletRoutes(ctx)` swaps only the
  `.handler` of the already-registered `GET:/api/v1/wallets` and
  `POST:/api/v1/wallets` routes (keeping the inherited schema, auth, rate-limit
  and channel-ownership preHandlers), calling the WDK base ork service then
  decorating the wallets. Exported alongside `routes`.
- `workers/http.node.wrk.js` — calls `libServer.applyUmaToWalletRoutes(this)` at
  the end of `_setupRoutes()`.
- `workers/lib/services/auth.js` — `ssoHandler` now surfaces `username` from the
  `/-wallet/v1/me` response (matched defensively:
  `username ?? preferredUsername ?? preferred_username`), so the decorated
  wallet routes can echo it. Omitted when absent.
- `config/common.json.example` — adds a `uma` block
  (`domain`, `minSendable`, `maxSendable`, `defaultSettlementLayer`).

## Repos touched
- `rumble-app-node` — UMA util, wallet-route decoration, SSO username surfacing,
  config example, tests.

## Layering / idempotency / separation notes
- Layering: `uma{}` is response-shaping at the HTTP `-app-node` boundary, so it
  lives there. The WDK base routes/schema, the ork, and the data-shard are
  untouched; the base `wdk-app-node` open repo is not modified (no fan-out).
- Idempotency: no new mutation. The POST path still delegates create to the same
  `ork.addWallet`; decoration is read-only post-processing, so retries/duplicate
  deliveries behave exactly as before.
- Separation: decoration runs in a single `preSerialization` hook, so the
  inherited handlers, auth (DefaultGuard + sso), rate-limit, and
  channel-ownership preHandlers are all preserved. `uma`/`username` are
  documented in the route response schema and pass the response validator
  (warn-only).
- No HyperDB schema involved; immutability is honoured by never accepting,
  validating, or persisting a username on this path.

## Tests
- `rumble-app-node`: `npx brittle tests/uma.unit.test.js` — 7/7 pass, 23
  asserts (buildUmaConfig config-only domain + defaults; `assertUmaConfig`
  required-domain guard; decorateWalletWithUma user vs channel, failed-create
  skip, username echo, null passthrough; decorateWalletResponse across all four
  route shapes + non-wallet passthrough).
- `rumble-app-node`: `npx brittle tests/http.node.wrk.intg.test.js` — wallet
  suite green: GET list (uma on user wallet, none on channel), new POST uma
  test, GET `/:id` and PATCH both assert uma, plus POST and channel validation.
  Added `uma` config to the setup hook.
- `npx standard` — clean repo-wide.
- Pre-existing unrelated failure: `GET /api/v1/wallets/:id/balance` throws
  `"tokenBalances" is required!` (the test mock's balance shape fails
  `balanceSchema` serialization) and the uncaught TypeError aborts the run.
  Confirmed identical on the clean tree (changes stashed), so it is not caused
  by this work.

## Review follow-up (3 findings addressed)
1. **UMA domain trusted a client header (valid bug).** Removed the
   `x-forwarded-host` fallback in `buildUmaConfig`; the domain now comes only
   from `conf.uma.domain`, and `assertUmaConfig` fails the worker at boot
   (`ERR_CONF_UMA_DOMAIN_REQUIRED`) if it is unset, so the payment domain can
   never be derived from an untrusted header.
2. **Response contract was stale (valid).** Added `uma`/`username` to the four
   wallet routes' `schema.response[200]` (`applyUmaWalletSchemas` in
   `server.js`, composing on the exported `wdk`
   `walletSchema`/`walletCreateResultSchema`) and to the rumble response
   validator, so Swagger and validation describe the new fields.
3. **Inconsistent wallet shape across endpoints (valid consistency point).**
   Replaced the two per-route handler swaps with a single `preSerialization`
   hook + shared `decorateWalletResponse` mapper, so `GET /wallets`,
   `GET /wallets/:id`, `POST /wallets`, and `PATCH /wallets/:id` all return the
   same uma-decorated user-wallet shape. Base handlers run unchanged.

### Second review pass (from-address route missed)
4. **`GET /wallets/from-address/:address` was not covered (valid).** It is
   another authenticated wallet-returning route. Fixed by introducing a single
   source of truth, `WALLET_RESPONSE_ROUTES` in `utils/uma.js`, that now drives
   the decorator, the route response schemas (`applyUmaWalletSchemas`), and the
   validator overrides together, so the three can no longer drift; `from-address`
   is included. While verifying it, found that `getWalletByAddress` resolves the
   address globally (the ork `getWalletIdByAddress` does not filter by userId),
   so the route can return another user's wallet. The `username` echo is
   therefore gated on ownership (`wallet.userId === req._info.user.id`): it is
   stamped only on the caller's own wallet, which is correct on every route; the
   `uma{}` config (deployment-level) is still attached to any user wallet. Added
   unit coverage for the ownership gate and the `from-address` shape, plus an
   integration test hitting `from-address`.

## Assumptions / open points
- The username field name in the Rumble `/-wallet/v1/me` response is unverified
  (no doc in `rumble-docs`). It is read defensively and the feature degrades
  gracefully: if absent, `uma{}` is still returned, only the echoed `username`
  is omitted. Worth confirming with Rumble, along with the spec's open item that
  `preferred_username` is always present and stable for wallet users.
- `lnurlp-by-username` / `/username/suggest` / `/username/check` and PATCH
  username set/reset are intentionally not implemented (see Scope decision).
- `conf.uma.domain` is now a required config key for `rumble-app-node` (worker
  refuses to boot without it).

---

# Addendum (2026-06-16) — Full UMA receive port (product confirmed interop)

## Why
Product confirmed RW and TW must be **interoperable**: an external UMA wallet
must be able to pay `username@domain` against Rumble. The original ticket shipped
only the address-display `uma{}` config. This addendum adds the actual receive
path, porting Tether Wallet's UMA surface to the Rumble side. TW code is the
reference only; **no `tether-wallet-*` repo was modified.**

## Key port decisions
- **Mongo-only, no HyperDB migration.** Rumble's deployed `dbEngine`/`lookupEngine`
  are both `mongodb` (same as TW), so `username`/`uma` live on the Mongo wallet
  doc + the ork's Mongo lookup table. No append-only HyperDB schema change, no
  `db:build`, no codec version bump. TW's data-shard is mongodb-only, so the
  HyperDB path is deliberately not built; UMA receive now explicitly requires
  `dbEngine: mongodb` and rejects with `ERR_UMA_REQUIRES_MONGODB_ENGINE` otherwise
  (see Review fix #4).
- **Username is the immutable Rumble `preferred_username`**, injected server-side
  into the wallet-create body from the auth token. No client input, no
  suggest/check/set/reset, none of TW's format rules (Rumble owns the namespace).
- **`/.well-known/lnurlp/:param` re-keyed from spark-pubkey to username** (TW
  parity, required for interop). The pay callback `GET /api/lnurl/payreq/:uuid`
  stays keyed on the spark identity key, so existing spark receives via the
  callback are unaffected. The dead spark-pubkey `handleLnurlpRequest` was removed.
- Dropped TW's blocked-account (`accountDeletion`) checks: Rumble has no such
  service.

## Changes by repo (all local, uncommitted)
- **rumble-data-shard-wrk**: `lib/utils/uma.validation.js` (new:
  normalizeUsername / getUmaPayloadFromWallet / walletToUmaResponse);
  Mongo wallets repo gets a unique sparse `username` index + `findByUsername` +
  `getActiveUserWalletWithUma`; `proc.addWallet` stamps `username`/`uma` onto a
  created user wallet via a follow-up unit-of-work write (dup-key →
  `ERR_UMA_USERNAME_TAKEN`); `api` adds + registers `getUmaByUserId`.
- **rumble-ork-wrk**: `api.ork.wrk.js` adds `lookupUmaUsername`, `getUmaByUserId`,
  `getUmaByUsername` (username → userId via the `uma_username` lookup → shard RPC)
  and an `addWallet` override that pre-checks uniqueness and reserves the lookup
  after create; the three read actions are registered.
- **rumble-app-node**: new `constants/uma-chains.js`, `utils/uma-defaults.js`
  (reads `conf.uma.domain`, not TW's `defaultDomain`), `services/uma.js` (ported
  lnurlp lookup/pay + uma payreq, minus suggest/check/blocked-account);
  `utils/uma.js` gains the chains/validation helpers; `services/ork.js` gains
  `getUmaByUsername`/`getUmaByUserId`/`getWalletById`; `services/indexer.js` gains
  `requestSparkPayreq`; `server.js` re-keys the lnurlp route to `:username` and
  adds `POST /api/uma/payreq/:uuid`; `http.node.wrk.js` injects the token username
  into `POST /wallets`; `config/common.json.example` documents
  `uma.supportedChains`/`currencies`/`commentAllowed`; response validator key
  updated to `:username`.

## Tests / verification
- `rumble-data-shard-wrk`: `uma.validation.unit.test.js` (new, 9 asserts);
  `getUmaByUserId` added to the api unit test; `addWallet` username-persistence +
  channel-skip added to the proc unit test. `test:unit` green except two
  **pre-existing** `rant*` failures in `rumble.server.util.unit.test.js`
  (reproduced with this work stashed — unrelated).
- `rumble-ork-wrk`: `uma.ork.unit.test.js` (new) — lookup, username→shard
  resolution, addWallet reserve/reject. `test:unit` fully green.
- `rumble-app-node`: `uma.service.unit.test.js` (new, 31 asserts) covers
  lookup/pay (lightning + EVM)/payreq/404; existing `uma.unit.test.js` still green.
  `http.node.wrk.intg.test.js` lnurlp test updated to the username flow + a uma
  payreq test added, BUT the intg file has a **pre-existing crash** at the
  balance test (uncaught TypeError on the balance mock, documented above) that
  aborts the run before the lnurl tests execute; verified pre-existing by stashing
  this work. The new flow is covered by the unit tests instead.
- `standard` lint clean on every file touched by this work.

## Review fixes
1. **lnurlp callback was GET-only, so external UMA payreq POSTs missed the handler
   (valid).** The lnurlp lookup advertised `callback = /api/lnurl/payreq/<sparkKey>`
   (GET-only), but the UMA spec POSTs the PayRequest to that callback, and the POST
   handler lived at a different path (`/api/uma/payreq/:uuid`) that nothing
   advertised. Fixed: the lookup now advertises `/api/uma/payreq/<receiverId>`, and
   that route is registered for **both POST** (UMA PayRequest body) **and GET**
   (plain-LNURL `?amount=`) via a shared handler, so one advertised callback serves
   both UMA and Lightning-Address senders. `getLnurlpCallback` →
   `getUmaPayreqCallback`. The legacy GET `/api/lnurl/payreq/:uuid` (spark-key) is
   kept for backward compatibility but is no longer the advertised callback. Unit +
   intg callback assertions updated. (Full UMA compliance — payerData/signature
   verification, currency conversion — remains a spark-indexer limitation, as
   before; the fix is about the callback being reachable by the spec's method.)

2. **UMA request signing / nonce / vaspDomain / payreq signature verification not
   implemented (valid spec gap, but inherited from TW — left as-is by direction).**
   The endpoints are UMA-shaped (response schema, `umaVersion: 1.0`, payerData) but
   skip the cryptographic VASP handshake. Verified TW does not implement this
   anywhere either: `@uma-sdk/core` is used in **zero** TW repos; no
   signature/nonce/vaspDomain/`fetchPublicKey`/`receivingVaspPrivateKey` logic, no
   `/.well-known/lnurlpubkey` route, no UMA signing key in TW config. The only
   `@uma-sdk` consumer in the workspace is the shared `wdk-indexer-wrk-spark`
   (`lnurl.js`), which generates **unsigned** responses
   (`receivingVaspPrivateKey: undefined`) and does no incoming verification.
   Direction was "mirror TW; if TW doesn't do it, say so" — TW doesn't, so nothing
   was ported. Closing the gap is a separate workstream (receiving-VASP keypair +
   `/.well-known/lnurlpubkey`, incoming signature+nonce verification, response
   signing in the spark indexer, payerData/Travel-Rule), needs key-custody
   decisions, and touches shared infra outside the Rumble overlay.

3. **UMA stamp was not atomic with wallet creation (valid) — made explicitly
   compensating.** `super.addWallet` commits the wallet, then `_persistWalletUma`
   was a second transaction; a failure there left a wallet with no UMA that a
   retry couldn't fix (base returns ERR_WALLET_ALREADY_EXISTS). True atomicity
   would mean forking the base's 170-line `addWallet` (no pre-commit seam exists),
   which breaks the extend-don't-fork layering — TW only gets away with a full
   fork because its wallet model is much simpler. Instead the stamp is now
   **all-or-nothing via compensation**: on a UMA-persist failure the just-created
   wallet is soft-deleted (`_rollbackWalletCreate` → base `deleteWallet`) and the
   error rethrown. Here the persist itself failed, so the wallet never carried a
   username; it is invisible to the base dup checks (`deletedAt` filtered) and not
   in the username index, so a retry recreates and re-stamps cleanly; the stamp is
   idempotent (upsert by id). (The case where the username WAS committed and the
   wallet later soft-deleted is handled by the partial username index — see Review
   fix #7.) Added a proc unit test asserting rollback + rethrow on persist failure.

4. **UMA was Mongo-only while the example config defaulted to HyperDB (valid) —
   made the Mongo requirement explicit.** UMA storage/lookup live only in the
   Mongo wallet repo; the HyperDB path was not ported. Confirmed TW's data-shard
   is **mongodb-only** (no `hyperdb` dir, factory throws `ERR_ADAPTER_NOT_SUPPORTED`
   for non-mongo, example defaults to mongodb), so per "mirror TW" the HyperDB path
   is intentionally not built. Instead the requirement is now explicit and loud:
   (a) `config/common.json.example` `dbEngine` default flipped `hyperdb` → `mongodb`
   (matches the deployed `common.json` and TW); (b) proc `addWallet` rejects a UMA
   user wallet up front with `ERR_UMA_REQUIRES_MONGODB_ENGINE` when
   `dbEngine !== 'mongodb'` (before any wallet is created, so no orphan); (c) api
   `getUmaByUserId` throws the same on a non-mongo engine instead of failing on a
   missing repo method. Added proc + api unit tests for the rejection.

5. **ork `uma_username` lookup could drift from the canonical wallet (valid) —
   made compensating + race-checked.** `super.addWallet` commits the shard wallet
   (and address lookups) before the ork writes the `uma_username` routing row; a
   failure there left a user with a username but no routing row (lnurlp 404, no
   repair on retry), and the `setOrIgnoreLookup` return (the real owner) was
   ignored so a lost race was silently accepted. The routing row is the public UMA
   source, so it now agrees with the wallet or the wallet is rolled back: the
   reserve is wrapped so (a) a write failure triggers `_rollbackUmaWallet`
   (ork `deleteWallet`, which also clears address lookups) and rethrows, and (b)
   `setOrIgnoreLookup` returning an owner != userId (lost race) rolls back and
   reports `ERR_UMA_USERNAME_TAKEN`. `setOrIgnoreLookup` is idempotent so retries
   converge. Added ork unit tests for the write-failure and lost-race paths.

6. **Advertised pay callback skipped amount/limit validation (valid) — now
   enforced.** `handleUmaPayreq` (the advertised callback after Review fix #1)
   never validated the amount, ignored the advertised `minSendable`/`maxSendable`,
   and defaulted a missing amount to `0`, so the sendability limits weren't
   authoritative. Added, before the layer branch (covers Lightning and EVM, both
   GET and POST): reject a missing/non-positive amount (`ERR_UMA_AMOUNT_INVALID`,
   no more `|| 0`) and enforce `getSendableLimits(uma)` bounds
   (`ERR_UMA_AMOUNT_TOO_SMALL`/`TOO_LARGE`), mirroring the `lnurlpPay` checks; the
   spark payreq URL now uses the validated amount. Also added a permissive Fastify
   `schema.body` on the POST route (`amount: integer`, `receivingCurrencyCode:
   string`, `additionalProperties: true` so UMA `payerData`/`compliance` survive)
   to honor the HTTP-boundary shape-validation rule; the authoritative semantic
   (min/max vs the resolved receiver) stays in the service since it can't be known
   at schema time. Added service unit tests for missing/zero/too-small/too-large.

7. **Soft-deleted wallets kept reserving the username forever (valid, real bug) —
   index made partial on active wallets.** The username index was `unique + sparse`
   on `{username}`; `softDel` sets `deletedAt` but leaves `username`, so a
   soft-deleted wallet stayed in the unique index and permanently burned the user's
   immutable username. This broke the Review-fix-#5 path: data-shard stamps the
   username → ork `uma_username` reserve fails → `deleteWallet` soft-deletes → the
   retry's `_persistWalletUma` then hits dup-key forever (and normal deletion had
   the same burn). Fixed: the index is now **partial unique**
   (`partialFilterExpression: { deletedAt: { $lte: 0 }, username: { $exists: true,
   $type: 'string' } }`, no `sparse` — Mongo forbids combining the two), so
   uniqueness applies only among active wallets, matching the `deletedAt <= 0`
   query convention used everywhere; a soft-deleted wallet releases its username
   and a retry recreates cleanly. This is what makes the #3/#5 compensation
   actually converge. Added a unit test locking the index definition. Caveat: real
   Mongo uniqueness-after-soft-delete is not exercised because this repo has no
   Mongo integration harness (its intg suite runs on hyperdb) — flagged for a
   follow-up Mongo intg test.

8. **UMA payreq treated the currency code as the settlement layer (valid) — now
   models layer + asset correctly.** `handleUmaPayreq` derived the layer from
   `receivingCurrencyCode` and compared it to `layerToChain` (layer names), so a
   `usdt`/`xaut` request fell through to Lightning and the EVM/Tron branch was only
   reachable by putting a chain name in `receivingCurrencyCode` — making the
   multi-chain `settlementOptions` the lookup advertises non-functional. Fixed to
   mirror `lnurlpPay`: the layer comes from `settlementLayer` (as advertised in
   `settlementOptions`, default `lightning`) and the asset from
   `settlementAsset`/`receivingCurrencyCode`; both go through
   `validateLnurlpPayParams`, plus a per-layer asset check
   (`getChainAssetIdentifiers`) so an asset the layer can't settle (e.g. usdt over
   Lightning) is rejected with `ERR_UMA_SETTLEMENT_ASSET_INVALID` instead of
   silently misrouted. POST body schema documents `settlementLayer`/`settlementAsset`.
   Added service tests: usdt on an EVM layer returns the EVM address; usdt with no
   compatible layer is rejected. (`lnurlpPay` already takes explicit layer/asset
   params and was not flagged; left as-is.)

9. **POST /api/v1/wallets dropped the inherited wallet-create rate limit (valid)
   — rate limit restored in the override.** The base WDK route's preHandler
   (`base server.js` `POST:/api/v1/wallets`) runs `auth.guard` **then**
   `rateLimitMiddleware` (`rateLimit.wallets.max || 100` per
   `rateLimit.wallets.timeWindow || 24h`, with the documented 429). Rumble
   replaces that whole preHandler in `http.node.wrk.js` `_setupRoutes` to add
   `channelOwnershipHandler`, and the replacement only carried auth — so the
   429 guard was gone on a write path that allocates wallets and creates
   cross-service `uma_username` lookup state. Note this gap predates RW-1920
   (the channel-ownership override already dropped it); the UMA username stamp
   was just added into the already-unprotected preHandler. Fixed on the Rumble
   side by composing the base protection back in: the override now runs
   `auth.guard` → `rateLimitMiddleware` (same conf keys/defaults as base) →
   `channelOwnershipHandler` → username stamp, so channel-ownership and UMA
   stamping layer on top of the limit rather than waiving it.
   `rateLimitMiddleware` is imported directly from
   `@tetherto/wdk-app-node/.../middlewares/rate.limit` (the base server imports
   it the same way; it is not re-exported on the middlewares index). Lint clean.
   No unit test added: the preHandler is wired inside the booted worker
   (`_setupRoutes`) and needs redis + a full worker to exercise; the only test
   that hits this route is the integration suite that already aborts on the
   pre-existing balance crash (see Still open), so there is no clean seam to
   assert the wiring without a brittle full-worker mock.

10. **Data-shard persisted request-controlled UMA domain/limit overrides (valid)
    — now stores the username only.** `getUmaPayloadFromWallet` copied
    `domain`/`minSendable`/`maxSendable`/`defaultSettlementLayer` off the
    incoming wallet (or its `uma` sub-object) into the persisted payload, and
    `walletToUmaResponse` returned them; app-node's `applyUmaDefaults` then let
    stored values win over config (`{ ...defaults, ...obj.uma }`). The HTTP
    schema blocks a normal client from sending those fields, but the internal
    HRPC path has no HTTP-boundary validation and ORK is unauthenticated, so a
    service-topic caller could poison a wallet's public UMA metadata (domain =
    payment identity, limits = sendability policy). This also contradicts the
    agreed Rumble model, stated in `uma-defaults.js` itself: Rumble stores only
    the username; domain and limits are deployment-level config. Fixed on the
    Rumble side by taking the finding's first option (store the normalized
    username only): `getUmaPayloadFromWallet` now returns `{ username }` and
    `walletToUmaResponse` returns `{ userId, walletId, username }`; the now-dead
    `uma` plumbing in `_persistWalletUma` was removed. App-node already fills
    domain/limits from config via `applyUmaDefaults`, so resolution is
    unchanged and the merge's "stored wins" branch is simply unreachable now
    (nothing is ever stored). This closes the vector at the source regardless of
    the app-node merge semantics. (Divergence from TW is sanctioned here: TW has
    username management + per-user settings; Rumble decided domain/limits are
    config-only.) Updated `uma.validation` unit tests to assert overrides are
    dropped on both extract and response, and strengthened the proc `addWallet`
    happy-path test to prove a request carrying `uma` overrides stores the
    username only (`saved[0].uma === undefined`, created wallet echoes no uma).
    Lint clean; validation 4/4, proc 37/37.

11. **UMA payreq lookup masked backend failures as a public 404 (valid) — error
    now propagates, only a real miss falls through.** `handleUmaPayreq` wrapped
    `getUmaByUserId` in a `try/catch` that swallowed any exception and fell
    through to the username lookup, which then returned `ERR_UMA_USER_NOT_FOUND`
    (404). A transient ORK failure, shard timeout, or
    `ERR_UMA_REQUIRES_MONGODB_ENGINE` config error therefore lied to the sender
    as "user not found" and hid the failure from retry/monitoring. The lookup
    contract already distinguishes the two cases: data-shard `getUmaByUserId`
    returns `null` for a genuine miss (`api.shard.data.wrk.js:218`) and **throws**
    for real errors (missing id / wrong engine, :214/:216); `getUmaByUsername`
    likewise returns null for an unknown username and throws on backend failure.
    Fixed by removing the swallowing catch: `let uma = await getUmaByUserId(...)`
    then `if (!uma) uma = await getUmaByUsername(...)`. A genuine miss (null)
    still falls through to the username-keyed fallback; a backend/config error
    now propagates with its own status (e.g. 500 for the engine error) instead
    of becoming a 404. Dropped the manual `logger.warn` (the framework error
    handler / Sentry logs the propagated error). Added two service tests: a null
    userId result still resolves via the username fallback; a thrown
    `ERR_UMA_REQUIRES_MONGODB_ENGINE` propagates rather than becoming
    `ERR_UMA_USER_NOT_FOUND`. Lint clean; uma service 17/17.

12. **Pay amounts parsed with truncating `parseInt` (valid) — strict integer
    parse.** `parseInt(amount, 10)` accepted malformed amounts and truncated
    decimals (`'1000abc'`→1000, `'1000.9'`→1000), so the service could mint a
    Spark invoice / return a settlement address for an amount different from what
    the sender supplied. Two call sites had it: `lnurlpPay` (the plain-LNURL GET
    `?amount=` path) and `handleUmaPayreq` (the advertised callback, GET feeds
    `req.query` so the POST body schema does not protect it). Added one
    `parseUmaAmount` helper (no dupe) that requires the whole value to be a safe
    positive integer (`number` → `Number.isSafeInteger && > 0`; `string` →
    `/^[0-9]+$/` then safe-int) and returns null otherwise; both sites now do
    `const n = parseUmaAmount(...); if (n === null) throw ERR_UMA_AMOUNT_INVALID`.
    Min/max enforcement and the spark payreq forward use the validated integer.
    Added service tests rejecting `1000abc`/`1000.9`/`1e3`/`0x10`/`-5`/`''` and a
    decimal number, with a clean integer string still accepted. Lint clean.

13. **New UMA HRPC errors unmapped at the app HTTP boundary (valid) — added to
    the worker error map.** The inherited `POST /api/v1/wallets` route maps HRPC
    errors via the worker error map (`rumbleErrorCodes`, loaded into
    `this.errorCodes` in `init`), NOT via the UMA service's `createAppError`
    statusCode (that path only covers the dedicated UMA routes, whose handler
    maps by `err.statusCode`). So `ERR_UMA_USERNAME_TAKEN` and
    `ERR_UMA_REQUIRES_MONGODB_ENGINE` propagating out of `ork.addWallet` (and the
    read-path `ERR_UMA_USERNAME_REQUIRED`) had no entries and fell through as
    generic 500s. Added to `errorsCodes.js`: `ERR_UMA_USERNAME_TAKEN: 409`
    (reservation conflict is a client conflict), `ERR_UMA_USERNAME_REQUIRED: 400`,
    `ERR_UMA_REQUIRES_MONGODB_ENGINE: 500` (deliberate deployment failure, not an
    accidental 500). App-node UMA service codes (amount/asset/etc.) stay on the
    `createAppError` statusCode path and need no map entry. Added a unit test
    locking the three statuses. Lint clean.

14. **Wallet create didn't fail / over-advertised UMA when the username claim was
    absent (valid) — advertisement now gated on a resolvable username.** The
    app-node preHandler stamps the username best-effort (`if (username) ...`), and
    `decorateWalletWithUma` advertised `uma` config on EVERY user wallet, so a
    wallet created without a persisted username still advertised a UMA handle that
    `getUmaByUsername` can't resolve. Chosen fix: gate the advertisement, NOT a
    hard 400 at creation. `decorateWalletWithUma` now resolves the username from
    the stored `wallet.username` (authoritative) or the owner's token username,
    and only attaches `uma` when one exists; otherwise the wallet passes through
    un-decorated. **Divergence from the finding's literal rec (hard-fail) is
    deliberate and TW-aligned:** the auth handler treats username as optional (the
    `/-wallet/v1/me` field name is still unconfirmed — see Still open), TW allows
    wallets without a username (separate username management), and noAuth test
    mode creates user wallets with no username — so a hard invariant would break
    legitimate creation flows and risk taking down all wallet creation if the
    claim is ever renamed/absent. Gating removes the false advertisement without
    that blast radius; in production (username always present) uma is still always
    advertised. Updated `uma.unit` decorate tests (stored-vs-token username
    resolution, no-username → no uma) and added stored usernames to the
    wallet-route intg stubs so they still assert uma. app-node uma.unit 7/7,
    uma.service 18/18; intg tests 1-8 green.

15. **UMA username persistence was a second uow after the base commit (valid) —
    now atomic, in the base unit of work (ALS).** `super.addWallet` committed the
    wallet, then `_persistWalletUma` opened a second uow for the username, so a
    crash between the two commits left an active user wallet with no username, and
    the compensating delete was best-effort. The base `addWallet` builds the
    wallet doc with a fixed field set and has no pre-commit seam, so it can't be
    matched to TW by a simple override; forking the base's ~170-line addWallet was
    rejected (duplication/divergence). Fix (user-chosen): the Rumble
    `WalletRepository.save` stamps the username onto the wallet doc INSIDE the
    base uow, scoped per-request via `AsyncLocalStorage`
    (`workers/lib/utils/uma.request-context.js`). The proc `addWallet` extracts
    the (single, caller-owned) username from `req.wallets` and runs
    `super.addWallet` inside `umaCreateContext.run({ username }, ...)`; the repo's
    save delegates to the base bulkWrite, so the wallet + username commit
    atomically. A dup-username (the unique partial index) makes the base commit
    reject and roll the whole create back; the proc maps `11000`/`E11000` to
    `ERR_UMA_USERNAME_TAKEN`. Removed `_persistWalletUma`, `_rollbackWalletCreate`
    and the post-commit stamping loop (no more compensating transaction). ALS is
    request-scoped (no cross-request leakage) and a no-op for updates, channel
    wallets and non-UMA creates. Reworked the proc addWallet tests (ALS carries
    the normalized username into the base uow; channel-only sets no context;
    dup-key → ERR_UMA_USERNAME_TAKEN) and added a wallet-repo save test. proc
    37/37, repo 2/2. (The ork-side `uma_username` lookup reservation is a separate
    cross-service step and is unchanged.)

16. **Data-shard UMA API test expected fields the shard now strips (valid) — test
    corrected.** Fallout from fix #10: `walletToUmaResponse` returns
    `{ userId, walletId, username }` only, but `api.shard.data.wrk.unit.test.js`
    still asserted `domain`/`minSendable` in the response. Updated the assertion
    to the username-only contract (and noted domain/limits come from app config),
    so the suite matches the helper and the app-node service. api.shard 8/8.

17. **App intg suite ran against the wrong config and hit unstubbed Redis (valid)
    — both fixed.** Two named issues: (a) `loadConf('common')` does
    `_.merge(this.conf, fileConf)` with the FILE as the merge source, and the
    worker keeps the passed conf BY REFERENCE, so `config/common.json` overwrote
    the inline test conf in place (uma.domain became `localhost`, maxSendable the
    huge default) and the first UMA assertion failed; (b) the restored
    wallet-create rate limiter (fix #9) calls `redis_r0.cli_rw.wdkAppNodeIdxRateLimit`,
    which the setup didn't stub, so POST /wallets hit a real Redis (ECONNREFUSED).
    Fixes: `tests/test-lib/hooks.js` snapshots the test conf (`_.cloneDeep`)
    before construction and re-merges it after the worker boots, so request-time
    reads see the test's values; the intg setup stubs `wdkAppNodeIdxRateLimit` as
    a plain function (survives the per-test `sandbox.reset()`). With both, intg
    tests 1-8 (incl. all wallet UMA assertions and the rate-limited POSTs) pass.
    Note (out of scope, flagged below): the legacy intg suite has pre-existing,
    non-UMA crashes after test 8 (balance/trend/notifications stubs use shapes the
    base response schemas reject, e.g. `token_balances` vs `tokenBalances`), which
    abort the run before the lnurlp/payreq route tests; and those UMA route tests
    additionally depend on the `@fastify/rate-limit` plugin's Redis store (base
    `_setupServer` passes `redis_r0.cli_rw`), which the redis-less harness can't
    serve. The lnurlp/payreq route LOGIC is covered by the uma.service unit tests
    (18/18). I reverted my exploratory balance/trend test edits to keep this diff
    scoped to UMA.

18. **Owned wallet without a stored username still advertised UMA via the token
    fallback (valid) — fallback removed, now TW-aligned.** Follow-up to #14: my
    gating still fell back to the owner's token username
    (`wallet.username || (ownsWallet ? user.username : undefined)`), so a wallet
    whose username was never persisted could still return `username` + `uma` on an
    owner response even though `getUmaByUsername` can't resolve it. Checked TW:
    it has no response decorator at all and attaches uma (via `applyUmaDefaults`,
    gated on `obj.username != null`) only when the wallet RECORD carries a
    username; username is optional at creation (client-supplied) and persisted on
    the record, never a response-only fallback. Fixed by gating
    `decorateWalletWithUma` purely on the stored `wallet.username` (dropped the
    token fallback and the now-unused `ownsWallet`). Safe because #15 persists the
    username atomically at creation, so the create response already carries it.
    Updated the decorate unit test (owned wallet with no stored username -> no uma;
    a wallet with its own stored username -> uma). uma.unit 7/7; intg 1-8 green.
    (This is the persist-based identity the finding asked for; creation stays
    non-failing on a missing claim, matching TW which also allows username-less
    wallets.)

19. **Direct LNURL GET pay could mint a Lightning invoice for a non-Lightning
    asset (valid) — per-layer check added to the lnurlpPay Lightning branch.**
    `lnurlpPay` (the `GET /.well-known/lnurlp/:username?amount=` path) returned
    from the Lightning branch without checking the asset belongs to Lightning, so
    `settlementLayer=lightning&settlementAsset=usdt` minted an `lnbc...` invoice
    (Lightning settles only `sat`). The POST callback (`handleUmaPayreq`, fix #8)
    already had this check; the GET path didn't. Checked TW: TW's `lnurlpPay` is
    structurally identical and has the SAME gap (no per-layer check in its
    Lightning branch), and `validateLnurlpPayParams` only checks the asset is
    globally configured — so this is a Rumble security hardening, not a TW-parity
    fix. Implemented minimally: added the same per-layer check
    (`getChainAssetIdentifiers(layerToChain[layer])`) inside `lnurlpPay`'s
    Lightning branch only, leaving `validateLnurlpPayParams` and the EVM branch
    TW-identical (the EVM branch already had its own asset check). A plain
    Lightning request with no asset is unaffected (check skipped when no asset).
    Added a service test (usdt on lightning via the GET path -> 400
    ERR_UMA_SETTLEMENT_ASSET_INVALID). uma.service 19/19, lint clean. NOTE: this
    plus fix #8 are the only two deliberate divergences from TW on the pay path
    (TW has the asset/layer gap on both paths); revert both if the team wants
    strict TW parity over the hardening.

20. **lnurlp lookup advertised a /api/uma/payreq/:userId callback instead of TW's
    spark callback (valid) — reverted to TW's callback, and removed the divergent
    GET route.** This unwinds my round-1 fix #1, which had repointed the callback
    to `/api/uma/payreq/:userId||username` and added GET+POST `/api/uma/payreq`
    routes. Checked TW `lnurlpLookup`: the callback is built by `getLnurlpCallback`
    -> `/api/lnurl/payreq/:identifier`, keyed on the wallet's `sparkIdentityKey`
    when present (Spark/Lightning receives proxy straight to the spark indexer,
    which does the UMA protocol work), else the `userId`, else the lnurlp self
    URL. Fixed to mirror TW exactly: renamed the helper to `getLnurlpCallback`
    (`/api/lnurl/payreq/`), and `lnurlpLookup` now does the same
    spark-key/userId/self branching. Also removed the GET `/api/uma/payreq/:uuid`
    route I had added (TW has POST only there) and simplified
    `handleUmaPayreqRoute` to POST-only (`req.body`); the plain-LNURL `?amount=`
    GET flow is already served by the lnurlp self URL (`lnurlpPay`) and the
    `/api/lnurl/payreq` spark proxy, so nothing is lost. Net route surface now
    matches TW: GET `/api/lnurl/payreq/:uuid` (spark proxy) + POST
    `/api/uma/payreq/:uuid` (UMA PayRequest). Updated the unit test (spark wallet
    -> `/api/lnurl/payreq/:sparkKey`; added a non-spark -> `/api/lnurl/payreq/:userId`
    case) and the intg lnurlp assertion. uma.service 20/20, uma.unit 7/7, intg
    1-8 green, lint clean.

## Round 4 review findings (verified against TW first)

21. **Existing wallets never become UMA-capable (real gap, but TW has it too) —
    no in-app code; ops migration.** App decorates only wallets with a stored
    username, and the data-shard stamps it only on new user-wallet creates, so
    pre-feature wallets stay non-resolvable. Verified TW: username is set only at
    creation (from the client body); there is no set-username route and PATCH does
    not accept it, and TW has no in-app backfill/migration either. So aligning with
    TW means NOT adding in-app backfill (that would diverge). Resolution: a
    one-time data migration to stamp `preferred_username` onto current user
    wallets, handled operationally outside this PR. No code change.

22. **POST UMA schema rejects string amounts (NOT a divergence) — no change.**
    TW's POST `/api/uma/payreq` schema is `amount: { type: 'integer' }`, identical
    to Rumble's, so a string amount is rejected the same way by both. The
    `parseUmaAmount` string handling serves the plain-LNURL GET `?amount=` path
    (query strings); on POST the body is pre-constrained to integer like TW. Left
    as-is to match TW.

23. **POST payreq URL passes sparkIdentityKey unencoded (matches TW) — no change.**
    TW's `handleUmaPayreq` builds the same URL unencoded and only encodes it on the
    GET path, so Rumble mirrors TW exactly. The value is a hex-encoded public key
    (no URL-significant chars), so the theoretical breakage cannot occur. Left as
    TW has it; a harmless `encodeURIComponent` could be added but would diverge from
    TW's code for no behavioral gain.

24. **UMA username lookup not removed on deletion (real divergence I introduced)
    — realigned to TW's permanent-identity model.** TW makes UMA identity permanent:
    `softDel` is disabled, the username index is `unique+sparse`, the ork lookup is
    never removed, and the ork has no create-failure compensation. My earlier
    fixes diverged: #7 made the index partial (releases the username on soft-delete)
    while the ork lookup stayed permanent, which is the asymmetry this finding
    describes; #5 added ork compensation TW lacks. Chosen resolution (user): match
    TW's permanence.
    - data-shard: reverted the username index from partial back to `unique+sparse`
      (matches TW); added a `softDel` override that throws
      `ERR_UMA_WALLET_DELETE_DISABLED` for any wallet carrying a username (UMA
      wallets are non-deletable, like TW). Scoped to UMA wallets (not TW's blanket
      disable) so Rumble's channel / username-less wallets still delete normally,
      a small justified Rumble accommodation.
    - ork: removed `_rollbackUmaWallet` and the owner-check/rollback in `addWallet`;
      it now mirrors TW exactly (pre-check `getLookup`, `super.addWallet`,
      `setOrIgnoreLookup` for created 201s, no rollback). The reservation is
      permanent and, with immutable per-user usernames, never reassigned across
      users, so no release path is needed (the original "another user blocked"
      concern cannot occur in Rumble's model).
    - tests: index test now asserts `unique+sparse` (no partial filter); added a
      softDel test (disabled for UMA, allowed for non-UMA); ork addWallet test
      drops the rollback cases and asserts the TW no-compensation shape. The proc
      atomic in-uow stamp (#15) and its dup-key -> `ERR_UMA_USERNAME_TAKEN`
      translation are unchanged and still green.
    - Caveat (accepted): an account/wallet-deletion path that soft-deletes a UMA
      wallet now errors (`ERR_UMA_WALLET_DELETE_DISABLED`); TW handles account
      removal by blocking, not deleting. There is no user-facing wallet DELETE
      route in Rumble or base WDK today.

## Still open
- Confirm the canonical UMA `domain` per environment and the exact
  `/-wallet/v1/me` username field name (still read defensively). This also gates
  whether the username invariant could be tightened from advertisement-gating
  (fix #14) to a hard create-time requirement.
- Pre-existing, non-UMA `http.node.wrk.intg.test.js` breakage (separate cleanup
  ticket, out of RW-1920 scope): (a) balance/trend/`/api/v1/balance`/notifications
  tests stub response shapes the base schemas reject (`token_balances` vs
  `tokenBalances`, `total` vs `balance`, trend `timestamp`/number vs `ts`/string),
  hard-crashing the run after test 8; (b) the lnurlp/payreq route tests depend on
  the `@fastify/rate-limit` plugin's Redis store (base `_setupServer` passes
  `redis_r0.cli_rw`), which the redis-less harness can't serve. Until these are
  addressed, the new UMA route intg tests can't run end-to-end in this suite; the
  route logic is covered by `uma.service.unit.test.js` (18/18).
- Mongo integration test for username uniqueness-after-soft-delete and for the
  atomic in-uow username stamp (fix #7/#15) — this repo's intg suite runs on
  hyperdb, so the Mongo-only behavior is currently locked by unit tests only.
