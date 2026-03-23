# WDK Indexer - Engineering Truth

Last Updated: 2026-03-23
Scope: `_INDEXER` workspace only (current code + tracked `_tether-indexer-docs` material in this repo)

---

## 1. Architecture Decisions (Current Runtime)

- **Gateway split**
  - `wdk-indexer-app-node` is the public API-key HTTP surface for direct address-based indexer queries.
  - `wdk-app-node` is the authenticated wallet/user HTTP surface.
  - `rumble-app-node` is the Rumble-specific extension of `wdk-app-node`.
- **Request paths**
  - Wallet/user path: app node -> ork -> data shard -> chain indexer RPC.
  - Public indexer path: indexer app -> chain indexer topic RPC (`{blockchain}:{token}`).
- **Worker pattern**
  - Proc workers own sync/write work and emit a proc RPC key.
  - API workers are read-side and require the matching proc RPC key.
- **Internal transport**
  - Hyperswarm RPC uses shared `topicConf.capability` + crypto key across services.
  - Transfer fan-out can also use Redis streams.
- **Storage / lookup choices**
  - Chain indexers and shards support `dbEngine: hyperdb | mongodb`.
  - Ork and processor lookup storage support `lookupEngine: autobase | mongodb`.
- **Transfer ingestion model**
  - Two paths exist in code today:
    - shard polling jobs (`syncWalletTransfers`)
    - Redis stream routing via `wdk-indexer-wrk-base` -> `wdk-indexer-processor-wrk` -> shard stream consumer
  - The workspace does not enforce one canonical path.
- **Migration reality**
  - Current runtime still treats wallet create/update as canonical storage only.
  - Migration snapshot/reconciliation exists in tasks/plans, not in shipped runtime code.
- **Local orchestration**
  - `_wdk_docker_network_v2` is a Rumble-focused local stack: Mongo + Redis + local DHT bootstrap + one USDT/EVM indexer + Rumble shard/ork/app.
  - It does not run `wdk-indexer-processor-wrk` or a full multi-chain stack.

---

## 2. Delivered Features (Verified In Code)

### 2.1 `wdk-indexer-app-node`

- `GET /api/v1/health`
- `GET /api/v1/chains`
- direct address routes for `token-transfers` and `token-balances`
- batch transfer/balance routes
- `/register` HTML request form plus `POST /api/v1/request-api-key`
- Swagger UI at `/docs`
- API keys are generated in plaintext, HMAC-hashed before storage, and emailed to the requester
- inactive-key cleanup exists with default cron `0 2 * * *` and threshold `30` days

### 2.2 `wdk-app-node`

- authenticated wallet/user balance and transfer routes, including:
  - `GET /api/v1/wallets/:walletId/token-transfers`
  - `GET /api/v1/users/:userId/token-transfers`
  - `GET /api/v1/users/:userId/spark/bitcoin/token-transfers`
- `GET /api/v1/ready` returns `503` / `ERR_NO_ORKS_AVAILABLE` when ork discovery is empty
- `_refreshOrks()` keeps the previous ork list if topic lookup temporarily returns empty
- Redis-backed cached routes use `CACHE_TTL_MS = 30000`
- `cache=false` skips both cache read and write

### 2.3 `wdk-ork-wrk` + `wdk-data-shard-wrk`

- Ork resolves user/wallet/address -> shard lookups via Autobase or MongoDB lookup storage
- Shard owns canonical wallet, balance, user-data, and wallet-transfer storage
- Shard supports both:
  - polling sync from indexers (`syncWalletTransfers`)
  - Redis shard-stream consumption (`@wdk/transactions:shard-{shardGroup}`)
- code fallback job schedules:
  - `syncBalances`: `0 */6 * * *`
  - `syncWalletTransfers`: `*/5 * * * *`
- repo example config currently overrides those with more aggressive values (`0 0 * * *` / `*/30 * * * * *`)
- legacy transfer APIs remain flat wallet-transfer reads; no grouped logical history layer is present

### 2.4 `wdk-indexer-processor-wrk`

