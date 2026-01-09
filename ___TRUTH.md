# WDK Indexer - Engineering Truth

Last Updated: 2026-01-07
Scope: `_INDEXER` workspace (indexer stack, rumble extensions, base libs, WDK SDK/docs)

---

## 1. Architecture (Key Decisions)

- Topology: wdk-indexer-app-node -> wdk-ork-wrk -> wdk-data-shard-wrk -> per-chain indexers.
- Transport: Hyperswarm/HyperDHT P2P RPC; all workers share `topicConf.capability` and `topicConf.crypto.key`.
- Topics: `@wdk/ork`, `@wdk/data-shard`, indexer topics per chain/token; Rumble uses `@rumble/*`.
- Proc/API pairing: Proc workers own writes and print RPC keys; API workers require `--proc-rpc`.
- Storage: HyperDB (append-only Hyperbee) or MongoDB; schema changes require migrations and version bumps.
- Autobase: ork for lookups and wdk-indexer-app-node for API key storage.
- Redis: required by wdk-app-node for caching/rate limiting; optional event engine for indexer -> data-shard transfer streams.
- Metrics: indexer base supports Pushgateway metrics and sync-lag monitoring when enabled.

---

## 2. Components (What They Do)

- `wdk-indexer-app-node`: Fastify HTTP API for balances/transfers, API key lifecycle, Swagger UI, email service, rate limits.
- `wdk-app-node`: HTTP gateway for wallet CRUD, JWT auth (or test mode), x-trace-id logging, Redis cache + rate limits, ork round-robin.
- `wdk-ork-wrk`: shard routing + wallet lookups via Autobase, LRU caches, cleanup of deleted users.
- `wdk-data-shard-wrk`: wallet storage, transfer aggregation, FX conversion (Bitfinex batch), scheduled sync jobs, optional Redis stream consumer.
- `wdk-indexer-wrk-base`: shared indexer logic, RPC circuit breaker, HyperDB/Mongo persistence, Redis transfer publish.
- Per-chain indexers: EVM/erc20, BTC, Solana/SPL, TON/Jetton, TRON/TRC20, Spark.
- Facilities: `tether-wrk-base` (Hyperswarm RPC + store), `svc-facs-httpd` (Fastify), `svc-facs-logging` (Pino + optional hyperswarm transport), `hp-svc-facs-store` (Corestore/Hyperbee/Autobase).

---

## 3. Supported Chains/Tokens (Docs vs Config)

- Configs/examples include:
  - EVM: Ethereum, Sepolia, Arbitrum, Polygon, Plasma (ETH + USDT + XAUT where configured)
  - Bitcoin: BTC
  - Solana: SOL + SPL USDT
  - TON: TON + Jetton USDT/XAUT
  - TRON: TRX + USDT
  - Spark: BTC
- `wdk-indexer-app-node/config/common.json.example` enforces chain whitelist + case sensitivity rules (TRON/TON/Solana/Bitcoin).
- `wdk-data-shard-wrk`/`wdk-ork-wrk` configs list the same chains; Rumble configs do not include Sepolia/Plasma.
- Docs (`wdk-docs/tools/indexer-api`) list: Ethereum, TON, TRON, Arbitrum, Sepolia, Plasma, Polygon, Bitcoin, Spark (no Solana).
- Token naming mismatches exist across configs/docs (`usdt` vs `usdt0`, `xaut` vs `xaut0`).

---

## 4. Delivered Features (Indexers + APIs)

- REST endpoints for balances/transfers, batch queries, per-route rate limits, Swagger docs.
- API key management + inactive-key cleanup job (wdk-indexer-app-node Autobase).
- Redis-backed caching (30s TTL) with `cache=false` skipping both read/write to avoid cache poisoning (wdk-app-node).
- Optional Redis stream pipeline for pushing transfers from indexers to data-shards.
- EVM: ERC-4337 bundler/paymaster config + paymaster list used for labeling paymaster transfers.
- TON/TRON: gasless/gasfree receipt lookup support via wallet SDKs.
- BTC: multi-provider support (rpc/quicknode/blockbook) and UTXO -> from/to normalization.
- Spark: time-based "block" indexing via SparkScan API with chunked lookback.

