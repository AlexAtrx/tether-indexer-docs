# WDK Indexer Architecture Analysis Report

**Date:** 2026-01-14
**Analyst:** Claude (AI Architecture Analysis)
**Scope:** Complete analysis of _INDEXER workspace including all repositories

---

## Executive Summary

The WDK (Wallet Development Kit) Indexer is a distributed, multi-chain blockchain indexing infrastructure designed for self-custodial wallet applications. The system comprises 25+ interconnected repositories implementing a layered microservices architecture using Hyperswarm for P2P RPC communication and supporting both HyperDB (distributed) and MongoDB (centralized) storage backends.

---

## 1. Repository Inventory

### Core Services (8 repos)
| Repository | Purpose | Worker Types |
|------------|---------|--------------|
| `wdk-app-node` | HTTP REST API for wallet operations | `wdk-server-http-base` |
| `wdk-indexer-app-node` | HTTP REST API for indexer queries | `wdk-server-http-base` |
| `wdk-ork-wrk` | Orchestration & shard routing | `wrk-ork-api` |
| `wdk-data-shard-wrk` | Wallet data storage | `wrk-data-shard-proc`, `wrk-data-shard-api` |
| `wdk-indexer-processor-wrk` | Redis stream transaction router | `wrk-processor-indexer` |
| `wdk-indexer-wrk-base` | Base indexer scaffold | (abstract) |
| `wdk-core` | SDK wallet orchestrator | (client-side) |
| `wdk-devops` | Deployment CLI & HAProxy proxy | (tooling) |

### Chain Indexers (6 repos)
| Repository | Chains | Tokens | Special Features |
|------------|--------|--------|------------------|
| `wdk-indexer-wrk-evm` | Ethereum, Arbitrum, Polygon, Sepolia, Plasma | ETH, USDT, XAUT | ERC-4337 gasless |
| `wdk-indexer-wrk-btc` | Bitcoin | BTC | UTXO conversion |
| `wdk-indexer-wrk-solana` | Solana | SOL, USDT (SPL) | Bitquery integration |
| `wdk-indexer-wrk-ton` | TON | TON, USDT, XAUT (Jetton) | TON gasless |
| `wdk-indexer-wrk-tron` | TRON | TRX, USDT, XAUT (TRC-20) | TRON gasfree |
| `wdk-indexer-wrk-spark` | Spark (Lightning) | BTC | Timestamp-based indexing |

### Rumble Extensions (4 repos)
| Repository | Extends | Additional Features |
|------------|---------|---------------------|
| `rumble-app-node` | wdk-app-node | SSO proxy, MoonPay, Swaps, Notifications API |
| `rumble-ork-wrk` | wdk-ork-wrk | Notification routing, cross-shard aggregation |
| `rumble-data-shard-wrk` | wdk-data-shard-wrk | FCM push, device registry, TX webhooks |
| `rumble-docs` | - | Bruno API collections |

### Shared Libraries (6 repos)
| Repository | Role |
|------------|------|
| `tether-wrk-base` | Base worker class with RPC infrastructure |
| `tether-wrk-ork-base` | Orchestrator base with rack management |
| `svc-facs-httpd` | Fastify HTTP facility |
| `svc-facs-logging` | Pino + Hyperswarm logging |
| `hp-svc-facs-store` | Holepunch Corestore facility |
| `tether-api-client-ruby` | Ruby API client |

### Documentation & DevOps (3 repos)
| Repository | Content |
|------------|---------|
| `wdk-docs` | GitBook SDK/API documentation |
| `wdk-devops` | wdk-be-deploy CLI, HAProxy auth proxy |
| `_wdk_docker_network` | Docker Compose local stack |

---

## 2. Architecture Overview

