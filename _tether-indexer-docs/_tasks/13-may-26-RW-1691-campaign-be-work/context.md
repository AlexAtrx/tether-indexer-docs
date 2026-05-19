# RW-1691 — Campaign Builder Wallet BE — Working Context

This file is the self-contained context for the RW-1691 work. Reading it should be enough to pick the feature up on a different machine without losing background.

Last updated: 2026-05-19.

---

## 1. What this feature is

Rumble is building an admin "Campaign Builder" where staff create promo campaigns. Users redeem a shared promo code in the Rumble Wallet app and get paid on-chain.

The architecture change vs the legacy promo service: **Rumble now owns campaigns, codes, eligibility, geo, budgets, first-N logic, audit.** Wallet-BE only forwards claims, signs and broadcasts the payout transfer, and reports back.

Locked product decisions:
- Payout goes to the redeeming user's wallet (not a creator wallet).
- Codes are shared / reusable (one code, first-N eligible users redeem it).
- Rumble validates everything; wallet-BE never pre-accepts.
- Use a fresh promo payout wallet for V2 (separate seed key from any legacy hot wallet).
- Initial scope: Ethereum, tokens USAT + USDT.

---

## 2. Source spec

The implementation-ready spec lives in this same directory:

`_tether-indexer-docs/_tasks/13-may-26-RW-1691-campaign-be-work/campaign-builder-wallet-backend-spec-implementation-ready.md`

Note: that spec is **Alex's writeup** of the contract we agreed to. It is NOT Rumble's signed-off API reference. Some details (response shapes especially) ended up differing from Andrei's actual mock; the code reflects the mock, not the spec doc.

---

## 3. Repos involved

Both repos sit at the workspace root `/Users/alexa/Documents/repos/tether/_INDEXER/`.

| Repo | Role |
|---|---|
| `rumble-app-node` | HTTP entrypoint. Owns `POST /api/v2/promo/claim`, auth guard, rate limit. Forwards via HRPC to the worker. |
| `rumble-promo-wrk` | Worker. Talks to Rumble admin API, persists the payout, broadcasts on-chain, runs the settled/failed callback outbox. |

`rumble-promo-wrk` was **freshly cloned** into the workspace as part of this work (it was not present locally before). The AlexAtrx fork was created via `gh repo fork tetherto/rumble-promo-wrk` and `origin` now points to the fork; `upstream` is the `tetherto` org.

### Branches

Both repos: `feat/rw-1691-campaign-builder-v2`, based off `upstream/dev`.

### Remotes (both repos)

