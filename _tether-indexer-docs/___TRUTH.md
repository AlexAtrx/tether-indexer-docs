# WDK Indexer - Engineering Truth

Last Updated: 2026-03-19
Scope: `_INDEXER` workspace only (current code + `_tether-indexer-docs` material in this repo)

---

## 1. Architecture Decisions (Current)

- **Gateway split**
  - `wdk-indexer-app-node` serves public indexer APIs with API-key auth.
  - `wdk-app-node` and `rumble-app-node` serve wallet/user APIs over ork + shard services.
- **Routing model**
  - App node -> ork -> data shard -> chain indexer topic RPC (`{chain}:{token}`).
- **Proc/API split**
  - Proc workers own sync/write paths.
  - API workers own read/query RPC and require proc RPC keys.
- **Internal trust model**
  - Service communication is Hyperswarm/topic based with shared `topicConf.capability` + crypto keys.
  - There is no identity-based transport layer in the current workspace.
- **Storage model**
  - Core workers still support `dbEngine: hyperdb | mongodb`.
  - `wdk-ork-wrk` lookup storage still supports `lookupEngine: autobase | mongodb`.
- **Transfer ingestion model**
  - The reliable runtime path in this workspace is still shard polling (`syncWalletTransfers`) from indexers.
  - Redis-stream plumbing exists, but it is partial: indexers publish chain/token streams while shards consume shard-group streams.
- **Migration reconciliation model**
  - Frontend migration snapshots are append-only records in shard storage.
  - Reconciliation runs/results are computed per shard, then merged by ork and exposed through admin endpoints.
- **Caching**
  - `wdk-app-node` uses Redis-backed cached routes with `CACHE_TTL_MS = 30000`.
  - `cache=false` skips both cache reads and writes.
- **Local orchestration note**
  - `_wdk_docker_network_v2` is a partial local stack: Mongo + Redis + DHT bootstrap + EVM indexer + Rumble shard/ork/app.
  - It is not a full multi-chain WDK stack.

---

## 2. Delivered Features (Verified in Code)

### 2.1 `wdk-indexer-app-node`

- Public chain discovery, token transfer, token balance, and batch APIs.
- API-key request flow via `/register` and `/api/v1/request-api-key`, with rate limits.
- Swagger UI at `/docs`.
- API keys are generated in plaintext, HMAC-hashed before storage, and the plaintext key is emailed to the requester.
- Inactive API-key cleanup exists with code/example defaults:
  - cron `0 2 * * *`
  - inactivity threshold `30` days

### 2.2 `wdk-app-node`

- Wallet, user, balance-trend, token-balance, and `.../token-transfers` APIs.
- `GET /api/v1/ready` returns `503` with `ERR_NO_ORKS_AVAILABLE` when no ork is available.
- `_refreshOrks()` keeps the previous ork list if topic discovery temporarily returns empty.
- Migration endpoints now exist:
  - `POST /api/v1/wallets/migration-snapshot`
  - `POST /api/v1/admin/migration-reconciliation/trigger`
  - `GET /api/v1/admin/migration-reconciliation/runs`
  - `GET /api/v1/admin/migration-reconciliation/runs/:runId/results`
  - `GET /api/v1/admin/migration-reconciliation/metrics`
- Migration admin access is gated by admin role claims or `conf.migrationReconciliation.adminUserIds`.

### 2.3 `wdk-ork-wrk` + `wdk-data-shard-wrk`

- Ork resolves user/wallet/channel -> shard lookups and supports Autobase or MongoDB lookup storage.
- Shard still owns canonical wallet, user, balance, and transfer data.
- Migration storage is present in both engines:
  - `migration-wallet-snapshots`
  - `migration-reconciliation-runs`
  - `migration-reconciliation-results`
- Reconciliation statuses in code:
  - `MATCH`
  - `MISMATCH`
  - `MISSING_IN_FE`
  - `MISSING_IN_BE`
  - `OWNED_BY_OTHER_USER`
- Ork fans out reconciliation to all shards and merges per-shard metrics.
- Ork has a scheduled migration reconciliation slot at `0 3 * * *` when `migrationReconciliation.enabled=true`.
- Shard job defaults in code:
  - `syncBalances`: `0 */6 * * *`
  - `syncWalletTransfers`: `*/5 * * * *`
- Shard Redis-stream defaults:
  - stream pattern `@wdk/transactions:shard-{shardGroup}`
  - consumer group `@wdk/transaction-consumers-{shardGroup}`

### 2.4 Chain indexers

