# MongoDB Pool Destruction Issue - Comprehensive Analysis

**Date:** November 27, 2025  
**Status:** Investigation In Progress - New Theory Identified  
**Severity:** Production Issue - Recurring

---

## Executive Summary

After extensive investigation attempting to reproduce `[HRPC_ERR]=Pool was force destroyed` errors locally, we discovered the **original diagnosis was likely incorrect**. The error does NOT appear to be a Hyperswarm RPC pool timeout issue, but rather a **MongoDB connection pool issue in the INDEXER services** that gets wrapped as an RPC error when returned to data-shard workers.

---

## Production Error Details

### Error Pattern from Production Logs

**Timestamp:** 2025-11-21 11:14:03.603 UTC (all errors same millisecond)  
**Affected Service:** `rumble-data-shard-wrk` (multiple workers)  
**Error Message:** `[HRPC_ERR]=Pool was force destroyed`

**Stack Trace:**
```
Error: [HRPC_ERR]=Pool was force destroyed
    at NetFacility.handleInputError (hp-svc-facs-net/index.js:58:11)
    at NetFacility.jRequest (hp-svc-facs-net/index.js:84:10)
    at async blockchain.svc.js:415:21
    at async Promise.all (index 6/11/21)  ← Multiple parallel requests
    at async BlockchainService.getTransfersForWalletsBatch (blockchain.svc.js:408:5)
    at async WrkDataShardProc._walletTransferBatch (proc.shard.data.wrk.js:471:57)
    at async WrkDataShardProc.syncWalletTransfersJob (proc.shard.data.wrk.js:455:9)
```

### Key Observations

1. **Multiple workers failed simultaneously** - Same exact timestamp across different PIDs:
   - `pid:565248` on `walletprd2` (Promise.all index 11 and 6)
   - `pid:565397` on `walletprd2` (Promise.all index 21)

2. **All errors for `ethereum:xaut` addresses** - Specific to XAUT token indexer

3. **Indexer was healthy** - XAUT indexer successfully processed blocks at 11:14:00.125-418Z (3 seconds before errors)

4. **No indexer restarts** - All indexers had 47+ hours uptime with 0 restarts

---

## Investigation Journey

### Phase 1: Original Hypothesis (INCORRECT)

**Theory:** Hyperswarm RPC `poolLinger` timeout causing pool destruction

**Test Attempts:**
1. `test_pool_destruction_v4.sh` - Tried to trigger RPC pool timeout by disabling wallets
2. `test_pool_destruction_v5.sh` - Enhanced version with better diagnostics
3. Ran tests 20+ times with `_run_the_repeat.sh`

**Result:** ❌ Could not reproduce the error  
**Reason:** RPC calls completed successfully (2-4ms), pools remained active

### Phase 2: MongoDB Hypothesis (Data-Shard)

**Theory:** MongoDB pool destruction in data-shard worker

**Test:** `test_mongodb_pool_auto.sh` - Stop MongoDB while data-shard processes wallet operations

**Result:** ❌ Could not reproduce the error  
**Reason:** Data-shard MongoDB operations not affected by the test

### Phase 3: MongoDB Hypothesis (Indexer) ← CURRENT

**Theory:** MongoDB pool destruction in INDEXER worker, error wrapped as `[HRPC_ERR]=`

**Test:** `test_indexer_mongodb.sh` - Stop MongoDB while indexer queries for transfer data

**Result:** ⏳ No reproduction yet, but theory remains strongest candidate

**Evidence Supporting This Theory:**

1. **Found "Pool was force destroyed" in MongoDB driver**
   - Located in: `node_modules/mongodb/lib/core/connection/pool.js:682`
   - Thrown when: `pool.destroy(true)` called with pending operations in queue

2. **`hp-svc-facs-net` wraps ALL errors with `[HRPC_ERR]=` prefix**
   - Code at line 164/171: `return this.toOutJSON(\`[HRPC_ERR]=\${e.message}\`)`
   - Any error from indexer → wrapped → sent to data-shard
   - Data-shard sees it as RPC error, but origin is MongoDB

