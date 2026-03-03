# WDK Indexer - Engineering Truth

Last Updated: 2026-02-27
Scope: `_INDEXER` workspace only (code + `_docs` notes/tasks/minutes in this repo)

---

## 1. Architecture Decisions (Current)

- **Gateway split**
  - `wdk-indexer-app-node` exposes public indexer APIs (`token-transfers`, `token-balances`, batch endpoints, API key flow).
  - `wdk-app-node` / `rumble-app-node` expose wallet/user APIs and route through ork + shard layers.
- **Routing model**
  - App node -> Ork lookup/routing -> Data shard -> Chain indexers (topic RPC by `chain:token`).
- **Proc/API worker split**
  - Indexer and shard stacks use Proc workers for write/sync jobs and API workers for read RPC endpoints.
- **Topic-based internal RPC**
  - Services use `topicConf.capability` and `topicConf.crypto.key` style shared secrets for mesh auth/signing.
- **Pluggable data engines**
  - Core workers support `dbEngine: hyperdb | mongodb` via db factories.
- **Two transfer ingestion paths in shard**
  - Polling sync jobs (`syncWalletTransfers`) from indexers.
  - Optional Redis stream consume path when `eventEngine=redis`.
- **Cache behavior in app node**
  - Redis-backed cache with 30s TTL for selected routes.
  - `cache=false` intentionally skips both cache read and cache write.

---

## 2. Delivered Features (Verified in Code)

### 2.1 `wdk-indexer-app-node`
- Public REST endpoints for chain/token/address transfers and balances.
- Batch endpoints for transfers and balances.
- API key request flow (`/register`, `/api/v1/request-api-key`) with rate limits.
- Swagger UI at `/docs`.
- Background job to revoke inactive API keys.
  - Default cron: `0 2 * * *`
  - Default threshold: `30` days
- API keys are hashed at rest; plaintext key is emailed to requester.

### 2.2 `wdk-app-node`
- Wallet/user balance + trend APIs and transfer APIs.
- Transfer endpoints are currently `.../token-transfers` (wallet/user/Spark-BTC routes).
- Readiness endpoint exists:
  - `GET /api/v1/ready` returns `503` with `ERR_NO_ORKS_AVAILABLE` when no ork is discovered.

### 2.3 `wdk-ork-wrk` + `wdk-data-shard-wrk`
- Ork supports lookup engines including Autobase and MongoDB.
- Ork has weekly cleanup job for inactive user lookup records.
- Shard supports wallet/user transfer reads via:
  - `getWalletTransfers`
  - `getUserTransfers`
- Shard scheduled jobs include:
  - `syncBalances` (default every 6h)
  - `syncWalletTransfers` (default every 5m)
- Shard stream consumer default naming:
  - stream pattern `@wdk/transactions:shard-{shardGroup}`
  - consumer group `@wdk/transaction-consumers-{shardGroup}`

### 2.4 Chain indexers
- Active chain worker repos in workspace:
  - `wdk-indexer-wrk-evm`, `-btc`, `-solana`, `-ton`, `-tron`, `-spark`
- Base indexer capabilities:
  - RPC circuit breaker (`failureThreshold=3`, `resetTimeout=30000`, `successThreshold=2` defaults)
  - deterministic provider selection support (`getProviderBySeed`)
  - Prometheus/Pushgateway metrics hooks
- Configured chain/token coverage (from current configs) includes:
  - EVM: Ethereum, Arbitrum, Polygon, Sepolia, Plasma (tokens vary by file)
  - Bitcoin, Solana, TON, TRON, Spark

### 2.5 Rumble extensions
- `rumble-app-node` adds Rumble-specific APIs (tip-jar, device IDs, MoonPay, swaps, admin transfer route).
- Swagger UI is protected with docs basic auth in Rumble app server.
- Notification flow includes explicit transfer types (`TOKEN_TRANSFER_RANT`, `TOKEN_TRANSFER_TIP`) and idempotency helpers.
- Device registration logic defaults `isActive` to true when not explicitly false.

---

## 3. Not Present in Current Workspace (Stale Claims Removed)

