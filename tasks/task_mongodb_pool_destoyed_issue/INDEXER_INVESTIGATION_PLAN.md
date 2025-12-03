# Indexer MongoDB Investigation Plan

## Objective
Determine if the "Pool was force destroyed" error originates from MongoDB operations in the indexer workers.

---

## Step 1: Understand Indexer Architecture

### Files to Review

1. **Indexer Entry Point**
   - `wdk-indexer-wrk-evm/worker.js` - Worker startup
   - Check what database connections are established

2. **RPC Handler Implementation**
   - Find where `queryTransfersByAddress` is implemented
   - Trace through to database queries
   - Verify if MongoDB is actually used for this query

3. **MongoDB Configuration**
   - `wdk-indexer-wrk-evm/config/facs/db-mongo.config.json`
   - Check pool settings, replica set connection string

### Questions to Answer

- [ ] Does the indexer query MongoDB for transfer lookups?
- [ ] Or does it use in-memory/cache structures?
- [ ] What MongoDB pool settings are configured?
- [ ] Is the connection string using replica set?

---

## Step 2: Check Indexer Error Handling

### Code Locations

```
wdk-indexer-wrk-evm/
├── workers/
│   ├── api.indexer.erc20.wrk.js    ← API worker (handles RPC)
│   └── proc.indexer.erc20.wrk.js   ← PROC worker (syncs blocks)
└── node_modules/
    └── @tetherto/
        └── wdk-indexer-wrk-base/   ← Base classes
```

### What to Look For

1. **RPC Response Method**
   ```javascript
   // How does indexer return errors?
   // Does it catch MongoDB errors and wrap them?
   respond(method, async (req) => {
     try {
       const result = await this.queryTransfersByAddress(req);
       return result;
     } catch (err) {
       return err.message;  // ← This gets wrapped by hp-svc-facs-net
     }
   });
   ```

2. **MongoDB Query Wrapping**
   - Are MongoDB operations wrapped in try/catch?
   - Are errors logged before being returned?
   - Is there any retry logic?

---

## Step 3: Add Diagnostic Logging

### Temporary Logging Additions

Add to indexer RPC handler:

```javascript
respond('queryTransfersByAddress', async (req) => {
  const startTime = Date.now();
  console.log(`[INDEXER_TRACE] queryTransfersByAddress START: ${JSON.stringify(req)}`);
  
  try {
    // Check MongoDB connection state
    const dbState = this.db.serverStatus?.connections || 'unknown';
    console.log(`[INDEXER_TRACE] MongoDB state: ${JSON.stringify(dbState)}`);
    
    const result = await this.actualQueryMethod(req);
    
    console.log(`[INDEXER_TRACE] queryTransfersByAddress SUCCESS: ${Date.now() - startTime}ms`);
    return result;
    
  } catch (err) {
    console.log(`[INDEXER_TRACE] queryTransfersByAddress ERROR: ${err.message}`);
    console.log(`[INDEXER_TRACE] Error stack: ${err.stack}`);
    
    // Log if it's a MongoDB error
    if (err.name === 'MongoError' || err.message.includes('Pool')) {
      console.log(`[INDEXER_TRACE] MONGODB ERROR DETECTED: ${JSON.stringify({
        name: err.name,
        message: err.message,
        code: err.code
      })}`);
    }
    
    throw err;  // Re-throw to let hp-svc-facs-net wrap it
  }
});
```

---

## Step 4: Local Reproduction Attempt

### Setup Requirements

1. **MongoDB Replica Set Locally**
   ```bash
   # Already have in _wdk_docker_network
   cd _wdk_docker_network
   npm run start:db
   npm run init:rs
   ```

2. **Start Indexer with Logging**
   ```bash
   cd wdk-indexer-wrk-evm
   node worker.js --wtype wrk-erc20-indexer-proc --chain xaut-eth
   # In another terminal:
   node worker.js --wtype wrk-erc20-indexer-api --chain xaut-eth --proc-rpc <KEY>
   ```

3. **Trigger Test**
   ```bash
   # Modified test that:
   # 1. Makes many concurrent RPC calls to indexer
   # 2. Triggers replica set failover (step down primary)
   # 3. Checks for the error
   ```

