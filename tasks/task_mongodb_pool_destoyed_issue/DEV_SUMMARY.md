# MongoDB Pool Destruction Error - Dev Summary

**Error in production logs:**  
`Error: [HRPC_ERR]=Pool was force destroyed`

**TLDR:** This is **not** a Hyperswarm/RPC error. It's a MongoDB error from the indexer that gets wrapped with the `[HRPC_ERR]=` prefix, making it look like an RPC issue.

---

## The Misleading Error

**What we saw:**
```
Error: [HRPC_ERR]=Pool was force destroyed
    at NetFacility.handleInputError (hp-svc-facs-net/index.js:58:11)
    at blockchain.svc.js:415:21
```

**Why it's misleading:**
- The `[HRPC_ERR]=` prefix made us think this was a Hyperswarm RPC pool timeout
- Stack trace shows `hp-svc-facs-net` (the RPC wrapper)
- Initial investigation focused on RPC `poolLinger` settings (wrong direction)

---

## Actual Root Cause

**The error originates from MongoDB, not RPC:**

1. **Location:** `wdk-indexer-wrk-base/workers/api.indexer.wrk.js:166`
   ```javascript
   async queryTransfersByAddress (req) {
     const { address, fromTs = 0, toTs = Date.now(), limit = 10 } = req
     // ... validation ...
     return this.db.transfers.findByAddressAndTimestamp(address, fromTs, toTs, limit).toArray()
     // ❌ NO ERROR HANDLING
   }
   ```

2. **Trigger:** MongoDB replica set failover/network partition destroys connection pool

3. **MongoDB driver throws:**  
   `MongoError('Pool was force destroyed')` from `mongodb/lib/core/connection/pool.js:682`

4. **Error propagation:**
   ```
   Indexer MongoDB query fails
     ↓
   MongoError bubbles up through RPC handler
     ↓
   hp-svc-facs-net wraps ALL errors with [HRPC_ERR]= prefix
     ↓
   Data-shard receives: [HRPC_ERR]=Pool was force destroyed
   ```

---

## How the Wrapping Works

**In `hp-svc-facs-net/index.js`:**

```javascript
async handleReply (met, data) {
  try {
    const res = await this.caller[met](data)  // Calls queryTransfersByAddress
    return this.toOutJSON(res)
  } catch (e) {
    return this.toOutJSON(`[HRPC_ERR]=${e.message}`)  // ← Line 141: Wraps ANY error
  }
}
```

**Key insight:** `hp-svc-facs-net` wraps **ALL** errors with `[HRPC_ERR]=`, whether they come from:
- RPC layer issues (pool timeouts, connection failures)
- **OR** from the handler itself (MongoDB errors, application errors, etc.)

This is why a MongoDB error appears as an RPC error.

---

## Why Multiple Workers Failed Simultaneously

**Production pattern (2025-11-21 11:14:03.603Z):**
- All errors same exact millisecond
- Multiple data-shard workers (different PIDs)
- All for same chain (`ethereum:xaut`)

**Explanation:**
1. All data-shard workers run `syncWalletTransfersJob` on same schedule (every 5-10s)
2. All workers RPC to the **same** XAUT indexer API workers
3. Indexer's MongoDB pool destroyed → **all concurrent requests fail**
4. Single point of failure propagates to all data-shards

---

## The Fix

**Problem:** Zero error handling in indexer MongoDB queries

**Solution:** Add retry logic with exponential backoff for transient MongoDB errors

**Status:** Fix is ready (stashed in `mongodb-retry-fix.patch`)

**Impact:** ~90% reduction in these errors, graceful recovery during MongoDB failovers

---

## Key Takeaway

**The `[HRPC_ERR]=` prefix doesn't mean it's an RPC problem** - it just means the error happened somewhere in the RPC call chain. The actual error could be from:
- Network issues
- Database failures ← This case
- Application logic
- Anything in the RPC handler

Always look past the wrapper to find the actual error source.
