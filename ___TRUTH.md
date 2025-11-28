# WDK Indexer - Engineering Truth Document

**Last Updated:** November 28, 2025  
**Previous Version:** November 18, 2025

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

### 1.6 Push-Based Sync Architecture (IN PROGRESS)

**Decision (Nov 25, 2025):** Transitioning from pull-based to push-based transaction sync  
**Rationale:** Current pull-based system causes lag at ~5K users; workers poll all wallets even when no txs arrive  
**Design Debate:**
- **Option 1 - Broadcast:** Indexers push lightweight tx envelopes to all shards; each shard filters locally (O(1) hash lookup)
  - Timeline: 2 weeks POC
  - Pros: Simple, no new service, leverages existing Hyperswarm, zero risk of missed transactions
  - Cons: ~99.9% irrelevant txs sent; ~50 MB/s at 5K tx/s peak
- **Option 2 - Router Service:** Indexers → router → shard (router holds address→wallet→shard lookups)
  - Timeline: 8-12 weeks
  - Pros: Network efficient, targeted delivery 
  - Cons: New service layer, state management complexity, 5+ new failure modes (change-stream lag, cache drift, resume token loss)

**Recommendation:** Broadcast-first approach for immediate deployment, validate with load tests (≤100ms p99, ≤10% CPU, ≤100MB/s network), only consider router if metrics fail

**Event Schema (Proposed):** `{ chainId, txHash, blockNumber, from, to, [token contracts] }` - shards fetch full tx from indexer when needed

---

## 2. KEY CHALLENGES & WEAK POINTS

### 2.1 Production Stability Issues (CRITICAL)

**MongoDB Timeout Hangs (ONGOING):**
- Jobs stop logging after few executions due to hanging transactions
- `isRunning` flag never resets when promises reject/hang
- Missing timeouts: `maxCommitTimeMS`, `maxTimeMS` on queries
- `bulkWrite` doesn't accept `maxTimeMS` (must use driver-level timeout)
- **Impact:** Manual restart + Redis clear required
- **Fix (In Progress):** Add `maxCommitTimeMS` to `session.startTransaction()`, wrap `abortTransaction` in try/catch, use `Promise.allSettled` for batch RPC calls
- **Investigation:** Extensive debugging documented in `_docs/task_mongodb_pool_destroyed_issue/` (53 files)

**Indexer-Wallet Sync Lag:**
- Missing balance updates and transaction notifications at scale
- Data shard worker missing sync jobs
- Root cause: DB lock waits have no timeout  
- **Push-based solution in progress** (see §1.6)

**Worker Stalls at ~5k Wallets:**
- Stress test worker stalled at ~5k wallets, logs enabled, under investigation
- Retry logic added in Alex's PR (pending validation)
- **Blocker:** Indexer sharding bottleneck for ~100k users (wallet launch target)
- **Action:** Stress test before beta launch

**Autobase State Divergence (Nov 25):**
- Alternating "wallet not found" / "user not found" errors from inconsistent reads between replicas
- Suggested root cause: Autobase replication lag or unresolved writer conflicts
- **Action:** Log replication heads across nodes, enable debug-level logging for replication layer, compare Autobase heads for both error states

**getWallets Pre-Check 500 Errors (Nov 26):**
- App using `getWallets` as pre-check before registration triggers 500 when user not provisioned
- **Fix:** Backend should return clean 404 or structured "user not found" response instead

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

**Address Uniqueness Bypass (FIXED Nov 19, 2025):**
- ✅ **Vulnerability:** Attackers could bypass uniqueness checks using different casing (e.g., `0xABC...` vs `0xabc...`)
- ✅ **Fix:** Local address normalization in `wdk-ork-wrk` before validation (fail-closed design, no RPC dependency)
- ✅ **Test Coverage:** 7 test suites, 20 assertions, security bypass test verified
- ✅ **Status:** Ready for staging deployment, awaiting integration testing
- **Migration needed:** Audit existing data for duplicates (see `rumble-data-shard-wrk/migrations/2025-01-27_10-01-00_remove-duplicate-ton-addresses.js`)

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

