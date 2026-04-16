# WDK Indexer - Engineering Truth

Last Updated: 2026-04-16
Scope: `_INDEXER` workspace only (current code + tracked `_tether-indexer-docs` material in this repo)

---

## 1. Architecture Decisions (Current Runtime)

- **Gateway split**
  - `wdk-indexer-app-node` is the public API-key HTTP surface for direct address-based indexer queries.
  - `wdk-app-node` is the authenticated wallet/user HTTP surface.
  - `rumble-app-node` is the Rumble-specific extension of `wdk-app-node`.
- **Request paths**
  - Wallet/user path: app node → ork → data shard → chain indexer RPC.
  - Public indexer path: indexer app → chain indexer topic RPC (`{blockchain}:{token}`).
- **Worker pattern**
  - Proc workers own sync/write work and emit a proc RPC key.
  - API workers are read-side and require the matching proc RPC key.
- **Internal transport**
  - Hyperswarm RPC uses shared `topicConf.capability` + crypto key across services.
  - Transfer fan-out uses Redis streams in addition to shard polling.
- **Storage / lookup choices**
  - Chain indexers and shards support `dbEngine: hyperdb | mongodb`.
  - Ork and processor lookup storage support `lookupEngine: autobase | mongodb`.
- **Transfer ingestion model**
  - Two paths exist in code today:
    - shard polling jobs (`syncWalletTransfers`)
    - Redis stream pipeline: indexer base `xadd` → `@wdk/transactions:{chain}:{token}` → (processor, external to this workspace) → `@wdk/transactions:shard-{shardGroup}` consumed by shard
  - The workspace does not enforce one canonical path.
- **Processor repo is not part of this workspace**
  - `wdk-indexer-wrk-base/workers/proc.indexer.wrk.js` publishes to `@wdk/transactions:{chain}:{token}`.
  - `wdk-data-shard-wrk/workers/proc.shard.data.wrk.js` consumes `@wdk/transactions:shard-{shardGroup}`.
  - The bridging `wdk-indexer-processor-wrk` is referenced by the 2026-04-15 discrepancy investigation but is not checked into this workspace; treat it as an external dependency when reasoning about runtime.
- **Migration reality**
  - Current runtime still treats wallet create/update as canonical storage only.
  - Migration snapshot/reconciliation exists in tasks/plans, not in shipped runtime code.
- **Local orchestration**
  - `_wdk_docker_network_v2` is a Rumble-focused local stack: Mongo + Redis + local DHT bootstrap + one USDT/EVM indexer + Rumble shard/ork/app.
  - It does not run a full multi-chain stack.

---

## 2. Delivered Features (Verified In Code)

### 2.1 `wdk-indexer-app-node`

- `GET /api/v1/health`, `GET /api/v1/chains`
- direct address routes: `/api/v1/:blockchain/:token/:address/token-transfers` and `/.../token-balances`
- batch routes: `POST /api/v1/batch/token-transfers`, `POST /api/v1/batch/token-balances`
- `GET /register` HTML form and `POST /api/v1/request-api-key`
- Swagger UI at `/docs`
- API keys are generated in plaintext, HMAC-hashed before storage (`utils.hashApiKey`) and emailed in plaintext body
- inactive-key cleanup cron `revokeInactiveKeysInterval` defaults to `0 2 * * *` with `inactivityThresholdDays: 30`
- config whitelist chains currently cover: ethereum, sepolia, plasma, avalanche, arbitrum, polygon, tron, ton, solana, bitcoin, spark

### 2.2 `wdk-app-node`

- authenticated wallet/user balance and transfer routes, including:
  - `GET /api/v1/wallets/:walletId/token-transfers`
  - `GET /api/v1/users/:userId/token-transfers`
  - `GET /api/v1/users/:userId/spark/bitcoin/token-transfers`
- `GET /api/v1/ready` returns `503` / `ERR_NO_ORKS_AVAILABLE` when ork discovery is empty
- `_refreshOrks()` keeps the previous ork list when a refresh returns empty
- Redis-backed cached routes use `CACHE_TTL_MS = 30000`; `cache=false` skips both read and write
- `/api/v1/balance/trend` is served through the ork (`getUserBalanceHist`) and is currently degraded on staging/prod (see §4)

