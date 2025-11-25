# Restart Services to Reproduce Hyperswarm Pool Timeout Issue

## Configuration Changes Applied

✅ **rumble-data-shard-wrk/config/common.json**:
- `poolLinger`: 30000ms (30 seconds) - pool destroys after 30s inactivity
- `syncWalletTransfers`: "*/10 * * * * *" - runs every 10 seconds
- Added `"xaut"` to ethereum ccys

## Required Services

You need to run **XAUT indexer** (not USDT) to reproduce the exact production issue.

---

## Step 1: Stop All Current Services

Stop all terminals running workers (Ctrl+C in each).

---

## Step 2: Start XAUT Indexer

### Terminal 1: XAUT Indexer Proc (Writer)

```bash
cd /Users/alexa/Documents/repos/tether/_INDEXER_clean/wdk-indexer-wrk-evm
node worker.js --wtype wrk-evm-indexer-proc --env development --rack xaut-proc --chain eth --ccy xaut
```

**⚠️ COPY THE PROC RPC KEY FROM LOGS!**

### Terminal 2: XAUT Indexer API (Reader)

```bash
cd /Users/alexa/Documents/repos/tether/_INDEXER_clean/wdk-indexer-wrk-evm
node worker.js --wtype wrk-evm-indexer-api --env development --rack xaut-api --chain eth --ccy xaut --proc-rpc <XAUT_PROC_RPC_KEY>
```

---

## Step 3: Start Data Shard (with new config)

### Terminal 3: Rumble Data Shard Proc (Writer)

```bash
cd /Users/alexa/Documents/repos/tether/_INDEXER_clean/rumble-data-shard-wrk
node worker.js --wtype wrk-data-shard-proc --env development --rack shard-1
```

**⚠️ COPY THE PROC RPC KEY FROM LOGS!**

Look for logs indicating the sync job schedule:
- Should show: `syncWalletTransfers schedule: */10 * * * * *`

### Terminal 4: Rumble Data Shard API (Reader)

```bash
cd /Users/alexa/Documents/repos/tether/_INDEXER_clean/rumble-data-shard-wrk
node worker.js --wtype wrk-data-shard-api --env development --rack shard-1-1 --proc-rpc <DATA_SHARD_PROC_RPC_KEY>
```

---

## Step 4: Start Org Service

### Terminal 5: Rumble Org Service

```bash
cd /Users/alexa/Documents/repos/tether/_INDEXER_clean/rumble-ork-wrk
node worker.js --wtype wrk-ork-api --env development --rack ork-1
```

---

## Step 5: Start HTTP App Node

### Terminal 6: Rumble App Node

```bash
cd /Users/alexa/Documents/repos/tether/_INDEXER_clean/rumble-app-node
node worker.js --wtype wrk-node-http --env development --port 3000
```

---

## Step 6: Run the Test

Once all services are running:

```bash
cd /Users/alexa/Documents/repos/tether/_INDEXER_clean/_docs/hyperswarm_prod_issue
./test_pool_timeout.sh
```

---

## What to Watch For

### In Terminal 3 (Data Shard Proc):

**Every 10 seconds, you should see:**
```
started syncing wallet transfers for wallets <wallet-id>, 2025-11-24T...
```

**After ~30 seconds, you should see THE ERROR:**
```
[HRPC_ERR]=Pool was force destroyed
ERR_WALLET_TRANSFER_RPC_FAIL: ethereum:xaut:<address>:<timestamp>
```

### In Terminals 1 & 2 (XAUT Indexer):

**Should show HEALTHY operation:**
- Processing blocks normally
- No errors
- This confirms it's NOT an indexer issue

---

## Timeline Explanation

```
0:00 - Wallet created, XAUT indexer pool is fresh
0:10 - First sync job → ✓ SUCCESS (pool active)
0:20 - Second sync job → ✓ SUCCESS (pool active)
0:30 - Pool destruction begins (30s poolLinger timeout)
0:30 - Third sync job → ❌ ERROR: "Pool was force destroyed"
```

The race condition occurs when the sync job tries to use the RPC pool **exactly when it's being destroyed**.

---

## Troubleshooting

### "Still no error after 60 seconds"

**Check these:**

1. **Is XAUT indexer running?**
   ```bash
   # Should show both xaut-proc and xaut-api
   ps aux | grep "xaut"
   ```

2. **Did data-shard pick up new config?**
   - Check Terminal 3 logs for: `syncWalletTransfers schedule: */10 * * * * *`
   - If not, restart data-shard-proc

3. **Is the wallet created?**
   ```bash
   curl -s http://127.0.0.1:3000/api/v1/wallets \
     -H "authorization: Bearer test_auth-" | jq '.[] | select(.name=="test-xaut-pool-timeout")'
   ```

4. **Are sync jobs running?**
   - Watch Terminal 3 for "started syncing wallet transfers" logs every 10s
   - If not appearing, the job might not be scheduled

### "Error appears but for USDT, not XAUT"

This means:
- You're still running USDT indexer instead of XAUT
- Stop the USDT indexer and start XAUT indexer (see Step 2 above)

---

## Quick Summary

**Stop**: All current services
**Start**: XAUT indexer (not USDT) + data-shard + org + app-node
**Run**: `./test_pool_timeout.sh`
**Watch**: Terminal 3 (data-shard-proc) for error at ~30 seconds

---

## After Reproducing

Once you see the error, you've confirmed:
✅ Hyperswarm RPC pool timeout race condition
✅ NOT a MongoDB issue
✅ NOT an indexer issue
✅ Fix needed: Retry logic + increase poolLinger in production