- Active chain worker repos in this workspace:
  - `wdk-indexer-wrk-evm`
  - `wdk-indexer-wrk-btc`
  - `wdk-indexer-wrk-solana`
  - `wdk-indexer-wrk-ton`
  - `wdk-indexer-wrk-tron`
  - `wdk-indexer-wrk-spark`
- Base indexer capabilities:
  - RPC circuit breaker defaults: `failureThreshold=3`, `resetTimeout=30000`, `successThreshold=2`
  - deterministic provider selection via `getProviderBySeed`
  - Prometheus/Pushgateway metrics hooks
  - HyperDB and MongoDB support
- Current active config files cover:
  - EVM: `eth`, `sepolia`, `usdt-arb`, `usdt-eth`, `usdt-pol`, `usdt-plasma`, `usdt-sepolia`, `xaut-eth`, `xaut-plasma`
  - BTC: `bitcoin`
  - Solana: `solana`, `usdt-sol`
  - TON: `ton`, `usdt-ton`, `xaut-ton`
  - TRON: `tron`, `usdt-tron`
  - Spark: `spark`
- BTC indexer stores per-transfer `metadata.inputs` in indexer DB records.

### 2.5 Rumble-specific behavior

- `rumble-app-node` adds tip-jar, device, MoonPay, swap, notification, and admin transfer routes.
- Swagger UI is protected with docs basic auth.
- `noAuth=true` is rejected in production.
- Sentry only starts when `conf.sentry.enabled=true`, and the Fastify handler ignores validation and other 4xx cases.
- MoonPay transaction/sell webhooks now warn-and-skip when `externalCustomerId` is missing.
- MoonPay `SWAP_COMPLETED` is still unimplemented and throws.
- `rumble-ork-wrk` applies LRU idempotency to `SWAP_STARTED`, `TOPUP_STARTED`, and `CASHOUT_STARTED`.
- `rumble-data-shard-wrk` defaults transfer notification dedupe to LRU, device normalization defaults `isActive` to `true`, and tx-webhook processing runs every `*/10 * * * * *`.

---

## 3. Not Present in Current Workspace

- No `/transfer-history` routes exist in current `wdk-app-node` or `rumble-app-node` runtime code.
- No `wdk-indexer-processor-wrk` repo is present in this workspace.
- No grouped transfer pipeline pieces such as `wallet_transfers_processed`, `processTransferGroup`, `_publishGroupedTransfers`, or `_enrichProcessedTransfer` exist in current runtime code.
- No shard-side BTC helpers such as `aggregateBtcSendTransfers()` or `isSentByWallet()` exist in the current codebase.
- No structured JSON stream payload exists between indexers and shards; the base indexer still publishes CSV `raw` messages.

---

## 4. Challenges / Weak Points

- **Solana sync is currently disabled**
  - `wdk-indexer-wrk-solana` removes the `sync-tx` scheduler entry at startup.
- **Redis stream routing is still incomplete**
  - Indexers publish to `@wdk/transactions:{chain}:{token}`.
  - Shards consume `@wdk/transactions:shard-{shardGroup}`.
  - No router/processor repo is present here to bridge those patterns.
- **BTC history is still only partially modeled end-to-end**
  - BTC indexer stores input metadata, but shard polling and shard stream parsing do not use it.
  - Sender-side, mixed-input, and change-output cases remain weak.
- **BTC balance fetch path is operationally fragile**
  - Bitcoin RPC balance flow still uses `scantxoutset`.
  - Busy/in-progress cases map to `ERR_SCANTXOUTSET_BUSY`.
  - March tasks still describe zero/missing BTC balances in apps.
- **Notification dedupe and idempotency remain memory-only**
  - `rumble-data-shard-wrk` transfer dedupe is LRU-based.
  - `rumble-ork-wrk` manual notification idempotency is also LRU-based.
- **MoonPay support is still partial**
  - Missing `externalCustomerId` no longer breaks the request, but notification delivery is skipped.
  - `SWAP_COMPLETED` is still unsupported.
- **Migration reconciliation is in code, but deployment guidance is incomplete**
  - App/ork config examples do not document `enabled`, `schedule`, or `adminUserIds`.
  - This increases deployment drift risk.
- **Config drift remains visible**
  - Example configs mention extra chains/tokens (`avalanche`, `usat`, `xaut-arb`, `xaut-avalanche`, `xaut-pol`) that are not backed by current active worker config files.
