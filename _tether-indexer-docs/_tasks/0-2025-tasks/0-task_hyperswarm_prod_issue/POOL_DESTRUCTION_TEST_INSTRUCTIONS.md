# Pool Destruction Error - Test Instructions

This guide will help you reproduce the "Pool was force destroyed" error locally and verify the fixes.

## What This Test Does

Simulates the production issue where:
1. An RPC connection pool is established between data-shard and indexer
2. The pool sits idle for more than `poolLinger` time (30 seconds in test, 5 minutes in prod)
3. The pool is destroyed due to inactivity
4. New requests arrive while the pool is being destroyed
5. Requests fail with `[HRPC_ERR]=Pool was force destroyed`

## Configuration Changes

**File: `rumble-data-shard-wrk/config/facs/net.config.json`** (ALREADY CREATED)
```json
{
  "r0": {
    "poolLinger": 30000,
    "timeout": 10000
  }
}
```

This reduces pool timeout from 5 minutes to 30 seconds for faster testing.

## Test Procedure

### Step 1: Stop All Workers

Kill all running workers (Terminals 1-6)

### Step 2: Restart Workers in Order

**Terminal 1** - EVM Indexer Proc:
```bash
cd /Users/alexa/Documents/repos/tether/_INDEXER/wdk-indexer-wrk-evm
node worker.js --wtype wrk-erc20-indexer-proc --env development --rack xaut-proc --chain xaut-eth
```

**Terminal 2** - EVM Indexer API (wait for RPC key from Terminal 1):
```bash
cd /Users/alexa/Documents/repos/tether/_INDEXER/wdk-indexer-wrk-evm
node worker.js --wtype wrk-erc20-indexer-api --env development --rack xaut-api --chain xaut-eth --proc-rpc <XAUT_PROC_RPC_KEY>
```

**Terminal 3** - Data Shard Proc:
```bash
cd /Users/alexa/Documents/repos/tether/_INDEXER/rumble-data-shard-wrk
node worker.js --wtype wrk-data-shard-proc --env development --rack shard-1
```

**Terminal 4** - Data Shard API (wait for RPC key from Terminal 3):
```bash
cd /Users/alexa/Documents/repos/tether/_INDEXER/rumble-data-shard-wrk
node worker.js --wtype wrk-data-shard-api --env development --rack shard-1-1 --proc-rpc <DATA_SHARD_PROC_RPC_KEY>
```

**Terminal 5** - Ork API:
```bash
cd /Users/alexa/Documents/repos/tether/_INDEXER/rumble-ork-wrk
node worker.js --wtype wrk-ork-api --env development --rack ork-1
```

**Terminal 6** - App Node:
```bash
cd /Users/alexa/Documents/repos/tether/_INDEXER/rumble-app-node
node worker.js --wtype wrk-node-http --env development --port 3000
```

### Step 3: Run the Test Script

**Terminal 7** - Run the test:
```bash
cd /Users/alexa/Documents/repos/tether/_INDEXER/_docs/task_hyperswarm_prod_issue
./test_pool_destruction.sh
```

## What to Watch For

### Terminal 3 (Data Shard Proc) - Expected Errors:

Look for logs like:
```
{"level":50,"time":...,"msg":"[HRPC_ERR]=Pool was force destroyed"}
```

OR if the pool is on the indexer side:
```
Error: Pool was force destroyed
    at ...blockchain.svc.js:408
```

### Terminal 4 (Data Shard API) - Expected Behavior:

Should show RPC calls being made after the idle period.

### Terminal 5 (Ork API) - Expected Behavior:

Should continue working, routing requests to the data shard.

### Terminal 6 (App Node) - Expected Behavior:

- Initial request: 200 OK
- After 35s wait: May see 500 errors if pool destroyed
- With retry fix: Should eventually return 200 OK after retry

## Understanding the Results

### Without Retry Fix
You'll see:
- 500 Internal Server Error responses
- Error logs with "Pool was force destroyed"
- Failed wallet creation requests

### With Retry Fix (Recommended from diagnosis report)
You should see:
- Initial failures logged
- Automatic retries
- Eventually successful 200 OK responses
- Graceful handling of transient failures

## Verifying the Fix

If you want to test the retry logic fix, you need to:

1. Apply the retry fix from the diagnosis report to `wdk-data-shard-wrk/workers/lib/blockchain.svc.js`
2. Restart Terminal 3 (data-shard-proc)
3. Run the test again
4. Requests should succeed after automatic retries

## Cleanup

After testing, you may want to:

1. Remove the test config:
   ```bash
   rm /Users/alexa/Documents/repos/tether/_INDEXER/rumble-data-shard-wrk/config/facs/net.config.json
   ```

2. Or change it back to production values:
   ```json
   {
     "r0": {
       "poolLinger": 600000,
       "timeout": 60000
     }
   }
   ```

## Troubleshooting

**"No errors appear"**
- Increase wait time in the script (35s → 45s)
- Check that net.config.json is being loaded
- Verify poolLinger is actually 30000ms

**"Workers crash"**
- Make sure the hyperswarm error handling fixes are applied
- Check that try-catch is in data.shard.util.js

**"Connection errors but not pool destruction"**
- Different error - likely network/discovery issue
- Try restarting workers in order with delays
