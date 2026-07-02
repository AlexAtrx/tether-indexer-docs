# WDK-1589 plan — migrate the user-data API to the wdk base layer

Covers both tickets: **WDK-1589** (this folder) and **WDK-1522** (batch set/get, folder 83,
open PRs tether-wallet-app-node #169, tether-wallet-ork-wrk #81, tether-wallet-data-shard-wrk #141).
Every fact below was verified on disk / via gh on 2026-07-02 (all repos on clean `dev`);
survey transcripts in the session scratchpad (`survey/`, `drift/`).

## 1. Verified current state

**wdk base (migration target) already owns the storage substrate, not the API:**

| Layer | Base repo | Has today | Missing |
|---|---|---|---|
| HTTP | wdk-app-node | nothing (`ERR_USER_DATA_SHARD_NOT_FOUND: 404` in errorsCodes.js:11 is the only mention) | routes, ork-service methods, error codes |
| Ork | wdk-ork-wrk | `purgeUserData` passthrough only (api.ork.wrk.js:305) | set/get/delete (+batch) forwarders |
| Shard | wdk-data-shard-wrk | proc `storeUserData`/`delUserData`/`purgeUserData` (proc:573-616,675), api `_storeUserData`/`_delUserData`/`_getUserData` helpers (api:126-144), Mongo repo `wdk_data_shard_user_data` + HyperDB repo `@wdk-data-shard/user-data` (spec collection id 3, already in base), staged-write UoW | public set/get/delete RPC handlers, validation, limits, `countByKeyPrefix`, `getUserDataMulti` |

Vigan's "I see them on data shard" = the seeds/entropies wrappers and private `_storeUserData`
helpers; there is no generic KV action on base main or dev.

**Both forks duplicate the API almost byte-for-byte** (ork forwarders and app-node ork-service
methods are literally identical; shard `_getUserDataLimits` is copy-pasted 4x: api+proc in both
forks, same defaults 128 / 65536 / 100 / `user_`; both `config/common.json.example` carry the
same `userData` block).

**Drift found (the full diff report is in the session scratchpad):**

1. **DELETE status**: TW 204 empty (server.js:925); Rumble 200 `{ success: true }`. The only
   known client (rumble-wallet-app-mobile `WalletApiClient.deleteUserData`) ignores the
   response entirely (`Promise<void>`), and only ever reads `.value` on GET.
2. **Error mapping**: TW maps `ERR_INVALID_KEY`/`ERR_INVALID_KEY_PREFIX`/`ERR_KEY_TOO_LONG`/
   `ERR_VALUE_TOO_LARGE`/`ERR_MAX_KEYS_EXCEEDED` to 400 via appError.js; Rumble has none of
   them in any map, so shard validation failures surface as **HTTP 500** on Rumble (and get
   captured by Sentry as server errors). Migration fixes this for free.
3. **Retry sets**: TW retries `getUserData` and `deleteUserData` across orks; Rumble only
   `getUserData`. `setUserData` non-retryable on both.
4. **Max-keys counting**: TW counts mutable + immutable repos; Rumble mutable only.
5. **TW-only**: immutable seeds/entropies handling (`immutableUserDataRepository`,
   `wdk_data_shard_user_data_immutable`, `isImmutableUserDataKey`, `_userDataRepoForKey`,
   `ERR_METHOD_DISABLED` delete guard), metadata LRU (`lru_15m` + `_getUserMetadata` +
   invalidation on 4 `user_*` keys in `setUserData`; note: TW `deleteUserData` does NOT
   invalidate — pre-existing staleness bug), `getUserDataMulti` (Mongo `$in`),
   `purgeUserData` no-op override, Sentry `_onRpcActionError` at ork+shard.
6. **Rumble-only**: HyperDB engine for user-data (TW factory is mongodb-only), its
   `countByKeyPrefix` hyperdb range-scan, a Mongo `countByKeyPrefix` with **unescaped**
   regex and no maxTimeMS (TW's version escapes and bounds — take TW's), warn-only
   response-validator entries.
7. **Batch (WDK-1522)**: exists only on TW `feat/user-data-batch-WDK-1522` branches / open PRs.
8. **Cohabitation constraint**: `devices`, `seeds*`, `entropies*` live in the SAME repository
   outside the `user_` keyspace; the prefix check is what protects them from client writes.
   Base changes must not alter `_getUserData(collection)` semantics.
9. **Stored shape** is identical in both forks (`doc.value = { value: <client value> }`,
   collection names unchanged) → **no data migration needed anywhere**.
10. **No other products affected**: org-wide code search hits only the two fork families
    (+ base + mobile client). No `city-*` repos visible to Alex; MiningOS unrelated.

## 2. Target architecture

Base gets the whole generic API; forks keep only genuinely product-specific overrides via
hooks (RW-1998 `_isDuplicateWallet` precedent).

### wdk-data-shard-wrk (base)
- **Repos**: add to abstract + Mongo + HyperDB `user.data.js`:
  - `countByKeyPrefix(userId, prefix)` — Mongo: TW's escaped-regex + maxTimeMS version
    (move `escapeRegexPrefix` into base); HyperDB: Rumble's range-scan version.
  - `getUserDataMulti(userId, keys)` — Mongo: TW's `$in` version; HyperDB: new (loop of
    `getUserData` or bounded range scan; no spec change — no new fields, append-only safe).
