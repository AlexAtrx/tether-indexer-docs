# WDK Indexer - Engineering Truth Document

**Last Updated:** November 18, 2025
**Previous Version:** November 17, 2025

---

## 1. KEY ARCHITECTURE DECISIONS

### 1.1 System Design

**Distributed Multi-Chain Blockchain Indexer** using P2P mesh architecture for self-custodial wallets (WDK – Wallet Development Kit).

**Service Stack (Runtime Order):**
```
User → wdk-indexer-app-node (HTTP REST, port 3000)
     → wdk-ork-wrk (Org service, API gateway)
     → wdk-data-shard-wrk (Business logic, wallet data)
     → wdk-indexer-wrk-{chain} (Per-chain indexers)
     → MongoDB + Blockchain RPC Providers
```

**Technology Choices:**
- **Runtime:** Node.js (ES Modules), minimum v16+
- **P2P Layer:** Hyperswarm v3.x for distributed RPC mesh
- **Storage:** HyperDB (append-only) + MongoDB replica set (3-node minimum)
- **HTTP:** Fastify-based server
- **Logging:** Pino v9.7.0

### 1.2 Proc/API Worker Pattern

**Decision:** Each service has two worker types:
- **Proc worker (writer):** Mutations, blockchain sync, HyperDB writes, prints unique RPC key
- **API worker (reader):** Serves queries, requires `--proc-rpc` key from Proc worker

**Rationale:** Write/read scaling independence, reduces lock contention
**Tradeoff:** Requires RPC key management, more processes to orchestrate

### 1.3 P2P RPC via Hyperswarm Mesh

**Decision:** All workers communicate via Hyperswarm topics for service discovery
**Rationale:** Eliminates single point of failure, enables dynamic scaling
**Tradeoff:** Requires shared secrets (`topicConf.capability` + `crypto.key`), complex debugging

**Critical Invariant:** All services MUST share identical `topicConf.capability` and `topicConf.crypto.key` in `config/common.json`. Mismatch = silent failure.

### 1.4 Storage Model

**MongoDB:** Per-domain databases (e.g., `wdk_indexer_evm`, `wdk_data_shard`)
**HyperDB:** Append-only log for blockchain data, schema codecs via `wdk-indexer-wrk-base`
**Decision:** Replica set required (not single-node)
**Rationale:** Write concern majority guarantees consistency
**Tradeoff:** Higher operational overhead, transaction support disabled by default

### 1.5 No Authentication in Org Service

**Decision:** `wdk-ork-wrk` has no auth layer
**Rationale:** Internal routing only, auth handled at HTTP boundary
**Risk:** Must be kept on internal network, vulnerable if exposed

---

## 2. KEY CHALLENGES & WEAK POINTS

### 2.1 Production Stability Issues (CRITICAL)

**MongoDB Timeout Hangs:**
- Jobs stop logging after few executions due to hanging transactions
- `isRunning` flag never resets when promises reject/hang
- Missing timeouts: `maxCommitTimeMS`, `maxTimeMS` on queries
- `bulkWrite` doesn't accept `maxTimeMS` (must use driver-level timeout)
- **Impact:** Manual restart + Redis clear required
- **Fix (In Progress):** Add `maxCommitTimeMS` to `session.startTransaction()`, wrap `abortTransaction` in try/catch, use `Promise.allSettled` for batch RPC calls

**Indexer-Wallet Sync Lag:**
- Missing balance updates and transaction notifications
- Data shard worker missing sync jobs
- Root cause: DB lock waits have no timeout
- **Fix:** Timeout settings implemented, needs MongoDB-savvy review

**Worker Stalls at ~5k Wallets:**
- Stress test worker stalled at ~5k wallets, logs enabled, under investigation
- Retry logic added in Alex's PR (pending validation)
- **Blocker:** Indexer sharding bottleneck for ~100k users (wallet launch target)
- **Action:** Stress test before beta launch

### 2.2 Security Vulnerabilities (CRITICAL)

**Hardcoded Secrets:**
- `apiKeySecret: "secret-key"` in example configs
- `topicConf.capability` and `topicConf.crypto.key` in plaintext config files
- **Impact:** Config file compromise = full system access
- **Fix:** Environment variables + secrets vault (HashiCorp Vault, AWS Secrets Manager)