**SHA1HULUD Supply Chain Attack (Nov 26 Security Audit):**
- ✅ **Audit Complete:** All 21 repositories scanned against 1,100+ malicious packages
- ✅ **Result:** CLEAN - Zero malicious packages detected
- ✅ **Legitimate packages confirmed:** ethers@6.14.4, hardhat@2.25.0
- **Recommendation:** Implement `ignore-scripts=true` in `.npmrc`, use `npm ci` in CI/CD, enable Dependabot

### 2.3 Notification/Webhook Issues

**Phantom "Transaction Completed" Notifications (Nov 26):**
- Users receive push notifications with no actual transaction
- Null `dt`/`id` fields cause schema validation failures
- Multi-device token handling issues
- **Fix (PR ready):** Discard requests with null fields, don't update Redis cache, ready to deploy post-meeting

**Admin Transfer Bug (Nov 26):**
- ✅ **Fixed and deployed:** Missing transfer index in admin-transfer endpoint
- Trace-ID feedback points addressed

**Webhook Duplication (Nov 18):**
- Same transaction sent twice with different hashes
- One payload from notification endpoint, another from indexer
- **Fix:** Add transactionShiftId flag handling

**Schema Validation:**
- No null fields allowed in notifications
- **Action:** Test all swap/transfer events, add CI/CD integration test for tipping flow

### 2.4 RPC Provider Management

**Rate Limiting Issues:**
- Authenticated flow: 3-4 RPC calls, no concerns
- Unauthenticated recovery flow: Single proxy endpoint hits provider limits
- **Mitigations Applied:** Increased proxy rate limits, provider rotation, Alchemy premium
- **Pending:** Run own nodes for full control
- **Nov 26 Note:** Heavy error volume from providers on two blockchains, not blocking Dawn/Prawn release

**Observability Gaps:**
- Error logs don't include **provider name** when RPC call fails
- No alerting on `RPCError: TIMEOUT_EXCEEDED`
- **Action:** Add provider identifiers to error logs, configure Grafana alerts for production and staging

### 2.5 Operational UX

**Hyperswarm Secrets Coupling:**
- If `topicConf.capability` or `crypto.key` differ, workers start but cannot communicate (silent failure)
- **Nov 26:** Hyperswarm integration >99% success per Alex's Slack update
- **Fix:** Config validation script, pre-flight checks

**Proc/API Key Dependency:**
- API workers cannot start without Proc RPC key (manual copying from logs)
- **Fix:** Helper scripts, env-file injection, automated key management

**Manual Deployment:**
- One-by-one deployments across services
- **Impact:** Slow releases, human error, no rollback
- **Nov 19 Progress:** Ansible playbooks for dev/staging in progress; need three test instances and Mongo cluster for rollout/rollback testing
- **Fix:** GitHub Actions + K8s, automated health checks, blue/green deployments

**Cache Layer Inconsistency (Nov 18):**
- Balance flicker and duplicate notifications
- Backend cache-delay logic (30s) misalignment with front-end query-param usage
- **Action:** Align front-end to consistently use or bypass cache, update docs on query-param behavior

**Address Normalization Migration (Nov 26):**
- Migration script being revisited
- **Goal:** Ensure full org-level consistency and idempotent normalization

**5xx Error Investigation (Nov 26):**
- Current example: 404 "data shard not found" error
- **Goal:** Keep dashboard clean, eliminate false-positive alerts

---

## 3. KEY SECURITY THREATS

### 3.1 Immediate Threats

1. **Exposed Hyperswarm Secrets** → Unauthorized mesh access
2. ~~**Address Uniqueness Bypass**~~ → ✅ FIXED Nov 19, 2025
3. **No Database Authentication** → Direct data access via network
4. **No RPC Authorization** → Internal service abuse (admin methods)
5. **Redis Unauthenticated** → Rate limit bypass

### 3.2 Medium-Term Threats

6. **Manual Wallet Endpoint Abuse** → Suspect RPC call with prod access (security incident?)
7. **No Audit Logging** → No forensic trail for incidents
8. **Malformed Address Validation** → Downstream errors (improved by normalization fix)
9. **No CAPTCHA on Registration** → Automated abuse, email spam
10. **Reliance on Public RPC Endpoints** → Rate-limit, censorship, inconsistent data

