# How to ACTUALLY Reproduce "Pool was force destroyed" Error

**Date:** November 27, 2025  
**Status:** Solution Identified

---

## Problem with Current Reproduction Attempts

Your existing scripts are **NOT** reproducing the correct error. Here's what's happening:

### ❌ What You're Currently Getting

```
MongoError: not master and slaveOk=false
```

**Source:** This is the **data-shard's own MongoDB** connection failing during replica set failover.  
**Why it appears:** When you stop `mongo1`, the data-shard's MongoDB connection to its own database fails.

### ✅ What You NEED to Get

```
[HRPC_ERR]=Pool was force destroyed
```

**Source:** This error originates from the **INDEXER's MongoDB** connection, NOT the data-shard's.  
**How it appears:** The indexer's MongoDB pool is destroyed **during an active query**, then the error is wrapped by `hp-svc-facs-net` when returned to data-shard.

---

## Root Cause of Your Failures

Looking at `/tmp/data-shard-proc-trace.log`, you're seeing:

1. ✅ Data-shard sync jobs running
2. ✅ MongoDB stopped (mongo1)
3. ❌ **WRONG ERROR**: data-shard's own MongoDB fails with `not master and slaveOk=false`
4. ❌ **MISSING ERROR**: No `[HRPC_ERR]=Pool was force destroyed` from indexer RPC calls

### Why the indexer error isn't appearing:

1. **No active indexer queries** - The indexer isn't being queried when you stop MongoDB
2. **No wallets to sync** - Data-shard has no wallets that would trigger RPC calls to the indexer
3. **Timing issue** - MongoDB is stopped, but data-shard isn't making RPC calls to the indexer at that moment

---

## The ACTUAL Reproduction Method

According to your analysis (COMPREHENSIVE_ANALYSIS.md), here's what needs to happen:

### Error Flow (from production)

```
1. Data-shard calls indexer RPC → queryTransfersByAddress()
2. Indexer queries MongoDB for transfers
3. MongoDB PRIMARY FAILS during the query (replica set failover)
4. Indexer's MongoDB driver throws: MongoError('Pool was force destroyed')
5. hp-svc-facs-net wraps it: [HRPC_ERR]=Pool was force destroyed
6. Data-shard receives the wrapped error
```

### Critical Missing Piece

**The indexer must be actively querying MongoDB when you stop it!**

Your current scripts stop MongoDB, but there's **no guarantee the indexer is making a MongoDB query at that exact moment**.

---

## Solution: How to Really Reproduce It

### Prerequisites

You need **ALL** of these running:

1. ✅ MongoDB replica set (mongo1, mongo2, mongo3)
2. ✅ **Indexer PROC worker** (e.g., `wdk-indexer-wrk-evm` for XAUT/ETH)
3. ✅ **Indexer API worker** (connected to PROC)
4. ✅ **Data-shard PROC worker**
5. ✅ **Data-shard API worker** (optional)
6. ✅ **At least ONE wallet** with addresses that will trigger transfer sync

### Step-by-Step Reproduction

#### 1. Ensure Indexer Has Data to Query

The indexer needs to have **actual transfer data** in its MongoDB so queries are real, not just empty results.

**Check if indexer has data:**
```bash
# Connect to indexer's MongoDB
docker exec mongo1 mongosh --quiet wdk_indexer_xaut --eval "db.transfers.countDocuments({})"
```

If it returns `0`, you need to let the indexer sync some data first, or manually insert test data.

#### 2. Create a Wallet That Will Trigger Indexer Queries

```bash
# Create a wallet with an address that the indexer is tracking
curl -X POST http://127.0.0.1:3000/api/v1/wallets \
  -H "authorization: Bearer test_auth_token" \
  -H "content-type: application/json" \
  -d '[{
    "name": "test-wallet-pool-repro",
    "type": "user",
    "enabled": true,
    "addresses": {
      "ethereum": "0x<SOME_ADDRESS_WITH_TRANSFERS>"
    }
  }]'
```

**Important:** Use an address that actually has transfer history in the indexer's database.

#### 3. Create Continuous Load on Indexer

You need to ensure the data-shard is **continuously** making RPC calls to the indexer's `queryTransfersByAddress` method.

**Option A: Trigger sync manually in a loop**
```bash
#!/bin/bash
# continuous_indexer_load.sh

echo "Creating continuous RPC load on indexer..."

while true; do
  # Get wallet transfers (this makes RPC calls to indexer)
  curl -s -X GET "http://127.0.0.1:3000/api/v1/wallets/<WALLET_ID>/transfers?limit=100" \
    -H "authorization: Bearer test_auth_token" > /dev/null
  
  echo "Queried indexer at $(date +%H:%M:%S)"
  sleep 0.1  # Query every 100ms
done
```

**Option B: Monitor data-shard sync job**
```bash
# Watch data-shard logs to confirm it's making RPC calls
tail -f /tmp/data-shard-proc-trace.log | grep -i "syncTransfersExec"
```

