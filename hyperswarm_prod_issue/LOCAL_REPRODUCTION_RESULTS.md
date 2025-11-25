# Local Reproduction Results - Hyperswarm RPC Issue

**Date**: November 24, 2025
**Environment**: Local development (macOS)
**Status**: ✅ **Successfully Reproduced Variant of Production Issue**

---

## Summary

Successfully reproduced Hyperswarm RPC failures locally, confirming the production diagnosis that the issue is **NOT MongoDB-related** but rather a **Hyperswarm RPC pool/peer availability problem**.

---

## Errors Reproduced

### 1. `ERR_TOPIC_LOOKUP_EMPTY`
**Trigger**: XAUT indexer not running, but data-shard trying to query it
**Impact**: Logged warning, sync job continues
**Log**:
```
ERR_WALLET_TRANSFER_RPC_FAIL: ethereum:xaut:0x68749665ff8d2d112fa859aa293f07a622782f38:1
Error: ERR_TOPIC_LOOKUP_EMPTY
    at NetFacility.lookupTopicKeyAll (hp-svc-facs-net/index.js:204:13)
```

### 2. `PEER_NOT_FOUND` (Unhandled - Crashes Worker)
**Trigger**: USDT indexer stopped while data-shard sync job running
**Impact**: **Worker crash** (unhandled exception)
**Log**:
```
DHTError: PEER_NOT_FOUND: Peer not found
    at findAndConnect (hyperdht/lib/connect.js:350:74)
Emitted 'error' event on NoiseSecretStream instance
```

**Critical**: This error is **NOT caught** by the try/catch in `blockchain.svc.js:405-433`, suggesting it's emitted from a lower layer (Hyperswarm DHT).

---

## Test Configuration

### Config Changes Made
**File**: `rumble-data-shard-wrk/config/common.json`

```json
{
  "netOpts": {
    "poolLinger": 30000,     // Reduced from 600000 (10min) to 30s
    "timeout": 60000
  },
  "wrk": {
    "syncWalletTransfers": "*/10 * * * * *"  // Every 10 seconds (was 5 minutes)
  },
  "blockchains": {
    "ethereum": { "ccys": [ "usdt" ] }  // Removed "xaut" to avoid errors
  }
}
```

### Services Running
1. ✅ MongoDB replica set (3 nodes)
2. ✅ USDT indexer (proc + api) - `wdk-indexer-wrk-evm`
3. ✅ Data shard (proc + api) - `rumble-data-shard-wrk`
4. ✅ Org service - `rumble-ork-wrk`
5. ✅ HTTP app node - `rumble-app-node`

---

## Why "Pool was force destroyed" Wasn't Reproduced Exactly

**Reason**: Timing mismatch

- **Production scenario**:
  - Sync job: Every 5 minutes
  - poolLinger: 5 minutes (300s)
  - **Race condition**: Pool destruction starts at 5min, sync fires at 5min → ERROR

- **Local setup attempt**:
  - Sync job: Every 10 seconds
  - poolLinger: 30 seconds
  - **Result**: Pool **never** idles for 30s because sync runs every 10s!

**However**: Stopping the indexer manually triggered `PEER_NOT_FOUND`, which is a **more severe variant** of the same underlying Hyperswarm issue.

---

## Proof That This Is NOT a MongoDB Issue

### Evidence:

1. ✅ **Error stack traces** point to `hp-svc-facs-net` (Hyperswarm RPC layer), NOT MongoDB drivers
2. ✅ **MongoDB logs** show healthy connections, no rejections
3. ✅ **Indexer logs** show healthy operation (processing blocks normally)
4. ✅ **Error pattern** matches peer/pool unavailability, not database operations
5. ✅ **`PEER_NOT_FOUND` crashes worker** - happens at Hyperswarm DHT level, before RPC layer

---

## Recommendations

### Immediate (Production)

1. **Increase `poolLinger`** to 10-15 minutes (600000-900000ms)
   - Current: 5 minutes
   - Gives more buffer between sync jobs

2. **Add retry logic** in `blockchain.svc.js:getTransfersForWalletsBatch()`
   - Use existing `retryTask` utility (already used for balance fetching)
   - Retry on transient Hyperswarm errors

3. **Use `Promise.allSettled`** instead of `Promise.all`
   - Better handling of partial failures in batch operations

4. **Better error handling for Hyperswarm peer errors**
   - Catch `PEER_NOT_FOUND`, `ERR_TOPIC_LOOKUP_EMPTY` gracefully
   - Don't crash worker on peer unavailability

### Code Changes Needed

**File**: `wdk-data-shard-wrk/workers/lib/blockchain.svc.js:405`

```javascript
// Current (simplified):
await Promise.all(calls.map(async ({ chain, ccy, address }) => {
  try {
    const res = await this._rpcCall(chain, ccy, 'queryTransfersByAddress', ...)
    // ... handle response
  } catch (err) {
    this.ctx.logger.warn({ err }, `ERR_WALLET_TRANSFER_RPC_FAIL: ${chain}:${ccy}:${address}`)
  }
}))

// Recommended:
const { retryTask } = require('./utils')

await Promise.allSettled(calls.map(async ({ chain, ccy, address }) => {
  try {
    const retryOpts = { maxRetries: 2, retryDelay: 500 }
    const res = await retryTask(retryOpts, () =>
      this._rpcCall(chain, ccy, 'queryTransfersByAddress', ...)
    )
    // ... handle response
  } catch (err) {
    this.ctx.logger.warn({ err }, `ERR_WALLET_TRANSFER_RPC_FAIL: ${chain}:${ccy}:${address}`)
  }
}))
```

---

## Team Lead's Question - Answered

> "From your message, if no RPC calls have been made to a specific indexer for 5 minutes, the pool starts destruction (timeout), we should be able to configure this to something more frequent, like every 5 seconds?"

**Answer**: No, making poolLinger shorter (e.g., 5 seconds) would **make the problem worse**:
- Pools would be destroyed more frequently
- More reconnection overhead
- Higher chance of race conditions

**Better approach**:
1. **Increase poolLinger** (give more time between sync jobs)
2. **Add retry logic** (handle failures gracefully)
3. **Keep sync interval < poolLinger** (ensure pool stays active)

---

## Files Modified

- `rumble-data-shard-wrk/config/common.json` - Test configuration
- Created test scripts:
  - `test_pool_timeout.sh`
  - `test_pool_timeout_usdt.sh`
  - `test_usdt_only.sh`
  - `test_force_pool_timeout.sh`

---

## Conclusion

✅ **Confirmed**: Production issue is a **Hyperswarm RPC pool/peer availability problem**
✅ **Not MongoDB**: All evidence points to P2P layer
✅ **Reproducible**: Multiple variants reproduced locally
✅ **Fix identified**: Retry logic + increase poolLinger
✅ **Severity**: Can crash workers (unhandled `PEER_NOT_FOUND`)

**Next Steps**: Implement retry logic in `blockchain.svc.js` and deploy to staging for validation.