- No `/transfer-history` endpoints are present in current `wdk-app-node` or `rumble-app-node` code.
- No `wallet_transfers_processed` collection or `processTransferGroup` implementation exists in current shard code.
- No grouped transaction publish path (`_publishGroupedTransfers`) exists in current indexer base worker.
- Current stream message type in indexer base is only `new_transaction` with CSV `raw` payload.
- `wdk-indexer-processor-wrk` repo is not present in this workspace.
- No `_enrichProcessedTransfer` hook exists in current `rumble-data-shard-wrk` code.

---

## 4. Challenges / Weak Points

- **Solana sync currently disabled in proc worker**
  - `sync-tx` scheduler entry is explicitly removed in Solana proc startup.
- **Event pipeline gap risk**
  - Indexer default stream naming is `@wdk/transactions:{chain}:{token}`.
  - Shard stream consumer default expects `@wdk/transactions:shard-{shardGroup}`.
  - Without a routing/processor bridge, stream-based propagation is incomplete.
- **BTC transfer modeling remains raw-output based**
  - Parser maps each `vout` into transfer records.
  - `from` can remain `null` when input addresses are mixed.
  - No explicit change-output labeling in current parser.
- **Notification dedupe is in-memory LRU based**
  - Restart loses dedupe memory; duplicate sends remain possible.
- **Config drift across examples vs active configs**
  - Token naming and chain lists vary (`usdt` vs `usdt0`, `xaut` vs `xaut0`, optional chains in examples).
- **Freshness incident reported on staging (2026-02-27)**
  - Latest indexer-visible tx not reflected in shard/API tx history according to meeting/slack notes.

---

## 5. Security Threats / Risk Areas

- **Internal trust model is shared-secret based**
  - No built-in mTLS between services; relies on topic secrets and network isolation.
- **API key delivery channel**
  - API key is emailed in plaintext to requester.
- **Auth safety toggle exists**
  - `noAuth` exists for app nodes; guarded against production misuse in code, but still a sensitive config.
- **Sentry behavior is config-gated, not environment-locked**
  - If `sentry.enabled=true`, reporting can run in any env unless deployment config restricts it.
- **Sensitive logging discipline remains an ongoing concern**
  - Minutes/tasks still track masking and log-volume cleanup work.

---

## 6. Must-Have Gaps To Reach Top Industry Standard

- Finish and merge transaction-history-v2 implementation path into mainline runtime code.
- Establish durable, end-to-end transfer pipeline (indexer -> processor/router -> shard) with clear ownership and replay guarantees.
- Replace in-memory dedupe with persistent dedupe (Redis/DB) for notifications/webhooks.
- Enforce service-to-service auth hardening (mTLS or equivalent identity-based auth).
- Implement fee extraction and user-id enrichment (`fromUserId` / `toUserId`) where planned.
- Add freshness SLOs and automated data-staleness alarms for shard/API outputs.

---

## 7. Good Add-Ons

- Unified OpenAPI/TS contracts across indexer/app/rumble services.
- Centralized feature-flag system for Spark/Plasma per flow.
- Dedicated Bitcoin node for reliability under rate limits.
- Automated daily data-quality checks (indexer vs shard/API parity).

---

## 8. Active TODOs (Source-Backed)

- [ ] Resolve 2026-02-27 staging stale transaction-history issue (indexer data ahead of shard/API).
- [ ] Re-enable or intentionally retire Solana `sync-tx` job after root-cause analysis.
- [ ] Close stream-routing gap (or explicitly standardize on polling-only mode).
- [ ] Merge tx-history-v2 related work from feature branches/tasks into active runtime.
- [ ] Implement fee extraction phase by chain (per `_tasks/17-feb-26-2-review-and-update-trx-history feature`).
- [ ] Implement/decide address->user enrichment strategy for `fromUserId` / `toUserId`.
- [ ] Move notification idempotency from volatile LRU to durable store.
- [ ] Align token naming/config conventions across active and example configs.
- [ ] Complete Sentry/logging hardening tasks (env gating + sensitive field masking + volume reduction).

