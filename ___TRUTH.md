# WDK Indexer - Engineering Truth

Last Updated: 2025-12-22
Scope: `_INDEXER` workspace (wdk-indexer-app-node, wdk-ork-wrk, wdk-data-shard-wrk, per-chain indexers, rumble-* extensions)

---

## 1. Architecture (Key Decisions)

- Topology: `wdk-indexer-app-node` (HTTP) -> `wdk-ork-wrk` (routing) -> `wdk-data-shard-wrk` (data) -> per-chain indexers.
- Transport: Hyperswarm/HyperDHT mesh with shared `topicConf.capability` + `topicConf.crypto.key`.
- Topics:
  - Ork uses `@wdk/ork`; data-shard uses `@wdk/data-shard`.
  - Indexers announce `chain:token` topics (e.g., `ethereum:usdt`).
- Worker pairs: Proc (writer) and API (reader); Proc prints RPC key, API requires `--proc-rpc`.
- Storage: `dbEngine` selects HyperDB or MongoDB. HyperDB schemas are append-only and require version bumps + migrations.
- Autobase: used for API keys (app-node) and lookups (ork).
- Redis: required by app-node for caching + rate limiting (shared Redis across instances).
- LRU caches: shard lookups (ork) and FX price (data-shard).
- FX rates: default via Bitfinex public API (configurable).

---

## 2. Components

- `wdk-indexer-app-node`: HTTP API, API key lifecycle, rate limiting, Swagger; built on `wdk-app-node`.
- `wdk-ork-wrk`: wallet CRUD, address normalization, shard routing, Autobase lookups.
- `wdk-data-shard-wrk`: wallet storage, balances/transfers aggregation, FX conversion.
- `wdk-indexer-wrk-{evm,btc,solana,ton,tron,spark}`: chain indexers.
- `tether-wrk-base` / `wdk-indexer-wrk-base`: shared worker scaffolding + Hyperswarm RPC.

---

## 3. Chain & Token Coverage (From Configs)

- EVM: Ethereum, Arbitrum, Polygon, Plasma, Sepolia with USDT/XAUT configs; ERC-4337 + bundler/paymaster config present.
- Bitcoin: BTC (UTXO normalization to standard format).
- Solana: SOL + USDT (SPL) via Bitquery provider.
- TON: TON + USDT/XAUT (Jetton configs).
- Tron: TRX + USDT (TRC20) with gas-free provider config.
- Spark: BTC with LNURL/UMA support.

Note: docs/tasks reference `usdt0/xaut0` topics for Plasma/Sepolia, while current configs use `usdt/xaut`.

---

## 4. Delivered Features

- Wallet creation/update, address normalization, and lookups via Autobase.
- Balances and transfers per wallet/user/token, plus batch endpoints.
- API key management: create/list/revoke/sweep + blocked owners.
- Trace ID propagation across HTTP and internal RPC (`x-trace-id`).
- Optional Redis event engine (`eventEngine=redis`) for push pipeline between indexer and data-shard (not set in shipped configs).
- Deterministic provider/peer selection for balance reads: `callWithSeed()` in RpcBaseManager routes requests to stable providers based on address hash; data-shard uses seeded peer selection via `_rpcCall(seed)`. Prevents balance oscillation across multi-peer/multi-provider deployments.

---

## 5. Rumble Extension Layer

- `rumble-app-node`: SSO/passkey proxies, MoonPay, notifications API, device management.
- `rumble-ork-wrk`: notification routing + LRU idempotency for user-initiated notifications.
- `rumble-data-shard-wrk`: FCM push + webhooks; notification types include transfers, swaps, topups, cashouts, login.

---

## 6. Challenges / Weak Points

- Cache bypass: `cache=false` bypasses Redis read/write; shared Redis across app-node workers is required to prevent per-worker divergence.
- Duplicate transfer/swap notifications: inserts/updates can re-emit; dedupe exists but not end-to-end.
- Address uniqueness: ork normalizes input, but data-shard `getWalletByAddress` relies on lowercasing; migrations needed for existing dupes.
- AA hash mapping: userOp hash vs bundle hash causes duplicate history/webhooks.
- `[HRPC_ERR]=Pool was force destroyed`: docs conflict (Hyperswarm pool race vs Mongo pool destruction); root cause unresolved.
- `config/facs/net.config.json` is not loaded by `tether-wrk-base`; netOpts (poolLinger/timeout) are ignored unless code changes are applied.
- Candide API usage spikes (1M/5 days) and provider errors; monitoring/alerts needed.
- Data-shard "latest transfers" ticket still open.

---

## 7. Security Threats

- Secrets committed in `config/common.json` (topicConf keys, JWT/SSO secrets, rumble server token).
- Internal RPC uses shared secrets only; no mTLS/JWT between services.
- API keys delivered via plaintext email; webhooks are not signed.
- Example configs omit Mongo/Redis auth/TLS.

---

## 8. Industry-Standard Gaps (Documented Backlog)

- Secret management + internal auth (Vault/env, mTLS/JWT).
- Idempotent push/webhook pipeline for transfers/swaps.
- Observability: provider-tagged errors + alerting.
- Load/stress testing (5k users ticket).

---

## 9. Good Add-Ons (Documented Ideas)

- Proxy endpoints for BTC/TON RPC.
- Add provider name in error logs.
- Align Plasma/Sepolia topic/token naming (`usdt0/xaut0` vs `usdt/xaut`).

---

## 10. Active TODOs (Tickets/Tasks)

- Address uniqueness migration + normalization consistency.
- Fix duplicate notifications end-to-end (swap/transfer).
- Decide and fix root cause for `Pool was force destroyed`.
- Apply net config loading in base worker if desired (`_loadFacConf` changes).
- Configure alerts + update BTC tests.
- Stress test Rumble backend (5k users).

---

## 11. References

- Architecture diagram: `_docs/wdk-indexer-local-diagram.mmd`
- Meeting minutes: `_docs/_minutes/*.md`
- Task documentation: `_docs/tasks/`
- Slack discussions: `_docs/_slack/*.md`
- Security audit: `_docs/tasks/task_dependencies_issue/security_audit_report.md`