### Test Script: `test_indexer_mongodb_v2.sh`

```bash
#!/bin/bash

echo "=== Indexer MongoDB Pool Test v2 ==="

API_URL="http://127.0.0.1:3000"
AUTH_HEADER="authorization: Bearer test_auth-"

# Create wallet
TIMESTAMP=$(date +%s)
ADDR="0x$(od -An -N20 -tx1 /dev/urandom | tr -d ' \n')"
WALLET_NAME="idx-mongo-test-$TIMESTAMP"

curl -s --request POST \
  --url "$API_URL/api/v1/wallets" \
  --header "$AUTH_HEADER" \
  --header "content-type: application/json" \
  --data "[{
    \"name\": \"$WALLET_NAME\",
    \"type\": \"user\",
    \"enabled\": true,
    \"addresses\": { \"ethereum\": \"$ADDR\" }
  }]" > /dev/null

sleep 2

# Fire 50 concurrent requests to indexer via data-shard
echo "Firing 50 concurrent transfer queries..."
for i in {1..50}; do
  curl -s --request GET \
    --url "$API_URL/api/v1/wallets/transfers?limit=100" \
    --header "$AUTH_HEADER" > /dev/null 2>&1 &
done

# Give them a moment to start
sleep 0.5

# Trigger MongoDB replica set step-down (forces new primary election)
echo "Triggering MongoDB replica set failover..."
docker exec mongo1 mongo --eval 'rs.stepDown(60)' > /dev/null 2>&1

echo "Failover triggered - waiting for errors..."
sleep 5

echo "Check logs for 'Pool was force destroyed' in:"
echo "  - Terminal 2 (indexer-api)"
echo "  - Terminal 3 (data-shard-proc)"
```

---

## Step 5: Analyze Production Logs

### What to Request from Production Team

1. **Indexer logs** from `2025-11-21 11:14:00` to `11:14:05` UTC
   ```bash
   pm2 logs idx-xaut-eth-api-w-0-0 --lines 1000 | grep -E "11:14:0[0-5]"
   pm2 logs idx-xaut-eth-proc-w-0 --lines 1000 | grep -E "11:14:0[0-5]"
   ```

2. **MongoDB logs** from same time window
   ```bash
   docker logs mongo1 --since "2025-11-21T11:13:00" --until "2025-11-21T11:15:00"
   # Look for: primary election, connection dropped, pool events
   ```

3. **Network/system metrics**
   - Connection count to MongoDB
   - Replica set status changes
   - Any network partitioning events

### What We're Looking For

- [ ] MongoDB errors in indexer logs at 11:14:03
- [ ] "Pool was force destroyed" string in indexer logs
- [ ] Replica set failover events around 11:14:03
- [ ] Connection pool exhaustion warnings
- [ ] MongoDB primary step-down events

---

## Step 6: Implement Fix

### Based on Findings

**If MongoDB pool destruction confirmed:**

1. **Add retry logic in indexer**
   - Wrap MongoDB queries with exponential backoff
   - Catch pool destruction errors specifically
   - Log retries for monitoring

2. **Improve connection handling**
   - Increase pool size if exhaustion detected
   - Add connection event listeners
   - Implement circuit breaker for persistent failures

3. **Add defensive retry in data-shard**
   - Retry RPC calls on pool destruction errors
   - Prevents cascading failures

---

## Checklist

- [ ] Review indexer codebase for MongoDB usage
- [ ] Check indexer MongoDB configuration
- [ ] Add diagnostic logging to indexer
- [ ] Test with local replica set failover
- [ ] Request production indexer logs
- [ ] Request production MongoDB logs
- [ ] Correlate timestamps between all logs
- [ ] Identify root cause
- [ ] Implement fix
- [ ] Test fix in staging
- [ ] Deploy to production
- [ ] Monitor for recurrence

---

## Current Blockers

1. **Need indexer source code access** - To confirm MongoDB usage
2. **Need production logs** - To confirm timing and correlation
3. **Local reproduction unsuccessful** - May need production-scale concurrency

---

**Status:** Ready to begin Step 1  
**Owner:** Engineering Team  
**Target:** Identify root cause within 1 week
