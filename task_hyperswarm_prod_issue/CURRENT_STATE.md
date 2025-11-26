# Current State - Hyperswarm Pool Issue Fix

**Date:** November 26, 2025
**PRs:**
- #19 (tether-wrk-base) - Pass netOpts config to hp-svc-facs-net facility
- #115 (wdk-data-shard-wrk) - Fix 'Hyperswarm pool destroyed' issue
**Status:** ✅ All reviewer feedback addressed

---

## Quick Summary

Following PR #19 and #115 review feedback from SargeKhan, the implementation has been **simplified and corrected**:

### ✅ What's Implemented

#### PR #19 (tether-wrk-base) - UPDATED Nov 26, 2025
1. **Proper config architecture** - Config moved to facility config file
2. **_loadFacConf() method** - Loads facility configs and passes as opts to hp-svc-facs-net
3. **Backward compatible** - Returns empty object if config doesn't exist, facility uses defaults
4. **DHT error handler removed** - Removed per reviewer feedback (separate concern)

#### PR #115 (wdk-data-shard-wrk)
1. **Promise.allSettled** - Prevents cascading batch failures
2. **Increased poolLinger** - Reduces pool timeout race conditions (600s vs 300s default)
3. **Retry logic removed** - Removed (sync frequency makes it unnecessary per reviewer)

### ❌ What Was Removed from Original Plan
1. **Retry logic** - Removed (sync frequency makes it unnecessary per reviewer)
2. **maxRetries/retryDelay configs** - No longer needed
3. **DHT error handlers** - Removed from PR #19 (should be handled separately if needed)

---

## Files Changed

### In tether-wrk-base Repository (PR #19) - UPDATED

| File | Change | Status |
|------|--------|--------|
| `workers/base.wrk.tether.js` | Added _loadFacConf() method, removed DHT handler, load from facility config | ✅ Done |
| `config/common.json.example` | Removed netOpts | ✅ Done |
| `config/facs/net.config.json.example` | Added poolLinger/timeout to r0 | ✅ Done |
| `README.md` | Updated docs to reflect correct config location | ✅ Done |

**Test results:** ✅ Syntax check pass, backward compatibility verified

### In wdk-data-shard-wrk Repository (PR #115)

| File | Change | Status |
|------|--------|--------|
| `config/facs/net.config.json.example` | Added poolLinger/timeout to r0 | ✅ Done |
| `config/common.json.example` | Removed netOpts | ✅ Done |
| `workers/lib/blockchain.svc.js` | Removed retry logic, kept Promise.allSettled | ✅ Done |
| `tests/unit/lib/blockchain.svc.unit.test.js` | Removed retry config | ✅ Done |

**Test results:** ✅ All tests pass (10/10, 46 assertions)

---

## What This Fixes

### ✅ Addressed
- Pool timeout race conditions (increased poolLinger 5min → 10min)
- Cascading batch failures (Promise.allSettled)
- Better observability (success/failure counting)

### ⚠️ Partially Addressed
- Transient RPC failures (no immediate retry, waits for next sync cycle)

### ❌ Not Addressed
- Worker crashes from `PEER_NOT_FOUND` DHT errors
- Immediate retry on transient failures

---

## Expected Impact

### Before Fix
- `[HRPC_ERR]=Pool was force destroyed` - ~15 errors every 5 minutes
- Batch operations fail completely when one RPC fails
- No visibility into partial failures

### After This Fix (Partial)
- Reduced pool timeout errors (~60-70% reduction)
- Batch operations continue even if some RPCs fail
- Clear logging of success/failure counts
- Failed wallets wait up to 5 minutes for retry

### After Complete Fix (with DHT handlers)
- ~90% reduction in pool timeout errors
- No worker crashes from DHT errors
- Improved resilience overall

---

## Reviewer Feedback Summary

### Comment 1: Config Location
> "this config should be in the net facility config file"