**No RPC Authentication:**
- Hyperswarm RPC has no authentication beyond topic membership
- Any service with capability can join mesh and call admin methods (`blockUser`, `deleteApiKeysForOwner`)
- **Impact:** Internal services can abuse admin functions
- **Fix:** Implement RPC method-level authorization with JWT or HMAC signatures

**API Keys Sent via Email:**
- Keys transmitted in plaintext emails
- **Impact:** Email interception exposes API keys
- **Fix:** Registration links + authenticated portal for key retrieval

**No MongoDB/Redis Authentication:**
- Example configs: `mongodb://mongo1:27017` without credentials
- Redis `auth: ""`
- No TLS/SSL encryption
- **Impact:** Network-level access = full database access
- **Fix:** Enable authentication, TLS, IP whitelisting

**Transaction Support Disabled:**
- `txSupport: false` by default
- **Impact:** Race conditions possible in concurrent writes
- **Fix:** Enable MongoDB transactions in production

### 2.3 Notification/Webhook Issues

**Phantom "Transaction Completed" Notifications:**
- Users receive push notifications with no actual transaction
- Null `dt`/`id` fields cause schema validation failures
- Multi-device token handling issues
- **Fix:** Discard requests with null fields, don't update Redis cache

**Webhook Stuck Job (CRITICAL - PR ready):**
- `getTransaction` job stuck, blocking tipping flow
- **Action:** Merge & deploy to staging/production ASAP

**Schema Validation:**
- No null fields allowed in notifications
- **Action:** Test all swap/transfer events, add CI/CD integration test for tipping flow

### 2.4 RPC Provider Management

**Rate Limiting Issues:**
- Authenticated flow: 3-4 RPC calls, no concerns
- Unauthenticated recovery flow: Single proxy endpoint hits provider limits
- **Mitigations Applied:** Increased proxy rate limits, provider rotation, Alchemy premium
- **Pending:** Run own nodes for full control

**Observability Gaps:**
- Error logs don't include **provider name** when RPC call fails
- No alerting on `RPCError: TIMEOUT_EXCEEDED`
- **Action:** Add provider identifiers to error logs, configure Grafana alerts

### 2.5 Operational UX

**Hyperswarm Secrets Coupling:**
- If `topicConf.capability` or `crypto.key` differ, workers start but cannot communicate (silent failure)
- **Fix:** Config validation script, pre-flight checks

**Proc/API Key Dependency:**
- API workers cannot start without Proc RPC key (manual copying from logs)
- **Fix:** Helper scripts, env-file injection, automated key management

**Manual Deployment:**
- One-by-one deployments across services
- **Impact:** Slow releases, human error, no rollback
- **Fix:** GitHub Actions + K8s, automated health checks, blue/green deployments

---

## 3. KEY SECURITY THREATS

### 3.1 Immediate Threats

1. **Exposed Hyperswarm Secrets** → Unauthorized mesh access
2. **Email-Based API Key Delivery** → Key interception
3. **No Database Authentication** → Direct data access via network
4. **No RPC Authorization** → Internal service abuse (admin methods)
5. **Redis Unauthenticated** → Rate limit bypass

### 3.2 Medium-Term Threats

6. **Manual Wallet Endpoint Abuse** → Suspect RPC call with prod access (security incident?)
7. **No Audit Logging** → No forensic trail for incidents
8. **Address Validation Bypass** → Malformed addresses cause downstream errors
9. **No CAPTCHA on Registration** → Automated abuse, email spam
10. **Reliance on Public RPC Endpoints** → Rate-limit, censorship, inconsistent data

### 3.3 Security Audit

**Status:** Pending
**Scope:** All backend repos + shared libraries (store-facility, net-facility)
**Action:** Collect line counts, update Asana, sync with Gany

---

## 4. KEY TODOs (Active Tickets)

### 4.1 CRITICAL

- [ ] **Webhook stuck job** - `getTransaction` blocking tipping (PR ready, needs deploy)
- [ ] **MongoDB timeout hangs** - Add `maxCommitTimeMS`, wrap abort in try/catch
- [ ] **Indexer-wallet sync lag** - Missing balance updates & notifications
- [ ] **Investigate wallet endpoint incident** - Verify prod access, potential breach

