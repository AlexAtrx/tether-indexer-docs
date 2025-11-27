# Trace Collection for Holepunch Team

This document explains how to collect comprehensive traces of the "Pool was force destroyed" error to share with the Holepunch team.

## What We've Added

**File: `rumble-data-shard-wrk/node_modules/hp-svc-facs-net/index.js`**

Added RPC tracing to the `jRequest` method (lines 78-105):
- Logs every RPC request initiation with target, method, poolLinger, and timeout
- Logs successful RPC completions with duration
- Logs failed RPC requests with full error details
- All logs are prefixed with `[RPC_TRACE]` for easy filtering

## Configuration

**Already configured:**
- `rumble-data-shard-wrk/config/facs/net.config.json` - poolLinger: 30s (reduced from 5min)

## Test Procedure

### 1. Restart All Workers with Trace Logging

**Terminal 3** - Data Shard Proc (this is where pool errors occur):
```bash
cd /Users/alexa/Documents/repos/tether/_INDEXER/rumble-data-shard-wrk
node worker.js --wtype wrk-data-shard-proc --env development --rack shard-1 2>&1 | tee /tmp/data-shard-proc-trace.log
```

**Terminal 4** - Data Shard API:
```bash
cd /Users/alexa/Documents/repos/tether/_INDEXER/rumble-data-shard-wrk
node worker.js --wtype wrk-data-shard-api --env development --rack shard-1-1 --proc-rpc <RPC_KEY_FROM_TERM3> 2>&1 | tee /tmp/data-shard-api-trace.log
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

**Terminal 1 & 2** - Indexers (start these first):
```bash
# Terminal 1
cd /Users/alexa/Documents/repos/tether/_INDEXER/wdk-indexer-wrk-evm
node worker.js --wtype wrk-erc20-indexer-proc --env development --rack xaut-proc --chain xaut-eth 2>&1 | tee /tmp/indexer-proc-trace.log

# Terminal 2 (wait for RPC key from Terminal 1)
cd /Users/alexa/Documents/repos/tether/_INDEXER/wdk-indexer-wrk-evm
node worker.js --wtype wrk-erc20-indexer-api --env development --rack xaut-api --chain xaut-eth --proc-rpc <RPC_KEY> 2>&1 | tee /tmp/indexer-api-trace.log
```

### 2. Run the Test

**Terminal 7**:
```bash
cd /Users/alexa/Documents/repos/tether/_INDEXER/_docs/task_hyperswarm_prod_issue
./test_pool_destruction_v2.sh
```

### 3. Wait and Observe

The test will:
1. Create a wallet (establishes RPC connections)
2. Wait 35 seconds for pools to expire
3. The next `syncWalletTransfersJob` (runs every 10s) should trigger pool destruction

**Watch Terminal 3** for logs containing:
- `[RPC_TRACE] Initiating RPC request...` - Shows when RPC starts
- `[RPC_TRACE] RPC request FAILED...` - Shows the failure with error details
- `[HRPC_ERR]=Pool was force destroyed` - The actual error

### 4. Collect the Traces

After the test completes, collect all log files:

```bash
# Create a trace bundle
mkdir -p /tmp/holepunch-traces
cp /tmp/*-trace.log /tmp/holepunch-traces/

# Add system info
echo "=== System Information ===" > /tmp/holepunch-traces/system-info.txt
echo "Date: $(date)" >> /tmp/holepunch-traces/system-info.txt
echo "Node version: $(node --version)" >> /tmp/holepunch-traces/system-info.txt
echo "OS: $(uname -a)" >> /tmp/holepunch-traces/system-info.txt
echo "" >> /tmp/holepunch-traces/system-info.txt
echo "=== NPM Package Versions ===" >> /tmp/holepunch-traces/system-info.txt
cd /Users/alexa/Documents/repos/tether/_INDEXER/rumble-data-shard-wrk
npm list @hyperswarm/rpc hyperdht hyperswarm --depth=0 >> /tmp/holepunch-traces/system-info.txt

# Create archive
cd /tmp
tar -czf holepunch-traces-$(date +%Y%m%d-%H%M%S).tar.gz holepunch-traces/

echo "Trace bundle created: /tmp/holepunch-traces-*.tar.gz"
```

## What to Look For in Traces

### Expected Trace Pattern for Pool Destruction:

```
[RPC_TRACE] Initiating RPC request to 1ab30ef0... method=queryTransfersByAddress, poolLinger=30000ms, timeout=30000ms
[RPC_TRACE] RPC request FAILED to 1ab30ef0..., method=queryTransfersByAddress, duration=123ms, error=[HRPC_ERR]=Pool was force destroyed
```

### Key Information to Share with Holepunch:

1. **Exact error message** from `[RPC_TRACE]` logs
2. **Stack trace** from the error object
3. **Timing information**: 
   - When was the last successful RPC call?
   - When did the pool get destroyed?
   - When did the failed request arrive?
4. **Pool configuration**: poolLinger, timeout values
5. **Package versions**: @hyperswarm/rpc, hyperdht, hyperswarm

## Minimal Reproduction Case for Holepunch

If they need a minimal reproduction, here's the essence:

```javascript
const RPC = require('@hyperswarm/rpc')

// Setup RPC with short poolLinger
const rpc = new RPC({ timeout: 10000, poolLinger: 30000 })

// Make initial request (establishes pool)
await rpc.request(serverKey, 'someMethod', data, opts)

// Wait for poolLinger + a few seconds
await new Promise(resolve => setTimeout(resolve, 35000))

// Make another request - this should hit dying pool
await rpc.request(serverKey, 'someMethod', data, opts)
// Error: Pool was force destroyed
```

## Additional Debug Info

If the error still doesn't reproduce, we can also add:

1. **Pool state monitoring** - patch @hyperswarm/rpc to log pool creation/destruction
2. **Connection monitoring** - log when connections are opened/closed
3. **DHT lookup monitoring** - log when peer discoveries happen

Let me know if you need any of these additional traces.