**Action:** ✅ Moved from `config/common.json.example` to `config/facs/net.config.json.example`

### Comment 2: Retry Logic
> "This job runs every 30 seconds. So, I don't think we need to retry here. If some requests for wallets fail, that's fine. We can fetch them next time."

**Action:** ✅ Removed retry logic from blockchain.svc.js

**Note:** Sync actually runs every 5 minutes (not 30 seconds), but reviewer's logic is sound.

---

## Trade-offs Accepted

### Simplicity vs Resilience
- **Gained:** Simpler code, easier to maintain
- **Lost:** No immediate retry on transient failures
- **Acceptable because:** Sync runs every 5 minutes, failures self-correct quickly

### Current Risk Profile
- **Medium Risk:** Transaction data staleness (up to 5 minutes)
- **High Risk:** Worker crashes from `PEER_NOT_FOUND` (if DHT handlers not added)

---

## Critical Gap: DHT Error Handlers

### The Problem
`PEER_NOT_FOUND` errors can be emitted as events from Hyperswarm DHT layer, bypassing try/catch blocks and crashing the worker.

### The Solution
See `ADDITIONAL_FIX_DHT_ERRORS.md` for implementation details.

**Priority:** ⚠️ **HIGH** (more critical now without retry logic)

**Location:** `tether-wrk-base/workers/base.wrk.tether.js`

**Code needed:**
```javascript
if (this.net_r0?.rpc?.dht) {
  this.net_r0.rpc.dht.on('error', (err) => {
    this.logger.warn({ err }, 'Hyperswarm DHT error (handled)')
  })
}
```

---

## Deployment Recommendation

### Option 1: Deploy Current Changes Only (Medium Risk)
- ✅ Addresses pool timeout race conditions
- ✅ Improves batch operation resilience
- ⚠️ Workers can still crash from `PEER_NOT_FOUND`
- ⚠️ Transient failures cause up to 5 minutes staleness

### Option 2: Deploy with DHT Error Handlers (Recommended)
- ✅ Addresses pool timeout race conditions
- ✅ Improves batch operation resilience
- ✅ Prevents worker crashes
- ⚠️ Transient failures cause up to 5 minutes staleness (acceptable)

**Recommendation:** Deploy with DHT error handlers

---

## Monitoring After Deployment

### Key Metrics
1. **Error frequency:** Watch for reduction in `[HRPC_ERR]=Pool was force destroyed`
2. **Worker uptime:** Verify no crashes from `PEER_NOT_FOUND` (if DHT handlers added)
3. **Data staleness:** Monitor transaction sync delays (should be < 5 minutes)
4. **Partial failures:** Check `txFetch:batch:partial` logs for failure patterns

### Success Criteria
- ✅ Pool timeout errors reduced by 60-70%+
- ✅ No worker crashes from DHT errors (if handlers added)
- ✅ Transaction data staleness < 5 minutes
- ✅ Batch operations continue despite individual failures

---

## Related Documentation

- `CODE_CHANGES_ASSESSMENT.md` - Detailed technical analysis (updated Nov 26)
- `EXAMPLE_CONFIG_UPDATES.md` - Configuration documentation (updated Nov 26)
- `ADDITIONAL_FIX_DHT_ERRORS.md` - Critical missing piece for worker crash prevention
- `LOCAL_REPRODUCTION_RESULTS.md` - Original reproduction findings

---

## Future Considerations

### If Transaction Staleness Becomes an Issue
- Re-evaluate retry logic addition
- Consider more frequent sync intervals
- Implement push-based notifications instead of polling

### If Pool Timeout Errors Persist
- Further increase poolLinger (e.g., 15 or 20 minutes)
- Investigate root cause of pool destruction timing
- Consider keep-alive pings to prevent pool idle timeout

---

**Last Updated:** November 26, 2025
**Updated By:** Claude Code (based on PR #115 review feedback)