#### 4. Stop MongoDB DURING Active Queries

**In one terminal:**
```bash
# Run the continuous load script
./continuous_indexer_load.sh
```

**In another terminal (after confirming queries are happening):**
```bash
# Watch indexer logs
tail -f /tmp/indexer-api-trace.log
```

**In a third terminal:**
```bash
# Stop MongoDB PRIMARY while queries are active
echo "Stopping MongoDB in 3 seconds..."
sleep 3
docker stop mongo1
```

#### 5. Check the Logs

**Check data-shard logs for the wrapped error:**
```bash
grep -i "HRPC_ERR.*Pool was force destroyed" /tmp/data-shard-proc-trace.log
```

**Check indexer logs for the original MongoDB error:**
```bash
grep -iE "pool.*destroyed|MongoError|topology.*destroyed" /tmp/indexer-api-trace.log
```

---

## Why This Works

1. **Continuous queries** - The loop ensures the indexer is constantly querying MongoDB
2. **Active connection** - The indexer has an active MongoDB connection with pending operations
3. **Forced shutdown** - `docker stop mongo1` triggers replica set failover
4. **Pool destruction** - MongoDB driver destroys the pool because the primary is gone
5. **Pending operations fail** - Any queries in the queue get rejected with "Pool was force destroyed"
6. **Error propagation** - The error is wrapped by `hp-svc-facs-net` and sent to data-shard

---

## Alternative: Use the Indexer's MongoDB Directly

Instead of stopping the data-shard's MongoDB, ensure you're stopping the **indexer's** MongoDB:

### Check Which MongoDB the Indexer Uses

```bash
# Check indexer's MongoDB config
cat wdk-indexer-wrk-evm/config/facs/db-mongo.config.json
```

Look for the `uri` field. It might be pointing to:
- Same replica set as data-shard
- Different database name on same replica set
- Completely different MongoDB instance

### If Using Same Replica Set (Different Database)

When you stop `mongo1`, **BOTH** the data-shard and indexer will fail. You'll see:

1. ✅ Data-shard's own MongoDB errors: `not master and slaveOk=false`
2. ✅ Indexer's MongoDB errors: `Pool was force destroyed` (wrapped as `[HRPC_ERR]=`)

**The key is:** Look for **BOTH** errors. The first one is expected noise, the second one is your target.

---

## Expected Output When Successfully Reproduced

### In Data-Shard Logs

```json
{
  "level": 50,
  "time": 1764279892700,
  "err": {
    "type": "Error",
    "message": "[HRPC_ERR]=Pool was force destroyed"
  },
  "msg": "ERR_WALLET_TRANSFER_RPC_FAIL"
}
```

**NOT this:**
```json
{
  "err": {
    "type": "MongoError",
    "message": "not master and slaveOk=false"
  }
}
```

### In Indexer Logs

```
MongoError: Pool was force destroyed
    at Connection.<anonymous> (.../mongodb/lib/core/connection/pool.js:453:61)
```

OR other MongoDB connection errors:
```
MongoNetworkError: connect ECONNREFUSED
topology was destroyed
```

---

## Quick Diagnostic

**Run this to see what errors you're currently getting:**

```bash
echo "=== Data-Shard Errors ==="
grep -i "error\|fail" /tmp/data-shard-proc-trace.log | tail -10

echo ""
echo "=== Looking for HRPC_ERR ==="
grep -i "HRPC_ERR" /tmp/data-shard-proc-trace.log | tail -10

echo ""
echo "=== Indexer Errors ==="
grep -i "error\|fail\|mongo" /tmp/indexer-api-trace.log | tail -10
```

---

## Summary: The Missing Ingredient

Your current reproduction attempts fail because:

❌ **You're not making RPC calls to the indexer when you stop MongoDB**  
❌ **No continuous query load on the indexer**  
❌ **No guarantee of timing - MongoDB stops but indexer isn't mid-query**

To fix this:

✅ **Create continuous RPC calls to the indexer** (via data-shard sync or direct API calls)  
✅ **Stop MongoDB WHILE queries are in flight**  
✅ **Monitor BOTH data-shard AND indexer logs**  
✅ **Look for the INDEXER's MongoDB error wrapped as [HRPC_ERR]= in data-shard logs**

---

## Final Note

If you **still** can't reproduce it locally, remember:

> **Production logs ARE the reproduction** - they show the exact error happening in real conditions.

You already have:
- ✅ Production error with full stack trace ([production_logs.log](file:///Users/alexa/Documents/repos/tether/_INDEXER/_docs/task_mongodb_pool_destoyed_issue/production_logs.log))
- ✅ Root cause identified (COMPREHENSIVE_ANALYSIS.md)
- ✅ Fix ready and tested (mongodb-retry-fix.patch)

Local reproduction is helpful for **validation**, but not strictly required when you have clear production evidence and identified root cause.
