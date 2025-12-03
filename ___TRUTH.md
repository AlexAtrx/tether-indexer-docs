# WDK Indexer – Engineering Truth

**Last Updated:** 2025-12-02  
**Scope:** `_INDEXER` workspace (app-node, ork, data-shard, per-chain indexers, docs)

## Architecture (from code/config)
- **Topology:** Fastify HTTP surface (`wdk-indexer-app-node`) → ork gateway (`wdk-ork-wrk`) → data shard (`wdk-data-shard-wrk` proc/api) → per-chain indexers (proc/api). All services are Node.js workers on Hyperswarm; topics use `${chain}:${token}` and share `topicConf.capability/crypto.key`.
- **Proc/API split:** Proc workers sync and write; API workers serve reads and require `--proc-rpc` (printed on proc start). `app-node` exposes RPC for API-key/admin ops; ork/data-shard expose RPC internally only.
- **Storage:** HyperDB is the default DB across repos; MongoDB is optional via config (no auth/TLS defined). Autobase holds API keys and wallet lookups in app-node/ork. Price cache is per-process LRU (no shared cache).
- **Data flow:** Data shard pulls balances/transfers over Hyperswarm (`jTopicRequest`); Redis stream publish/consume exists in indexer/data-shard but is **off by default** unless `eventEngine: "redis"` is set.
- **Scheduling:** Indexers run `syncTx` + cleanup (daily/weekly). Data shard runs balance history, transfer sync (`*/5 * * * *` default), inactivity cleanup. App node revokes inactive API keys (daily).
- **Chain/Token coverage (configs):** Ethereum, Arbitrum, Polygon, Sepolia (`usdt0`), Plasma (`usdt0`, `xaut0`), Tron, TON, Solana, Bitcoin, Spark. EVM configs include ERC-4337 bundler/paymaster endpoints; data-shard/app configs expect the `usdt0/xaut0` names for test chains.
- **HTTP surface:** Swagger at `/docs`. Routes: request API key (email), health, token balances/transfers (single + batch) with API-key auth and per-route rate limits (Redis-backed).

## Delivered Capabilities
- Token balance/transfer queries over HTTP (single and batch) mapped to per-chain indexer RPCs with address normalization for non-case-sensitive chains.
- API key lifecycle via RPC/HTTP (`create/revoke/get/deleteApiKeysForOwner`, block/unblock user); inactivity sweep job.
- Data shard wallet CRUD, balance aggregation with FX lookup, transfer history per wallet/user; sanitizes addresses using chain-specific case rules.
- Per-chain indexers stream blocks/transactions from configured RPC providers, store to HyperDB/Mongo, and (optionally) publish to Redis streams.

## Challenges & Weak Points
- **Mongo pool failures unhandled:** Indexer API handlers lack retries/timeouts; documented root cause (`[HRPC_ERR]=Pool was force destroyed`) is not patched in the current code.
- **Address uniqueness gap:** Ork only logs warnings on duplicate addresses; no enforced normalization/uniqueness at org level. Data shard allows same address across users after sanitization.
- **Config drift on token names:** App/data-shard use `usdt0/xaut0` for Sepolia/Plasma while indexer configs use `usdt`/`xaut`; risk of topic mismatch and empty data.
- **Pull-only sync:** `eventEngine` is unset in shipped configs, so data shard polls indexers; push/broadcast design is pending (Nov 25–Dec 2 meetings).
- **Balance flicker:** Slack/tickets cite mixed cache behavior (per-worker LRU, cache poisoning when `cache=false` still writes) plus provider height differences.
- **Tracing gaps:** Trace ID utilities exist in ork/data-shard, but HTTP layer doesn’t inject/propagate IDs; logs are hard to stitch end-to-end.
- **Secrets in repo:** `topicConf` keys and `apiKeySecret` committed; no TLS/auth for Mongo/Redis in configs; proc RPC keys printed to stdout.
- **Observability gaps:** RPC errors omit provider name; Alertmanager/Grafana contact points incomplete; rate-limit/proxy usage unclear for heavy providers (Candide usage spike).
- **AA duplicate hashes:** UserOperation hash vs bundle hash not reconciled; leads to duplicate webhook/history entries.
- **Swap correlation not implemented:** Dec 2 discussion defined `transactions` + `transaction_legs` with `swapId`; no code yet.