### 2.3 `wdk-ork-wrk` + `wdk-data-shard-wrk`

- Ork resolves user/wallet/address → shard lookups via Autobase or MongoDB lookup storage
- Ork registers `wallet.meta.spark.sparkDepositAddress` into the address lookup during wallet create/update (`api.ork.wrk.js:440-444`) — see §4 (RW-1526)
- Shard owns canonical wallet, balance, user-data, and wallet-transfer storage
- Shard supports both:
  - polling sync from indexers (`syncWalletTransfers`)
  - Redis shard-stream consumption (`@wdk/transactions:shard-{shardGroup}`) with consumer group, blocking reads, claim of pending messages, and trim of old messages
- code-default job schedules: `syncBalances` `0 */6 * * *`, `syncWalletTransfers` `*/5 * * * *`
- `proc.shard.data.json.example` overrides to `syncBalances "0 0 * * *"` (daily), `syncWalletTransfers "*/30 * * * * *"` (30s); timeouts default `syncBalances=1_200_000 ms` (20 min), `syncWalletTransfers=600_000 ms` (10 min)
- `getUserTransfers` computes direction per wallet (`type = ownedFrom ? 'sent' : 'received'`) — fixes the WDK-1287 filter bug — and is unit-tested
- `getUserTransfers` includes `sparkDepositAddress` in the per-wallet address list used to match transfers (`api.shard.data.wrk.js:345-347`) — this is the mechanism behind the phantom-BTC-history bug
- transfer APIs remain flat wallet-transfer rows; no grouped logical transaction-history layer is present

### 2.4 Indexer Redis stream boundary

- `wdk-indexer-wrk-base/workers/proc.indexer.wrk.js` batches `pipe.xadd` onto `@wdk/transactions:{chain}:{token}` with default `publishBatchSize = 100`
- the shard consumes the shard-scoped stream `@wdk/transactions:shard-{shardGroup}`; the bridging processor that rewrites keys lives outside this workspace
- payload is still CSV `raw`, not JSON (`TRANSACTION_MSG_TYPES.NEW_TRANSACTION = 'new_transaction'`)

### 2.5 Chain indexers

- active worker repos in this workspace:
  - `wdk-indexer-wrk-evm`, `wdk-indexer-wrk-btc`, `wdk-indexer-wrk-solana`, `wdk-indexer-wrk-ton`, `wdk-indexer-wrk-tron`, `wdk-indexer-wrk-spark`
- base indexer capabilities:
  - circuit-breaker defaults `failureThreshold=3`, `resetTimeout=30000`, `successThreshold=2`
  - deterministic provider selection via `getProviderBySeed()`
  - optional metrics manager / Prometheus hooks
  - `hyperdb | mongodb` storage
- BTC indexer persists `metadata.inputs` in indexer transfer records
- Solana proc still deletes the `sync-tx` scheduler entry at startup

### 2.6 Rumble extensions

- `rumble-app-node` adds device, MoonPay, notification, swaps, logs, and admin transfer routes
- Swagger UI is protected with docs basic auth; fallback is `admin` / `password` if `docsAuth` config is missing
- `noAuth=true` is rejected when `ctx.env === 'production'`
- Sentry only starts when `conf.sentry.enabled=true`
- Fastify/Sentry error handler ignores `error.validation`, 4xx status codes, and mapped `errorCodes` below 500
- MoonPay buy/sell webhook handlers warn-and-skip when `externalCustomerId` is missing
- MoonPay `SWAP_COMPLETED` is still unsupported and throws (`SWAP_COMPLETED_NOT_SUPPORTED_PAYLOAD_MISSING`)
- `rumble-ork-wrk` uses LRU idempotency for `SWAP_STARTED`, `TOPUP_STARTED`, and `CASHOUT_STARTED`
- `rumble-data-shard-wrk` uses LRU transfer dedupe, defaults device `isActive = true`, and runs tx-webhook processing on `*/10 * * * * *` (every 10 seconds)

