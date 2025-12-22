# Investigation: Intermittent Wallet Balance Oscillation After Transactions

## Summary

The `/api/v1/wallets/balances` endpoint returns oscillating balance values (e.g., `0.107729` → `0.341362` → `0.107729`) for approximately 30 minutes after transactions. This investigation confirms the root cause and explains why the previous fix did not fully resolve the issue.

---

## Root Cause Analysis

The oscillation is caused by a **confluence of three factors**:

### 1. Round-Robin RPC Provider Selection

**File:** `wdk-indexer-wrk-base/workers/lib/rpc.base.manager.js` (lines 186-211)

```javascript
get secondary () {
  if (this.secondaries.length === 1) {
    return this.secondaries[0]
  }
  // ... circuit breaker logic ...
  const provider = this.secondaries[this.index]
  this.index = (this.index + 1) % this.secondaries.length  // Round-robin
  // ...
}
```

Each balance request cycles through multiple RPC providers in round-robin fashion. Different providers can be at **different blockchain heights**, returning different balance values for the same wallet.

### 2. Mixed Cache Usage Pattern

**File:** `wdk-app-node/workers/lib/server.js` (lines 569-591)

```javascript
{
  method: 'GET',
  url: '/api/v1/wallets/balances',
  schema: {
    querystring: {
      properties: {
        cache: { type: 'boolean', default: true }  // Default: use cache
      }
    }
  },
  handler: async (req, rep) => {
    return send200(
      rep,
      await cachedRoute(ctx, ckeyParts, '/api/v1/wallets/balances',
        () => service.ork.getUserWalletsBalances(ctx, req),
        !req.query.cache,  // overwriteCache = true when cache=false
        allPropsNonNullDeep)
    )
  }
}
```

The endpoint accepts a `cache` query parameter:
- `cache=true` (default): Uses Redis cache (30s TTL)
- `cache=false`: Bypasses cache, fetches fresh from RPC

### 3. Cache Behavior on `cache=false`

**File:** `wdk-app-node/workers/lib/utils/cached.route.js`

```javascript
const CACHE_TTL_MS = 30000  // 30 seconds

async function cachedRoute (ctx, ckeyParts, apiPath, func, overwriteCache = false, shouldCache = () => true) {
  // ...
  if (!overwriteCache) {
    const cached = await redis.get(ckey)
    if (cached) {
      cval = JSON.parse(cached)
    }
  }

  if (cval === undefined) {
    cval = await func()
    // Previous fix: only write to cache when NOT in overwrite mode
    if (shouldCache(cval) && !overwriteCache) {
      await redis.set(ckey, JSON.stringify(cval), 'PX', CACHE_TTL_MS)
    }
  }

  return cval
}
```

**Previous Fix Applied:** When `cache=false`, the code now skips both reading AND writing to the cache. This was intended to prevent "cache poisoning" where a stale RPC response could overwrite a more recent cached value.

---

## Why The Previous Fix Failed

The previous fix only addressed cache poisoning but did NOT address the fundamental oscillation problem:

### Oscillation Scenario

| Request | Cache Param | Action | Provider Hit | Block Height | Balance Returned |
|---------|-------------|--------|--------------|--------------|------------------|
| 1 | `cache=true` | Read miss, fetch, write cache | Provider A | 1000 | **0.341362** |
| 2 | `cache=false` | Skip cache, fetch fresh | Provider B | 999 | **0.107729** |
| 3 | `cache=true` | Read from cache | (cached) | (1000) | **0.341362** |
| 4 | `cache=false` | Skip cache, fetch fresh | Provider C | 1001 | **0.341362** |
| 5 | `cache=true` | Read from cache | (cached) | (1000) | **0.341362** |
| 6 | `cache=false` | Skip cache, fetch fresh | Provider B | 999 | **0.107729** |

**Result:** User sees: `0.341362` → `0.107729` → `0.341362` → `0.341362` → `0.341362` → `0.107729`

The oscillation occurs because:
1. **Cached responses** come from a specific provider snapshot (Provider A at height 1000)
2. **Fresh responses** can come from ANY provider (including stale ones like Provider B at height 999)
3. Alternating between cached and fresh requests produces visible flickering

---

## Evidence From Screenshots

**Screenshot 1 (19:33:36):** Wallet `982923c1-f27e-4693-859c-...` shows polygon balance: `"0.107729"`
**Screenshot 3 (19:34:23):** Same wallet shows polygon balance: `"0.341362"`

The timestamps are ~1 minute apart, but the transaction occurred at 19:13:38 (20+ minutes before). This confirms the oscillation persists well beyond the 30-second cache TTL.

---

## Evidence From Team Discussion

From `_docs/_slack/fluctating_balanc.md`:

**Alex's analysis:**
> "The param cache=false only skips the 30s HTTP cache read but still writes its result back, and each fetch round-robins across RPC providers at different block heights. Therefore a 'refresh' can poison the cache with a stale provider response."

**Usman's insight (revealing per-worker caching):**
> "The lru cache library we use is specific for each worker. So, it's possible that first request goes to app-node worker A and we cache this value. 2nd request goes to server B and by this time balance is updated, we cache this value as well. 3rd request goes again to app-node worker A and it returns the stale cached value."