### 3.3 Supply Chain Security

11. ✅ **SHA1HULUD Attack (Nov 26):** All repositories verified clean
12. **Best Practices Implemented:**
    - Package lock files committed
    - Exact version pinning in most repos
13. **Recommended Additions:**
    - `.npmrc` with `ignore-scripts=true`
    - GitHub Dependabot for automated security updates
    - Weekly `npm audit` in CI/CD

---

## 4. KEY TODOs (Active Tickets)

### 4.1 CRITICAL

- [ ] **Push notification fix** - Null field handling (PR ready Nov 26, deploy immediately)
- [ ] **MongoDB timeout hangs** - Add `maxCommitTimeMS`, wrap abort in try/catch
- [ ] **Push-based sync POC** - Broadcast approach, 2-week timeline, load test at 5K tx/s
- [ ] **Address normalization migration** - Ensure org-level consistency, idempotent
- [ ] **Investigate wallet endpoint incident** - Verify prod access, potential breach

### 4.2 HIGH

- [ ] **Stress test 5k users** - Worker stalls at ~5k wallets, needs tuning before beta launch
- [ ] **Add Sepolia testnet** - USDT0 token indexer (`0xd077A400968890Eacc75cdc901F0356c943e4fDb`), announce under topic `sepolia+usdt0`
- [ ] **Add Plasma indexer** - USDT0 (`0xB8CE59FC3717ada4C02eaDF9682A9e934F625ebb`) + XAUT0 (`0x1B64B9025EEbb9A6239575dF9Ea4b9Ac46D4d193`), topics `plasma+usdt0` and `plasma+xaut0`
- [ ] **Create BTC/TON proxy endpoints** - BTC: Port 50001/50002, TON: `/proxy/tonApiClient`, `/proxy/tonClient` (HTTPS port 443, TLS termination)
- [ ] **Configure Grafana alerts** - Production and staging, start with `RPCError: TIMEOUT_EXCEEDED` frequency
- [ ] **Analytics webhook PR** - Pending Jesse's review before staging deployment
- [ ] **ORC worker benchmarking** - Performance tuning based on results
- [ ] **Autobase state divergence debug** - Log replication heads, compare between nodes
- [ ] **getWallets 404 response** - Return structured error instead of 500 for unprovisioned users

### 4.3 MEDIUM

- [ ] **Ansible playbook completion** - Rollout/rollback testing on three test instances
- [ ] **Fee unification** - Single normalized fee at indexer level
- [ ] **Provider error logging** - Add provider name to RPC error logs
- [ ] **Notification schema validation** - Test all swap/transfer events
- [ ] **CI/CD automation** - GitHub Actions for tests, integration test for tipping flow
- [ ] **Cache layer alignment** - Front-end query-param consistency
- [ ] **Webhook duplication** - transactionShiftId flag handling

### 4.4 COMPLETED (since Nov 18)

- [x] Admin-transfer bug - Fixed and deployed Nov 26
- [x] Trace-ID feedback - Addressed Nov 26
- [x] Address uniqueness security fix - Implemented Nov 19
- [x] SHA1HULUD security audit - Completed Nov 26, all clean
- [x] Retry logic for worker stalls
- [x] Grafana alerting setup (staging)
- [x] Bitcoin indexer refactor
- [x] Proxy endpoints for EVM chains
- [x] Token refresh flow fix - v0.10.9
- [x] Paymaster support for Plasma and Sepolia

---

## 5. KEY FEATURES OFFERED BY THE INDEXER (WDK)

### 5.1 Core Capabilities

**Multi-Chain Support:**
- EVM: Ethereum, Arbitrum, Polygon, Plasma (Chain ID 9745), Sepolia + ERC-20 tokens (USDT, XAUT)
- Bitcoin (native BTC via UTXO model conversion)
- Solana (native SOL + SPL tokens)
- TON, Tron, Spark
- ERC-4337: Account abstraction for gasless transactions via paymasters (Plasma and Sepolia)

