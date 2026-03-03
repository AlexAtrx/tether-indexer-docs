# Next Steps to Capture Trace for Holepunch

## Summary

You've successfully set up the environment to reproduce the pool destruction error. Now we need to capture comprehensive traces to share with the Holepunch team.

## What We've Set Up

✅ Reduced pool timeout (30s instead of 5min) for faster testing
✅ Added RPC tracing to log every request/response/failure  
✅ Created test scripts to trigger the race condition
✅ Prepared documentation for Holepunch

## Step-by-Step Instructions

### 1. Restart Workers with Trace Logging

Stop all current workers and restart them with logging:

**Terminal 1** - Indexer Proc:
```bash
cd /Users/alexa/Documents/repos/tether/_INDEXER/wdk-indexer-wrk-evm
node worker.js --wtype wrk-erc20-indexer-proc --env development --rack xaut-proc --chain xaut-eth 2>&1 | tee /tmp/indexer-proc-trace.log
```

**Terminal 2** - Indexer API (use RPC key from Terminal 1):
```bash
cd /Users/alexa/Documents/repos/tether/_INDEXER/wdk-indexer-wrk-evm
node worker.js --wtype wrk-erc20-indexer-api --env development --rack xaut-api --chain xaut-eth --proc-rpc <KEY> 2>&1 | tee /tmp/indexer-api-trace.log
```

**Terminal 3** - Data Shard Proc (⚠️ THIS IS WHERE THE ERROR APPEARS):
```bash
cd /Users/alexa/Documents/repos/tether/_INDEXER/rumble-data-shard-wrk
node worker.js --wtype wrk-data-shard-proc --env development --rack shard-1 2>&1 | tee /tmp/data-shard-proc-trace.log
```

**Terminal 4** - Data Shard API (use RPC key from Terminal 3):
```bash
cd /Users/alexa/Documents/repos/tether/_INDEXER/rumble-data-shard-wrk
node worker.js --wtype wrk-data-shard-api --env development --rack shard-1-1 --proc-rpc <KEY> 2>&1 | tee /tmp/data-shard-api-trace.log
```

**Terminal 5** - Ork API:
```bash
cd /Users/alexa/Documents/repos/tether/_INDEXER/rumble-ork-wrk
node worker.js --wtype wrk-ork-api --env development --rack ork-1 2>&1 | tee /tmp/ork-api-trace.log
```

**Terminal 6** - App Node:
```bash
cd /Users/alexa/Documents/repos/tether/_INDEXER/rumble-app-node
node worker.js --wtype wrk-node-http --env development --port 3000 2>&1 | tee /tmp/app-node-trace.log
```

### 2. Run the Test

**Terminal 7**:
```bash
cd /Users/alexa/Documents/repos/tether/_INDEXER/_docs/task_hyperswarm_prod_issue
./test_pool_destruction_v2.sh
```

### 3. Watch Terminal 3 Carefully

Look for these log patterns:

**Before the error (normal operation):**
```json
{"msg":"[RPC_TRACE] Initiating RPC request to 1ab30ef0... method=queryTransfersByAddress..."}
{"msg":"[RPC_TRACE] RPC request successful to 1ab30ef0..., duration=50ms"}
```

**When the error occurs:**
```json
{"msg":"[RPC_TRACE] Initiating RPC request to 1ab30ef0... method=queryTransfersByAddress..."}
{"level":50,"msg":"[RPC_TRACE] RPC request FAILED to 1ab30ef0..., error=[HRPC_ERR]=Pool was force destroyed"}
```

### 4. If Error Doesn't Appear

The test might need adjustment. Try:

**Option A: Run test multiple times**
```bash
# Run the test 3 times in a row
for i in {1..3}; do
  echo "=== Test run $i ==="
  ./test_pool_destruction_v2.sh
  sleep 5
done
```

