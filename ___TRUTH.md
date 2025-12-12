# WDK Indexer – Engineering Truth

**Last Updated:** 2025-12-12
**Scope:** `_INDEXER` workspace (app-node, ork, data-shard, per-chain indexers, Rumble extensions)

---

## 1. Architecture

### 1.1 Topology
- **HTTP Surface:** `wdk-indexer-app-node` (Fastify) → `wdk-ork-wrk` (routing) → `wdk-data-shard-wrk` (data layer) → per-chain indexers
- **Transport:** Hyperswarm/HyperDHT peer-to-peer mesh; topics use `${chain}:${token}` format with shared `topicConf.capability` and `crypto.key`
- **Worker Types:** Proc (writer) and API (reader) pairs; Proc publishes RPC key, API connects to it

### 1.2 Service Layers
| Layer | Repo | Function |
|-------|------|----------|
| HTTP Gateway | `wdk-indexer-app-node` | API key mgmt, rate limiting, Swagger docs |
| Orchestrator | `wdk-ork-wrk` | Wallet registry, address lookups, multi-shard aggregation |
| Data Shard | `wdk-data-shard-wrk` | Wallet/transfer storage, balance aggregation, FX lookup |
| Chain Indexers | `wdk-indexer-wrk-{evm,btc,solana,ton,tron,spark}` | Block/tx sync from RPC providers |

### 1.3 Storage
- **Primary:** HyperDB (peer-to-peer) or MongoDB (centralized) via pluggable factory
- **Caching:** Per-worker LRU for balances/lookups (10K max, 15min TTL)
- **Autobase:** API keys, wallet lookups, org registry

### 1.4 Data Flow
```
Client → HTTP (app-node) → Hyperswarm RPC → ork → data-shard → indexer
                                                      ↓
                                              MongoDB/HyperDB ← RPC Providers
```

---

## 2. Chain & Token Coverage

| Chain | Native | Tokens | Indexer | Sync Interval | Notes |
|-------|--------|--------|---------|---------------|-------|
| Ethereum | ETH | USDT, XAUT | wdk-indexer-wrk-evm | 30s | ERC-4337/Paymaster support |
| Polygon | MATIC | USDT | wdk-indexer-wrk-evm | 15s | Candide bundler |
| Arbitrum | ETH | USDT | wdk-indexer-wrk-evm | 5s | Fast blocks (~0.25s) |
| Plasma | - | USDT0, XAUT0 | wdk-indexer-wrk-evm | 30s | Test chain |
| Sepolia | - | USDT0 | wdk-indexer-wrk-evm | 30s | Test chain |
| Bitcoin | BTC | - | wdk-indexer-wrk-btc | 10m | UTXO conversion |
| Solana | SOL | USDT (SPL) | wdk-indexer-wrk-solana | 5s | Bitquery integration |
| TON | TON | USDT, XAUT (Jetton) | wdk-indexer-wrk-ton | 10s | Gasless/Paymaster |
| Tron | TRX | USDT (TRC20) | wdk-indexer-wrk-tron | 15s | Gasfree.io integration |
| Spark | BTC | - | wdk-indexer-wrk-spark | 10s | Time-based indexing, LNURL |

---

## 3. Rumble Extension Layer

Rumble extends WDK with consumer-facing features:

| Repo | Extends | Added Features |
|------|---------|----------------|
| `rumble-app-node` | `wdk-app-node` | SSO auth, MoonPay, device mgmt, notifications API |
| `rumble-ork-wrk` | `wdk-ork-wrk` | FCM device registry, notification routing, idempotency |
| `rumble-data-shard-wrk` | `wdk-data-shard-wrk` | Firebase notifications, webhooks, Rumble server integration |

**Key Rumble Features:**
- Firebase Cloud Messaging (FCM) for push notifications
- Multi-device registration and management
- Notification types: TOKEN_TRANSFER, SWAP_*, TOPUP_*, CASHOUT_*, LOGIN
- Transaction webhooks ("rant" for tips)
- MoonPay buy/sell integration
- LNURL/Lightning support

---

## 4. Delivered Capabilities

### 4.1 Core Features
- Token balance/transfer queries (single and batch) with address normalization
- API key lifecycle: create, revoke, list, delete; inactivity sweep (30-day default)
- Wallet CRUD with balance aggregation and FX conversion (Bitfinex API)
- Per-chain indexers sync blocks/transactions with configurable batch sizes