### 4.2 HIGH

- [ ] **Stress test 5k users** - Worker stalls at ~5k wallets, needs tuning before beta launch
- [ ] **Add Sepolia testnet** - USDT0 token indexer (`0xd077A400968890Eacc75cdc901F0356c943e4fDb`), announce under topic `sepolia+usdt0`
- [ ] **Add Plasma indexer** - USDT0 (`0xB8CE59FC3717ada4C02eaDF9682A9e934F625ebb`) + XAUT0 (`0x1B64B9025EEbb9A6239575dF9Ea4b9Ac46D4d193`), topics `plasma+usdt0` and `plasma+xaut0`
- [ ] **Create BTC/TON proxy endpoints** - BTC: Port 50001/50002, TON: `/proxy/tonApiClient`, `/proxy/tonClient` (HTTPS port 443, TLS termination)
- [ ] **Replicate BTC test structure** - Apply to all chain repos (EVM, Solana, TON, Tron), follow EVM PR #14 template
- [ ] **Configure Grafana alerts** - Start with `RPCError: TIMEOUT_EXCEEDED` frequency, add provider name to error logs
- [ ] **Enable GitHub Actions** - Automated tests for WDK rumble budgets (task wdk610-1-2)

### 4.3 MEDIUM

- [ ] **Fee unification** - Single normalized fee at indexer level (vs. separate primary + network fee)
- [ ] **Balance fetch optimization** - Parallel RPC calls with caching (currently serial, causes stale balances)
- [ ] **Onboarding flow atomicity** - Single endpoint for wallet creation + seed storage (currently 3 requests)
- [ ] **Provider error logging** - Add provider name to RPC error logs
- [ ] **Notification schema validation** - Test all swap/transfer events, fix null fields
- [ ] **CI/CD automation** - GitHub Actions for tests, integration test for tipping flow

### 4.4 COMPLETED

