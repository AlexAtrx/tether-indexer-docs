# Quick Start: Reproducing the Pool Destruction Error

**Problem:** Your test v4 is correct, but the "Pool was force destroyed" error is a **timing race condition** that's hard to trigger.

---

## What I Found

### ✅ Good News
- Your test setup is correct
- RPC calls **ARE being made** (`ethereum:xaut` combination)
- The blockchain service is syncing your wallet addresses
- The pool mechanism is working as designed

### ⚠️ The Issue
- The error is a **race condition** - happens only when:
  1. Pool is established (first RPC call)
  2. No RPC calls for exactly `poolLinger` milliseconds (5 seconds in your config)
  3. Pool gets destroyed
  4. New RPC call attempts to use destroyed pool → **ERROR**

- With `poolLinger: 5000ms` and sync every 10 seconds, the window is tiny
- You need to run the test **many times** to hit it

---

## Quick Action: Run Test 20 Times

```bash
cd /Users/alexa/Documents/repos/tether/_INDEXER/_docs/task_hyperswarm_prod_issue

# Run test 20 times and save output
for i in {1..20}; do
  echo "=== Test run $i/20 ==="
  ./cleanup_mongo_test_wallets.sh
  ./test_pool_destruction_v4.sh  # or v5
  sleep 2
done 2>&1 | tee full-test-run.log

# Check if error appeared in Terminal 3
grep "Pool was force destroyed" /tmp/data-shard-proc-trace.log
```

---

## Before Running: Verify RPC Calls Are Working

**Quick 30-second test:**

```bash
# 1. Create a test wallet
curl --request POST \
  --url "http://127.0.0.1:3000/api/v1/wallets" \
  --header "authorization: Bearer test_auth-" \
  --header "content-type: application/json" \
  --data '[{
    "name": "quick-rpc-test",
    "type": "user",
    "enabled": true,
    "addresses": {
      "ethereum": "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb"
    }
  }]'

# 2. Wait 15 seconds for next sync job
sleep 15

# 3. Check Terminal 3 logs for:
#    ✅ "txFetch:start ethereum:xaut"
#    ✅ "[RPC_TRACE] Initiating RPC request"
#    ✅ "queryTransfersByAddress"

# If you see these, RPC is working! Proceed to run test 20 times.
# If you DON'T see these, check if services are running properly.
```

---

## Services Must Be Running

Before testing, ensure all services are started:

**Terminal 1** - XAUT Indexer Proc:
```bash
cd wdk-indexer-wrk-evm
node worker.js --wtype wrk-erc20-indexer-proc --env development --rack xaut-proc --chain xaut-eth
```

**Terminal 2** - XAUT Indexer API (use key from Terminal 1):
```bash
cd wdk-indexer-wrk-evm
node worker.js --wtype wrk-erc20-indexer-api --env development --rack xaut-api --chain xaut-eth --proc-rpc <KEY>
```

**Terminal 3** - Data Shard Proc (WATCH THIS ONE):
```bash
cd rumble-data-shard-wrk
node worker.js --wtype wrk-data-shard-proc --env development --rack shard-1 2>&1 | tee /tmp/data-shard-proc-trace.log
```

**Terminal 4** - Data Shard API (use key from Terminal 3):
```bash
cd rumble-data-shard-wrk
node worker.js --wtype wrk-data-shard-api --env development --rack shard-1-1 --proc-rpc <KEY>
```

**Terminal 5** - Ork API:
```bash
cd rumble-ork-wrk
node worker.js --wtype wrk-ork-api --env development --rack ork-1
```

**Terminal 6** - App Node:
```bash
cd rumble-app-node  
node worker.js --wtype wrk-node-http --env development --port 3000
```

---

## What to Look For in Terminal 3

### ✅ Normal Operation (Pool Working)
```json
{"msg":"[RPC_TRACE] Initiating RPC request to 1ab30ef0... method=queryTransfersByAddress, poolLinger=5000ms"}
{"msg":"[RPC_TRACE] RPC request successful to 1ab30ef0..., duration=75ms"}
```

### 🎯 Target Error (What We're Trying to Reproduce)
```json
{"msg":"[RPC_TRACE] Initiating RPC request to 1ab30ef0..."}
{"level":50,"msg":"[HRPC_ERR]=Pool was force destroyed"}
```

---

## If Error Still Doesn't Appear After 20 Runs

Try these adjustments:

### Option A: Increase poolLinger for Wider Window

Edit `rumble-data-shard-wrk/config/facs/net.config.json`:

```json
{
  "r0": {
    "poolLinger": 30000,  // Changed from 5000 to 30000 (30 seconds)
    "timeout": 10000
  }
}
```

Then in test, wait 40 seconds instead of 10 for pool to timeout.

### Option B: Decrease Sync Frequency

Edit `rumble-data-shard-wrk/config/common.json`:

```json
"wrk": {
  "syncWalletTransfers": "0 */1 * * * *"  // Changed to every 1 minute
}
```

Now you have a 5-second window every minute where pool can timeout.

---

## Files Created

1. **ROOT_CAUSE_FINAL.md** - Complete analysis of why RPC calls ARE being made
2. **DIAGNOSIS_WHY_NO_RPC.md** - Technical details about sync mechanism  
3. **test_pool_destruction_v5.sh** - Improved test with better diagnostics
4. **QUICK_START.md** (this file) - Quick instructions to reproduce error

---

## Need Help?

### Problem: No RPC_TRACE logs appear
**Solution:** RPC tracing might not be enabled. Check `hp-svc-facs-net` configuration or look for lower-level logs like `"txFetch:start"`.

### Problem: Services won't start  
**Solution:** Check MongoDB is running and all proc workers started before api workers.

### Problem: Wallet already exists error
**Solution:** Run `./cleanup_mongo_test_wallets.sh` before each test.

### Problem: Error never appears after 20+ runs
**Solution:** This is a very narrow race condition. Try Option A or B above to widen the window.

---

**Bottom line:** Run the test 20 times. The race condition WILL eventually trigger!