**Chain-Specific Sync Settings:**
- Ethereum (12s blocks): `txBatchSize: 20`, sync: 30s
- Arbitrum (0.25-0.3s blocks): `txBatchSize: 40`, sync: 5s
- Polygon (2.1s blocks): `txBatchSize: 30`, sync: 15s
- Plasma (12s blocks): `txBatchSize: 20`, sync: 30s
- Bitcoin (~10min blocks): `txBatchSize: 20`, sync: 60s

**API Features:**
- Token balances (single + batch, max 10 addresses)
- Token transfers (single + batch, max 10 addresses)
- Transaction history
- API key management (create, revoke, list, block/unblock users)
- Rate limiting: Per-key, per-route, per-method (Redis-backed)

**Developer Experience:**
- Swagger UI at `/docs`
- Bruno API client
- Configurable sync intervals per chain
- RPC provider rotation with weights

### 5.2 Operational Features

**Observability:**
- Grafana dashboards (staging configured)
- Pino structured logging
- Sentry error tracking
- Health endpoints

**Job Scheduling:**
- Transaction sync (configurable per chain)
- Delete old blocks (7-day retention, daily at midnight)
- Clean old blocks (HyperDB cache, weekly Sundays)
- Revoke inactive API keys (30-day threshold, daily 2 AM)

**Retry & Resilience:**
- 3-attempt retry on MongoDB errors (exponential backoff)
- 3-attempt retry on RPC calls
- Write concern majority (30s timeout)
- Provider failover on rate limit

### 5.3 Rumble Extensions

- Notifications: Push notifications for transactions
- Webhooks: MoonPay integration
- Gasless: Paymaster integration (3-5 attempts, chain-aware)

---

## 6. FEATURES NEEDED FOR TOP INDUSTRY STANDARD

### 6.1 Critical Gaps

1. **Webhook System (Enterprise-Grade):** HMAC signatures, retry logic, dead letter queue
2. **GraphQL API:** Flexible queries, real-time subscriptions
3. **Historical Data Archive:** 7-day retention → configurable long-term storage
4. **Chain-Aware Fee Estimation:** Real-time gas price prediction, fee unification
5. **Transaction Status Tracking:** Mempool monitoring, confirmation depth, reorg detection
6. **Push-Based Sync System (IN PROGRESS):** Event-driven architecture, 2-week POC timeline

### 6.2 High-Priority Enhancements

7. **Multi-Shard Support:** Horizontal sharding for 100M+ users
8. **Advanced Authentication:** OAuth 2.0, JWT scopes, IP whitelisting
9. **Metrics & Analytics API:** On-chain metrics, chain health
10. **Automated Deployment:** GitHub Actions, K8s, Ansible (in progress)
11. **Resilient Provider Strategy:** Health checks, circuit breaker, API key rotation

### 6.3 Observability & Security

12. **First-Class Observability:** Provider IDs in logs, correlation IDs, PagerDuty
13. **Hardened Security:** mTLS for internal RPC, secrets vault, MongoDB auth, audit logging

---

## 7. NICE-TO-HAVE / ADD-ON FEATURES

1. **TypeScript/OpenAPI Spec Sharing:** Auto-generated client SDKs
2. **Local Dev Improvements:** One-command setup, mock RPC providers
3. **SDK/Library Ecosystem:** npm, Python, Go, React Native
4. **MEV Protection:** Private mempool, Flashbots
5. **Multi-Sig Wallet Support:** Gnosis Safe indexing
6. **NFT/ERC-721 Indexing:** Token metadata, collections
7. **DeFi Protocol Integrations:** Uniswap, Aave, staking
8. **Historical Reindexing Tools:** Backfilling, corruption recovery

---

## 8. OTHER NOTES, CONCERNS, SUGGESTIONS

### 8.1 Technical Debt

- **Configuration Management:** Secrets in plaintext → Vault/KMS
- **No Shared Type Definitions:** Manual consistency → OpenAPI spec, TypeScript
- **Limited Test Coverage:** BTC done, replicate to other chains, GitHub Actions CI
- **Monitoring Gaps:** Grafana alerts incomplete for production → PagerDuty integration

