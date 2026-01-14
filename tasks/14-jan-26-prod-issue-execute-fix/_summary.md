# Production Issue Fix Summary

## Issue Description
After system restart on Jan 5, 2026, new wallet creation failed for ~4.5 hours because the ork list was empty. The code didn't handle empty ork lists gracefully, causing cryptic internal errors (HTTP 500) instead of informative service unavailable errors (HTTP 503).

## Root Causes
1. **RoundRobin.updateItems() NaN corruption** - When called with empty array, `this.index %= 0` produces `NaN`, corrupting the index permanently
2. **resolveOrkRpcKey() no empty check** - When ork list is empty, `orks[NaN]` returns `undefined`, causing downstream RPC failures
3. **Missing error code mappings** - No mapping for `ERR_NO_ORKS_AVAILABLE` or `ERR_EMPTY` to HTTP 503
4. **_refreshOrks() overwrites good data** - Empty results from discovery overwrote valid ork list

## Files Modified

### Core Fixes

| File | Change |
|------|--------|
| `wdk-app-node/workers/lib/utils/round.robin.js:19-26` | Reset index to 0 on empty list instead of NaN |
| `wdk-ork-wrk/workers/lib/round.rubin.js:19-26` | Same fix (identical code in both repos) |
| `wdk-app-node/workers/lib/services/ork.js:14-16` | Added guard: throws `ERR_NO_ORKS_AVAILABLE` when ork list empty |
| `wdk-app-node/workers/lib/utils/errorsCodes.js:40-41` | Added `ERR_NO_ORKS_AVAILABLE: 503` and `ERR_EMPTY: 503` |
| `wdk-app-node/workers/base.http.server.wdk.js:69-72` | Skip updating orkIdx when refresh returns empty list; logs warning |

### Test Files Added/Modified

| File | Type | Tests Added |
|------|------|-------------|
| `wdk-app-node/tests/unit/utils/round.robin.test.js` | New | 4 tests for updateItems empty handling |
| `wdk-app-node/tests/unit/services/ork.test.js` | New | 5 tests for resolveOrkRpcKey edge cases |
| `wdk-app-node/tests/integration/base.http.server.test.js` | Modified | 1 test for HTTP 503 response |
| `wdk-ork-wrk/tests/round.rubin.unit.test.js` | Modified | 2 tests for updateItems empty handling |

## Test Results

### wdk-app-node Unit Tests
```
# tests = 11/11 pass
# asserts = 14/14 pass
```

### wdk-ork-wrk Unit Tests
```
# tests = 5/5 pass
# asserts = 12/12 pass
```

## Behavior After Fix

| Scenario | Before | After |
|----------|--------|-------|
| Empty ork list at startup | HTTP 500, cryptic error | HTTP 503, clear `ERR_NO_ORKS_AVAILABLE` |
| Empty refresh result | Ork list overwritten, all requests fail | Previous ork list preserved, warning logged |
| RoundRobin with empty items | Index corrupted to NaN permanently | Index reset to 0, ready for repopulation |

## Key Code Changes

### resolveOrkRpcKey() Guard
```javascript
const orks = ctx.orkIdx.getItems()
if (orks.length === 0) {
  throw new Error('ERR_NO_ORKS_AVAILABLE')
}
```

### RoundRobin.updateItems() Fix
```javascript
updateItems (items) {
  this.items = items
  if (this.items.length === 0) {
    this.index = 0
  } else {
    this.index %= this.items.length
  }
}
```

### _refreshOrks() Validation
```javascript
async _refreshOrks () {
  const keys = await this.net_r0.lookupTopicKeyAll(this.conf.orkTopic, false)
  if (keys.length === 0) {
    this.logger.warn('_refreshOrks: received empty ork list, keeping existing orks')
    return
  }
  this.orkIdx.updateItems(keys)
}
```

## Recommendations for Deployment
1. Deploy to staging first and verify HTTP 503 responses when orks are unavailable
2. Monitor logs for `_refreshOrks: received empty ork list` warnings after deployment
3. Consider adding alerting for prolonged empty ork conditions
