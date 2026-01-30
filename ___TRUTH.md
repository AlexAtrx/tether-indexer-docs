# WDK Indexer - Engineering Truth

Last Updated: 2026-01-28
Scope: `_INDEXER` workspace (indexer stack, rumble extensions, shared libs, WDK SDK/docs)

---

## 1. Architecture (Key Decisions)

### Request Flow
- `wdk-indexer-app-node` (HTTP:3000) serves indexer REST and calls `chain:token` topics directly
- `wdk-app-node`/`rumble-app-node` serve wallet APIs via `wdk-ork-wrk` → `wdk-data-shard-wrk` → indexers
- Full path: Client → App Node (Redis cache) → Ork (LRU lookup) → Data Shard (aggregation) → Indexer (multi-provider RPC) → Blockchain → FX conversion (Bitfinex) → Response

### Proc/API Worker Split
- **Proc workers**: Singleton, handles writes, sync jobs; prints RPC public key at startup
- **API workers**: Stateless, handles reads; requires `--proc-rpc` key from Proc logs; horizontally scalable
- Enables read scaling while concentrating write operations

### Hyperswarm P2P RPC Mesh
- Services discover each other via DHT topics: `@wdk/ork`, `@wdk/data-shard`, per-chain `{chain}:{token}`, `@rumble/*`
- Authentication via shared `topicConf.capability` (handshake) and `topicConf.crypto.key` (HMAC-SHA384)
- All services in same deployment must use **identical** secrets
- Silent failure if topics/secrets mismatch - services start but don't connect

### Storage Engine Selection
- Configurable via `dbEngine` parameter: `hyperdb` or `mongodb`
- **HyperDB**: Distributed, append-only, P2P replication (blockchain data)
- **MongoDB**: Centralized, replica set required, transactions (wallet/user data)
- Schema changes in HyperDB require version bumps and migrations (append-only constraint: new fields MUST be added at END)

### Autobase Coordination
- Ork uses Autobase for user/wallet/channel → shard mappings
- Indexer app stores API keys in Autobase
- Processor uses Autobase lookups for routing
- Ensures consistent routing across shards without single point of failure

### Caching & Metrics
- Redis required for `wdk-app-node` caching (30s TTL), rate limits, optional transfer streams
- `cache=false` parameter skips both read and write (risk: mixed cache/live calls cause balance oscillation)
- Indexer base pushes Prometheus metrics (sync lag, latency, RPC metrics)

---

## 2. Components (What They Do)

### API Nodes
- **wdk-indexer-app-node**: Token balances/transfers, batch endpoints, API-key auth, request-api-key email flow, Swagger UI at `/docs`
- **wdk-app-node**: Wallet CRUD, balance + trend endpoints, token transfers; JWT auth with optional dev test mode
- **rumble-app-node**: SSO/passkey proxy, device-id APIs, notification endpoint, MoonPay + swaps, admin APIs, Sentry

### Routing Layer
- **wdk-ork-wrk**: Shard routing, Autobase lookups, LRU caches, deleted-user cleanup (12AM Sundays)
- **rumble-ork-wrk**: Notification routing, LRU idempotency for manual types, balance-failure thresholds, cross-shard admin queries

### Data Shards
- **wdk-data-shard-wrk**: Wallet storage, aggregation, FX pricing (Bitfinex), scheduled sync (balance: 6h, transfers: 5min)
- **rumble-data-shard-wrk**: FCM device registry, transfer notification dedupe (LRU), webhooks (Rumble server + Fivetran), gasless retry controls

### Chain Indexers
- **wdk-indexer-wrk-base**: Base class with multi-provider RPC, circuit breaker (3 failures → OPEN → 30s reset)
- **Chain workers**: EVM (Ethereum, Arbitrum, Polygon, Sepolia, Plasma), BTC, Solana/SPL, TON/Jetton, TRON/TRC-20, Spark

### Event Routing
- **wdk-indexer-processor-wrk**: Routes Redis transfer streams to shard streams (optional)
- Data shards consume when `eventEngine=redis`

### Shared Infrastructure
- **tether-wrk-base**, **tether-wrk-ork-base**: Base worker extensions
- **svc-facs-httpd**: Fastify HTTP facility
- **svc-facs-logging**: Pino logging facility
- **hp-svc-facs-store**: Holepunch persistent datastores
- **wdk-devops**: BE deployment configs, HAProxy auth proxy

---

## 3. Supported Chains/Tokens