### 8.2 Operational Clarity

**Critical for Correctness:**
- System depends on precise config (shared secrets, RPC URLs, Mongo URIs, Proc RPC keys)
- Small misconfigurations produce subtle failures
- **Investment needed:** Config validation scripts, pre-flight checks

**Deployment Checklist:**
1. Update numbered repos to match base
2. Mirror changes to `rumble-*` repos
3. Version bumps for schema changes
4. Validate: dev → staging → production
5. Integration tests
6. Monitor: Sentry, indexer health
7. Freeze 1-2 days before major releases
8. Hot-fix process (needs definition)

**Configuration Gotchas:**
- Hyperswarm: Identical `capability` + `crypto.key` required
- RPC keys: API workers need Proc worker's key
- MongoDB: Replica set required
- HyperDB: Append-only, no field insertion
- Rumble sync: Manual mirroring required

### 8.3 Meeting Insights (Nov 25-26, 2025)

**Push-Based Sync:**
- Pull-based causes lag at 5K users
- Broadcast: 2 weeks, simple, 50 MB/s at peak
- Router: 8-12 weeks, complex, saves bandwidth but 5+ failure modes
- Recommendation: Broadcast-first with feature flag

**Address Normalization:**
- Alex finalizing, no client changes needed
- Push notification fix PR ready (deploy immediately)
- Migration script for org-level consistency

**Production Status:**
- Hyperswarm >99% success
- Heavy provider errors on two chains (not blocking)
- Analytics webhook pending Jesse's review

---

## 9. PRODUCT/ENGINEERING RECOMMENDATIONS

### 9.1 Immediate (1-2 Weeks)

1. Deploy push notification fix (CRITICAL)
2. Deploy MongoDB timeout fixes
3. Launch push-based sync POC (broadcast)
4. Stress test 5K users
5. Configure Grafana alerts (production + staging)
6. Deploy address normalization migration
7. Investigate wallet endpoint incident

### 9.2 Short-Term (1-2 Months)

8. Migrate secrets to Vault
9. Enable MongoDB/Redis auth
10. Implement RPC authorization
11. Complete Ansible playbooks
12. Fee unification
13. CI/CD automation
14. Webhook system v1

### 9.3 Mid-Term (3-6 Months)

15. Multi-shard architecture
16. GraphQL API
17. Historical data archive
18. Advanced auth (OAuth, JWT scopes)
19. Metrics API
20. Kubernetes migration
21. SDK ecosystem

### 9.4 Long-Term (6+ Months)

22. MEV protection
23. Multi-sig support
24. NFT indexing
25. DeFi integrations

---

## 10. CONCLUSION

**System Maturity:** Early production, stable at 5K users, transitioning to push-based sync for 100K+ scale.

**Key Strengths:**
- Distributed P2P architecture
- Multi-chain support
- >99% Hyperswarm stability
- Granular rate limiting

**Critical Risks:**
- Stability: MongoDB timeouts, Autobase divergence
- Security: Hardcoded secrets, no RPC auth
- Scalability: Single shard, pull-based sync lag
- Operations: Manual deployments, incomplete monitoring

**Path Forward:**
1. **Pre-Beta (1-2 weeks):** Push notification fix, MongoDB timeouts, push-sync POC
2. **Security (1-2 months):** Secrets vault, enable auth, RPC authorization
3. **Scale (3-6 months):** Multi-shard, GraphQL, CI/CD
4. **Enterprise (6+ months):** Webhooks, metrics API, SDKs

**Timeline:**
- **5K beta:** 1-2 weeks (push notification + MongoDB fixes CRITICAL)
- **100K launch:** 3-6 months (push-sync + multi-shard + CI/CD)
- **Enterprise:** 6+ months (webhooks + GraphQL + advanced auth)

---

**Document Versioning:**
- Version: 3.0 (November 28, 2025)
- Previous: 2.1 (November 18, 2025)
- Next Review: December 15, 2025 (post-push-sync POC validation)
- Contributors: Engineering team, meeting minutes, codebase analysis, security audits (SHA1HULUD Nov 26)
- Maintainer: Update after major architectural changes or monthly reviews
