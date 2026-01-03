# WDK Indexer - Engineering Truth

Last Updated: 2026-01-02
Scope: `_INDEXER` workspace (wdk-indexer-app-node, wdk-ork-wrk, wdk-data-shard-wrk, per-chain indexers, rumble-* extensions, base libs)

---

## 1. Architecture (Key Decisions)

- Topology: app-node -> ork -> data-shard -> per-chain indexers (matches `_docs/wdk-indexer-local-diagram.mmd`).
- Transport: Hyperswarm/HyperDHT mesh; all workers share `topicConf.capability` and `topicConf.crypto.key`.
- Topics: `@wdk/ork`, `@wdk/data-shard` (Rumble uses `@rumble/*`); indexers announce `chain:token` topics.
- Proc/API pairing: Proc prints RPC key; API uses `--proc-rpc` to access its Proc.
- Storage: HyperDB (append-only, migration/versioned schema) or MongoDB for indexers and data-shard.
- Autobase: ork for lookups/uniqueness; wdk-indexer-app-node for API keys.
- Redis: hard dependency for `wdk-app-node` caching/rate limiting; optional event engine (Redis streams) for indexer -> data-shard transfer pipeline; used for rate limiting in wdk-indexer-app-node.
- FX rates: data-shard fetches Bitfinex batch FX and caches in LRU (1 min default).
- Metrics: indexer base supports Pushgateway metrics and sync lag monitoring when enabled.

---

## 2. Components (What They Do)

- `wdk-indexer-app-node`: REST API for balances/transfers (batch limits), API key lifecycle (Autobase), rate limiting.
- `wdk-app-node`: HTTP gateway for wallet CRUD/balances with Redis cache (30s TTL) and `cache=false` bypass; supports JWT/noAuth.
- `wdk-ork-wrk`: wallet CRUD, address normalization/uniqueness checks, shard routing, Autobase lookups with LRU cache.
- `wdk-data-shard-wrk`: wallet storage, balance/transfer aggregation, FX conversion, scheduled sync jobs; Redis stream consumer when `eventEngine=redis`.
- `wdk-indexer-wrk-*`: per-chain indexers (proc/API) emitting normalized transfers; BTC converts UTXO to standard from/to format.
- `tether-wrk-base` / `wdk-indexer-wrk-base`: worker scaffolding, Hyperswarm RPC, RPC circuit breaker/failover ordering.

---

## 3. Supported Chains/Tokens (Code/Config vs Docs)

- Worker repos + configs exist for:
  - EVM: Ethereum, Arbitrum, Polygon, Plasma, Sepolia (USDt, XAUt where configured)
  - Bitcoin: BTC
  - Solana: SOL + SPL (USDT)
  - TON: TON + Jetton (USDT, XAUT)
  - Tron: TRX + USDT
  - Spark: BTC (Spark network)
- Docs (`wdk-docs/tools/indexer-api`) list: Ethereum, TON, TRON, Arbitrum, Sepolia, Plasma, Polygon, Bitcoin, Spark (no Solana).
- Token naming mismatch: some configs use `usdt/xaut`, others use `usdt0/xaut0` (e.g., `wdk-indexer-app-node/config/common.json` vs examples/docs).

---

## 4. Delivered Features (Indexer/WDK)

- HTTP endpoints for balances/transfers, including batch endpoints and per-route rate limits.
- Wallet creation/update, address lookups, user/wallet balance aggregation.
- API key issuance, revoke, and inactive-key sweep (wdk-indexer-app-node).
- Redis-backed caching with explicit `cache=false` bypass to avoid cache poisoning.
- Optional Redis stream pipeline for indexer -> data-shard transfer push.
- Circuit breaker + failover ordering for RPC providers (RpcBaseManager) used by most chain clients.
- FX valuation via Bitfinex batch endpoint.

---

## 5. Rumble Extensions

- `rumble-app-node`: auth + device management + notifications + MoonPay + passkey/SSO proxy endpoints.
- `rumble-ork-wrk`: notification routing with LRU idempotency for manual types (`SWAP_STARTED`, `TOPUP_STARTED`, `CASHOUT_STARTED`).
- `rumble-data-shard-wrk`: FCM pushes + signed Rumble webhooks; transfer dedupe cache; gasless retry config.

---

## 6. Challenges / Weak Points

- Balance oscillation: data-shard selects indexer peers randomly; chain clients use round-robin providers. Docs describe deterministic `callWithSeed`/seeded peer selection, but current code still uses `rpcManager.call` + `jTopicRequest` without seeds.
- `cache=false` bypasses Redis read/write by design, so mixed cached/live reads expose provider/peer drift (30s TTL).
- Duplicate/missing notifications: transfer-based notifications fire on every upsert and can be sent before DB commit; no end-to-end idempotency for automatic transfers; device registration is not deterministic and invalid token cleanup is incomplete (per docs/tasks).
- Address uniqueness: ork normalizes addresses and checks duplicates, but migrations are required to backfill existing data; data-shard `getWalletByAddress` falls back to lowercase.
- `[HRPC_ERR]=Pool was force destroyed`: docs disagree on root cause (Hyperswarm pool vs Mongo pool). `netOpts` appear in `wdk-data-shard-wrk/config/common.json`, but `tether-wrk-base` does not load net fac config today.
- Circuit breaker behavior in staging is questioned (tasks show repeated errors from a failed provider despite circuit breaker).
- Provider quota spikes (Candide) and missing alerts/monitoring remain open.

---

## 7. Security Threats / Risks

- Secrets committed in repo config files (`topicConf` keys, API key/JWT/rumble tokens).
- Internal RPC trust relies on shared `topicConf` secrets only (no mTLS/JWT between workers).
- API keys are emailed in plaintext by `wdk-indexer-app-node` when configured.
- Dependency audit found no SHA1HULUD packages, but recommends pinning versions and auditing install scripts/transitive deps.

---

## 8. Industry-Standard Gaps (Documented Backlog)

- Deterministic provider and peer selection for balance reads (stop oscillation).
- End-to-end idempotency for transfer notifications/webhooks.
- Observability: provider-tagged errors + alerting (RPC/Candide).
- Load/stress testing at 5k+ users; keep BTC tests updated.
- Secret management and internal auth hardening.

---

## 9. Good Add-Ons (Documented Ideas)

- Proxy endpoints for BTC/TON RPC to centralize provider usage.
- Align token naming (`usdt` vs `usdt0`) across configs/docs/topics.
- Push-based transaction sync (broadcast vs router service) to replace polling; needs load tests.

---

## 10. Active TODOs (from tasks/minutes)

- Address normalization migrations for ork/data-shard and duplicate cleanup.
- Fix duplicate notifications and device registration determinism.
- Resolve pool destruction errors and decide net config loading/DHT error handling.
- Investigate circuit breaker behavior on staging.
- Add monitoring/alerts; update BTC tests; run stress tests.
- Clarify ERC-4337 failed-transaction handling (userOp vs bundle hash).

---

## 11. References

- Architecture diagram: `_docs/wdk-indexer-local-diagram.mmd`
- Meeting minutes: `_docs/_minutes/*.md`
- Tasks: `_docs/tasks/`
- Slack notes: `_docs/_slack/*.md`
- Security audit: `_docs/tasks/task_dependencies_issue/security_audit_report.md`