---

## 3. Not Present In Current Runtime

- no migration snapshot / reconciliation runtime endpoints, storage tables, or scheduled reconciliation jobs
- no `tx-history v2` / grouped logical transfer pipeline in runtime code (no `processTransferGroup`, `underlyingTransfers`, `wallet_transfers_processed`, `totalAmount`, `feeToken`)
- no backend `/config` or `/feature-flags` endpoint for Spark / Plasma rollout
- no JSON stream payload between indexers and shards (still CSV `raw`)
- no `wdk-indexer-processor-wrk` repo in this workspace (runtime likely depends on it externally — see §1)

---

## 4. Challenges / Weak Points

- **`sparkDepositAddress` pollutes BTC history (RW-1526, 2026-04-15)**
  - Ork registers `sparkDepositAddress` as a wallet-owned address in the global lookup.
  - Shard `getUserTransfers` also injects `sparkDepositAddress` into the per-wallet match set.
  - Result: MoonPay → Spark deposits appear as BTC transfers in `/api/v1/users/{userId}/token-transfers` even though on-chain BTC balance for the main address excludes them, producing a structural mismatch between `token-transfers` and balance for every user who has used MoonPay-to-Spark. No financial loss; full UX/data-correctness bug.
  - No `token=btc` or address filter is applied by the mobile app; the backend makes no distinction between main BTC address and Spark deposit address.
- **`/api/v1/balance/trend` returns empty for real users (2026-04-15)**
  - Trend endpoint is only as good as `syncBalancesJob` snapshots, and the job has five interacting failure modes (full breakdown lives in `_tasks/15-apr-26-Xaxis-is-incorrect/analysis.md`):
    1. RPC call explosion: `users × wallets × chains × ccys` (~14 ccy slots) per run.
    2. `_processUserBalanceIfMissing` skips the user entirely when `bal.balance === null`, even if individual `tokenBalances` succeeded — a single transient RPC failure on e.g. `spark:btc` voids the whole snapshot.
    3. On abort (`getSignal()?.aborted`) the job `return`s before flushing the tail pipe, losing up to ~499 buffered entries.
    4. `_saveBalanceBatch` catches errors by clearing the pipe (`pipe = []`) — a DB write failure silently drops up to 500 user snapshots.
    5. `range=all` falls back to `new Date(0)` when no snapshots exist, producing 10 buckets spanning 1970–2026 that all return null.
  - Usman's PR #186 fixed the MongoDB cursor lifetime and abort plumbing, but the above five remain.
- **Push notification decimal precision (RW-1601, 2026-04-16)**
  - `rumble-app-node/workers/lib/server.js` declares `amount: { type: 'number' }` at lines 220 (v1) and 304 (v2).
  - Imprecise floats (e.g. `0.026882800000000002`) are then interpolated verbatim into the push template (`notification.util.js:87-126`, plain `${amount}`), so every externally-triggered template — `TOKEN_TRANSFER`, `TOKEN_TRANSFER_RANT`, `TOKEN_TRANSFER_TIP`, `SWAP_STARTED`, `TOPUP_STARTED`, `CASHOUT_STARTED`, and the topup/cashout `*_COMPLETED` variants — can exhibit the artifact.
  - Indexer-sourced notifications (internal `TOKEN_TRANSFER_COMPLETED` path) escape the bug only because the indexer hands over a pre-formatted decimal string; they are correct by accident, not by design.
- **Partial balance display debate (2026-04-08, PR `wdk-data-shard-wrk#205`)**
  - Tech-lead rejects showing partial balances on chart/history; no durable fallback (last-known balance cache) has been shipped.
  - A prior attempt to cache last-known balance was scoped out; decision is still "app handles it", but no owner/PR closes the loop.
- **Dual ingestion path remains ambiguous**
  - shard polling and processor-based streams both exist; freshness bugs are harder to reason about.
  - the 2026-02-27 staging lag (fresh transfers in indexer, stale history in shard/app) is consistent with a processor/propagation fault, not a chain-indexer fault.