- **Freshness and parity protection are still weak**
  - Feb 27 tasks/minutes still describe shard/API history lagging the latest indexed data.
  - No code-level freshness SLO or parity checker is visible in this workspace.

---

## 5. Security Threats / Risk Areas

- **Service-to-service trust is still shared-secret based**
  - No mTLS or equivalent service identity layer is documented in the current workspace.
- **API key delivery is plaintext over email**
  - Hash-at-rest is good, but the issued key is still sent in email body text.
- **Auth bypass toggle exists**
  - `noAuth` is guarded against production in Rumble code, but it remains a sensitive deployment setting.
- **Sentry is config-gated, not environment-gated**
  - Current code allows any environment if `sentry.enabled=true`; production-only behavior still depends on deployment config.
- **Logging volume and masking remain active concerns**
  - Tasks/minutes still track Sentry noise, validation noise, and sensitive-field/log cleanup work.

---

## 6. Must-Have Gaps To Reach Top Industry Standard

- Pick and document one canonical transfer-ingestion path (polling vs routed streams) and remove the partial dual-mode ambiguity.
- Ship one canonical transaction-history API path, or explicitly retire the unused tx-history-v2 expectations.
- Carry BTC input/change context through shard/app reads, or explicitly document BTC sender-side limitations.
- Harden BTC balance provider strategy with fallback behavior, monitoring, and error budgets.
- Move notification/webhook dedupe and idempotency to durable storage with replay safety.
- Add parity and freshness monitoring between indexer output and shard/app responses.
- Harden service-to-service auth beyond shared topic secrets.
- Operationalize migration reconciliation with documented config, dashboards, and runbooks.

---

## 7. Good Add-Ons

- Unified typed contracts or OpenAPI across indexer, app, and Rumble services.
- Centralized feature flags for Spark, Plasma, and migration rollout.
- Dedicated Bitcoin node or provider pool tuned for balance/history workloads.
- Internal admin UI/reporting for reconciliation runs and drill-down results.
- Daily automated data-quality and parity checks.

---

## 8. Active TODOs (Source-Backed)

- [ ] Resolve the BTC balance inconsistency documented on 2026-03-06 and re-reported on 2026-03-17; define backend fallback behavior when BTC RPC fails.
- [ ] Either re-enable or intentionally retire Solana `sync-tx`.
- [ ] Close the stream-pattern gap or explicitly document polling as the only supported ingestion mode.
- [ ] Decide whether tx-history-v2 should still ship; current runtime still exposes `token-transfers`.
- [ ] Carry BTC input metadata through shard/app history or explicitly document current sender-side BTC limitations.
- [ ] Move Rumble transfer dedupe and manual notification idempotency out of volatile LRUs.
- [ ] Document and wire migration reconciliation config (`enabled`, `schedule`, `adminUserIds`, timeouts) in shipped examples/docs.
- [ ] Align example and active config naming/coverage so deployment behavior is less surprising.
- [ ] Implement or explicitly retire MoonPay `SWAP_COMPLETED`.
- [ ] Add automated parity/freshness checks between indexer, shard, and app outputs.

---

## 9. Verification Spot Checks (Code/Config)