- the processor repo is present and active in code
- it consumes per-chain Redis streams `@wdk/transactions:{chain}:{token}`
- it resolves wallet -> shard ownership through lookup storage
- it forwards raw transfers to shard streams `@wdk/transactions:shard-{shardGroup}`
- payload format is still CSV `raw`, not JSON

### 2.5 Chain indexers

- active worker repos in this workspace:
  - `wdk-indexer-wrk-evm`
  - `wdk-indexer-wrk-btc`
  - `wdk-indexer-wrk-solana`
  - `wdk-indexer-wrk-ton`
  - `wdk-indexer-wrk-tron`
  - `wdk-indexer-wrk-spark`
- base indexer capabilities:
  - circuit-breaker defaults `failureThreshold=3`, `resetTimeout=30000`, `successThreshold=2`
  - deterministic provider selection via `getProviderBySeed()`
  - optional metrics manager / Prometheus hooks
  - `hyperdb | mongodb` storage
- current checked-in config files cover:
  - EVM: `eth`, `sepolia`, `usdt-arb`, `usdt-eth`, `usdt-plasma`, `usdt-pol`, `usdt-sepolia`, `xaut-eth`, `xaut-plasma`
  - BTC: `bitcoin`
  - Solana: `solana`, `usdt-sol`
  - TON: `ton`, `usdt-ton`, `xaut-ton`
  - TRON: `tron`, `usdt-tron`
  - Spark: `spark`
- BTC indexer persists `metadata.inputs` in indexer transfer records
- Solana proc still deletes the `sync-tx` scheduler entry at startup

### 2.6 Rumble extensions

- `rumble-app-node` adds device, MoonPay, notification, swaps, logs, and admin transfer routes
- Swagger UI is protected with docs basic auth
- if docs auth is unset, code falls back to `admin` / `password`
- `noAuth=true` is rejected in production
- Sentry only starts when `conf.sentry.enabled=true`
- Fastify/Sentry integration ignores validation errors and other mapped 4xx cases
- MoonPay buy/sell webhook handlers warn-and-skip when `externalCustomerId` is missing
- MoonPay `SWAP_COMPLETED` is still unsupported and throws
- `rumble-ork-wrk` uses LRU idempotency for `SWAP_STARTED`, `TOPUP_STARTED`, and `CASHOUT_STARTED`
- `rumble-data-shard-wrk` uses LRU transfer dedupe, defaults device `isActive` to `true`, and runs tx-webhook processing on `*/10 * * * * *`

---

## 3. Not Present In Current Runtime

- no migration snapshot / reconciliation runtime endpoints, storage tables, or scheduled reconciliation jobs
- no `tx-history v2` / grouped logical transfer pipeline in runtime code:
  - no `processTransferGroup`
  - no `underlyingTransfers`
  - no `wallet_transfers_processed`
  - no `totalAmount` / `feeToken` wallet-history layer
- no backend `/config` feature-flag endpoint for Spark / Plasma rollout
- no JSON stream payload between indexers, processor, and shards

---

## 4. Challenges / Weak Points

- **Dual ingestion path remains ambiguous**
  - shard polling and processor-based streams both exist
  - this makes freshness bugs harder to reason about
- **Stale history has been observed in docs/tasks**
  - Feb 27 evidence shows indexers had fresh transfers while shard/app history lagged
  - the likely fault domain is propagation/processing, not raw chain indexing
- **Legacy transfer APIs are still flat rows**
  - runtime returns wallet-transfer rows, not one logical transaction per on-chain action
  - tx-history v2 docs/tasks are ahead of shipped code
- **BTC sender-side history is still weak**
  - indexer parses one row per output
  - shard wallet-transfer schema has no fee/change/input fields
  - user/wallet history still derives direction mostly from wallet ownership of `from`
  - `WDK-1287` fixed the `type=` filter to use computed per-wallet type, but the user-level merge still does not dedupe self-transfers across wallets
- **BTC balance fetch path is operationally fragile**
  - balance uses `scantxoutset`
  - busy/in-progress cases map to `ERR_SCANTXOUTSET_BUSY`
  - March tasks still report zero/missing BTC balances
