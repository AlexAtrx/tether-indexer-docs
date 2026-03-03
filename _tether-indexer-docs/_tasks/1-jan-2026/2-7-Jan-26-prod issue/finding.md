# Final Verified Analysis: Jan 5 2026 Production Issue - New Wallet Creation Failure

## Summary

After a full system restart, new wallet creation was blocked for ~4.5 hours. The immediate cause was `wdk-app-node` attempting RPC calls with an `undefined` key when no ork workers were available. A secondary latent bug in `RoundRobin.updateItems` can corrupt the index permanently.

## Error and Log Ownership

**Log source:** The `"unhandled route error"` log is emitted by `wdk-app-node/workers/base.http.server.wdk.js:146`. It appears under `rumble-app-node` because `rumble-app-node/workers/http.node.wrk.js` extends `WdkServerHttpBase`.

**Error source:** The error `[HRPC_ERR]=The first argument must be of type string...` originates from `hp-svc-facs-net` when `jRequest` is called with an undefined RPC key. The `[HRPC_ERR]=` prefix is added by the RPC layer during error wrapping.

## Root Cause Analysis

### Primary Bug: Empty Ork List Handling

**File:** `wdk-app-node/workers/lib/services/ork.js:8-16`

```javascript
const resolveOrkRpcKey = (ctx, userId) => {
  if (!userId) {
    return ctx.orkIdx.next()  // Throws ERR_EMPTY if no orks
  }

  const orks = ctx.orkIdx.getItems()
  const i = (CRC32.str(userId) >>> 0) % orks.length  // BUG: length=0 → i=NaN
  return orks[i]  // BUG: orks[NaN] = undefined
}
```

When `orks` array is empty:
1. `(CRC32.str(userId) >>> 0) % 0` evaluates to `NaN`
2. `orks[NaN]` returns `undefined`
3. `ctx.net_r0.jRequest(undefined, ...)` fails in `hp-svc-facs-net`

### Secondary Bug: RoundRobin Index Corruption (affects `next()` path)

**Files:**
- `wdk-app-node/workers/lib/utils/round.robin.js:19-22`
- `wdk-ork-wrk/workers/lib/round.rubin.js:19-22`

```javascript
updateItems (items) {
  this.items = items
  this.index %= this.items.length  // BUG: length=0 → index=NaN
}
```

When `items.length === 0`:
- `this.index %= 0` sets `index` to `NaN`
- Once `NaN`, the index stays corrupted permanently:
  - `items[NaN]` returns `undefined`
  - `NaN % anything` remains `NaN`
- Even after items appear, `next()` remains broken (used when `userId` is absent).  
  The hash path (`getItems()` + CRC32) does **not** depend on `index` and works once the list is non-empty.

This means a single empty update can break the RoundRobin until process restart.

### Initialization Sequence

**File:** `wdk-app-node/workers/base.http.server.wdk.js:120-127`

```javascript
this.orkIdx = new RoundRobin(
  [],                              // Starts empty
  this.status.orkIdx ?? 0
)
await this._refreshOrks()          // May return empty list after restart
this.interval_0.add('process-update-orks', () => {
  this._refreshOrks().catch(...)
}, 120_000)
```

After a full system restart:
1. Ork workers may not be on DHT yet when `_refreshOrks()` runs
2. Empty list passed to `updateItems()` corrupts index to `NaN`
3. HTTP requests arrive before orks are available
4. Even when orks appear later, the corrupted index keeps returning `undefined`

## Call Chain

```
HTTP POST /api/v1/connect
  → wdk-app-node/workers/lib/server.js:40
    → service.ork.resolveDataShard(ctx, req)
      → wdk-app-node/workers/lib/services/ork.js:31
        → rpcCall(ctx, req, 'lookupDataShard', { userId })
          → resolveOrkRpcKey(ctx, userId)
            → Returns undefined when list is empty (hash path) or when `next()` index is NaN (no userId path)
          → ctx.net_r0.jRequest(undefined, ...)
            → hp-svc-facs-net throws error
```

## Files Involved

| File | Repository | Role |
|------|------------|------|
| `workers/lib/services/ork.js` | wdk-app-node | Contains `resolveOrkRpcKey` with missing empty check |
| `workers/base.http.server.wdk.js` | wdk-app-node | Initializes `orkIdx`, runs `_refreshOrks` |
| `workers/lib/utils/round.robin.js` | wdk-app-node | RoundRobin with `updateItems` NaN bug |
| `workers/lib/round.rubin.js` | wdk-ork-wrk | Same RoundRobin bug (affects data shard selection) |
| `workers/lib/data.shard.util.js` | wdk-ork-wrk | Uses RoundRobin for shard assignment |
| `workers/lib/utils/errorsCodes.js` | wdk-app-node | HTTP status code mappings |

## Required Fixes

### Fix 1: Guard Empty Ork List

**File:** `wdk-app-node/workers/lib/services/ork.js`

```javascript
const resolveOrkRpcKey = (ctx, userId) => {
  const orks = ctx.orkIdx.getItems()

  if (orks.length === 0) {
    throw new Error('ERR_NO_ORKS_AVAILABLE')
  }

  if (!userId) {
    return ctx.orkIdx.next()
  }

  const i = (CRC32.str(userId) >>> 0) % orks.length
  return orks[i]
}
```

### Fix 2: Add Error Code Mapping

**File:** `wdk-app-node/workers/lib/utils/errorsCodes.js`

```javascript
module.exports = {
  // ... existing codes ...
  ERR_NO_ORKS_AVAILABLE: 503,
  ERR_EMPTY: 503
}
```

Without this, the new error will return HTTP 500 instead of 503 Service Unavailable.  
Note: `ERR_EMPTY` mapping is optional if you instead catch `ERR_EMPTY` and rethrow `ERR_NO_ORKS_AVAILABLE`.

### Fix 3: Fix RoundRobin.updateItems NaN Bug

**Files:**
- `wdk-app-node/workers/lib/utils/round.robin.js`
- `wdk-ork-wrk/workers/lib/round.rubin.js`

```javascript
updateItems (items) {
  this.items = items
  if (this.items.length === 0) {
    this.index = 0  // Reset to valid state instead of NaN
  } else {
    this.index %= this.items.length
  }
}
```

### Fix 4: Prevent Empty List Overwrites (optional; see tradeoff)

**File:** `wdk-app-node/workers/base.http.server.wdk.js`

```javascript
async _refreshOrks () {
  const keys = await this.net_r0.lookupTopicKeyAll(this.conf.orkTopic, false)
  if (keys.length === 0) {
    this.logger.warn('No ork workers discovered, keeping previous list')
    return  // Tradeoff: avoids empty list but can keep stale keys; consider pairing with 503 on empty discovery.
  }
  this.orkIdx.updateItems(keys)
}
```

## Recommended Additional Steps

1. **Integration test:** Add test in `wdk-app-node` calling `/api/v1/connect` when `orkIdx` is empty, asserting 503 response

2. **Startup health check:** Log/metric for `orkIdx` size, alert when zero for >N minutes

3. **Readiness gate:** Consider not accepting requests until at least one ork is discoverable

## Impact Assessment

- **Affected:** wdk-app-node (and rumble-app-node which extends it)
- **Operations affected:** All ork-dependent operations (wallet creation, balance queries, etc.)
- **Duration:** ~4.5 hours
- **Root causes:** Two bugs - missing empty check + RoundRobin NaN corruption