| Claim | Verification Source |
|------|----------------------|
| `GET /api/v1/ready` returns `503` with `ERR_NO_ORKS_AVAILABLE`, and empty ork refresh keeps prior orks | `wdk-app-node/workers/lib/server.js`, `wdk-app-node/workers/base.http.server.wdk.js` |
| Migration snapshot/admin reconciliation endpoints exist, and admin gating uses role/allowlist checks | `wdk-app-node/workers/lib/server.js`, `wdk-app-node/workers/lib/middlewares/migration.reconciliation.admin.js` |
| Ork fans out reconciliation to all shards and schedules it at `0 3 * * *` when enabled | `wdk-ork-wrk/workers/api.ork.wrk.js` |
| Shard stores migration snapshots/runs/results in HyperDB | `wdk-data-shard-wrk/workers/lib/db/hyperdb/build.js` |
| Shard stores migration snapshots/runs/results in MongoDB repos | `wdk-data-shard-wrk/workers/lib/db/mongodb/repositories/migration-snapshots.js`, `wdk-data-shard-wrk/workers/lib/db/mongodb/repositories/migration-reconciliation-runs.js`, `wdk-data-shard-wrk/workers/lib/db/mongodb/repositories/migration-reconciliation-results.js` |
| Reconciliation classifies `MATCH` / `MISMATCH` / `MISSING_IN_FE` / `MISSING_IN_BE` / `OWNED_BY_OTHER_USER` and fetches balances for mismatches | `wdk-data-shard-wrk/workers/proc.shard.data.wrk.js` |
| Indexer app inactive-key cleanup defaults are cron `0 2 * * *` and threshold `30` days | `wdk-indexer-app-node/workers/base.http.server.wdk.js`, `wdk-indexer-app-node/config/common.json.example` |
| API keys are HMAC-hashed before storage and plaintext is emailed | `wdk-indexer-app-node/workers/lib/services/api.key.js`, `wdk-indexer-app-node/workers/lib/services/email.js`, `wdk-indexer-app-node/workers/lib/utils.js` |
| Indexer stream type is `new_transaction` and the published `raw` payload is CSV, not JSON | `wdk-indexer-wrk-base/workers/lib/constants.js`, `wdk-indexer-wrk-base/workers/proc.indexer.wrk.js` |
| Shard Redis defaults consume `@wdk/transactions:shard-{shardGroup}` with `@wdk/transaction-consumers-{shardGroup}` | `wdk-data-shard-wrk/workers/proc.shard.data.wrk.js`, `wdk-data-shard-wrk/config/facs/redis.config.json.example` |
| BTC balance RPC path uses `scantxoutset` and maps busy scans to `ERR_SCANTXOUTSET_BUSY` | `wdk-indexer-wrk-btc/workers/lib/providers/rpc.provider.js` |
| Solana proc disables `sync-tx` | `wdk-indexer-wrk-solana/workers/proc.indexer.solana.wrk.js` |
| Rumble docs auth, `noAuth` production guard, Sentry filtering, and MoonPay missing-`externalCustomerId` handling are current | `rumble-app-node/workers/http.node.wrk.js`, `rumble-app-node/workers/lib/services/moonpay.utils.js` |

---

## 10. Recent Changes (Keep Last ~10)

| Date | Change | Status |
|------|--------|--------|
| 2026-03-17 | Migration reconciliation moved from task plan into workspace runtime code (snapshot endpoint, shard run/result storage, ork merge/admin surface) | Reflected in code |
| 2026-03-17 | Balance-fetching issue reopened; notes still point to BTC RPC failures causing zero/missing balances | Open |
| 2026-03-06 | BTC sender-side amount bug documented with a two-phase fix plan | Only indexer-side metadata is visible; shard/app path is still incomplete |
| 2026-03-05 | MoonPay `externalCustomerId` requirement removal tracked | Reflected in code |
| 2026-03-05 | Rumble address-route Sentry false-positive investigation added | Filtering reflected in code |
| 2026-02-27 | Staging tx history reported stale versus latest indexed data | Investigating |
| 2026-02-27 | Cross-repo log-volume reduction / debug-level cleanup review started | In progress |
| 2026-02-19 | Feature-flag strategy for Spark and Plasma documented | Planned |
| 2026-02-19 | tx-history-v2 noted as not yet on staging or production | Still absent from current runtime workspace |
| 2026-02-19 | Dedicated Bitcoin node/provider proposal added because current BTC client is unreliable/rate-limited | Planned |

---

## 11. References

- `WARP.md`
- `GEMINI.md`
- `_tether-indexer-docs/about_Tether.md`
- `_tether-indexer-docs/app-structure-and-diagrams/`
- `_tether-indexer-docs/analysis-2026-01-14/`
- `_tether-indexer-docs/app_setup/`
- `_tether-indexer-docs/meeting-minutes/`
- `_tether-indexer-docs/_tasks/5-march-26-fix-Remove-externalCustomerId-requirement/`
- `_tether-indexer-docs/_tasks/5-march-26-fix-Rumble-Address-Sentry-False-Positives/`
- `_tether-indexer-docs/_tasks/6-march-26-BTC-transactions-logged-with-incorrect-amounts/`
- `_tether-indexer-docs/_tasks/6-march-26-fix-btc-balance-fetching-rw862/`
- `_tether-indexer-docs/_tasks/17-march-26-Balance-fetching/`
- `_tether-indexer-docs/_tasks/17-march-26-Migration-Reconciliation-Job/`
- `_wdk_docker_network_v2/`
- `wdk-indexer-app-node/`
- `wdk-app-node/`
- `wdk-ork-wrk/`
- `wdk-data-shard-wrk/`
- `wdk-indexer-wrk-base/`
- `wdk-indexer-wrk-btc/`
- `wdk-indexer-wrk-solana/`
- `rumble-app-node/`
- `rumble-data-shard-wrk/`
- `rumble-ork-wrk/`