3. **Production timing suggests indexer issue**
   ```
   11:14:00.125Z - Indexer starts processing blocks
   11:14:00.418Z - Indexer finishes successfully  
   11:14:03.603Z - Multiple data-shards fail with same error
   ```
   3-second gap suggests indexer was queried by data-shards shortly after block processing

---

## Technical Deep Dive

### MongoDB Pool Destruction Mechanism

From `mongodb/lib/core/connection/pool.js`:

```javascript
Pool.prototype.destroy = function(force, callback) {
  // ...
  if (force) {
    // Flush any remaining work items with an error
    while (self.queue.length > 0) {
      var workItem = self.queue.shift();
      if (typeof workItem.cb === 'function') {
        workItem.cb(new MongoError('Pool was force destroyed'));  ← ERROR SOURCE
      }
    }
    return destroy(self, connections, { force: true }, callback);
  }
  // ...
}
```

**When does this happen?**
- Replica set failover (primary election)
- Network partitioning
- Connection timeout during high load
- `pool.destroy(true)` called explicitly

### Error Propagation Flow

```
┌─────────────────────────────────────────────────────────────────┐
│ 1. Data-Shard Worker                                            │
│    syncWalletTransfersJob() runs every 5-10 seconds             │
│    └─> getTransfersForWalletsBatch()                            │
│        └─> Promise.all([...multiple RPC calls...])              │
└────────────────────────────┬────────────────────────────────────┘
                             │ Hyperswarm RPC
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│ 2. Indexer API Worker                                           │
│    Receives: queryTransfersByAddress(address, fromTs, limit)    │
│    └─> Queries MongoDB for transfer data                        │
│        ┌─────────────────────────────────────────────┐          │
│        │ 3. MongoDB Connection Pool                  │          │
│        │    If pool destroyed while query pending:   │          │
│        │    → MongoError('Pool was force destroyed') │          │
│        └─────────────────────────────────────────────┘          │
│    ← Returns error to RPC layer                                 │
└────────────────────────────┬────────────────────────────────────┘
                             │ Error wrapped by hp-svc-facs-net
                             │ at handleReply() line 171:
                             │ return `[HRPC_ERR]=${e.message}`
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│ 4. Data-Shard Worker (receives response)                        │
│    hp-svc-facs-net/index.js:58 - handleInputError()             │
│    Detects `[HRPC_ERR]=` prefix                                 │
│    └─> throw new Error('[HRPC_ERR]=Pool was force destroyed')   │
│                                                                  │
│    Caught by blockchain.svc.js:408                              │
│    Logged as: ERR_WALLET_TRANSFER_RPC_FAIL                      │
└─────────────────────────────────────────────────────────────────┘
```

### Why Multiple Workers Fail Simultaneously

1. **Sync job timing** - All data-shard workers run `syncWalletTransfersJob` on same 5-10 second schedule
2. **Batch processing** - Each worker processes multiple wallets in parallel via `Promise.all`
3. **Shared indexer** - All workers RPC to the same XAUT indexer API workers
4. **Single point of failure** - If indexer's MongoDB pool is destroyed, ALL concurrent requests fail
5. **No connection pooling between data-shard and indexer** - Each RPC request hits same backend

---

## Why Local Reproduction Failed

### Environment Differences

| Aspect | Local Dev | Production |
|--------|-----------|------------|
| MongoDB Setup | Single node | Replica set (3+ nodes) |
| Worker Count | 1 of each | Multiple horizontal instances |
| Load | Minimal | Real user traffic |
| Network | Localhost | Distributed, potential partitions |
| Pool Lifetime | Short-lived tests | Long-running services |

### Missing Triggers

1. **No replica set failovers** - Local single-node MongoDB doesn't have primary elections
2. **No network issues** - Localhost connections are stable
3. **Timing too fast** - Our RPC calls completed in 2-4ms, before MongoDB could be affected
4. **No concurrent load** - Not enough parallel requests to queue operations

---

## Architecture Context

### Production Environment