---

## 5. Rumble Extensions

- `rumble-app-node`: SSO + MoonPay + swaps, passkey/auth proxy endpoints, Sentry integration.
- `rumble-ork-wrk`: notification routing with LRU idempotency for manual types (SWAP_STARTED/TOPUP_STARTED/CASHOUT_STARTED) and balance-failure thresholds.
- `rumble-data-shard-wrk`: device registry + FCM notifications, transfer dedupe LRU, Rumble/Fivetran webhooks, gasless retry controls.

---

## 6. WDK SDK/Docs in This Workspace

- `wdk-core` orchestrates wallet + protocol modules (register wallets/protocols/middleware, account access).
- `wdk-docs` documents wallet modules (EVM, ERC-4337, BTC, TRON, TON, Solana, Spark), bridge (USDT0 EVM/TON), swap (Velora EVM, StonFi TON), lending (Aave V3 EVM), fiat (MoonPay), community modules, UI kit.
- Tooling docs: Secret Manager (`wdk-secret-manager`) and price rates (`wdk-pricing-bitfinex-http`) are documented here.

---

## 7. Challenges / Weak Points

- Balance oscillation: RPC provider selection is round-robin (RpcBaseManager) and data-shard RPC peer selection is non-deterministic; combined with cache bypass, this yields inconsistent balances (documented in tasks).
- Solana proc indexer disables the `sync-tx` scheduler (`// TEMP disable`), so background sync is currently off.
- Notification gaps: transfer dedupe is per-process LRU; end-to-end idempotency for automatic transfer notifications/webhooks is not implemented (tasks).
- Address normalization: ork/data-shard require migrations; `getWalletByAddress` falls back to lowercase and can mask duplicates.
- `[HRPC_ERR]=Pool was force destroyed`: docs conflict on root cause (Hyperswarm pool vs MongoDB pool). Net config exists but base worker does not load it today.
- Circuit breaker effectiveness on staging is still questioned in task notes.

---

## 8. Security Threats / Risks

- Internal RPC trust relies on shared `topicConf` secrets only; no per-service auth layer.
- Config files in repo include placeholders for secrets; risk if real values are committed.
- API keys are emailed in plaintext when wdk-indexer-app-node email service is enabled.
- Secret handling depends on application-level discipline even with Secret Manager tooling.

---

## 9. Industry-Standard Gaps (Documented Backlog)

- Deterministic provider/peer selection for balance reads.
- End-to-end idempotency for transfer notifications/webhooks.
- Provider-tagged errors + alerting for RPC/bundler quotas.
- Load/stress testing at scale (5k+ users), plus BTC regression tests.
- Secret management hardening and internal auth between services.

---

## 10. Active TODOs (from tasks/minutes)

- Complete address-normalization migrations and duplicate cleanup (ork + data-shard).
- Implement deterministic device IDs + invalid-token cleanup for notifications.
- Fix ERC-4337 failed-transaction mapping (userOp hash vs bundle hash).
- Resolve pool-destroyed root cause and add retries/backoff where needed.
- Add monitoring/alerts and finalize load tests.
- Align token naming across configs/docs.
- Audit doc references for missing files (e.g., `_docs/mapping.md` references `running_indexer_task.md`).

---

## 11. References

- Architecture: `WARP.md`, `_docs/APP_RELATIONS.md`, `_docs/wdk-indexer-local-diagram.mmd`
- Setup: `_docs/_app_setup/LOCAL_INDEXER_SETUP_PLAN.md`
- Docs: `wdk-docs/README.md`, `wdk-docs/tools/indexer-api/README.md`
- Tasks/minutes/slack: `_docs/tasks/`, `_docs/_minutes/`, `_docs/_slack/`
