# WDK Indexer - Engineering Truth

Last Updated: 2026-01-11
Scope: `_INDEXER` workspace (indexer stack, rumble extensions, shared libs, WDK SDK/docs)

---

## 1. Architecture (Key Decisions)

- **Request flows**: `wdk-indexer-app-node` serves indexer REST and calls `chain:token` topics; `wdk-app-node`/`rumble-app-node` serve wallet APIs via `wdk-ork-wrk` -> `wdk-data-shard-wrk` -> indexers.
- **Proc/API split**: proc workers run writes and sync jobs; API workers read and require `--proc-rpc` from proc logs.
- **RPC mesh**: Hyperswarm/HyperDHT RPC with shared `topicConf.capability` and `topicConf.crypto.key`; topics include `@wdk/ork`, `@wdk/data-shard`, per-chain `chain:token`, and `@rumble/*`.
- **Storage**: HyperDB/Hyperbee or MongoDB selected by `dbEngine`; HyperDB schemas are append-only and changes require migrations + version bump.
- **Autobase**: ork uses Autobase for user/wallet/channel lookups; indexer app stores API keys in Autobase; processor uses Autobase lookups for routing.
- **Redis + metrics**: Redis is required for `wdk-app-node` caching/rate limits and used for optional transfer streams; indexer base can push Prometheus metrics and sync-lag data.

## 2. Components (What They Do)

- **API nodes**: `wdk-indexer-app-node` (token balances/transfers, API keys, Swagger) and `wdk-app-node`/`rumble-app-node` (wallet CRUD, balances, auth, device/notification endpoints).
- **Routing**: `wdk-ork-wrk` (shard routing, Autobase lookups, LRU caches, deleted-user cleanup).
- **Data shards**: `wdk-data-shard-wrk` (wallet storage, aggregation, FX pricing, scheduled sync) and `rumble-data-shard-wrk` (FCM notifications, device registry, webhooks).
- **Indexers**: `wdk-indexer-wrk-base` plus chain workers (EVM + ERC20, BTC, Solana/SPL, TON/Jetton, TRON/TRC20, Spark) with multi-provider RPC and circuit breaker.
- **Event routing**: `wdk-indexer-processor-wrk` routes Redis transfer streams to shard streams (optional); data shards can consume when `eventEngine=redis`.
- **Shared libs/devops**: `tether-wrk-base`, `tether-wrk-ork-base`, `svc-facs-httpd`, `svc-facs-logging`, `hp-svc-facs-store`; `wdk-devops/wdk-be-deploy` and `wdk-devops/haproxy-auth-proxy`.

## 3. Supported Chains/Tokens (Config vs Docs)

- **Indexer app config**: Ethereum (USDT/XAUT), Sepolia (USDT), Plasma (USDT/XAUT), Arbitrum (USDT), Polygon (USDT), TRON (USDT), TON (USDT/XAUT), Solana (USDT), Bitcoin (BTC), Spark (BTC).
- **Ork/data-shard config**: Ethereum, Arbitrum, Polygon, TRON, TON, Solana, Bitcoin, Spark; `rumble-data-shard-wrk` adds Plasma.
- **Docs**: `wdk-docs/tools/indexer-api` lists Ethereum, TON, TRON, Arbitrum, Sepolia, Plasma, Polygon, Bitcoin, Spark (no Solana).
- **Naming mismatches**: token names vary across configs/docs (`usdt` vs `usdt0`, `xaut` vs `xaut0`, `btc` vs `BTC`).

## 4. Delivered Features (Indexer + Wallet APIs)

- **Indexer REST**: token balances/transfers, batch endpoints, API-key auth, request-api-key email flow, Swagger UI.
- **Wallet REST**: connect, wallet CRUD, balance + trend endpoints, token transfers, tip-jar endpoints; JWT auth with optional dev test mode.
- **Cache behavior**: Redis-backed cache in `wdk-app-node` (30s TTL); `cache=false` skips both read and write.
- **RPC resilience**: weighted multi-provider selection with circuit breaker in `RpcBaseManager`; provider metrics in indexer base.
- **Gasless receipts**: ERC-4337 receipts (EVM), gasless TON receipts, gasfree TRON receipts; paymaster labels for EVM transfers.
- **Pricing + streams**: Bitfinex batch FX conversion; scheduled balance/transfer sync jobs; optional Redis stream pipeline for transfers.