- **Legacy transfer APIs are still flat rows**
  - runtime returns wallet-transfer rows, not one logical transaction per on-chain action.
- **BTC sender-side history is still weak**
  - indexer parses one row per output; shard wallet-transfer schema has no fee/change/input fields.
  - user/wallet history derives direction from wallet ownership of `from`; the user-level merge still does not dedupe self-transfers across wallets.
- **BTC balance fetch path is operationally fragile**
  - balance uses `scantxoutset` on bitcoind; busy/in-progress cases map to `ERR_SCANTXOUTSET_BUSY`.
  - March/April tasks still report zero/missing BTC balances.
- **Solana sync is intentionally disabled**
  - `sync-tx` is removed on startup in the Solana proc worker.
- **Notification dedupe / idempotency are memory-only**
  - restart loses transfer dedupe and manual-notification idempotency state.
- **MoonPay support is still partial**
  - missing `externalCustomerId` no longer 500s, but notification delivery is skipped.
  - `SWAP_COMPLETED` remains unimplemented.
- **Docs / setup drift exists**
  - `_wdk_docker_network_v2/README.md` tells developers `make up`; the Makefile's `up` target only brings up Mongo + Redis — `up-all` is the full stack.
  - public indexer chain list in config is broader than the chain worker repos checked in.

---

## 5. Security / Risk Areas

- **Service-to-service trust is shared-secret based** — no mTLS or service-identity layer in this workspace.
- **API keys are delivered in plaintext email** — hashed at rest, but initial delivery is still inline in an email body.
- **Rumble docs auth has dangerous defaults** — falls back to `admin` / `password` when `docsAuth` config is missing.
- **Auth bypass toggle exists** — `noAuth` is guarded against production but is still a high-risk deployment setting.
- **Sentry is config-gated, not environment-gated** — enabling Sentry in non-prod is a deployment choice, not a code guard.
- **Notification templates reflect upstream payloads verbatim** — any imprecise float / malformed string hits users (RW-1601).
- **Logging / sensitive-data hygiene remains active work** — tasks/minutes still track Sentry noise, false positives, and log masking concerns.

---

## 6. Must-Have Gaps To Reach Top Industry Standard

- pick one canonical ingestion path (stream vs polling) and instrument freshness / parity indexer → processor → shard → app.
- ship or retire the grouped transaction-history v2 API; runtime still serves legacy `/token-transfers`.
- distinguish on-chain BTC from Spark-deposit BTC at the API layer (dedicated label/field or separate endpoint) and fix balance aggregation to match history semantics.
- make `syncBalancesJob` partial-success safe: persist `tokenBalances` even when aggregated `balance` is null, flush on abort, retry/record failed batches, add per-user backfill, and add per-run observability counters.
- enforce strict decimal contracts on notification payloads (string + regex / BigInt) across the `/api/v2/notifications` boundary.
- persist BTC fee / input / change context end-to-end and use it in wallet-history responses.
- harden BTC balance reads with fallback providers or dedicated infrastructure.
- move transfer dedupe and manual notification idempotency to durable storage.
- replace shared topic secrets with stronger service identity / trust controls.
- if migration remains active, add dedicated snapshot + reconciliation endpoints rather than overloading wallet create/update.
- tighten setup/docs drift so local and staging behavior are reproducible.

---

## 7. Good Add-Ons

- remote config / feature-flag endpoint for Spark / Plasma rollout.
- admin tooling to inspect processor lag, pending Redis stream messages, and shard freshness.
- daily automated parity checks between direct indexer queries and shard/app history.
- dedicated Bitcoin node / provider pool tuned for balance and history workloads.
- unified typed contracts across indexer app, wallet app, and Rumble extensions.
- last-known-balance cache to avoid dropping trend snapshots on transient RPC failures.

---

## 8. Active TODOs (Source-Backed)