---

## 9. Verification Spot Checks (Code/Config)

| Claim | Verification Source |
|------|----------------------|
| `wdk-app-node` readiness returns 503 + `ERR_NO_ORKS_AVAILABLE` when no orks | `wdk-app-node/workers/lib/server.js`, `wdk-app-node/workers/lib/services/ork.js` |
| Transfer endpoints are `token-transfers` (not `transfer-history`) | `wdk-app-node/workers/lib/server.js`, `rumble-app-node/workers/lib/server.js` |
| `cache=false` skips both cache read and cache write; TTL is 30s | `wdk-app-node/workers/lib/utils/cached.route.js` |
| Indexer app has `/docs` and request-api-key flow | `wdk-indexer-app-node/workers/base.http.server.wdk.js`, `wdk-indexer-app-node/workers/lib/server.js` |
| Inactive key revoke defaults: cron `0 2 * * *`, threshold `30` days | `wdk-indexer-app-node/workers/base.http.server.wdk.js`, `wdk-indexer-app-node/config/common.json` |
| Shard transfer read methods are `getUserTransfers` and `getWalletTransfers` | `wdk-data-shard-wrk/workers/api.shard.data.wrk.js` |
| Indexer base publishes only `new_transaction` raw CSV stream messages | `wdk-indexer-wrk-base/workers/proc.indexer.wrk.js`, `wdk-indexer-wrk-base/workers/lib/constants.js` |
| Solana proc disables sync-tx scheduler | `wdk-indexer-wrk-solana/workers/proc.indexer.solana.wrk.js` |
| Rumble device default active flag behavior | `rumble-data-shard-wrk/workers/lib/utils/device.util.js`, `rumble-data-shard-wrk/workers/api.shard.data.wrk.js` |
| Rumble Sentry is config-gated via `sentry.enabled` | `rumble-app-node/workers/http.node.wrk.js`, `rumble-app-node/config/common.json.example` |
| Processor repo referenced in older docs is absent in current workspace | workspace directory listing (`wdk-indexer-processor-wrk` not present) |

---

## 10. Recent Changes (Keep Last ~10)

| Date | Change | Status |
|------|--------|--------|
| 2026-02-27 | Staging tx history reported stale vs indexer latest tx (BTC and other flows discussed) | Investigating |
| 2026-02-27 | Cross-repo PR review work started for log-volume reduction (debug-level migration) | In progress |
| 2026-02-26 | Sentry issue investigation task added with screenshots | Investigating |
| 2026-02-19 | Feature-flag strategy for Spark/Plasma documented in minutes | Planned |
| 2026-02-19 | Dedicated Bitcoin node discussed due rate-limit pressure | Planned |
| 2026-02-19 | tx-history-v2 noted as not yet on staging/production in minutes | Pending deployment |
| 2026-02-18 | Trace-id propagation initiative recorded | In progress |
| 2026-02-17 | Fee extraction phase plan documented | Planning |
| 2026-02-17 | tx-history endpoint contract/spec docs produced in tasks | Documented |
| 2026-02-16 | Monitoring VM resized (300 GB) and retention policy updated (21d logs / 60d metrics) | Done |

---

## 11. References

- `CLAUDE.md`, `WARP.md`, `GEMINI.md`
- `_docs/APP_RELATIONS.md`, `_docs/mapping.md`, `_docs/diagram_nodes.md`, `_docs/wdk-indexer-local-diagram.mmd`
- `_docs/analysis-2026-01-14/`
- `_docs/minutes/`
- `_docs/_tasks/11-feb-26-execute-plan-trx-history/`
- `_docs/_tasks/17-feb-26-1-give-me-contract-trx-history-endpoints/`
- `_docs/_tasks/17-feb-26-2-review-and-update-trx-history feature/`
- `_docs/_tasks/19-feb-26-1-tx-history-answer-userid-q/`
- `_docs/_tasks/26-feb-26-sentry-error-1/`
- `_docs/_tasks/27-feb-26-2-trx-not-showing/`
- `_wdk_docker_network_v2/`