- `origin` → `AlexAtrx/<repo>` (SSH, the user's fork; this is where we push)
- `upstream` → `tetherto/<repo>` (the org we open PRs against)

### Open PRs

- `rumble-app-node` PR #211 → https://github.com/tetherto/rumble-app-node/pull/211 (open, mergeable, base `dev`)
- `rumble-promo-wrk` PR #46 → https://github.com/tetherto/rumble-promo-wrk/pull/46 (open, mergeable, base `dev`)

Neither is merged yet; both are out of draft.

### Dependency order

`rumble-promo-wrk` PR #46 should land first — `rumble-app-node` calls into a new `claimCodeV2` RPC method that lives in the worker. If `rumble-app-node` merges first, the route 503s until the worker ships.

---

## 4. End-to-end flow (current)

1. Wallet app: `POST /api/v2/promo/claim` with `{ code }` and an authed JWT.
2. `rumble-app-node` → `services/promo.v2.js#claimCode`:
   - Pulls `userId` from the auth session.
   - Resolves the user's single "unrelated" wallet via the ork (`getUserWallets`).
   - Reads client IP via `req.ip` (Fastify `trustProxy` is on in the base http server).
   - HRPC call to `rumble-promo-wrk` with `{ code, userId, clientIp, wallet }`.
   - On HRPC error, strips the `[HRPC_ERR]=` prefix before rethrowing so FE sees a clean `message`.
3. `rumble-promo-wrk` → `proc.promo.wrk.js#claimCodeV2`:
   - Picks the user's Ethereum address from the wallet object.
   - HMAC-signed `POST` to Rumble `/-wallet/v1/admin/campaign-redeem` with `{ code, id: userId, clientIp }` via `RumbleAdminClient`.
   - On 2xx: validates response (claimId required, amount must be a decimal string, token must be configured, decimals within bounds, chain must be ethereum). Any post-accept validation failure enqueues a `failed` callback so Rumble releases the budget, then throws `ERR_PROMO_SERVICE_UNAVAILABLE`.
   - On 4xx: throws the Rumble `errorCode` as-is (e.g. `ALREADY_CLAIMED`).
   - On 5xx / status 0 (network): throws `ERR_PROMO_SERVICE_UNAVAILABLE`.
   - On success: `INSERT OR IGNORE` into `promo_payouts_v2` keyed by `claimId`.
   - Returns to the app node which replies `202 { claimId, status: "received" }`.
4. Scheduler tick (`v2-process-payouts`, every 5s):
   - Pulls queued payouts per (chain, token) and assigns sequential nonces (wallet-wide).
   - **Sign-then-persist-then-broadcast**: builds + signs the tx locally, appends the hash to the row's `txHash` JSON array, then broadcasts. This invariant is what makes recovery deterministic.
   - On success: `setPayoutBroadcast` (status `broadcast`) and `callbacksV2.ensureEnqueued` a `settled` callback.
   - Same tick also runs `_recoverStuckV2Payouts` and `_finalizeCancellingV2Payouts` (see §6).
5. Scheduler tick (`v2-dispatch-callbacks`, every 5s):
   - Runs `_reconcileV2MissingCallbacks` first (backfill outbox rows for payouts that reached a terminal status without their corresponding callback row).
   - Then `_dispatchV2Callbacks` drains the outbox: signed POST to `campaign-claim-settled` or `campaign-claim-failed`, 2xx marks delivered (settled also flips the local payout to `paid`), non-2xx reschedules with exponential backoff until `callbackMaxRetries` then dead-letters.

---

## 5. Key files

`rumble-app-node` (`/Users/alexa/Documents/repos/tether/_INDEXER/rumble-app-node/`):
- `workers/lib/server.js` — V2 route registration.
- `workers/lib/schemas/promo.js` — request/response schemas.
- `workers/lib/services/promo.v2.js` — HTTP handler, HRPC pass-through.
- `workers/lib/services/index.js` — exports `promoV2`.
- `workers/lib/utils/errorsCodes.js` — Rumble rejection codes registered for status mapping. **Anything not in this map becomes 500 to FE**, so all thrown error strings from the worker must be either Rumble codes or one of the `ERR_*` entries here.

`rumble-promo-wrk` (`/Users/alexa/Documents/repos/tether/_INDEXER/rumble-promo-wrk/`):
- `workers/api.promo.wrk.js` — thin API worker, only exposes `claimCodeV2` RPC.
- `workers/proc.promo.wrk.js` — proc worker. Owns `claimCodeV2`, payout loop, recovery loop, cancelling-finalizer, callback dispatcher, reconciler, metrics.
- `workers/lib/rumble.admin.client.js` — HMAC-signed POST helper. Network errors normalized to `{ status: 0 }` (not rethrown).
- `workers/lib/wallet.bot.evm.v2.js` — multi-token EVM bot (USAT + USDT) with `signTransfer` / `broadcast` / `signCancel`.
- `workers/lib/queries/payouts.v2.js` — payout-table CRUD.
- `workers/lib/queries/payout_callbacks.v2.js` — outbox CRUD + metrics aggregate.
- `workers/lib/schema.js` — SQLite schema. `promo_payouts_v2` and `promo_payout_callbacks_v2` are in `SCHEMA_SQL` (created at startup), no `MIGRATIONS` array.
- `workers/lib/constants.js` — `PAYOUT_STATUSES_V2`, `CALLBACK_KINDS_V2`, `CALLBACK_STATUSES_V2`, `VALID_TOKENS_V2`, `VALID_BLOCKCHAINS_V2`.
- `config/proc.promo.json.example` — example config with `chainV2`, `rumbleAdmin`, `v2.*` knobs.

Reused from V1 era (kept, not rewritten): `workers/lib/gas.js`, `workers/lib/erc20.js`, `workers/lib/slack.notification.js`, `workers/lib/rate.limiter.js`.

V1 fully removed: old `claimCode` / `getCodeStatus` RPC, `_processClaimedCodes`, `_monitorPayingCodes`, V1 wallet bot, V1 queries, `promo_campaigns` and `promo_codes` tables, `scripts/` (pay-eth, pay-token, generate-codes), `nanoid` dep, the legacy promo eligibility HTTP call.

---

## 6. State machine

Payout row statuses (`PAYOUT_STATUSES_V2`):

```
queued
  └─> paying           (nonce assigned, attempting broadcast)
        ├─> broadcast  (success; settled callback enqueued)
        │     └─> paid (settled callback delivered)
        └─> cancelling (retries exhausted; cancel tx broadcast to consume nonce)
              ├─> paid (rare race: original payout actually landed; settled enqueued)
              └─> failed (cancel mined OR original reverted; failed callback enqueued)
```

Callback (outbox) statuses: `pending`, `delivered`, `dead`.

### Key invariants

1. **Sign-then-persist-then-broadcast.** Every hash the chain could possibly know about is in the DB before `broadcastTransaction`. Recovery uses the chain as ground truth: it never resubmits a tx that already landed, and it never tells Rumble "failed" when the user got paid.
2. **Idempotent on `claimId`.** `INSERT OR IGNORE` for both `promo_payouts_v2` and `promo_payout_callbacks_v2` (the latter via UNIQUE `(claimId, kind)`). Retries / reconciler / repeat redeems collapse cleanly.
3. **Cancel before fail.** When payout retries are exhausted with nothing on-chain, we sign + broadcast a 0-value self-transfer at the assigned nonce, transition to `cancelling`, and only mark `failed` once any tx (cancel or original) actually mines. Prevents leaving a nonce hole in the funding wallet's sequence.
4. **Reverted = consumed.** `status: 0` receipts (revert) consume the nonce just like `status: 1`, so they end the cancelling state. Receipt's `to` address distinguishes "user paid" (token contract → settled) from "cancel landed or payout reverted" (anything else → failed).
5. **Network errors are retryable, not 500.** `RumbleAdminClient._post` returns `{ status: 0 }` for non-HTTP errors so callers throw `ERR_PROMO_SERVICE_UNAVAILABLE` (503).
6. **Post-accept failures must call back.** Once Rumble has issued a `claimId`, any failure path (bad amount, unsupported token/chain, insert error) enqueues a `failed` callback before throwing so Rumble releases its budget reservation.
7. **Outbox reconciler.** If the proc crashes between `setPayoutBroadcast` and `ensureEnqueued`, the next dispatch tick finds the `broadcast` row with no corresponding `settled` callback and backfills it. Same for `failed`.

### Recovery / scheduler loops

- `v2-process-payouts` tick runs: `_processV2Payouts` → `_recoverStuckV2Payouts` → `_finalizeCancellingV2Payouts`.
- `v2-dispatch-callbacks` tick runs: `_reconcileV2MissingCallbacks` → `_dispatchV2Callbacks`.
- `collect-metrics` tick runs: `_collectV2Metrics` (logs + balance check).

---

## 7. Rumble API (Andrei's staging mock)

Base URL: `https://web190181.rumble.com`

**Important: requires the wallet-BE host to be on Rumble's staging IP allowlist.** Calls from a laptop won't work — Rumble's IP filter rejects them before signature check.

HMAC scheme = same as `transaction-init` / `transaction-complete` / `jar-sync` webhooks (already used in `rumble-data-shard-wrk`'s `RumbleServerUtil`): `x-signature` + `x-signed-on` headers, signing `timestampSeconds + JSON.stringify(body)` with HMAC-SHA256 using a shared secret.

### Endpoints

#### `POST /-wallet/v1/admin/campaign-redeem`

Request body:
```json
{ "code": "fakecode", "id": "<userId>", "clientIp": "8.8.8.8" }
```

Success (2xx):
```json
{ "claimId": "2576690190715342544", "amount": "10.00", "token": "USAT" }
```
(top-level fields; the spec doc's `{ data: {...} }` wrapper is NOT what the mock returns)

Rejection (4xx):
```json
{ "errorCode": "WRONG_GEO", "message": "User country is not in the campaign target geos" }
```
(again top-level; not `{ error: { code, message } }`)

To trigger a rejection from the mock, send `code: "ERR_<KIND>"` (e.g. `"ERR_WRONG_GEO"`). The mock echoes back the corresponding `errorCode` without the `ERR_` prefix.

Documented rejection codes (registered in `rumble-app-node/workers/lib/utils/errorsCodes.js`, all map to 409):
`CODE_NOT_FOUND`, `CAMPAIGN_NOT_ACTIVE`, `WRONG_GEO`, `STATE_BLOCKED`, `ALREADY_CLAIMED`, `RESTRICT_DAYS_HIT`, `BUDGET_EXHAUSTED`, `ELIGIBILITY_FAILED`, `USER_NOT_FOUND`.

#### `POST /-wallet/v1/admin/campaign-claim-settled`

Body: `{ claimId, walletAddress, txHash }` → returns `{ success: true }`.

#### `POST /-wallet/v1/admin/campaign-claim-failed`

Body: `{ claimId, walletAddress, reason }` → returns `{ success: true }`.

### Real API status

Andrei said the real API is "coming next week" (as of 2026-05-15). Until then this is a mock. When real ships, retest the four cases: happy path, each rejection code, network failure, accepted-then-malformed-response.

---

## 8. Configuration

Both repos need configuration before they boot V2:

### `rumble-promo-wrk` — `config/proc.promo.json`

Key blocks (see `proc.promo.json.example`):

- `chainV2.providerUrl` — Ethereum RPC (Alchemy/Infura/etc).
- `chainV2.tokens.USAT.{contract, decimals}` — mainnet USAT contract address (currently in example: `0x07041776f5007ACa2A54844F50503a18A72A8b68`, 6 decimals).
- `chainV2.tokens.USDT.{contract, decimals}` — mainnet USDT (`0xdAC17F958D2ee523a2206206994597C13D831ec7`, 6 decimals).
- `chainV2.seedKeyName` — `"seedPhraseV2"` (kept separate from any legacy seed key).
- `rumbleAdmin.url` — `"https://web190181.rumble.com"` for staging.
- `rumbleAdmin.secretToken` — HMAC secret. **Same one used by transaction webhooks**, get from ops/`rumble-data-shard-wrk` config.
- `v2.*` — schedules, batch sizes, retry counts, stale thresholds.

If `chainV2` or `rumbleAdmin` is missing the proc throws `ERR_V2_NOT_CONFIGURED` at startup and the worker won't accept RPCs.

### `rumble-app-node` — no V2-specific config

Just needs the existing `promoService` RPC keys (already used by V1) so the app-node knows which `rumble-promo-wrk` proc shard to talk to.

---

## 9. Open / pending decisions

| # | Item | Status |
|---|---|---|
| 1 | FE route shape (`/api/v2/promo/claim`, no path params) | Confirmed by FE / tech lead |
| 2 | FE error surface (Rumble code in `message` field, mapped to 409) | Confirmed (pass-through, no mapping) |
| 3 | Encrypted user id? | No, V1 sent raw `userId`; V2 does the same |
| 4 | Staging Rumble base URL | `https://web190181.rumble.com` (Andrei, 2026-05-15) |
| 5 | Prod Rumble base URL | Pending (coming with real API) |
| 6 | HMAC secret per env | Reuse the one already used by `transaction-init` / `jar-sync`; get from ops |
| 7 | Token contract addresses per env | Mainnet addresses in example; staging/prod values pending |
| 8 | Status endpoint (`GET .../claim/status`) | FE confirmed not called; deleted with V1 |
| 9 | V1 deprecation | Tech lead said "kill it" — done. V1 routes, queries, tables, scripts all removed. |
| 10 | Callback retry policy | Default `callbackMaxRetries=12` with exponential backoff (base 30s). Tune in prod. |
| 11 | Payout retry / cancel-retry policy | `payoutMaxRetries=6`, `cancelMaxRetries=6`. Tune based on observed mempool behavior. |

---

## 10. Test recipe (smoke test)

Once both services are deployed to a host on Rumble's IP allowlist with config in place:

```bash
curl -X POST https://<wallet-be-host>/api/v2/promo/claim \
  -H "Authorization: Bearer <user-jwt>" \
  -H "Content-Type: application/json" \
  -d '{"code": "fakecode"}'
```

Expected: `202 { "claimId": "...", "status": "received" }`. Andrei's mock returns success for **any** code string.

To exercise rejection paths: send `code: "ERR_WRONG_GEO"` (or any other `ERR_<CODE>` from the list above) and confirm the wallet app gets `409 { "message": "WRONG_GEO", ... }`.

For the async side (actual broadcast + settled callback): need a funded promo wallet on staging (ETH for gas + USAT/USDT for transfers). Without funds, the broadcast loop fails every cycle, eventually triggering the `cancelling → failed` path — which is itself a useful integration test of the failed-callback outbox.

---

## 11. Review threads (resolved)

PR #46 (`rumble-promo-wrk`) had three line comments + one general review, all addressed:

1. **Line `proc.promo.wrk.js:364`** — "Does `getTransaction` return from mempool or chain?" Updated comment + log to "the provider knows about this tx (mempool or just-mined)". Behavior unchanged.
2. **Line `proc.promo.wrk.js:369`** — "`enqueue` with `INSERT OR IGNORE` is misleading". Renamed `enqueueCallback` → `ensureEnqueued`; added a comment about at-least-once outbox semantics.
3. **`queries/payouts.v2.js:1`** — "Two tables, two files?" Split into `payouts.v2.js` + `payout_callbacks.v2.js`. Method names inside the callbacks module dropped the redundant `Callback` prefix (`markDelivered`, `markDead`, `reschedule`, `getDue`, `ensureEnqueued`, `gatherMetrics`).
4. **SargeKhan general review** — "why rewrite v1 paying logic vs extend?" Replied explaining the contract change (claimId-keyed payouts, sign-then-persist, callback outbox, cancelling state, multi-token, Rumble HMAC). Reusable infra (gas, erc20, slack, rate limiter, proc/api scaffold, seed loading, txHash JSON-array with 1.5x bump) was kept.

Later round of review found two more issues, both fixed in `c83fe94`:

- Unsupported token/chain was throwing dynamic `ERR_UNSUPPORTED_TOKEN_<X>` / `ERR_UNSUPPORTED_CHAIN_<X>`, not registered in errorsCodes → 500. Now throws `ERR_PROMO_SERVICE_UNAVAILABLE` → 503. Detail still in failed-callback reason.
- Stale comment in `rumble.admin.client.js` referencing the old `{data: {...}}` / `{error: {code, message}}` shape. Updated to match the mock.

---

## 12. Known follow-ups / risks

- **Real Rumble API behavior unknown.** The mock returns success for any code; real API will gate on actual code validity. Retest happy path + rejection codes when real lands.
- **Funded staging wallet required for end-to-end test.** Operationally Rumble funds the wallet; we'll get an address when the seed is generated at first boot of the worker against staging config.
- **No tests added for V2.** The repo has `tests/` with brittle tests for V1; V2 is currently uncovered. Worth adding before prod.
- **`gatherMetrics` lives in `payout_callbacks.v2.js`** even though it touches both tables. Justified in the file as "the metrics loop is callback-anchored"; if it grows, consider a dedicated `metrics.v2.js`.
- **Cancel cancel-retry budget.** If the cancel tx itself keeps getting dropped (very unusual since it's a 0-value self-transfer with bumped fees), after `cancelMaxRetries=6` the row sits in `cancelling` indefinitely and a Slack alert fires. Operator intervention required.
- **HRPC error prefix strip is V2-only.** Done in `services/promo.v2.js`. Other routes still have the `[HRPC_ERR]=` prefix in their FE responses; that's a wdk-app-node-wide bug we didn't tackle here.

---

## 13. Workspace skills / docs to know

Project-local skills (see `_INDEXER/CLAUDE.md` and `_INDEXER/.claude/CLAUDE.md`):
- `fetch-asana-ticket` — pulls Asana ticket into `_tasks/<slug>/`. Used to seed this folder.
- `refresh-todos` — refreshes `_tether-indexer-docs/TODO.md` from Asana.
- `commit` — sanity-check, branch, commit, push to AlexAtrx fork, returns draft PR links.
- `pr-review`, `code-review`, `pr-triage`, `security-review` — various review skills.

Authoritative repo / architecture docs:
- `_tether-indexer-docs/___TRUTH.md` — long-form architecture truth.
- `_INDEXER/.claude/repos.md` — repo inventory.
- `_INDEXER/.claude/CLAUDE.md` — service layering (proc/api split, Hyperswarm, HMAC patterns).

User-level brain:
- `/Users/alexa/Documents/repos/brain_v1/projects/tether/TODO.md` — Alex's personal Tether tickets list (this ticket may or may not be linked there).

---

## 14. Picking the work up

If you're reading this on a different machine in a fresh session, do this first:

1. `cd /Users/alexa/Documents/repos/tether/_INDEXER/`
2. Confirm both repos are present. If `rumble-promo-wrk` is missing: `gh repo clone tetherto/rumble-promo-wrk`, then `cd rumble-promo-wrk && gh repo fork && git remote rename origin upstream && git remote add origin git@github.com:AlexAtrx/rumble-promo-wrk.git && git fetch --all`.
3. Check out the branch in both: `git checkout feat/rw-1691-campaign-builder-v2`.
4. `git pull origin feat/rw-1691-campaign-builder-v2` to grab the latest from the fork.
5. Read this file plus the spec doc in the same dir.
6. Visit the two open PRs to see the latest review state.

Then resume wherever Alex left off (most likely waiting on Andrei's real API, or addressing further reviews).