- **Solana sync is intentionally disabled**
  - `sync-tx` is removed on startup in the Solana proc worker
- **Notification dedupe / idempotency are memory-only**
  - restart loses transfer dedupe and manual-notification idempotency state
- **MoonPay support is still partial**
  - missing `externalCustomerId` no longer 500s, but notification delivery is skipped
  - `SWAP_COMPLETED` remains unimplemented
- **Docs / setup drift exists**
  - `_wdk_docker_network_v2/README.md` says `make up` starts everything, but the Makefile uses `up-all` for the full stack
  - public indexer chain list in example config is broader than current checked-in chain worker configs

---

## 5. Security / Risk Areas

- **Service-to-service trust is still shared-secret based**
  - no mTLS or equivalent service identity layer is visible in this workspace
- **API keys are delivered in plaintext email**
  - they are hashed at rest, but initial delivery remains email-body plaintext
- **Rumble docs auth has dangerous defaults**
  - docs basic auth falls back to `admin` / `password` if config is missing
- **Auth bypass toggle exists**
  - `noAuth` is protected against production, but it is still a high-risk deployment setting
- **Sentry is config-gated, not environment-gated**
  - enabling Sentry in non-prod is a deployment choice, not a hard code guard
- **Logging / sensitive-data hygiene remains active work**
  - minutes/tasks still track Sentry noise, false positives, and log masking concerns

---

## 6. Must-Have Gaps To Reach Top Industry Standard

- pick one canonical ingestion path and instrument freshness / parity across indexer -> processor -> shard -> app
- ship one canonical grouped transaction-history API, or explicitly retire the v2 contract work
- persist BTC fee / input / change context end-to-end and use it in wallet-history responses
- harden BTC balance reads with fallback providers or dedicated infrastructure
- move transfer dedupe and manual notification idempotency to durable storage
- replace shared topic secrets with stronger service identity / trust controls
- if migration remains active, add dedicated snapshot + reconciliation endpoints rather than overloading wallet create/update
- tighten setup/docs drift so local and staging behavior are reproducible

---

## 7. Good Add-Ons

- remote config / feature-flag endpoint for Spark / Plasma rollout
- admin tooling to inspect processor lag, pending Redis stream messages, and shard freshness
- daily automated parity checks between direct indexer queries and shard/app history
- dedicated Bitcoin node / provider pool tuned for balance and history workloads
- unified typed contracts across indexer app, wallet app, and Rumble extensions

---

## 8. Active TODOs (Source-Backed)

- [ ] Resolve BTC balance inconsistency / zero-balance reports from March tasks
- [ ] Decide whether processor-stream ingestion or shard polling is the supported default, then document and monitor it
- [ ] Ship or retire the grouped transaction-history v2 design; runtime still serves legacy `/token-transfers`
- [ ] Carry BTC change / input / fee context into shard wallet history
- [ ] Add durable dedupe/idempotency for notifications and transfer processing
- [ ] Either re-enable Solana `sync-tx` or document it as unsupported
- [ ] Implement MoonPay `SWAP_COMPLETED` or explicitly retire it
- [ ] If migration is still ongoing, build a separate migration snapshot + reconciliation path
- [ ] Align public docs / example config / docker instructions with the actual runnable stack
- [ ] Harden docs auth defaults so `/docs` never falls back to a known credential pair

---

## 9. Verification Spot Checks