- [x] Retry logic for worker stalls (Alex's PR)
- [x] Grafana alerting setup (staging configured, production pending)
- [x] Bitcoin indexer refactor (template for other chains)
- [x] Proxy endpoints for EVM chains (remove API key requirement, expose public rate-limited endpoints)
- [x] Logging transport switch (Hyperswarm → Promtail)
- [x] Token refresh flow fix (access token 1h, refresh token 7d) - v0.10.9
- [x] Paymaster support for Plasma and Sepolia (integration testing pending)

---

## 5. KEY FEATURES OFFERED BY THE INDEXER (WDK)

### 5.1 Core Capabilities

**Multi-Chain Support:**
- EVM: Ethereum, Arbitrum, Polygon, Plasma + ERC-20 tokens (USDT, XAUT)
- Bitcoin (native BTC via UTXO model conversion)
- Solana (native SOL + SPL tokens)
- TON, Tron, Spark
- Testnet: Sepolia (pending)
- ERC-4337: Account abstraction for gasless transactions via paymasters

**API Features:**
- Token balances (single + batch, max 10 addresses)
- Token transfers (single + batch, max 10 addresses)
- Transaction history
- API key management (create, revoke, list, block/unblock users)
- Rate limiting: Per-key, per-route, per-method (Redis-backed, sliding window)
- Email-based API key delivery

**Developer Experience:**
- Swagger UI at `/docs`
- Bruno API client (Postman alternative)
- Configurable sync intervals per chain
- RPC provider rotation with weights

### 5.2 Operational Features

**Observability:**
- Grafana dashboards (staging alerts configured, production pending)
- Pino structured logging
- Sentry error tracking
- Redis cache for performance
- Health endpoints

**Job Scheduling:**
- Transaction sync (configurable per chain: Ethereum 30s, Arbitrum 5s, Polygon 15s)
- Delete old blocks (7-day retention, daily at midnight)
- Clean old blocks (HyperDB cache, weekly on Sundays)
- Revoke inactive API keys (30-day threshold, daily at 2 AM)

**Retry & Resilience:**
- 3-attempt retry on transient MongoDB errors (exponential backoff)
- 3-attempt retry on RPC calls (configurable)
- Write concern majority (30s timeout)
- Provider failover on rate limit

### 5.3 Rumble Extensions

- `rumble-*` repos extend base WDK with notifications, webhooks, gasless transactions
- Notifications: Push notifications for transaction completion, swap events
- Webhooks: MoonPay integration (cache transaction statuses, async sync worker)
- Gasless: Paymaster integration with retry logic (3-5 attempts, chain-aware back-off)

---

## 6. FEATURES NEEDED FOR TOP INDUSTRY STANDARD

### 6.1 Critical Gaps

**1. Webhook System (Enterprise-Grade):**
- HMAC-SHA256 signature verification
- Retry with exponential backoff (3-5 attempts)
- Dead letter queue for failed webhooks
- Per-webhook rate limiting
- Admin dashboard for webhook management

**2. GraphQL API:**
- Flexible queries vs. fixed REST endpoints
- Subscriptions for real-time updates
- Batch queries without artificial limits
- Cursor-based pagination

**3. Historical Data Archive:**
- Current: 7-day retention only
- Needed: Configurable long-term storage (S3/BigQuery)
- Query interface for historical data
- Analytics-ready data lake

**4. Chain-Aware Fee Estimation:**
- Real-time gas price prediction
- Priority fee recommendations
- Fee unification (single normalized fee to UI)
- Paymaster cost detection and labeling

**5. Transaction Status Tracking:**
- Mempool monitoring
- Confirmation depth tracking
- Reorg detection and alerts
- Failed transaction debugging

### 6.2 High-Priority Enhancements

**6. Multi-Shard Support:**
- Current: Single data shard bottleneck
- Needed: Horizontal sharding for 100M+ users
- Consistent hashing for wallet distribution
- Cross-shard query optimization

**7. Advanced Authentication:**
- OAuth 2.0 / OpenID Connect
- JWT with refresh tokens (1h access, 7d refresh - already implemented, monitor for regressions)
- API key scopes (read-only, write, admin)
- IP whitelisting per key

**8. Metrics & Analytics API:**
- On-chain metrics (TVL, volume, unique wallets)
- Chain health indicators
- Provider performance tracking
- User-facing analytics dashboard

**9. Automated Deployment:**
- GitHub Actions for CI/CD
- Kubernetes orchestration (vs. manual EC2)
- Rolling deployments with health checks
- Ansible playbooks for multi-server scripts (in progress)

**10. Resilient Provider Strategy:**
- Smarter load-balancing and failover (health checks, backoff, provider scoring)
- Data validation / cross-checking between providers
- Circuit breaker pattern for failed providers
- API key rotation for external RPC providers

### 6.3 Observability & Security

**11. First-Class Observability:**
- Structured logs with provider IDs, chain, shard, correlation IDs
- Metrics: Latency, error rate, timeout rate per provider/chain
- Dashboards: Grafana with production contact points (PagerDuty)
- Alerting: Job failures, sync lag, Mongo replication issues

**12. Hardened Security & Isolation:**
- Authentication/authorization for internal RPC (mTLS, signed tokens)
- Secret management for `topicConf` values (vault/KMS vs. static config)
- MongoDB auth with role-based access
- Comprehensive audit logging with tamper-proof storage

---

## 7. NICE-TO-HAVE / ADD-ON FEATURES

### 7.1 Developer Experience

**1. TypeScript/OpenAPI Spec Sharing:**
- Shared types between frontend/backend
- Auto-generated client SDKs (JS, Python, Go)
- Contract-first API design

**2. Local Dev Improvements:**
- One-command setup script
- Docker Compose for all services (partially done via `_mongo_db_local/`)
- Mock RPC providers for offline dev
- Synthetic blockchain data generator

**3. SDK/Library Ecosystem:**
- npm: `@wdk/indexer-client`
- Python: `wdk-indexer-python`
- Go: `github.com/wdk/indexer-go`
- Mobile: React Native bindings

### 7.2 Advanced Features

**4. MEV Protection:**
- Private mempool submission
- Flashbots integration
- Transaction bundle support

**5. Multi-Sig Wallet Support:**
- Gnosis Safe indexing
- Multi-sig transaction tracking
- Pending approval notifications

**6. NFT/ERC-721 Indexing:**
- Token metadata caching
- Collection-level queries
- Marketplace integration hooks

**7. DeFi Protocol Integrations:**
- Uniswap/Sushiswap LP tracking
- Lending protocol positions (Aave, Compound)
- Staking/yield farming balances

**8. Historical Reindexing Tools:**
- Backfilling for missing data
- Recovery from corruption
- Chain reorganization handling

---

## 8. OTHER NOTES, CONCERNS, SUGGESTIONS

### 8.1 Technical Debt

**Configuration Management:**
- Problem: Secrets in plaintext config files (e.g., `apiKeySecret: "secret-key"`)
- Impact: Security risk, deployment complexity, config file compromise = full system access
- Fix: Environment variables + Vault, separate configs per environment

**No Shared Type Definitions:**
- Problem: Frontend/backend consistency handled manually, no TypeScript/OpenAPI spec
- Impact: API contract drift, runtime errors
- Fix: OpenAPI spec generation, shared TypeScript types, contract tests, auto-generated client SDKs

**Limited Test Coverage:**
- Problem: BTC tests refactored (done), other chains need same structure, no integration tests for critical flows
- Impact: Regressions slip to production
- Fix: Replicate BTC test template to all chain repos (Plasma, Sepolia, TON, Tron), add tipping flow integration test, GitHub Actions CI

**Monitoring Gaps:**
- Problem: No alerting on job failures, Grafana alerts not fully configured, old log format still showing
- Impact: Issues discovered by users, not monitoring
- Fix: Complete Grafana setup with production contact points (Slack/Telegram), PagerDuty integration, auto-restart strategy, structured audit logs with correlation IDs

### 8.2 Operational Clarity

**Critical for Correctness:**
- System depends on precise config (shared secrets, RPC URLs, Mongo URIs, Proc RPC keys)
- Small misconfigurations produce subtle failures
- **Investment needed:** Config validation scripts, pre-flight checks, automated tooling

**Deployment Checklist:**
1. Update numbered repos (`1_`, `2_`, `3_`, `4_`) to match base repo versions
2. Mirror base repo changes to `rumble-*` child repos
3. Version bumps: Any schema change requires version bump + update all dependents
4. Validate: dev → staging → production
5. Integration tests: Token handling, tipping, notifications
6. Monitor: Sentry for 404s, indexer health during release
7. Freeze: 1-2 days before major releases (5k user rollout)
8. Hot-fix process: Dedicated channel, trigger steps (needs definition)

**Configuration Gotchas:**
- Hyperswarm topics: All services MUST share identical `capability` + `crypto.key`
- RPC keys: API workers cannot start without Proc worker's RPC key
- MongoDB: Replica set required (single-node NOT supported)
- HyperDB: Append-only, cannot insert fields in middle
- Rumble sync: Changes to `wdk-*` must be manually mirrored in `rumble-*`

### 8.3 On-Call Strategy (Needs Definition)

**Not Yet Defined:**
- Who is on-call?
- Escalation path?
- Auto-restart vs. manual intervention?
- Runbooks for common issues (MongoDB timeout, worker stall, RPC provider down)

**Documentation Needed:**
- Deployment flow
- Container setup
- Troubleshooting guide
- Incident response playbook

### 8.4 Meeting Insights (Recent)

**Proxy Layer Setup (17 Nov):**
- Proxy should expose HTTPS on port 443, terminate TLS, forward to internal RPC
- WDK config: `host = proxy domain`, `port = 443` for all chains
- Clarify BTC proxy host/port with Vigan/DevOps (NGINX/Traefik config)

**Gasless Transaction Retry (14 Nov):**
- Stuck on invalid receipt IDs
- Retry strategy: 3-5 attempts, chain-aware back-off
- BTC ≈ 3-4 min, Arbitrum/Polygon ≈ 20-30s
- Separate handling for provider rate-limit errors
- Document and get approval from Jesse/Vegan

**Deployment Automation (14 Nov):**
- Stabilizing workers, planning multi-server scripts
- Issues to be posted in backend channel for peer input

**MoonPay Integration (5 Nov):**
- Cache transaction statuses periodically (vs. real-time queries)
- Async sync via background worker
- Use webhook payload to map transactions before logic

---

## 9. PRODUCT/ENGINEERING RECOMMENDATIONS

### 9.1 Immediate (Pre-Beta Launch - 1-2 Weeks)

1. **Merge webhook fix PR** - Unblock tipping flow (CRITICAL)
2. **Deploy MongoDB timeout fixes** - Prevent job hangs (CRITICAL)
3. **Stress test 5k users** - Validate worker stability before beta
4. **Configure alerts** - Start with `TIMEOUT_EXCEEDED` in Grafana
5. **Security audit prep** - Finalize scope, collect line counts
6. **Investigate wallet endpoint incident** - Verify prod access, potential breach

### 9.2 Short-Term (1-2 Months)

7. **Migrate secrets to Vault** - Remove plaintext from configs
8. **Enable MongoDB/Redis auth** - Production hardening
9. **Implement RPC authorization** - Prevent internal service abuse
10. **Add Sepolia + Plasma indexers** - Testnet support
11. **Fee unification** - Single normalized fee to UI
12. **CI/CD automation** - GitHub Actions, reduce deployment risk
13. **Webhook system v1** - HMAC signatures, retry logic, admin dashboard

### 9.3 Mid-Term (3-6 Months)

14. **Multi-shard architecture** - Prepare for 100M users
15. **GraphQL API** - Flexible queries, real-time subscriptions
16. **Historical data archive** - Configurable retention, analytics
17. **Advanced auth** - OAuth, JWT scopes, IP whitelisting
18. **Metrics API** - On-chain analytics, chain health
19. **Kubernetes migration** - Replace manual EC2 deployments
20. **SDK ecosystem** - JS, Python, Go client libraries

### 9.4 Long-Term (6+ Months)

21. **MEV protection** - Private mempool, Flashbots
22. **Multi-sig support** - Gnosis Safe indexing
23. **NFT/ERC-721 indexing** - Token metadata, collections
24. **DeFi integrations** - Uniswap, Aave, staking protocols
25. **Smart contract event decoding** - ABI registry, human-readable logs

---

## 10. CONCLUSION

**System Maturity:** Early production, stable for current scale (~5k users) but architectural gaps prevent enterprise adoption and 100k+ user scale.

**Key Strengths:**
- Distributed P2P architecture eliminates single points of failure
- Multi-chain support with extensible worker pattern
- Granular rate limiting and API key management
- Strong retry/resilience patterns

**Critical Risks:**
- **Security:** Hardcoded secrets, no RPC auth, plaintext API key delivery
- **Stability:** MongoDB timeout hangs, worker stalls, indexer-wallet sync lag
- **Scalability:** Single data shard bottleneck, no horizontal sharding
- **Operations:** Manual deployments, no CI/CD, limited monitoring

**Path Forward:**
1. **Pre-Beta:** Fix critical bugs (webhooks, timeouts), stress test 5k users
2. **Security Hardening:** Migrate secrets, enable auth, RPC authorization
3. **Scale Prep:** Multi-shard architecture, GraphQL, historical archive
4. **DevOps Maturity:** CI/CD automation, K8s, comprehensive monitoring
5. **Enterprise Features:** Webhooks, metrics API, SDK ecosystem

**Timeline Alignment:**
- **5k beta launch:** Immediate (1-2 weeks)
- **100k wallet launch:** Requires multi-shard + CI/CD (3-6 months)
- **Enterprise adoption:** Requires webhooks + GraphQL + advanced auth (6+ months)

---

---

## 11. REPOSITORY STRUCTURE & KEY FILES

### Repository Organization

**Service Directories (Deployment Order):**
- `wdk-indexer-app-node/` - HTTP REST API server (Fastify, port 3000)
  - Entry: `worker.js`
  - Config: `config/common.json`, `config/facs/`
  - Worker: `workers/base.http.server.wdk.js`
- `wdk-ork-wrk/` - Organization/routing service (API gateway)
- `wdk-data-shard-wrk/` - Business logic, wallet data, encrypted seeds
  - Proc: `workers/proc.shard.data.wrk.js`
  - API: `workers/api.shard.data.wrk.js`
- `wdk-indexer-wrk-evm/` - EVM chain indexers
  - Entry: `worker.js`
  - Proc: `workers/proc.indexer.evm.wrk.js`
  - API: `workers/api.indexer.evm.wrk.js`
  - ERC20: `workers/proc.indexer.erc20.wrk.js`
  - Config: `config/eth.json`, `config/usdt-eth.json`, etc.

**Base Libraries:**
- `wdk-core/` - Core WDK framework
- `wdk-indexer-wrk-base/` - Shared indexer scaffold
  - DB schemas: `workers/lib/db/`
  - RPC manager: `workers/lib/rpc.base.manager.js`
  - Chain client: `workers/lib/chain.base.client.js`
- `tether-wrk-base/` - Base worker class (extends bfx-wrk-base)
- `tether-wrk-ork-base/` - Base organization worker
- `hp-svc-facs-store/` - Holepunch persistent datastores
- `svc-facs-httpd/` - HTTP service facilities
- `svc-facs-logging/` - Logging facilities

**Chain-Specific Workers:**
- `wdk-indexer-wrk-btc/` - Bitcoin indexer
- `wdk-indexer-wrk-solana/` - Solana indexer
- `wdk-indexer-wrk-ton/` - TON indexer
- `wdk-indexer-wrk-tron/` - Tron indexer
- `wdk-indexer-wrk-spark/` - Spark (Lightning Network) indexer

**Rumble Extensions:**
- `rumble-app-node/` - Extends `@tetherto/wdk-app-node` with notifications
- `rumble-ork-wrk/` - Extends `@tetherto/wdk-ork-wrk`
- `rumble-data-shard-wrk/` - Extends `@tetherto/wdk-data-shard-wrk` with Firebase push, webhooks

**Documentation & Infrastructure:**
- `_docs/` - Meeting minutes, architecture docs, tickets
  - `_minutes/` - Meeting recordings and notes
  - `_tickets/` - Feature requests, bug reports
  - `wdk-indexer-local-diagram.mmd` - System diagram
- `_mongo_db_local/` - Local MongoDB replica set setup (Docker Compose)
- `tether-api-client-ruby/` - Ruby API client (alternative to Bruno)

### Key Configuration Patterns

**Common Config** (`config/common.json`):
```json
{
  "debug": 0,
  "dbEngine": "hyperdb",
  "topicConf": {
    "capability": "<handshake-secret>",
    "crypto": { "algo": "hmac-sha384", "key": "my-secret" }
  }
}
```

**Chain Config** (`config/{chain}.json`):
```json
{
  "chain": "ethereum",
  "token": "eth",
  "decimals": 18,
  "mainRpc": { "rpcUrl": "https://..." },
  "secondaryRpcs": [{ "rpcUrl": "...", "weight": 1 }],
  "txBatchSize": 20,
  "syncTx": "*/30 * * * * *"
}
```

**MongoDB Config** (`config/facs/db-mongo.config.json`):
```json
{
  "dbMongo_m0": {
    "name": "db-mongo",
    "opts": {
      "mongoUrl": "mongodb://mongo1:27017,mongo2:27017,mongo3:27017/DB?replicaSet=rs0",
      "dedicatedDb": true,
      "txSupport": false,
      "maxPoolSize": 150,
      "socketTimeoutMS": 30000
    }
  }
}
```

### Recommended Sync Settings

- **Ethereum** (12s blocks): `txBatchSize: 20`, `syncTx: */30 * * * * *` (every 30s)
- **Arbitrum** (0.25-0.3s blocks): `txBatchSize: 40`, `syncTx: */5 * * * * *` (every 5s)
- **Polygon** (2.1s blocks): `txBatchSize: 30`, `syncTx: */15 * * * * *` (every 15s)
- **Bitcoin** (~10min blocks): `txBatchSize: 20`, `syncTx: */60 * * * * *` (every 60s)

---

**Document Versioning:**
- Version: 2.1 (November 18, 2025)
- Previous: 2.0 (November 17, 2025)
- Next Review: December 2025 (post-5K beta launch)
- Contributors: Engineering team, meeting minutes, codebase analysis, security exploration
- Maintainer: Update after major architectural changes or monthly reviews
