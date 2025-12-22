# Final Report: Intermittent Wallet Balance Oscillation

**Date:** 2025-12-19  
**Status:** Root cause strongly supported by code and reports; fix plan ready (not yet implemented)  
**Priority:** High (user trust issue)

---

## Executive Summary

The `/api/v1/wallets/balances` endpoint can oscillate between pre-transaction and post-transaction values because balance reads are served by **non-deterministic upstream selection** at two layers: (1) random indexer peer selection via HyperDHT, and (2) round-robin RPC provider selection inside each indexer worker. When providers are at different block heights, repeated requests can return alternating balances.

In the current codebase, `cache=false` **does not read or write** Redis, so cache poisoning is not present in this version. However, mixing `cache=true` (cached) and `cache=false` (live) still exposes upstream variation, causing oscillation. The short cache TTL (30s) makes this more visible.

This report corrects prior inaccuracies and provides an implementation-ready plan with accurate file paths.

---

## 1. Root Cause Analysis

### 1.1 Architecture Overview

```
Client Request
      │
      ▼
┌─────────────────────────────────────────────────────────────────┐
│  wdk-app-node / rumble-app-node (HTTP Gateway)                  │
│  └─ cached.route.js: Redis cache (30s TTL)                      │
│     └─ cache=true: read/write cache                             │
│     └─ cache=false: bypass cache (no read, no write)            │
└─────────────────────────────────────────────────────────────────┘
      │
      ▼
┌─────────────────────────────────────────────────────────────────┐
│  wdk-ork-wrk (Orchestrator)                                     │
│  └─ Routes request to data-shard                                │
└─────────────────────────────────────────────────────────────────┘
      │
      ▼
┌─────────────────────────────────────────────────────────────────┐
│  wdk-data-shard-wrk                                             │
│  └─ blockchain.svc.js:_rpcCall() → ctx.net_r0.jTopicRequest()   │
│                            │                                    │
│                            ▼                                    │
│              ┌─────────────────────────────┐                    │
│              │  LAYER 1: RANDOM PEER       │                    │
│              │  hp-svc-facs-net:209-212    │                    │
│              │  Math.random() * keys.length│                    │
│              └─────────────────────────────┘                    │
└─────────────────────────────────────────────────────────────────┘
      │
      ▼ (randomly selected indexer peer)
┌─────────────────────────────────────────────────────────────────┐
│  wdk-indexer-wrk-{chain}                                        │
│  └─ rpc.base.manager.js:186-211                                 │
│              ┌─────────────────────────────┐                    │
│              │  LAYER 2: ROUND-ROBIN       │                    │
│              │  this.index++ % length      │                    │
│              └─────────────────────────────┘                    │
└─────────────────────────────────────────────────────────────────┘
      │
      ▼ (selected RPC provider)
┌─────────────────────────────────────────────────────────────────┐
│  External RPC Providers (Infura, Alchemy, etc.)                 │
│  └─ May be at different block heights                           │
└─────────────────────────────────────────────────────────────────┘
```

### 1.2 The Two Layers of Non-Determinism

#### Layer 1: Random Indexer Peer Selection (HyperDHT)

**File:** `tether-wrk-base/node_modules/hp-svc-facs-net/index.js:209-212`

```javascript
async lookupTopicKey (topic, cached = true) {
  const keys = await this.lookupTopicKeyAll(topic, cached)
  const index = Math.floor(Math.random() * keys.length)  // random
  return keys[index]
}
```

If multiple indexer peers serve the same topic, each balance request may land on a different peer.

#### Layer 2: Round-Robin RPC Provider Selection (Indexer)

**File:** `wdk-indexer-wrk-base/workers/lib/rpc.base.manager.js:186-211`

```javascript
get secondary () {
  // ...
  const provider = this.secondaries[this.index]
  this.index = (this.index + 1) % this.secondaries.length
  // ...
  return provider
}
```

Within each indexer worker, the balance call cycles across multiple RPC providers.

### 1.3 Why Oscillation Occurs

When providers and peers are at different block heights:

| Request | Cache | Peer Selected | Provider Selected | Block Height | Balance |
|---------|-------|---------------|-------------------|--------------|---------|
| 1 | `true` | Peer A | Provider 1 | 1000 | 0.341362 (cached) |
| 2 | `false` | Peer B | Provider 2 | 999 | 0.107729 |
| 3 | `true` | (cached) | - | - | 0.341362 |
| 4 | `false` | Peer A | Provider 3 | 1001 | 0.341362 |
| 5 | `false` | Peer B | Provider 2 | 999 | 0.107729 |

User sees: `0.341362 → 0.107729 → 0.341362 → 0.341362 → 0.107729`

### 1.4 Additional Contributors

- **Cache bypass still exposes upstream variation:** `cache=false` bypasses Redis entirely (no read/write), so live responses can still differ between requests.
- **Caching suppression on nulls:** `allPropsNonNullDeep` only caches if all values are non-null. Any null result forces live reads, increasing exposure to upstream variation.
- **Shared Redis requirement:** Code assumes a single shared Redis instance (`wdk-app-node/README.md:29`). If production uses per-instance Redis, oscillation can occur even without provider variation.
- **Peer multiplicity:** If more than one indexer peer serves a topic, peer randomness remains a source of variation even after provider selection is stabilized.

### 1.5 Prior “Cache Poisoning” Hypothesis

In the current code, `cache=false` skips both Redis reads and writes (`wdk-app-node/workers/lib/utils/cached.route.js:21-28`). That means cache poisoning is **not** present in this version. If a deployed version differs from this code, validate production behavior before concluding.

---

## 2. Evidence

### 2.1 Screenshots (Dec 10, 2025)

- **19:33:36** - Wallet `982923c1-f27e-...` polygon balance: `"0.107729"`
- **19:34:23** - Same wallet polygon balance: `"0.341362"`
- Transaction timestamp: **19:13:38** (20+ minutes before screenshots)

### 2.2 Code References

| Component | File | Purpose |
|-----------|------|---------|
| Endpoint | `wdk-app-node/workers/lib/server.js:569` | `/api/v1/wallets/balances` route |
| Cache middleware | `wdk-app-node/workers/lib/utils/cached.route.js:3` | Redis cache, TTL 30s |
| Cache validation | `wdk-app-node/workers/lib/utils/helpers.js:3` | `allPropsNonNullDeep` |
| Balance aggregation | `wdk-data-shard-wrk/workers/lib/blockchain.svc.js:591` | `getMultiWalletsBalances` |
| RPC call to indexer | `wdk-data-shard-wrk/workers/lib/blockchain.svc.js:79` | `_rpcCall` → `jTopicRequest` |
| Peer selection | `tether-wrk-base/node_modules/hp-svc-facs-net/index.js:209` | Random peer via `Math.random()` |
| Provider selection | `wdk-indexer-wrk-base/workers/lib/rpc.base.manager.js:186` | Round-robin provider |

### 2.3 Team Discussion (Historical Context)

Slack notes mention per-worker LRU caching. That was accurate historically, but current code uses Redis for cached routes. Validate production Redis configuration (shared vs per-instance) before assuming LRU is still relevant.

---

## 3. Solution (Implementation-Ready)

### 3.1 Primary Fix: Deterministic Provider Selection for Balance Reads

**Goal:** For the same address, always choose the same provider (unless it fails), so balances don’t oscillate due to provider rotation.

#### Step 1: Add deterministic selection methods

**File:** `wdk-indexer-wrk-base/workers/lib/rpc.base.manager.js`

Add two methods:

```javascript
getProviderBySeed (seed) {
  if (this.secondaries.length === 1) {
    return this.secondaries[0]
  }

  let hash = 0
  for (let i = 0; i < seed.length; i++) {
    hash = ((hash << 5) - hash) + seed.charCodeAt(i)
    hash |= 0
  }
  const index = Math.abs(hash) % this.secondaries.length
  const provider = this.secondaries[index]
  const state = this._updateProviderState(provider)

  // If selected provider is OPEN, fall back to round-robin
  if (state === CIRCUIT_STATES.OPEN) {
    return this.secondary
  }

  return provider
}

async callWithSeed (fn, seed, opts = { maxRetries: 3 }) {
  const maxRetries = opts.maxRetries ?? 3
  let lastError = null

  for (let attempt = 0; attempt < maxRetries; attempt++) {
    const provider = attempt === 0
      ? this.getProviderBySeed(seed)
      : this.secondary

    try {
      const result = await fn(provider)
      this._recordSuccess(provider)
      return result
    } catch (err) {
      this._recordFailure(provider)
      lastError = err
    }
  }

  throw lastError || new Error('ERR_ALL_PROVIDERS_FAILED')
}
```

#### Step 2: Use deterministic selection in balance calls

Update `getBalance` methods in chain clients to call `callWithSeed` using the **address** as the seed. This keeps provider choice stable regardless of address ordering in `getBalanceMulti`.

**Actual files to change:**

- `wdk-indexer-wrk-evm/workers/lib/chain.evm.client.js`
- `wdk-indexer-wrk-evm/workers/lib/chain.erc20.client.js`
- `wdk-indexer-wrk-btc/workers/lib/chain.btc.client.js`
- `wdk-indexer-wrk-solana/workers/lib/chain.solana.client.js`
- `wdk-indexer-wrk-solana/workers/lib/chain.spl.client.js`
- `wdk-indexer-wrk-ton/workers/lib/chain.ton.client.js`
- `wdk-indexer-wrk-ton/workers/lib/chain.jetton.client.js`
- `wdk-indexer-wrk-tron/workers/lib/chain.tron.client.js`
- `wdk-indexer-wrk-tron/workers/lib/chain.trc20.client.js`

**Example (EVM):**

```javascript
async getBalance (address) {
  const balUnit = await this.rpcManager.callWithSeed(
    (p) => p.getBalance(address.toLowerCase()),
    address.toLowerCase()
  )
  return ethers.formatEther(balUnit)
}
```

**Example (SPL, multi-call):**

```javascript
const seed = address
const tokenAccounts = await this.rpcManager.callWithSeed(
  (p) => p.getTokenAccountsByOwner(userAddress, { mint: this.tokenMint }),
  seed
)
const balance = await this.rpcManager.callWithSeed(
  (p) => p.getTokenAccountBalance(tokenAccounts.value[0].pubkey),
  seed
)
```

This keeps all balance reads for a given address pinned to the same provider unless that provider is failing.

### 3.2 Optional Fix: Deterministic Indexer Peer Selection (only if multiple peers exist)

If more than one indexer peer serves the same topic, random peer selection can still cause oscillation. You can remove that randomness without modifying `node_modules` by selecting a peer deterministically in data-shard.

**File:** `wdk-data-shard-wrk/workers/lib/blockchain.svc.js`

Add a deterministic key selection path in `_rpcCall`:

```javascript
async _rpcCall (blockchain, ccy, method, payload, opts = { timeout: this.rpcTimeout }, cached = true, seed = null) {
  const ctx = this.ctx
  const topic = `${blockchain}:${ccy}`
  const payloadWithTraceId = { traceId: getTraceId(), ...payload }

  if (!seed) {
    return ctx.net_r0.jTopicRequest(topic, method, payloadWithTraceId, opts, cached)
  }

  const keys = await ctx.net_r0.lookupTopicKeyAll(topic, cached)
  const key = pickDeterministically(keys, seed) // stable hash
  return ctx.net_r0.jRequest(key, method, payloadWithTraceId, { ...ctx.net_r0.lookup.reqOpts(), ...opts })
}
```

Then call `_rpcCall` with a stable seed in `fetchBalancesByChain` (e.g., `chain + token + address` or a hash of the sorted address list).

**Note:** If production runs a single indexer peer per topic, this step is optional.

---

## 4. Testing Plan

### 4.1 Unit Tests (brittle)

File: `wdk-indexer-wrk-base/tests/rpc.base.manager.unit.test.js`