| Claim | Verification Source |
|------|----------------------|
| Public indexer app exposes `/register`, `/api/v1/request-api-key`, `/api/v1/chains`, direct token transfer/balance routes, and batch routes | `wdk-indexer-app-node/workers/lib/server.js` |
| API keys are HMAC-hashed, emailed in plaintext, and inactive-key cleanup defaults to `0 2 * * *` / `30` days | `wdk-indexer-app-node/workers/lib/services/api.key.js`, `wdk-indexer-app-node/workers/lib/services/email.js`, `wdk-indexer-app-node/workers/base.http.server.wdk.js`, `wdk-indexer-app-node/config/common.json.example` |
| `wdk-app-node` returns `ERR_NO_ORKS_AVAILABLE`, keeps old ork list on empty refresh, and `cache=false` skips cache read/write | `wdk-app-node/workers/lib/services/ork.js`, `wdk-app-node/workers/base.http.server.wdk.js`, `wdk-app-node/workers/lib/utils/cached.route.js` |
| Wallet/user token-transfer routes exist, including Spark/Bitcoin user transfer route | `wdk-app-node/workers/lib/server.js` |
| Processor repo consumes `@wdk/transactions:{chain}:{token}` and forwards to `@wdk/transactions:shard-{shardGroup}` | `wdk-indexer-processor-wrk/workers/indexer.processor.wrk.js`, `wdk-indexer-processor-wrk/README.md` |
| Indexer stream payload is still CSV `raw`, and shard consumer still parses CSV | `wdk-indexer-wrk-base/workers/proc.indexer.wrk.js`, `wdk-data-shard-wrk/workers/proc.shard.data.wrk.js` |
| BTC balance uses `scantxoutset`, maps busy scans to `ERR_SCANTXOUTSET_BUSY`, and BTC parser persists `metadata.inputs` in indexer records | `wdk-indexer-wrk-btc/workers/lib/providers/rpc.provider.js`, `wdk-indexer-wrk-base/workers/proc.indexer.wrk.js`, `wdk-indexer-wrk-base/workers/lib/db/hyperdb/build.js` |
| Solana proc disables `sync-tx` | `wdk-indexer-wrk-solana/workers/proc.indexer.solana.wrk.js` |
| `WDK-1287` self-transfer `type=` filtering is covered in code/tests | `wdk-data-shard-wrk/workers/api.shard.data.wrk.js`, `wdk-data-shard-wrk/tests/unit/api.shard.data.wrk.unit.test.js` |
| Rumble docs auth, production `noAuth` guard, Sentry filtering, MoonPay missing-`externalCustomerId` handling, and unsupported `SWAP_COMPLETED` are current | `rumble-app-node/workers/http.node.wrk.js`, `rumble-app-node/workers/lib/services/auth.js`, `rumble-app-node/workers/lib/services/moonpay.utils.js` |

---

## 10. Recent Changes (Keep Last ~10)

| Date | Change | Status |
|------|--------|--------|
| 2026-03-23 | `getUserTransfers` type filter bug (`WDK-1287`) is now covered by code/tests; self-transfer dedupe across wallets is still absent | Partially reflected in code |
| 2026-03-17 | Migration reconciliation gained strong analysis/build plans, but no runtime endpoints/jobs are present in the current workspace | Planned only |
| 2026-03-17 | Balance-fetching issue reopened; March task material still points to BTC RPC failures / missing balances | Open |
| 2026-03-06 | BTC sender-side amount bug documented; runtime still uses flat output-level wallet transfers | Open |
| 2026-03-05 | MoonPay missing-`externalCustomerId` path changed from 500/error to warn-and-skip | Reflected in code |
| 2026-03-05 | Rumble Sentry false-positive cleanup landed: validation and other 4xx cases are filtered out of Sentry handling | Reflected in code |
| 2026-02-27 | Staging history lag was observed: indexers had fresh transfers while shard/app history was stale | Still a risk |
| 2026-02-19 | Spark / Plasma feature-flag strategy discussed; no backend remote-config endpoint is present in current runtime | Planned only |
| 2026-02-19 | tx-history v2/grouped endpoint still not on staging/production per minutes and remains absent from current runtime code | Not shipped |
| 2026-02-11 | Address-based / seed-phrase history design was discussed; current runtime still relies on the public indexer API plus legacy wallet/user transfer routes | Partially covered |

---

## 11. References

- `WARP.md`
- `GEMINI.md`
- `_tether-indexer-docs/about_Tether.md`
- `_tether-indexer-docs/app-structure-and-diagrams/`
- `_tether-indexer-docs/analysis-2026-01-14/`
- `_tether-indexer-docs/app_setup/`
- `_tether-indexer-docs/meeting-minutes/`
- `_tether-indexer-docs/_tasks/`
- `_wdk_docker_network_v2/`