### Production Configuration

| Chain | Tokens | Worker | Gasless | Block Time | Batch Size |
|-------|--------|--------|---------|------------|------------|
| Ethereum | ETH, USDT, XAUT | wrk-evm-indexer | ERC-4337 | 12s | 20 |
| Arbitrum | USDT | wrk-erc20-indexer | ERC-4337 | 0.25s | 40 |
| Polygon | USDT | wrk-erc20-indexer | ERC-4337 | 2.1s | 30 |
| Sepolia | USDT | wrk-erc20-indexer | - | - | Testnet |
| Plasma | USDT, XAUT | wrk-erc20-indexer | - | 12s | Chain 9745 |
| Bitcoin | BTC | wrk-btc-indexer | - | - | UTXO model |
| Solana | SOL, USDT (SPL) | wrk-solana-indexer | - | - | Via Bitquery |
| TON | TON, USDT, XAUT (Jetton) | wrk-ton-indexer | Native | - | - |
| TRON | TRX, USDT, XAUT (TRC-20) | wrk-tron-indexer | Gasfree | - | - |
| Spark | BTC | wrk-spark-indexer | - | - | Lightning |

### Config vs Docs Discrepancies
- **Solana**: Supported in config but not listed in public docs
- **Token naming**: Inconsistent (`usdt` vs `usdt0`, `xaut` vs `xaut0`, `btc` vs `BTC`)
- **Ork/data-shard configs**: Separate from indexer app config; Rumble adds Plasma

---

## 4. Delivered Features

### Indexer REST API
- Token balances/transfers queries with batch support
- API-key authentication with TTL and rate limiting
- Request-API-key email flow
- Swagger UI documentation

### Wallet REST API
- Connect wallet endpoints
- Wallet CRUD operations
- Balance + trend endpoints
- Token transfer history
- Tip-jar endpoints (Rumble)
- JWT authentication with optional dev test mode

### RPC Resilience
- **Multi-provider selection**: Weighted round-robin to multiple RPC endpoints
- **Circuit breaker**: CLOSED → OPEN (3 failures) → HALF_OPEN (30s reset)
- **Provider metrics**: Tracked in indexer base for monitoring

### Gasless Transactions
- **EVM**: ERC-4337 with paymaster labels for transfers
- **TON**: Native gasless receipts
- **TRON**: Gasfree native transfers

### Pricing & Streams
- Bitfinex batch FX conversion for multi-currency balance queries
- Scheduled sync jobs: balance sync (6h), transfer sync (5min)
- Optional Redis stream pipeline for transfer event routing

---

## 5. Rumble Extensions

### rumble-app-node
- SSO and passkey proxy endpoints
- Device-id APIs, notification endpoint
- MoonPay + swaps integration
- Admin APIs, Sentry error tracking

### rumble-ork-wrk
- Notification routing with LRU idempotency for manual types
- Balance-failure thresholds
- Cross-shard admin queries

### rumble-data-shard-wrk
- FCM device registry with deduplication
- Transfer notification dedupe (LRU)
- Webhooks: Rumble server + Fivetran
- Gasless retry controls

### Transaction Types (Jan 2026 Update)
- **Phase 1 (Deployed)**: Explicit types `TOKEN_TRANSFER_RANT` (requires `payload`, `dt`, `id`) and `TOKEN_TRANSFER_TIP` (requires `dt`, `id`) with strict validation
- **Phase 2 (Pending)**: Remove legacy `TOKEN_TRANSFER` inference after mobile migration (2-3 releases)

---

## 6. WDK SDK/Docs Snapshot

### wdk-core
- Orchestrates wallets + protocol modules
- Register wallets, protocols, middleware

### Wallet Modules
- EVM, ERC-4337, BTC, TRON, TON (gasless), Solana, Spark
- See `wdk-docs/sdk/wallet-modules`

### Protocol Modules
- **Swap**: Velora (EVM), StonFi (TON)
- **Bridge**: USDT0 EVM/TON
- **Lending**: Aave V3 (EVM)
- **Fiat**: MoonPay

### Tools
- Secret manager, pricing (Bitfinex), UI kit, community modules

---

## 7. Challenges / Weak Points

### Balance Oscillation (CRITICAL)
- **Root cause**: Round-robin RPC provider + random shard peer selection
- **Symptom**: User balance fluctuates due to inconsistent reads
- **Evidence**: Multiple task files document balance oscillation after transactions
- **Mitigation**: Sticky provider selection PRs exist (not merged); deterministic peer selection needed