### 4.2 Recent Implementations (Dec 2025)
- **MongoDB Retry Logic:** Configurable retries with exponential backoff in data-shard and indexer repos (PR #115, #120, #52)
- **Circuit Breaker:** Provider health tracking with CLOSED/OPEN/HALF_OPEN states in `RpcBaseManager`
- **Address Uniqueness Fix:** Local normalization in ork-wrk prevents case-sensitivity bypass attacks
- **Push-Based Mechanism:** Deployed to dev; 3-retry limit with hourly pull fallback
- **Prometheus Metrics:** Indexer lag, error counts, histograms via push-gateway
- **Test Fixes:** wdk-data-shard-wrk unit tests now 78/78 passing

---

## 5. Challenges & Weak Points

### 5.1 Resolved or Mitigated
- **Mongo timeouts:** Retry logic + `maxTimeMS` added to all read/write operations
- **Address uniqueness:** Local normalization at ork-wrk validation layer
- **RPC failover:** Circuit breaker with weighted provider ordering

### 5.2 Remaining Issues
- **Balance flicker:** Per-worker LRU cache divergence across multiple app-node instances; shared Redis cache planned but not implemented
- **Cache poisoning:** `cache=false` param still writes results; providers at different block heights cause oscillation
- **Pull-only sync:** `eventEngine` unset in shipped configs; push/broadcast POC needs production validation
- **Tracing gaps:** Trace-ID utilities exist but HTTP layer doesn't inject/propagate end-to-end
- **Secrets in repo:** `topicConf` keys and `apiKeySecret` committed; no mTLS/auth on Mongo/Redis
- **AA duplicate hashes:** UserOperation hash vs bundle hash not reconciled; causes duplicate webhook/history entries
- **Swap correlation:** `transactions` + `transaction_legs` tables designed (Dec 2 meeting) but not implemented

### 5.3 Operational Concerns
- **Candide API usage:** 1M calls in 5 days of 5M monthly limit; needs monitoring
- **ORC worker stability:** Peer connection failures at scale (100K requests); HyperDB data-hash issues
- **Provider errors:** Heavy volume from some RPC providers; not release-blocking but needs alerts

---

## 6. Security

### 6.1 Threats
- Shared capability/crypto keys + API-key secret in Git
- No mTLS/JWT on internal RPC; proc RPC tokens are bearer secrets
- API keys delivered via plaintext email; no CAPTCHA or HMAC-signed webhooks
- Redis/Mongo auth/TLS absent in example configs

### 6.2 Mitigations Applied
- Address normalization prevents collision attacks (Nov 2025)
- SHA1HULUD supply-chain audit: all 21 repos clean (Nov 26, 2025)
- Exact dependency versions pinned in package.json

### 6.3 Recommendations (from audit)
- Add `.npmrc` with `ignore-scripts=true`
- Enable Dependabot alerts
- Move secrets to env/Vault
- Implement HMAC-signed webhooks

---

## 7. Features Needed for Industry Standard

| Priority | Feature | Why |
|----------|---------|-----|
| High | Shared Redis balance cache | Eliminate per-worker LRU divergence |
| High | Trace-ID propagation from HTTP | End-to-end request tracing |
| High | Secret management (Vault/env) | Remove secrets from repo |
| Medium | Push pipeline with idempotency | At-least-once delivery, replace polling |
| Medium | AA hash mapping | Map userOp + bundle hash in webhooks/history |
| Medium | mTLS/JWT on internal RPC | Secure mesh communication |
| Low | Shared OpenAPI/TypeScript schema | Reduce drift, generate SDKs |

---

## 8. Nice-to-Haves (from discussions)

- Cross-chain swap orchestration with `swapId` metadata
- Provider-aware error logging with rate-limit dashboards
- One-command local stack (Mongo replica, Redis, Hyperswarm keys)
- Automated deployment scripts (Ansible/K8s)
- Manual retry endpoint for skipped blocks/transactions

---

## 9. Active TODOs

### 9.1 High Priority
- [ ] Migrate balance caching to Redis (task: `task_update_caching_to_redis`)
- [ ] Implement AA hash mapping (userOp + bundle) to stop duplicate transactions
- [ ] Add trace-ID injection from HTTP layer
- [ ] Move secrets to env and apply audit recommendations

### 9.2 Medium Priority
- [ ] Gate transfer-triggered pushes on new inserts to prevent duplicate notifications (task: `Duplicate_swap_notifications_observed`)
- [ ] Add per-notification idempotency for transfer pushes
- [ ] Finish push-based broadcast POC and load tests
- [ ] Align Plasma/Sepolia token names across all repos (usdt0/xaut0 vs usdt/xaut)

### 9.3 Low Priority
- [ ] Create proxy endpoints for BTC/TON RPC
- [ ] Support swap linking via orchestration layer
- [ ] Add Firebase registration toggle via console

---

## 10. Configuration Patterns

### 10.1 File Structure
```
repo/
├── config/
│   ├── common.json          # Global settings, blockchains, topics
│   ├── <chain>.json         # Chain-specific RPC/sync config
│   └── facs/
│       ├── db-mongo.config.json    # MongoDB operations
│       ├── net.config.json         # Hyperswarm/pool settings
│       └── redis.config.json       # Redis connection
```

### 10.2 Key Config Options
```json
// MongoDB retry (db-mongo.config.json)
{ "operations": { "readRetries": 1, "readRetryDelay": 500, "readTimeout": 30000 } }

// Circuit breaker (rpc.base.manager defaults)
{ "failureThreshold": 3, "resetTimeout": 30000, "successThreshold": 2 }

// Sync scheduling (common.json)
{ "syncTx": "*/30 * * * * *", "txBatchSize": 20 }
```

---

## 11. References

| Resource | Path |
|----------|------|
| Architecture diagram | `_docs/wdk-indexer-local-diagram.mmd` |
| Meeting minutes | `_docs/_minutes/*.md` |
| Task documentation | `_docs/tasks/` |
| Slack discussions | `_docs/_slack/*.md` |
| Security audit | `_docs/tasks/task_dependencies_issue/security_audit_report.md` |

---

## 12. Glossary

| Term | Definition |
|------|------------|
| Proc worker | Write-path worker that syncs from blockchain and writes to DB |
| API worker | Read-path worker that serves queries; requires proc-rpc key |
| HyperDHT | Distributed hash table for peer discovery |
| Autobase | Distributed append-only log for wallet/key lookups |
| Jetton | TON token standard (like ERC-20) |
| ERC-4337 | Account abstraction standard for gasless/bundled transactions |
| Paymaster | Contract that sponsors gas fees for ERC-4337 |