## Security Threats
- Shared capability/crypto keys + API-key secret stored in Git; no mTLS/JWT on internal RPC; proc RPC tokens are bearer secrets.
- API keys delivered via plaintext email; no CAPTCHA or HMAC-signed webhooks; Redis/Mongo auth/TLS absent in examples.
- Address collision risk from missing normalization/uniqueness enforcement.
- Supply-chain audit (SHA1HULUD) in docs reports clean on 2025-11-26; recommendations (ignore-scripts, Dependabot) not applied in configs.

## Features Needed for Industry Standard
- Authenticated mesh and secret management (Vault/env), mTLS/JWT/HMAC on RPC + secure API-key delivery portal.
- End-to-end tracing with trace IDs from HTTP → ork → data-shard → indexer, plus provider metadata in logs and alerts.
- Robust push pipeline (Redis/Kafka) with at-least-once + idempotency for transfers instead of cron polling; health checks/metrics on delivery lag.
- Shared OpenAPI/TypeScript schema + generated SDKs to reduce drift (noted lack of shared spec in reviews).
- Centralized caching for balances (Redis) and provider health/circuit-breakers to avoid per-worker LRU divergence.
- Webhook hardening (HMAC signatures, retry/DLQ) and AA hash mapping (userOp + bundle hash) in history/webhooks.

## Nice-to-Haves (from discussions)
- Cross-chain swap orchestration layer using `transactions` + `transaction_legs` with `swapId` metadata.
- Provider-aware error logging/alerting and rate-limit dashboards; automated deployment scripts (Ansible/K8s) for workers.
- One-command local stacks (Mongo replica set, Redis, sample Hyperswarm keys) for reproducible tests.

## Active TODOs (from minutes/tickets/tasks)
- Add Mongo retry/timeouts in indexer API handlers; fix `[HRPC_ERR]=Pool was force destroyed` crash path.
- Handle Hyperswarm pool/DHT errors (netOpts/poolLinger) in tether-wrk-base; align data-shard/indexer configs.
- Enforce address normalization + uniqueness in ork/data-shard; add migration for existing data.
- Migrate balance caching to Redis (`update_caching_of_endpoints_to_use_bfx-facs-redis_as_opposed_to_lru_cache.md`); avoid cache poisoning when bypassing cache.
- Align Plasma/Sepolia token names/topics across app/data-shard/indexer; verify HyperDHT topics (`plasma+usdt0/xaut0`, `sepolia+usdt0`).
- Add provider identifiers to RPC error logs; configure alerts for critical RPC timeouts.
- Finish push-based broadcast POC and load tests; keep router design as fallback.
- Add trace-id propagation from HTTP layer; include service name + trace in logs.
- Create proxy endpoints for BTC/TON RPC per ticket; confirm port/TLS expectations.
- Implement AA hash mapping (userOp + bundle) to stop duplicate transactions in webhooks/history.
- Apply security-audit recs (ignore-scripts, Dependabot, secret scanning) and move secrets to env.
- Support Sepolia/Plasma deployments per tickets; ensure configs and tests are updated accordingly.

## References
- Diagram: `_docs/wdk-indexer-local-diagram.mmd`
- Minutes: `_docs/_minutes/*.md` (Nov 5–Dec 2 sessions on timeouts, cache, push design, swaps)
- Slack notes: `_docs/_slack/*.md` (balance flicker, trace ID, AA duplicate hashes, provider usage)
- Tasks/Tickets: `_docs/tasks/*`, `_docs/_tickets/*` (Mongo pool destruction analysis, Hyperswarm pool fixes, caching, Sepolia/Plasma, proxy endpoints)