**Option B: Manually trigger sync**
```bash
# Create a wallet, then wait 40 seconds
# The sync job runs every 10 seconds, so it should trigger during the pool destruction window
curl --request POST \
  --url "http://127.0.0.1:3000/api/v1/wallets" \
  --header "authorization: Bearer test_auth-" \
  --header "content-type: application/json" \
  --data '[{"name":"test-wallet-'$(date +%s)'","type":"user","addresses":{"ethereum":"0x'$(openssl rand -hex 20)'"}}]'

# Wait 40 seconds
sleep 40

# The next sync job should hit the destroyed pool
```

### 5. Collect the Traces

Once you see the error in Terminal 3, collect everything:

```bash
# Create trace bundle
mkdir -p /tmp/holepunch-traces
cp /tmp/*-trace.log /tmp/holepunch-traces/

# Add system info
cat > /tmp/holepunch-traces/system-info.txt << 'SYSINFO'
=== System Information ===
Date: $(date)
Node version: $(node --version)
OS: $(uname -a)

=== NPM Package Versions ===
SYSINFO

cd /Users/alexa/Documents/repos/tether/_INDEXER/rumble-data-shard-wrk
npm list @hyperswarm/rpc hyperdht hyperswarm --depth=0 >> /tmp/holepunch-traces/system-info.txt

# Copy documentation
cp /Users/alexa/Documents/repos/tether/_INDEXER/_docs/task_hyperswarm_prod_issue/SUMMARY_FOR_HOLEPUNCH.md /tmp/holepunch-traces/
cp /Users/alexa/Documents/repos/tether/_INDEXER/_docs/task_hyperswarm_prod_issue/DIAGNOSIS_REPORT.md /tmp/holepunch-traces/

# Create archive
cd /tmp
tar -czf holepunch-traces-$(date +%Y%m%d-%H%M%S).tar.gz holepunch-traces/

echo "✅ Trace bundle created!"
ls -lh holepunch-traces-*.tar.gz
```

### 6. Extract Key Information

Look through the trace logs and extract:

```bash
# Find all RPC errors
grep -n "RPC_TRACE.*FAILED" /tmp/data-shard-proc-trace.log

# Find the timing of the error
grep -n "Pool was force destroyed" /tmp/data-shard-proc-trace.log

# Get context around the error (20 lines before and after)
grep -B 20 -A 20 "Pool was force destroyed" /tmp/data-shard-proc-trace.log
```

### 7. Share with Holepunch

Create a GitHub issue or discussion with:

**Title:** "Pool destruction race condition causing request failures"

**Body:**
- Attach the trace bundle (holepunch-traces-*.tar.gz)
- Link to SUMMARY_FOR_HOLEPUNCH.md
- Include the key error traces you extracted
- Mention you can provide more details or test patches

**Where to post:**
- https://github.com/holepunchto/hyperswarm/issues
- Or https://github.com/holepunchto/hyperdht/issues
- Or their Discord/community channel

## Alternative: If Error Still Doesn't Reproduce

If the error doesn't appear locally, you can:

1. **Test in a more production-like environment** with higher load
2. **Instrument the @hyperswarm/rpc library directly** to log pool lifecycle
3. **Share production traces** (if you have them) showing the error

Let me know if you need help with any of these approaches!

## Files Ready for Holepunch

All in `/Users/alexa/Documents/repos/tether/_INDEXER/_docs/task_hyperswarm_prod_issue/`:

- ✅ `SUMMARY_FOR_HOLEPUNCH.md` - Issue overview
- ✅ `DIAGNOSIS_REPORT.md` - Detailed investigation
- ✅ `TRACE_FOR_HOLEPUNCH.md` - How traces were collected
- ✅ `test_pool_destruction_v2.sh` - Reproduction script
- ✅ `POOL_DESTRUCTION_TEST_INSTRUCTIONS.md` - Setup guide

## Current Status

🟢 Environment configured
🟢 RPC tracing added
🟢 Test scripts ready
🟡 Waiting for error reproduction with full traces
⬜ Share with Holepunch team

Good luck! Let me know when you have traces to share or if you need any adjustments.