- **Shared limits util** `workers/lib/utils/userData.limits.js`: `getUserDataLimits(conf)`
  (kills the 4-way duplication); `config/common.json.example` gets the `userData` block.
- **api worker**: `_validateUserDataKey`, `setUserData` (validate + value-size check +
  `_procRpcCall('setUserData', req)`), `getUserData` (local read, `{ value: data?.value ?? null }`),
  `deleteUserData`, `setUserDataBatch` (per-entry validation, `ERR_INVALID_BATCH` /
  `ERR_BATCH_TOO_LARGE` / `ERR_DUPLICATE_KEY` / `ERR_VALUE_TOO_LARGE`, forward to proc),
  `getUserDataBatch` (one `getUserDataMulti`, `{ values: { key: value|null } }`).
  Register all five in the base api `rpcActions`.
  Hook: `_userDataRepoForKey(key)` default `this.db.userDataRepository` and use it in
  `_getUserData` (TW's existing override then keeps routing immutable keys).
- **proc worker**: `setUserData`, `deleteUserData`, `setUserDataBatch` (single UoW, one
  commit, upserts idempotent on HRPC redelivery), all built on existing base
  `storeUserData`/`delUserData` so TW's immutable-routing overrides keep working.
  Hooks:
  - `_countUserDataKeysForLimit(userId, prefix)` → default mutable `countByKeyPrefix`;
    TW overrides to add the immutable count.
  - `_onUserDataMutated(userId, keys)` → default no-op, called after successful
    set/batch-set/delete; TW overrides for `lru_15m` invalidation (this also fixes the
    TW delete-staleness bug as a side effect).
  Register `setUserData`/`deleteUserData`/`setUserDataBatch` in base proc `rpcActions`.

### wdk-ork-wrk (base)
- Five forwarders (`setUserData`, `getUserData`, `deleteUserData`, `setUserDataBatch`,
  `getUserDataBatch`): `resolveUserShardRpc(req.userId)` → `_rpcRequest({ shardId, ...req }, action)`.
  Add to base `rpcActions`. Sentry stays fork-side via the existing `_onRpcActionError` seam.

### wdk-app-node (base)
- Routes in `workers/lib/server.js` with TW's full schemas/swagger metadata
  (`tags: ['User data']`, response schemas, security): POST/GET/DELETE `/api/v1/user-data`
  + POST/GET `/api/v1/user-data/batch` (batch body `entries[]`, `maxItems:
  conf.userData?.maxKeysPerUser ?? 100`; GET `keys` string-or-array `anyOf`).
- `services/ork.js`: the five methods; add `getUserData`, `deleteUserData`,
  `getUserDataBatch` to `CORE_RETRYABLE_METHODS` (deletes are idempotent upsert/delete —
  safe to retry; unifies drift #3 upward).
- `utils/errorsCodes.js`: add `ERR_INVALID_KEY`, `ERR_INVALID_KEY_PREFIX`, `ERR_KEY_TOO_LONG`,
  `ERR_VALUE_TOO_LARGE`, `ERR_MAX_KEYS_EXCEEDED` (all 400), `ERR_INVALID_BATCH`,
  `ERR_BATCH_TOO_LARGE`, `ERR_DUPLICATE_KEY` (400), `ERR_METHOD_DISABLED` (403).
- Routes use the base errorCodes-Map errorHandler (no TW `createHandler` needed once the
  codes are in the map).

### tether-wallet-* (fork cleanup)
- Bump base pins, delete duplicated routes/service methods/forwarders/handlers/limits and
  their registrations; **keep**: `_userDataRepoForKey` + immutable repo + `userDataKeys.util`
  (`isImmutableUserDataKey`, `keyFromValue`), `_countUserDataKeysForLimit` override,
  `_onUserDataMutated` override (LRU), `delUserData` `ERR_METHOD_DISABLED` guard,
  `purgeUserData` no-op, Sentry overrides, `getUserLanguage` (app-node) — it just calls the
  now-base `getUserData`.
- appError.js keeps TW-specific extras; the user-data codes can stay (harmless duplicate of
  base map) or be dropped from the fork copy.

### rumble-* (fork cleanup)
- Bump base pins, delete duplicated routes/service methods/forwarders/handlers/limits, the
  `RUMBLE_EXTRA_RETRYABLE_METHODS` `getUserData` entry (now core), both `userdata.js` repo
  subclasses (countByKeyPrefix now in base, with the regex-escape fix), and the
  response-validator user-data entries (base routes carry real response schemas).
- Rumble inherits the batch endpoints and the 400 error mapping for free.
- Rumble's hand-rolled RPC registration loops just lose three entries; fork must ship the
  removal in the same release as the pin bump (each fork repo is one deployable, so there is
  no mixed-wire window; action names and payloads are unchanged for old ork ↔ new shard).

## 3. WDK-1522 fold-in (merge-order recommendation)

**Recommendation: fold WDK-1522 into WDK-1589 — implement batch directly in the base, close
or repurpose the three TW PRs.** Rationale: merging #169/#81/#141 first means landing ~550
lines into the fork and deleting them weeks later in the migration PR; the batch code is
already written and reviewed, so porting it into the base PRs is mostly a move (validation →
base api worker, UoW write → base proc, routes/service → base app-node). The TW PRs then
shrink to "bump pin + delete dup + keep overrides" and WDK-1522 closes when the base lands.
Needs a quick sign-off from Vigan/Francesco since WDK-1522 is In Progress with open PRs.
(Fallback if they want WDK-1522 shipped immediately: merge the three PRs as-is, then the
migration deletes the fork copies; functionally identical end state, more churn.)

## 4. PR train (9 PRs, strictly ordered)

| # | Repo | Content | Depends on |
|---|---|---|---|
| 1 | wdk-data-shard-wrk | repos + limits util + api/proc handlers + batch + hooks + tests | — |
| 2 | wdk-ork-wrk | 5 forwarders + registration + tests | 1 (for e2e only) |
| 3 | wdk-app-node | routes + ork service + retryables + error codes + config example + tests | — |
| 4-6 | tether-wallet-{data-shard,ork,app-node} | pin bump + dedup + keep overrides | 1-3 merged |
| 7-9 | rumble-{data-shard,ork,app-node} | pin bump + dedup + delete repo subclasses | 1-3 merged |

- Base PRs are purely additive → forks keep working on old pins until 4-9 land (no forced
  lockstep; conventions.md "mirror manually" applies).
- Version bumps per conventions.md: bump each base package.json (0.1.x → 0.2.0 makes sense,
  new API surface), forks pin the new SHAs, `npm install` in every dependent
  (mind the `~/.npmrc` @tetherto→GitHub-Packages 404 gotcha: install with
  `--@tetherto:registry=https://registry.npmjs.org`).

## 5. Intentional behavior changes shipped (to state in PR descriptions)

- Rumble: shard validation errors 400 instead of 500 (bugfix; also de-noises Sentry).
- Rumble: gains `/api/v1/user-data/batch` (POST+GET).
- Rumble: `deleteUserData` becomes ork-retryable (idempotent; matches TW).
- Rumble: DELETE `/api/v1/user-data` returns 204 empty instead of 200 `{success:true}`
  (base adopts TW semantics; mobile client provably ignores the response — flag to team).
- TW: `deleteUserData` now invalidates the metadata LRU (fixes a real staleness bug).
- TW: max-keys check semantics unchanged (immutable count preserved via hook).
- Nobody: no data migration, no collection/index changes, no RPC action renames.

## 6. Test plan

- Port TW's shard api/proc user-data unit tests + repo tests to base (they test generic
  behavior); port Rumble's `user-data.intg.test.js` (boots real hyperdb proc+api) to base —
  it becomes the base's engine-agnostic integration proof and covers the new hyperdb
  `getUserDataMulti`/`countByKeyPrefix`.
- Fork suites shrink to overrides: TW immutable routing / immutable count / LRU invalidation
  (incl. the new delete-invalidation) / Sentry; Rumble mostly deletions.
- Per repo: unit tests + `standard` lint green. E2E smoke: boot the local stack (or dev box)
  and curl the five endpoints on both TW and Rumble app nodes; verify single-key wire shapes
  are byte-identical to before.

## 7. Risks / conflicts to coordinate

- **Same-file open PRs**: wdk-ork-wrk #165 (tx-enrich, api.ork.wrk.js), wdk-data-shard-wrk
  #257 (api worker + **hyperdb spec files — append-only ordering conflict if both add spec
  entries**; our plan adds none, so risk is rebase-only), #263 remove-balance (same api/proc
  files), wdk-app-node #136/#139 (server.js/ork.js/errorsCodes.js),
  tether-wallet-app-node #159 (bumps the same base pin). Sequence with the team; rebase fast.
- Rumble hyperdb replication lag (api reads replica): batch GET after batch SET may lag,
  same as today's single-key behavior — not a regression, but worth a note in the batch docs.
- Open-source exposure: the base API text (swagger descriptions, error names) becomes public;
  keep naming generic (no TW/Rumble references).

## 8. Decisions (Alex, 2026-07-02)

1. **Fold WDK-1522 into the base migration.** Batch is implemented directly in the base
   PRs; #169/#81/#141 will be closed in favor of them (close when the base PRs are up,
   not before).
2. **Rumble wire changes approved:** DELETE unifies to 204 empty, shard validation errors
   become 400 (via the base error map).