### 2.1 Layered Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     CLIENT LAYER                                 │
│  WDK SDK (wdk-core) │ Web/Mobile Apps │ Admin Dashboard          │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                   HTTP GATEWAY LAYER                             │
│  wdk-app-node │ wdk-indexer-app-node │ rumble-app-node           │
│  (JWT Auth)   │ (API Key Auth)       │ (SSO + Extensions)        │
└─────────────────────────────────────────────────────────────────┘
                              │ Hyperswarm RPC
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                 ORCHESTRATION LAYER                              │
│  wdk-ork-wrk (shard routing, Autobase lookups, LRU cache)        │
│  rumble-ork-wrk (+ notification routing, idempotency)            │
└─────────────────────────────────────────────────────────────────┘
                              │ Hyperswarm RPC
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                   DATA SHARD LAYER                               │
│  wdk-data-shard-wrk (Proc: writes, API: reads)                   │
│  rumble-data-shard-wrk (+ FCM, webhooks)                         │
│  └─ Scheduled Jobs: Balance sync (6h), Transfer sync (5min)      │
└─────────────────────────────────────────────────────────────────┘
                              │ Hyperswarm RPC / Redis Streams
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                 TRANSACTION PROCESSOR                            │
│  wdk-indexer-processor-wrk (Redis stream consumer/router)        │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                   INDEXER LAYER                                  │
│  wdk-indexer-wrk-base (schema, metrics, circuit breaker)         │
│  ├─ wdk-indexer-wrk-evm (+ ERC-4337)                             │
│  ├─ wdk-indexer-wrk-btc (+ UTXO)                                 │
│  ├─ wdk-indexer-wrk-solana (+ Bitquery)                          │
│  ├─ wdk-indexer-wrk-ton (+ gasless)                              │
│  ├─ wdk-indexer-wrk-tron (+ gasfree)                             │
│  └─ wdk-indexer-wrk-spark (+ timestamp)                          │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                   STORAGE LAYER                                  │
│  MongoDB Replica Set │ HyperDB/Hyperbee │ Redis (cache/streams)  │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│               BLOCKCHAIN RPC PROVIDERS                           │
│  Infura │ Ankr │ Cloudflare │ TonCenter │ TronGrid │ Bitquery    │
└─────────────────────────────────────────────────────────────────┘
```

### 2.2 Key Architectural Patterns

1. **Proc/API Worker Split**: Each service has:
   - **Proc Worker**: Handles writes, syncs, prints unique RPC key
   - **API Worker**: Handles reads, requires Proc's RPC key

2. **Hyperswarm Mesh**: P2P RPC with capability-based auth:
   - Topic format: `@wdk/{service}` or `{chain}:{token}`
   - Shared `topicConf.capability` and `crypto.key` required

3. **Autobase Coordination**: Distributed append-only logs for:
   - User/wallet/channel to shard mappings
   - API key storage
   - Address lookups

4. **Circuit Breaker**: RPC resilience pattern in indexers:
   - States: CLOSED → OPEN (after 3 failures) → HALF_OPEN
   - Weighted secondary RPC providers
   - Seeded selection for consistent routing

5. **Dual Storage Engine**: Swappable via `dbEngine` config:
   - HyperDB: Distributed, append-only, P2P replication
   - MongoDB: Centralized, replica set, transactions

---

## 3. Data Flow Analysis

### 3.1 Wallet Balance Query Path
```
Client → wdk-app-node (Redis cache check) → wdk-ork-wrk (LRU lookup)
→ wdk-data-shard-wrk (aggregation) → wdk-indexer-wrk-{chain} (RPC)
→ Blockchain RPC → Response with FX conversion
```

### 3.2 Transaction Indexing Path
```
Blockchain → Chain Indexer (sync job) → HyperDB/MongoDB + Redis stream
→ wdk-indexer-processor-wrk (routing) → wdk-data-shard-wrk (storage)
→ Notification/webhook triggers
```

### 3.3 Topic Communication Matrix

| Source | Target | Topic | Methods |
|--------|--------|-------|---------|
| wdk-app-node | wdk-ork-wrk | @wdk/ork | addWallet, getBalance, etc. |
| wdk-indexer-app-node | Chain indexers | {chain}:{token} | getBalance, queryTransfers |
| wdk-ork-wrk | wdk-data-shard-wrk | @wdk/data-shard | wallet CRUD, balance queries |
| wdk-data-shard-wrk | Chain indexers | {chain}:{token} | getBalance, getTransfers |

---

## 4. Supported Chains & Tokens

### 4.1 Configuration Matrix (from actual configs)

| Chain | Token | Worker Type | Decimals | Gasless | Notes |
|-------|-------|-------------|----------|---------|-------|
| Ethereum | ETH | wrk-evm-indexer | 18 | ERC-4337 | Mainnet |
| Ethereum | USDT | wrk-erc20-indexer | 6 | ERC-4337 | ERC-20 |
| Ethereum | XAUT | wrk-erc20-indexer | 6 | ERC-4337 | ERC-20 |
| Sepolia | USDT | wrk-erc20-indexer | 6 | - | Testnet |
| Plasma | USDT | wrk-erc20-indexer | 6 | - | Chain 9745 |
| Plasma | XAUT | wrk-erc20-indexer | 6 | - | Chain 9745 |
| Arbitrum | USDT | wrk-erc20-indexer | 6 | ERC-4337 | L2 |
| Polygon | USDT | wrk-erc20-indexer | 6 | ERC-4337 | L2 |
| Bitcoin | BTC | wrk-btc-indexer | 8 | - | Native |
| Solana | SOL | wrk-solana-indexer | 9 | - | Native |
| Solana | USDT | wrk-spl-indexer | 6 | - | SPL token |
| TON | TON | wrk-ton-indexer | 9 | TON gasless | Native |
| TON | USDT | wrk-jet-indexer | 6 | TON gasless | Jetton |
| TON | XAUT | wrk-jet-indexer | 6 | TON gasless | Jetton |
| TRON | TRX | wrk-tron-indexer | 6 | TRON gasfree | Native |
| TRON | USDT | wrk-trc20-indexer | 6 | TRON gasfree | TRC-20 |
| Spark | BTC | wrk-spark-indexer | 8 | - | Lightning |

### 4.2 Documentation vs Config Discrepancies

| Item | Config Says | Docs Say | Resolution |
|------|-------------|----------|------------|
| Solana | Supported | Not listed | Config is source of truth |
| Token naming | usdt, xaut | usdt0, xaut0 | Inconsistent, needs alignment |
| BTC case | btc | BTC | Normalize to lowercase |

---

## 5. Feature Analysis

### 5.1 Delivered Features ✓

- **Multi-chain indexing** (6 blockchains + L2s)
- **REST APIs** with Swagger documentation
- **API key authentication** with TTL, rate limiting
- **JWT authentication** for wallet APIs
- **Redis caching** (30s TTL for balances)
- **Prometheus metrics** (sync lag, RPC errors, DB writes)
- **Circuit breaker** with weighted provider selection
- **Gasless transactions** (ERC-4337, TON, TRON)
- **FX price conversion** (Bitfinex API)
- **FCM push notifications** (Rumble extension)
- **Webhook integration** (Rumble server, Fivetran)
- **MoonPay fiat on/off ramp** (Rumble extension)

### 5.2 Known Weak Points (from TRUTH file + code review)

1. **Balance Oscillation**: Round-robin RPC + random shard selection causes inconsistent reads
2. **Ork Startup Fragility**: Empty ork list → undefined RPC key → generic 500 errors
3. **Notification Reliability**: In-memory LRU idempotency → duplicates possible on restart
4. **Address Normalization**: Migration required; `getWalletByAddress` fallback masks duplicates
5. **MongoDB Timeouts**: Pool-destroyed errors observed; inconsistent retry settings
6. **Solana Sync Disabled**: `sync-tx` job commented out with "TEMP disable"

### 5.3 Security Considerations

1. **Internal RPC Auth**: Only `topicConf` secrets; ork has no additional auth layer
2. **API Key Email**: Can send keys in plaintext (no encryption)
3. **Config Secrets**: Placeholder secrets in example configs (risk if committed)
4. **Address Duplication**: Normalization gaps can map same address to multiple wallets

---

## 6. Rumble Extension Analysis

The Rumble extension layer adds B2C features on top of WDK:

| Feature | App Node | Ork | Data Shard |
|---------|----------|-----|------------|
| SSO Proxy | ✓ | - | - |
| MoonPay Integration | ✓ | - | - |
| Swap API | ✓ | - | - |
| Notifications Endpoint | ✓ | - | - |
| Notification Routing | - | ✓ | - |
| Idempotency (LRU) | - | ✓ | - |
| Cross-shard Aggregation | - | ✓ | - |
| FCM Push | - | - | ✓ |
| Device Registry | - | - | ✓ |
| TX Webhooks | - | - | ✓ |
| Rumble Server Integration | - | - | ✓ |

---

## 7. Recommendations

### 7.1 Critical (from backlog)

1. **Deterministic reads**: Implement sticky provider/peer selection (PRs exist)
2. **Durable idempotency**: Persist notification dedupe to Redis/DB
3. **Startup readiness gates**: 503 responses until ork/shard discovery completes
4. **Address normalization**: Complete migration across all shards

### 7.2 Important

1. **Re-enable Solana sync-tx**: Investigate root cause of TEMP disable
2. **Config alignment**: Unify chain/token naming across configs and docs
3. **Provider metrics**: Add provider-name logging and alerting
4. **Load testing**: Implement repeatable 5k+ user stress tests

### 7.3 Nice to Have

1. **Service authentication**: Mutual TLS or token-based inter-service auth
2. **Unified secret management**: Integrate with vault or secret manager
3. **RPC proxy endpoints**: Centralized TON/BTC RPC routing

---

## 8. Files in This Analysis

| File | Description |
|------|-------------|
| `wdk-indexer-architecture-2026-01-14.mmd` | Full system architecture diagram |
| `wdk-data-flow-2026-01-14.mmd` | Sequence diagram of key data flows |
| `wdk-component-dependencies-2026-01-14.mmd` | Repository dependency graph |
| `ANALYSIS_REPORT.md` | This document |

---

## 9. Conclusion

The WDK Indexer is a sophisticated distributed system with solid architectural foundations. The Hyperswarm-based RPC mesh provides decentralization benefits, while the Proc/API worker split enables read scaling. The main areas for improvement center on consistency (balance reads, notification dedupe) and operational resilience (startup gates, provider failover).

The Rumble extensions demonstrate the extensibility of the base WDK layer, adding B2C features without modifying core services. This pattern should be maintained for future feature additions.

---

*Analysis generated by Claude based on comprehensive code review of all 25+ repositories in the _INDEXER workspace.*