## 5. Rumble Extensions

- **rumble-app-node**: SSO and passkey proxy endpoints, device-id APIs, notification endpoint, MoonPay + swaps integration, admin APIs, Sentry.
- **rumble-ork-wrk**: notification routing, LRU idempotency for manual types, balance-failure thresholds, cross-shard admin queries.
- **rumble-data-shard-wrk**: FCM device registry, transfer notification dedupe (LRU), rumble server + Fivetran webhooks, gasless retry controls.
- **Docs**: `rumble-docs` provides Bruno collections for Rumble APIs.

## 6. WDK SDK/Docs Snapshot (Repo-local)

- **wdk-core**: orchestrates wallets + protocol modules; register wallets, protocols, middleware.
- **Wallet modules**: EVM, ERC-4337, BTC, TRON, TON (gasless), Solana, Spark; see `wdk-docs/sdk/wallet-modules`.
- **Protocol modules**: swap (Velora EVM, StonFi TON), bridge (USDT0 EVM/TON), lending (Aave V3 EVM), fiat (MoonPay).
- **Tools**: secret manager, pricing (Bitfinex), UI kit, community modules.

## 7. Challenges / Weak Points

- **Balance oscillation**: RPC provider selection is round-robin and data-shard peer selection is random; mixed cache/live calls cause inconsistent balances.
- **Ork startup fragility**: empty ork list leads to undefined RPC key and generic 500s; RoundRobin index can corrupt on empty updates; no readiness gate.
- **Notification reliability**: idempotency is in-memory LRU; transfer notifications/webhooks can duplicate or drop; device tokens/IDs can go stale or duplicate.
- **Address normalization**: migrations required; `getWalletByAddress` fallback to lowercase can mask duplicates; duplicate addresses are a known risk.
- **MongoDB timeouts**: pool-destroyed and timeout errors observed; retry/timeout settings inconsistent and can hang under replica set issues.
- **Solana indexing**: `sync-tx` job is disabled in `wdk-indexer-wrk-solana` proc worker (TEMP disable).

## 8. Security Threats / Risks

- **Internal RPC auth**: services rely only on shared `topicConf` secrets; ork has no auth layer.
- **API key delivery**: `wdk-indexer-app-node` can email API keys in plaintext.
- **Secrets in configs**: repo includes example config placeholders; risk if real secrets are committed.
- **Address duplication**: normalization gaps can map the same address to multiple wallets/users.
- **Supply-chain exposure**: dependency attack reports exist (Shai-Hulud); local audit notes indicate none of the flagged packages were used, but re-verify.

## 9. Industry-Standard Gaps (Backlog)

- **Deterministic reads**: sticky provider/peer selection for balance queries (PRs exist but not merged here).
- **Durable idempotency**: persisted dedupe for notifications/webhooks and transfer processing.
- **Startup readiness**: 503 mapping and readiness gates for empty ork/shard discovery.
- **Observability**: provider-tagged errors and alerting (tickets exist); app/data-shard metrics limited vs indexers.
- **Load testing**: repeatable stress tests (5k+ users) and BTC regression tests.
- **Service auth/secret management**: internal auth between workers and unified secret manager usage.

## 10. Active TODOs (from tasks/tickets)

- **Address normalization**: run ork/data-shard migrations and clean duplicates across shards and Rumble extensions.
- **Ork empty-list fix**: guard `ERR_NO_ORKS_AVAILABLE`, fix RoundRobin empty update, add readiness gate.
- **Notification/device cleanup**: deterministic device IDs, invalid-token cleanup, idempotency for auto transfer notifications/webhooks.
- **Balance determinism**: merge deterministic provider/peer selection with failover fallback; align cache usage.
- **ERC-4337 mapping**: track failed transactions by userOp hash vs bundle hash.
- **Config/ops alignment**: align chain/token configs/docs, add provider-name logging + alerts, implement RPC proxy endpoints (TON/BTC), run stress tests, and replace deprecated local Docker orchestration.

## 11. References

- `WARP.md`
- `_docs/APP_RELATIONS.md`
- `_docs/wdk-indexer-local-diagram.mmd`
- `_docs/_app_setup/LOCAL_INDEXER_SETUP_PLAN.md`
- `wdk-indexer-app-node/README.md`
- `wdk-docs/tools/indexer-api/README.md`