**Deployed on:** Promises (client-side? - needs clarification)  
**Deployment:** Horizontal scaling for all workers

**Worker Types:**
1. **Indexer Workers** (multiple chains/tokens)
   - PROC workers: 1 per chain (singleton, writes to MongoDB)
   - API workers: 2+ per chain (read from MongoDB, handle RPC requests)
   - Examples: `idx-xaut-eth-proc`, `idx-xaut-eth-api-w-0-0`, `idx-xaut-eth-api-w-0-1`

2. **Data-Shard Workers**
   - PROC workers: Handle writes, wallet operations
   - API workers: Handle read requests from app-node

### Communication Flow

```
App Node (HTTP API)
    ↓ RPC
Data-Shard Workers
    ↓ RPC (Hyperswarm)
Indexer API Workers
    ↓ MongoDB Query
MongoDB Replica Set
```

---

## Proposed Solutions

### Option 1: Add Retry Logic in Indexer (Recommended)

**Where:** `wdk-indexer-wrk-evm` (and other indexer implementations)  
**What:** Wrap MongoDB queries with retry logic to handle transient pool destruction

**Why This Works:**
- Indexer is closest to the error source
- Can detect MongoDB-specific errors
- Retry before returning to data-shard
- Prevents error propagation

**Implementation:**
```javascript
// In indexer's queryTransfersByAddress handler
async queryTransfersByAddress({ address, fromTs, limit }) {
  const maxRetries = 2;
  let lastError;
  
  for (let attempt = 0; attempt <= maxRetries; attempt++) {
    try {
      const transfers = await this.db.transfers.find({
        address, timestamp: { $gte: fromTs }
      }).limit(limit).toArray();
      
      return transfers;
    } catch (err) {
      lastError = err;
      
      // Only retry on pool destruction or connection errors
      if (err.message.includes('Pool was force destroyed') ||
          err.message.includes('connection') ||
          err.message.includes('ECONNREFUSED')) {
        
        this.logger.warn(`MongoDB query retry ${attempt + 1}/${maxRetries}: ${err.message}`);
        await new Promise(resolve => setTimeout(resolve, 200 * Math.pow(2, attempt)));
        continue;
      }
      
      // Other errors - don't retry
      throw err;
    }
  }
  
  throw lastError;
}
```

### Option 2: Improve MongoDB Connection Handling

**Where:** Indexer MongoDB configuration  
**What:** Better connection pool settings, auto-reconnect

**Configuration:**
```javascript
{
  "mongoUrl": "mongodb://mongo1:27017,mongo2:27017,mongo3:27017/wdk_indexer_xaut?replicaSet=rs0",
  "poolSize": 20,
  "retryWrites": true,
  "retryReads": true,
  "maxPoolSize": 50,
  "minPoolSize": 5,
  "maxIdleTimeMS": 60000,
  "serverSelectionTimeoutMS": 30000,
  "socketTimeoutMS": 45000
}
```

### Option 3: Add Retry Logic in Data-Shard

**Where:** `wdk-data-shard-wrk/workers/lib/blockchain.svc.js`  
**What:** Retry failed RPC calls when they return pool destruction errors

**Why This Helps:**
- Defense in depth
- Handles ANY transient RPC failures, not just MongoDB
- Already used for balance fetching

**Implementation:**
```javascript
// In getTransfersForWalletsBatch
const { retryWithBackoff } = require('./utils/retry.util');

const res = await retryWithBackoff(
  () => this._rpcCall(chain, ccy, 'queryTransfersByAddress', {...}),
  {
    times: 2,
    interval: 500,
    shouldRetry: (err) => err.message.includes('Pool was force destroyed')
  }
);
```

---

## Next Investigation Steps

### Immediate Actions

1. **Check indexer MongoDB configuration**
   - Verify connection pool settings
   - Check if using replica set properly
   - Review reconnection strategy

2. **Add logging to indexer**
   - Log all MongoDB connection events
   - Log pool creation/destruction
   - Monitor for replica set state changes