---

## How to Reproduce Locally

### Prerequisites
- Multiple RPC providers configured (or simulate with different responses)
- Multiple app-node instances (if testing per-worker caching theory)

### Reproduction Script

```bash
#!/bin/bash

USER_TOKEN="<your-auth-token>"
BASE_URL="http://localhost:3000"

echo "Starting oscillation test..."

for i in {1..20}; do
  # Request with cache=true
  CACHED=$(curl -s -H "Authorization: Bearer $USER_TOKEN" \
    "$BASE_URL/api/v1/wallets/balances?cache=true" | jq '.["982923c1-..."].usdt.polygon')

  sleep 0.1

  # Request with cache=false
  FRESH=$(curl -s -H "Authorization: Bearer $USER_TOKEN" \
    "$BASE_URL/api/v1/wallets/balances?cache=false" | jq '.["982923c1-..."].usdt.polygon')

  echo "Request $i: cached=$CACHED, fresh=$FRESH"

  if [ "$CACHED" != "$FRESH" ]; then
    echo "  ^^^ OSCILLATION DETECTED ^^^"
  fi

  sleep 0.5
done
```

### Simulating Provider Lag

To simulate different provider heights locally:

1. **Modify `rpc.base.manager.js`** to add artificial delays to specific providers
2. **Or** use a mock RPC provider that returns different balances based on a rotating counter
3. **Or** intercept network requests to one provider and delay them by 1-2 blocks

---

## Recommended Fixes

### Option A: Sticky Provider Selection (Recommended)

**Ensure the same user always hits the same RPC provider for balance requests.**

**File to modify:** `wdk-indexer-wrk-base/workers/lib/rpc.base.manager.js`

```javascript
// Add method to get provider by user hash
getProviderForUser(userId) {
  const hash = this._hashUserId(userId)
  const index = hash % this.secondaries.length
  return this.secondaries[index]
}

_hashUserId(userId) {
  // Simple hash function
  let hash = 0
  for (let i = 0; i < userId.length; i++) {
    hash = ((hash << 5) - hash) + userId.charCodeAt(i)
    hash |= 0
  }
  return Math.abs(hash)
}
```

**Pros:** Consistent results for the same user, no oscillation
**Cons:** May not evenly distribute load

### Option B: Always Bypass Cache

**Change the default to always fetch fresh data.**

**File to modify:** `wdk-app-node/workers/lib/server.js`

```javascript
// Change default from true to false
cache: { type: 'boolean', default: false }
```

**Pros:** Always returns the latest data from RPC
**Cons:** Higher load on RPC providers, potential rate limiting

### Option C: Block Height Validation

**Reject responses from providers that are behind the expected block height.**

**File to modify:** `wdk-data-shard-wrk/workers/lib/blockchain.svc.js`

```javascript
async getMultiWalletsBalances(...) {
  // Fetch current block height from majority of providers
  const expectedHeight = await this._getConsensusBlockHeight()

  // Only accept balance responses from providers at or above expected height
  const result = await this._rpcCall(...)
  if (result.blockHeight < expectedHeight - 1) {
    // Retry with different provider or throw
  }
  return result
}
```

**Pros:** Guarantees fresh data
**Cons:** More complex, requires provider block height tracking

### Option D: Unified Cache with TTL Extension on Fresh Data

**When cache=false returns fresher data, update the cache.**

**File to modify:** `wdk-app-node/workers/lib/utils/cached.route.js`

```javascript
async function cachedRoute (ctx, ckeyParts, apiPath, func, overwriteCache = false, shouldCache = () => true) {
  // ...
  if (cval === undefined) {
    cval = await func()
    // Always write if the data is valid AND newer than what's cached
    if (shouldCache(cval)) {
      const cached = await redis.get(ckey)
      const cachedData = cached ? JSON.parse(cached) : null
      if (!cachedData || cval.timestamp > cachedData.timestamp) {
        await redis.set(ckey, JSON.stringify(cval), 'PX', CACHE_TTL_MS)
      }
    }
  }
  return cval
}
```

**Pros:** Cache always has the freshest known data
**Cons:** Requires adding timestamps to balance responses

---

## Key Files Reference

| Component | File Path |
|-----------|-----------|
| Endpoint definition | `wdk-app-node/workers/lib/server.js:569-591` |
| Cache middleware | `wdk-app-node/workers/lib/utils/cached.route.js` |
| ORK service | `wdk-app-node/workers/lib/services/ork.js:214` |
| RPC manager (round-robin) | `wdk-indexer-wrk-base/workers/lib/rpc.base.manager.js:186-211` |
| Blockchain service | `wdk-data-shard-wrk/workers/lib/blockchain.svc.js:591-641` |

---

## Conclusion

The balance oscillation bug persists because the previous fix only prevented cache poisoning but did not address the fundamental issue: **round-robin RPC provider selection combined with mixed cache usage returns inconsistent data when providers are at different block heights**.

The most effective fix is **Option A (Sticky Provider Selection)**, which ensures consistent results without increasing RPC load. This should be combined with monitoring to detect when providers fall significantly behind.