- [ ] Separate main-BTC-address transfers from `sparkDepositAddress` transfers in shard queries (and/or filter on FE) — RW-1526.
- [ ] Save balance snapshots on partial success (`tokenBalances` non-null) instead of skipping users when aggregated balance is null.
- [ ] Flush the pipe on `syncBalancesJob` abort; retry or persist batches that fail to save.
- [ ] Tighten `/api/v2/notifications` schema to require a decimal string, and make templates defensive on number inputs — RW-1601.
- [ ] Resolve BTC balance inconsistency / zero-balance reports still carried over from March tasks.
- [ ] Decide whether processor-stream ingestion or shard polling is the supported default, then document and monitor it.
- [ ] Ship or retire the grouped transaction-history v2 design.
- [ ] Carry BTC change / input / fee context into shard wallet history.
- [ ] Add durable dedupe/idempotency for notifications and transfer processing.
- [ ] Either re-enable Solana `sync-tx` or document it as unsupported.
- [ ] Implement MoonPay `SWAP_COMPLETED` or explicitly retire it.
- [ ] If migration is still ongoing, build a separate migration snapshot + reconciliation path.
- [ ] Align public docs / example config / docker instructions with the actual runnable stack.
- [ ] Harden docs auth defaults so `/docs` never falls back to a known credential pair.

---

## 9. Verification Spot Checks

| Claim | Verification Source |
|------|----------------------|
| Public indexer app exposes `/register`, `/api/v1/request-api-key`, `/api/v1/chains`, `/api/v1/health`, direct address token-transfer/balance routes, and batch routes | `wdk-indexer-app-node/workers/lib/server.js:223,239,309,348,423,459,494,584` |
| API keys are HMAC-hashed, emailed in plaintext, and inactive-key cleanup defaults to `0 2 * * *` / `30` days | `wdk-indexer-app-node/workers/lib/services/api.key.js:28,31`, `wdk-indexer-app-node/config/common.json.example:14-15` |
| `wdk-app-node` returns `ERR_NO_ORKS_AVAILABLE`, keeps old ork list on empty refresh, and `cache=false` skips cache read/write | `wdk-app-node/workers/lib/services/ork.js`, `wdk-app-node/workers/base.http.server.wdk.js`, `wdk-app-node/workers/lib/utils/cached.route.js` |
| Ork registers `sparkDepositAddress` in lookup; shard `getUserTransfers` also includes it in wallet address set | `wdk-ork-wrk/workers/api.ork.wrk.js:440-444`, `wdk-data-shard-wrk/workers/api.shard.data.wrk.js:345-347` |
| `syncBalancesJob` timeout, signal abort, and pipe-clear-on-error behaviour | `wdk-data-shard-wrk/workers/proc.shard.data.wrk.js:90,662,784,800-804` |
| `proc.shard.data.json.example` cron overrides for syncBalances / syncWalletTransfers | `wdk-data-shard-wrk/config/proc.shard.data.json.example:3-6` |
| Indexer stream fan-out uses Redis `xadd` to `@wdk/transactions:{chain}:{token}`; shard consumes `@wdk/transactions:shard-{shardGroup}` | `wdk-indexer-wrk-base/workers/proc.indexer.wrk.js:362,434`, `wdk-data-shard-wrk/workers/proc.shard.data.wrk.js:1321-1324` |
| Indexer → shard payload is still CSV raw `new_transaction` | `wdk-indexer-wrk-base/workers/lib/constants.js:3`, `wdk-data-shard-wrk/workers/proc.shard.data.wrk.js:1047` |
| BTC balance uses `scantxoutset`, maps busy scans to `ERR_SCANTXOUTSET_BUSY`; BTC parser persists `metadata.inputs` | `wdk-indexer-wrk-btc/workers/lib/providers/rpc.provider.js:79,86-89` |
| Solana proc disables `sync-tx` at startup | `wdk-indexer-wrk-solana/workers/proc.indexer.solana.wrk.js:28` |
| WDK-1287 per-wallet type filter is computed and unit-tested | `wdk-data-shard-wrk/workers/api.shard.data.wrk.js:364,379`, `wdk-data-shard-wrk/tests/unit/api.shard.data.wrk.unit.test.js:418` |
| Rumble docs auth fallback, production `noAuth` guard, Sentry filtering | `rumble-app-node/workers/lib/services/auth.js:64-82`, `rumble-app-node/workers/http.node.wrk.js:124,137-146` |
| MoonPay missing-`externalCustomerId` warn-and-skip and unsupported `SWAP_COMPLETED` | `rumble-app-node/workers/lib/services/moonpay.utils.js:92-93,126-127,153-154` |
| `/api/v2/notifications` body schema accepts `amount: number` and templates use raw `${amount}` | `rumble-app-node/workers/lib/server.js:220,304`, `rumble-data-shard-wrk/workers/lib/utils/notification.util.js:87-126` |
| `rumble-data-shard-wrk` tx-webhook cron is `*/10 * * * * *` (every 10s) | `rumble-data-shard-wrk/workers/proc.shard.data.wrk.js:64` |
| Circuit breaker defaults `failureThreshold=3`, `resetTimeout=30000`, `successThreshold=2` | `wdk-indexer-wrk-base/workers/lib/rpc.base.manager.js:60-62` |
| Docker drift: README says `make up`, Makefile's `up` = Mongo+Redis, `up-all` = full stack | `_wdk_docker_network_v2/README.md`, `_wdk_docker_network_v2/Makefile` |