3. **Review indexer error handling**
   - Check how MongoDB errors are currently returned
   - Verify error wrapping in RPC response

### Questions to Answer

1. **Does the indexer actually query MongoDB for `queryTransfersByAddress`?**
   - Or does it query from a cache/memory structure?
   - Check the indexer implementation

2. **What MongoDB setup does production use?**
   - Replica set configuration
   - Auto-failover settings
   - Connection pool settings per indexer instance

3. **Are there indexer logs showing MongoDB errors at 11:14:03?**
   - Need production indexer logs from that time
   - Look for MongoDB connection errors

4. **How many data-shard workers query the same indexer?**
   - Could be connection pool exhaustion
   - Too many concurrent requests

### Validation Tests

1. **Production Log Analysis**
   - Get indexer logs from error time window
   - Correlation with MongoDB replica set events
   - Check for connection pool metrics

2. **Reproduce with Replica Set**
   - Set up local 3-node MongoDB replica set
   - Trigger failover while queries are running
   - Use production-like concurrency levels

3. **Stress Testing**
   - Multiple data-shard workers
   - High concurrency RPC calls to indexer
   - Monitor MongoDB connection pool usage

---

## Files and Evidence

### Production Logs
- `production_logs.log` - OCR'd error logs from production screenshots
- Shows 3 simultaneous errors at 11:14:03.603 UTC
- XAUT indexer processing blocks successfully right before

### Test Scripts Created
- `test_pool_destruction_v4.sh` - Hyperswarm pool timeout test (failed to reproduce)
- `test_pool_destruction_v5.sh` - Enhanced version with diagnostics (failed to reproduce)
- `test_mongodb_pool_auto.sh` - MongoDB pool test for data-shard (failed to reproduce)
- `test_indexer_mongodb.sh` - MongoDB pool test for indexer (in progress)

### Key Source Files
- `hp-svc-facs-net/index.js:164,171` - Error wrapping with `[HRPC_ERR]=` prefix
- `mongodb/lib/core/connection/pool.js:682` - Source of "Pool was force destroyed" string
- `blockchain.svc.js:408,415` - Data-shard RPC call site
- `proc.shard.data.wrk.js:455,471` - Sync job entry point

---

## Conclusions

### High Confidence Findings

1. ✅ **Error originates from MongoDB driver**, not Hyperswarm RPC
2. ✅ **Error is wrapped by `hp-svc-facs-net`** when returning from indexer to data-shard
3. ✅ **Multiple data-shard workers fail simultaneously** when shared indexer has issues
4. ✅ **Indexers themselves were healthy** at time of errors
5. ✅ **Original Hyperswarm `poolLinger` diagnosis was incorrect**

### Medium Confidence Theories

1. 🤔 **Indexer's MongoDB pool is being destroyed** during replica set events
2. 🤔 **Error happens in indexer, not data-shard** (needs indexer logs to confirm)
3. 🤔 **Connection pool exhaustion** possible with many concurrent data-shard workers

### Open Questions

1. ❓ What triggers MongoDB pool destruction in production?
2. ❓ Does the indexer have retry logic for MongoDB operations?
3. ❓ Are there MongoDB replica set failover events corresponding to errors?
4. ❓ What is the indexer's MongoDB connection pool configuration?

---

## Recommended Next Actions

**Priority 1 - Evidence Gathering:**
1. Get indexer worker logs from 11:14:00-11:14:05 UTC on 2025-11-21
2. Check MongoDB replica set logs for failover events at that time
3. Review indexer MongoDB connection configuration

**Priority 2 - Quick Wins:**
1. Add retry logic to data-shard `blockchain.svc.js` (defensive measure)
2. Add MongoDB connection event logging to indexer
3. Monitor production for pattern: does error correlate with replica set events?

**Priority 3 - Long-term:**
1. Review and optimize indexer MongoDB connection pool settings
2. Add comprehensive error handling in indexer for MongoDB failures
3. Consider caching layer in indexer to reduce MongoDB dependency

---

**Last Updated:** 2025-11-27  
**Next Review:** After obtaining indexer production logs