### Ork Startup Fragility (CRITICAL)
- **Issue**: Empty ork list → undefined RPC key → generic 500 errors
- **Root cause**: RoundRobin index corrupts on empty updates; no readiness gate
- **Impact**: Service starts but is unusable until peers discovered
- **Solution needed**: Guard `ERR_NO_ORKS_AVAILABLE`, fix RoundRobin, add readiness gate

### Notification Reliability (HIGH)
- **Idempotency**: In-memory LRU only (no persistence) - duplicates possible on restart
- **Device tokens**: Can go stale or duplicate
- **Issues**: "Duplicate swap notifications" and "missing live chat notifications" documented
- **Solution needed**: Persist dedupe to Redis/DB, deterministic device IDs

### Address Normalization (HIGH)
- **Vulnerability**: Case-sensitivity bypass allowed duplicate wallet creation
- **Status**: FIXED (Nov 2025) - local normalization in ork-wrk
- **Remaining**: Legacy duplicates may exist; `getWalletByAddress` fallback to lowercase can mask duplicates
- **Action**: Run migrations to clean existing duplicates across shards

### MongoDB Timeouts (HIGH)
- **Errors**: `pool-destroyed` and timeout errors observed in production
- **Status**: FIXED (Dec 2025) - configurable retry logic added (maxTimeMS: 30000, readRetries: 1, readRetryDelay: 500)
- **Cause**: Inconsistent retry/timeout settings, replica set issues

### Solana Sync Disabled (MEDIUM)
- **Status**: `sync-tx` job commented with "TEMP disable" in Solana proc worker
- **Impact**: Solana transaction indexing not working
- **Action**: Investigate and re-enable or remove

### FCM Token Default (FIXED)
- **Issue**: New device registrations had `isActive: false` by default
- **Status**: FIXED (Jan 2026) - changed default to `true`
- **Remaining**: `isLikelyFcmToken()` heuristic is architectural debt - should be removed

---

## 8. Security Threats / Risks

### Address Duplication Risk
- **Status**: FIXED (Nov 2025) - local normalization in ork-wrk
- **Remaining**: Legacy duplicates may exist in database
- **Action**: Run migrations to identify and clean duplicates

### Internal RPC Auth Gaps
- **Issue**: Services rely only on shared `topicConf` secrets; ork has no additional auth
- **Risk**: Internal-network-only deployment assumed
- **Mitigation**: Add network policies in Kubernetes, consider mutual TLS

### API Key Plaintext Delivery
- **Issue**: Email-based API key distribution in `wdk-indexer-app-node`
- **Risk**: Keys visible in email, logs, browser history
- **Mitigation**: Use secure key delivery (in-app generation, WebAuthn, OAuth)

### Config Secrets Risk
- **Issue**: Example configs contain placeholder secrets
- **Risk**: Accidental real secret commits
- **Mitigation**: Use environment variables, secrets manager, .gitignore

### Device Token Deduplication
- **Issue**: Same FCM token can register for multiple devices
- **Status**: FIXED (Jan 2026) - added device deactivation logic for duplicate tokens
- **Risk**: Notifications sent to wrong user (mitigated)

### Supply Chain Risk
- **Status**: Dependency audit completed; Shai-Hulud attack reports verified - none of flagged packages used
- **Action**: Regular re-audit recommended

---

## 9. Industry-Standard Gaps (To Be Top-Tier)

### Must Have
- **Deterministic reads**: Sticky provider/peer selection for balance queries (PRs exist, not merged)
- **Durable idempotency**: Persisted dedupe for notifications/webhooks (Redis/DB)
- **Startup readiness**: 503 mapping and readiness gates for empty ork/shard discovery
- **Service health checks**: Comprehensive health endpoints

### Should Have
- **Observability**: Provider-tagged errors and alerting (tickets exist); app/data-shard metrics limited vs indexers
- **Load testing**: Repeatable stress tests (5k+ users); BTC regression tests
- **Service auth**: Internal auth between workers (mutual TLS or token auth)
- **Secret management**: Unified secret manager integration (Vault, AWS Secrets)

### Nice to Have
- Shared TypeScript/OpenAPI spec for API contracts
- Full Kubernetes migration (Docker Compose → K8s)
- RPC proxy endpoints for centralized TON/BTC routing

---

## 10. Active TODOs