- Add tests for `getProviderBySeed` and `callWithSeed`.
- Ensure same seed returns same provider.
- Ensure different seeds distribute across providers.
- Ensure fallback works when provider is OPEN.

### 4.2 Integration Test

- Repeatedly call `/api/v1/wallets/balances?cache=false` and confirm values are stable **when using a single indexer peer or after peer selection fix**.
- If multiple peers are active and peer selection is still random, stability may not hold; that is expected until optional fix is applied.

### 4.3 Local Reproduction (pre-fix)

- Configure multiple RPC providers with different block heights.
- Call `/api/v1/wallets/balances` repeatedly with `cache=false`.
- Observe oscillation.

After the fix, repeated calls for the same address should be stable (though they can still update once the provider itself catches up).

---

## 5. Rollout Plan

### Phase 1: Deterministic Provider Selection (Primary Fix)
1. Add `getProviderBySeed` and `callWithSeed` in `wdk-indexer-wrk-base/workers/lib/rpc.base.manager.js`.
2. Update `getBalance` in the chain client files listed above to use `callWithSeed`.
3. Deploy to staging and run the integration test.
4. If stable, deploy to production.

### Phase 2: Deterministic Peer Selection (If Needed)
1. Only if multiple indexer peers per topic are confirmed in production.
2. Add deterministic peer selection in `wdk-data-shard-wrk/workers/lib/blockchain.svc.js`.
3. Deploy and re-test.

---

## 6. Monitoring & Validation

Because `RpcBaseManager` does not currently have a logger, logging should be added in chain clients or by adding an optional `logger` to the `RpcBaseManager` constructor.

Recommended log fields per balance call:
- seed (address hash or address)
- provider index
- provider type/url (if available)
- success/failure

Add alerts for:
- oscillation detection (if possible in UI/API layer)
- provider error rate spikes

---

## 7. Documentation Updates

### 7.1 Update `_docs/___TRUTH.md`

Revise lines about cache behavior to match current code:
- `cache=false` skips both read and write in `cached.route.js`.
- Redis is required and should be shared across app-node instances; verify production config.
- Balance oscillation is primarily due to upstream non-determinism, not cache poisoning.

### 7.2 Document `cache` Parameter

**File:** `rumble-docs/api/Wallets and balance/GET -api-v1-wallets--balances.bru`

Add:
- `cache` (boolean, default: true): when true, returns cached balance up to 30s old; when false, bypasses cache and hits the chain.

---

## 8. Summary

| Issue | Root Cause | Fix | Status |
|-------|------------|-----|--------|
| Balance oscillation | RPC provider rotation per request | Deterministic provider selection (`callWithSeed`) | Ready to implement |
| Balance oscillation | Random indexer peer selection | Deterministic peer selection (optional) | Optional if multi-peer |
| Cache poisoning | `cache=false` writes to cache | Not present in current code | Verify deployed version |
| Cache divergence | Non-shared Redis | Shared Redis required by code | Verify production config |

**Minimum change set:**  
- `wdk-indexer-wrk-base/workers/lib/rpc.base.manager.js`  
- Chain client balance methods (9 files listed in Section 3.1)

---

## 9. Appendix: Quick Reference

**Core change location**

```
wdk-indexer-wrk-base/workers/lib/rpc.base.manager.js
└── Add getProviderBySeed() and callWithSeed()
```

**Usage change locations**

```
wdk-indexer-wrk-evm/workers/lib/chain.evm.client.js
wdk-indexer-wrk-evm/workers/lib/chain.erc20.client.js
wdk-indexer-wrk-btc/workers/lib/chain.btc.client.js
wdk-indexer-wrk-solana/workers/lib/chain.solana.client.js
wdk-indexer-wrk-solana/workers/lib/chain.spl.client.js
wdk-indexer-wrk-ton/workers/lib/chain.ton.client.js
wdk-indexer-wrk-ton/workers/lib/chain.jetton.client.js
wdk-indexer-wrk-tron/workers/lib/chain.tron.client.js
wdk-indexer-wrk-tron/workers/lib/chain.trc20.client.js
```
