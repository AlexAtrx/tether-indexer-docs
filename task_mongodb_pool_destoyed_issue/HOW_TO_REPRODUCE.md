# How to Reproduce "Pool was force destroyed" Error

**For:** Development team  
**Purpose:** Reproduce the MongoDB pool destruction error locally

---

## Quick Start

```bash
cd /Users/alexa/Documents/repos/tether/_INDEXER/_docs/task_mongodb_pool_destoyed_issue
./REPRODUCE_ERROR.sh
```

The script will:
1. Start MongoDB in Docker
2. Start EVM indexer workers  
3. Stop MongoDB to trigger the error
4. Show you the logs with the error

---

## Manual Reproduction Steps

If you want to reproduce manually:

### 1. Start MongoDB

```bash
docker run -d --name mongodb_test -p 27017:27017 mongo:5
```

### 2. Start EVM Indexer

```bash
cd /Users/alexa/Documents/repos/tether/_INDEXER/wdk-indexer-wrk-evm

# Start PROC worker
node worker.js --wtype to-evm-indexer-proc --chain eth

# In another terminal, start API worker (use the RPC key from PROC logs)
node worker.js --wtype wrk-evm-indexer-api --chain eth --proc-rpc <RPC_KEY>
```

### 3. Trigger the Error

While the indexer is running:

```bash
# Kill MongoDB
docker stop mongodb_test
```

### 4. Make an RPC Call (triggers the error)

If you have data-shard workers running, they will call `queryTransfersByAddress` and get the error.

Alternatively, simulate it with a direct MongoDB query attempt - the indexer will fail when MongoDB is unavailable.

### 5. Observe the Error

Check the indexer API worker logs. You'll see errors like:

```
MongoNetworkError: connect ECONNREFUSED
Pool was force destroyed
topology was destroyed
```

When this error propagates through RPC to data-shard, it becomes:
```
[HRPC_ERR]=Pool was force destroyed
```

---

## Root Cause

The error happens in [`api.indexer.wrk.js`](file:///Users/alexa/Documents/repos/tether/_INDEXER/wdk-indexer-wrk-base/workers/api.indexer.wrk.js):

```javascript
async queryTransfersByAddress (req) {
  // ... validation ...
  return this.db.transfers.findByAddressAndTimestamp(address, fromTs, toTs, limit).toArray()
  // ❌ NO ERROR HANDLING - throws when MongoDB pool is destroyed
}
```

When MongoDB becomes unavailable (replica set failover, network partition, etc.):
1. MongoDB driver destroys the connection pool
2. Any pending queries throw `MongoError('Pool was force destroyed')`
3. Error propagates to RPC layer → gets wrapped as `[HRPC_ERR]=`
4. Data-shard workers see the wrapped error

---

## Production Scenario

In production, this happens when:

1. **Data-shard workers** continuously call `queryTransfersByAddress` via RPC
2. **MongoDB** experiences a brief disruption:
   - Replica set primary election
   - Network partition
   - Connection timeout under load
3. **All concurrent requests fail** simultaneously (same timestamp)
4. **Error logged** in multiple data-shard workers

See [`production_logs.log`](file:///Users/alexa/Documents/repos/tether/_INDEXER/_docs/task_mongodb_pool_destoyed_issue/production_logs.log) for real examples.

---

## Expected Output

When you successfully reproduce, you'll see:

**In indexer logs:**
```
MongoNetworkError: connect ECONNREFUSED 127.0.0.1:27017
```

**In data-shard logs (if running):**
```
Error: [HRPC_ERR]=Pool was force destroyed
    at NetFacility.handleInputError (hp-svc-facs-net/index.js:58:11)
    at NetFacility.jRequest (hp-svc-facs-net/index.js:84:10)
    at async blockchain.svc.js:415:21
```

---

## Clean Up

```bash
# Stop MongoDB
docker stop mongodb_test
docker rm mongodb_test

# Kill indexer processes
pkill -f "node.*wdk-indexer-wrk-evm"
```

---

## Fix Available

Once you've reproduced the error, the fix is ready to apply:

See [`HOW_TO_RESTORE_FIX.md`](file:///Users/alexa/Documents/repos/tether/_INDEXER/_docs/task_mongodb_pool_destoyed_issue/HOW_TO_RESTORE_FIX.md) for instructions.

The fix adds retry logic with exponential backoff to handle transient MongoDB failures gracefully.