### Phase 1: Transaction Types (IN PROGRESS)
- [x] Design explicit types: `TOKEN_TRANSFER_RANT`, `TOKEN_TRANSFER_TIP`
- [x] Add validation in `rumble-ork-wrk`
- [ ] Coordinate mobile team migration
- [ ] Monitor legacy vs. explicit type usage
- [ ] Phase 2: Remove inference logic after 2-3 mobile releases

### Phase 2: Address Normalization Cleanup
- [ ] Run ork/data-shard migrations across all shards
- [ ] Clean duplicate addresses from Rumble extensions
- [ ] Verify with mixed-case addresses on all chains
- [ ] Monitor for `ERR_ADDRESS_ALREADY_EXISTS`

### Phase 3: Ork Startup Resilience
- [ ] Guard `ERR_NO_ORKS_AVAILABLE` error path
- [ ] Fix RoundRobin empty update handling
- [ ] Add readiness gate (503 until discovery complete)
- [ ] Add health check endpoint

### Phase 4: Balance Determinism
- [ ] Merge sticky provider selection PRs
- [ ] Implement deterministic shard peer selection
- [ ] Align cache usage between balance APIs
- [ ] Load testing with 5k+ users

### Phase 5: Durable Idempotency
- [ ] Migrate in-memory LRU dedupe to Redis
- [ ] Persist transfer notification webhook state
- [ ] Deterministic device ID generation
- [ ] Handle restart safely without duplicates

### Other High-Priority
- [ ] Re-enable Solana sync-tx job (investigate TEMP disable)
- [ ] Add provider-name logging + alerting
- [ ] ERC-4337: Track failed transactions by userOp hash vs bundle hash
- [ ] Remove `isLikelyFcmToken` heuristic (coordinate with mobile)
- [ ] Config/docs alignment (chain/token naming)
- [ ] Replace deprecated local Docker orchestration

---

## 11. Technology Stack

### Runtime & Frameworks
- **Node.js** - Primary runtime
- **Fastify** - HTTP server (via `svc-facs-httpd`)
- **bfx-svc-boot-js** - Service bootstrap framework (Bitfinex)

### P2P & Storage
- **Hyperswarm/HyperDHT** - P2P networking layer
- **HyperDB/Hyperbee** - Distributed append-only database
- **Autobase** v7.24.0 - Distributed append-only log
- **MongoDB** v7.0 - Centralized data store (replica set required)
- **Redis** v7.0 - Caching, rate limiting, streams

### Blockchain Libraries
- **Ethers** v6.14.4 - EVM interaction
- **Solana Web3.js** - Solana integration
- TON, TRON, Bitcoin native libraries
- Spark for Lightning Network

### Development
- **TypeScript** v5.8.3 - Type safety
- **Brittle** v3.16.3 - Testing (services)
- **Jest** - Testing (wdk-core)
- **Standard** v17.1.2 - Linting (no semicolons)
- **Pino** - Logging

### Third-Party Services
- **Bitfinex API** - FX price conversion
- **Infura/Alchemy/Cloudflare** - RPC endpoints
- **Tenderly** - Transaction simulation
- **Firebase Admin** - FCM push (Rumble)
- **MoonPay** - Fiat on/off ramp (Rumble)
- **Candide** - ERC-4337 paymaster

---

## 12. Recent Changes (Nov 2025 - Jan 2026)

| Date | Change | Status |
|------|--------|--------|
| Jan 27, 2026 | Explicit transaction types (RANT/TIP) proposal | Phase 1 deployed |
| Jan 23, 2026 | FCM token isActive default fix | Deployed |
| Dec 2, 2025 | MongoDB timeout & retry implementation | Deployed |
| Nov 26, 2025 | Hyperswarm poolLinger fix (300s → 600s) | Deployed |
| Nov 19, 2025 | Address uniqueness security fix | Deployed |

---

## 13. References

- `WARP.md` - Detailed setup and boot order
- `GEMINI.md` - Overall project architecture
- `_docs/APP_RELATIONS.md` - Service relationships
- `_docs/wdk-indexer-local-diagram.mmd` - Architecture diagram
- `_docs/_app_setup/LOCAL_INDEXER_SETUP_PLAN.md` - Local setup guide
- `_docs/analysis-2026-01-14/ANALYSIS_REPORT.md` - Comprehensive analysis
- `wdk-indexer-app-node/README.md` - Indexer app docs
- `wdk-docs/tools/indexer-api/README.md` - API documentation
- `rumble-docs/` - Bruno collections for Rumble APIs