---

## 10. Recent Changes (Keep Last ~10)

| Date | Change | Status |
|------|--------|--------|
| 2026-04-16 | Push notification decimal precision bug (RW-1601): `/api/v2/notifications` schema accepts float `amount`; template interpolates raw `${amount}`, producing IEEE-754 artifacts in user-visible pushes | Open — fix at caller + schema + template |
| 2026-04-15 | RW-1526 phantom BTC transactions: `sparkDepositAddress` registered in ork lookup and included in shard `getUserTransfers` causes MoonPay→Spark transfers to show in BTC history while balance excludes them | Open — affects all users with MoonPay→Spark |
| 2026-04-15 | `/api/v1/balance/trend` returns empty data (X-axis ticket): root cause is 5 interacting `syncBalancesJob` failures (RPC fan-out, null-balance skip, abort-loses-pipe, batch-save-loses-pipe, range=all bootstrap); Usman PR #186 fixed only cursor lifetime + abort plumbing | Open — primary cause is null-balance skip at proc.shard.data.wrk.js:662 |
| 2026-04-08 | Partial balance display debate on PR `wdk-data-shard-wrk#205`: tech-lead rejects partial displays; no last-known-balance fallback is implemented | Open |
| 2026-03-23 | `getUserTransfers` per-wallet type computation covers the WDK-1287 filter; cross-wallet self-transfer dedupe still absent at the user-level merge | Partially reflected in code |
| 2026-03-17 | Migration reconciliation analysis and build plan exist; no runtime endpoints or scheduled jobs present in workspace | Planned only |
| 2026-03-06 | BTC sender-side amount bug documented; runtime still uses flat output-level wallet transfers | Open |
| 2026-03-05 | MoonPay missing-`externalCustomerId` path changed from 500/error to warn-and-skip; Rumble Sentry false-positive filter (validation + 4xx + mapped errorCodes) landed | Reflected in code |
| 2026-02-27 | Staging history lag: indexers had fresh transfers while shard/app history was stale — consistent with processor/propagation fault, not indexer fault | Still a risk |
| 2026-02-19 | Spark / Plasma feature-flag endpoint discussed; no backend remote-config endpoint in current runtime | Planned only |

---

## 11. References

- `WARP.md`, `GEMINI.md`
- `_tether-indexer-docs/about_Tether.md`
- `_tether-indexer-docs/app-structure-and-diagrams/`
- `_tether-indexer-docs/analysis-2026-01-14/`
- `_tether-indexer-docs/app_setup/`
- `_tether-indexer-docs/_tasks/` (priority: `15-apr-26-1-check-discrepancy`, `15-apr-26-Xaxis-is-incorrect`, `16-apr-26-1-The-amount-in-the-push-looks-with-incorrect-decimals`, `8-apr-26-1-`, `2-march-2026/17-march-26-Migration-Reconciliation-Job`, `2-march-2026/6-march-26-BTC-transactions-logged-with-incorrect-amounts`)
- `_wdk_docker_network_v2/`
