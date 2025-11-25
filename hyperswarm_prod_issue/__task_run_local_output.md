# Step-by-Step Guide to Reproduce the Hyperswarm RPC Pool Timeout Issue Locally

## Context
According to the **DIAGNOSIS_REPORT.md**, the issue is:
- **NOT a MongoDB problem**
- **Root cause**: Hyperswarm RPC connection pool timeout race condition
- **Trigger**: When no RPC calls are made to a specific indexer for 5 minutes, the pool starts destruction, causing a race condition with new sync jobs

---

## Prerequisites

### 1. MongoDB Replica Set Setup

```bash
# Navigate to Docker network directory
cd /Users/alexa/Documents/repos/tether/_INDEXER_clean/_wdk_docker_network

# Start MongoDB replica set (3 nodes)
npm run start:db

# Wait ~30 seconds for containers to be healthy, then initialize replica set
npm run init:rs

# Verify MongoDB is running
mongosh "mongodb://mongo1:27017,mongo2:27017,mongo3:27017/?replicaSet=rs0" --quiet --eval "db.adminCommand('ping')"
# Expected: { ok: 1, ... }
```

### 2. Add Hostnames to /etc/hosts (if not already done)

```bash
# Check if hostnames exist
grep -E "mongo1|mongo2|mongo3" /etc/hosts

# If not present, add them (requires sudo):
# sudo nano /etc/hosts
# Add these lines:
# 127.0.0.1 mongo1
# 127.0.0.1 mongo2
# 127.0.0.1 mongo3
```

---

## Services to Run (Minimal Setup)

To reproduce the issue, you need:
1. **EVM Indexer** (Proc + API workers) - for XAUT token
2. **Data Shard** (Proc + API workers) - makes RPC calls to indexer
3. **Optionally**: Org Service + HTTP App Node for manual testing

---

## Step 1: Configure Hyperswarm Shared Secrets

**CRITICAL**: All services MUST use the **same** `topicConf.capability` and `topicConf.crypto.key`.

### Edit Common Config in Each Service

For each of these directories:
- `wdk-indexer-wrk-evm/`
- `wdk-data-shard-wrk/`
- `wdk-ork-wrk/` (if using)
- `wdk-indexer-app-node/` (if using)

Edit `config/common.json`:

```json
{
  "debug": 0,
  "dbEngine": "hyperdb",
  "topicConf": {
    "capability": "my-local-test-capability-secret",
    "crypto": {
      "algo": "hmac-sha384",
      "key": "my-local-test-encryption-key"
    }
  }
}
```

**Note**: Use simple values for local testing. In production, these would be cryptographically secure.

---

## Step 2: Configure MongoDB Connections

### EVM Indexer MongoDB Config

Edit `wdk-indexer-wrk-evm/config/facs/db-mongo.config.json`:

```json
{
  "dbMongo_m0": {
    "name": "db-mongo",
    "opts": {
      "mongoUrl": "mongodb://mongo1:27017,mongo2:27017,mongo3:27017/wdk_indexer_evm_local?replicaSet=rs0",
      "dedicatedDb": true,
      "txSupport": false,
      "maxPoolSize": 150,
      "socketTimeoutMS": 30000
    }
  }
}
```

### Data Shard MongoDB Config

Edit `wdk-data-shard-wrk/config/facs/db-mongo.config.json`:

```json
{
  "dbMongo_m0": {
    "name": "db-mongo",
    "opts": {
      "mongoUrl": "mongodb://mongo1:27017,mongo2:27017,mongo3:27017/wdk_data_shard_local?replicaSet=rs0",
      "dedicatedDb": true,
      "txSupport": false,
      "maxPoolSize": 150,
      "socketTimeoutMS": 30000
    }
  }
}
```

---

## Step 3: Configure RPC Provider for EVM

You need an Ethereum RPC endpoint. Options:
1. **Infura**: https://infura.io (free tier)
2. **Alchemy**: https://alchemy.com (free tier)
3. **Public endpoints**: Less reliable, rate-limited

Edit `wdk-indexer-wrk-evm/config/eth.json`:

```json
{
  "chain": "ethereum",
  "token": "eth",
  "decimals": 18,
  "mainRpc": {
    "rpcUrl": "https://mainnet.infura.io/v3/YOUR_INFURA_API_KEY"
  },
  "secondaryRpcs": [
    {"rpcUrl": "https://rpc.ankr.com/eth", "weight": 1},
    {"rpcUrl": "https://cloudflare-eth.com", "weight": 2}
  ],
  "txBatchSize": 20,
  "syncTx": "*/30 * * * * *"
}
```

### Configure XAUT Token (Critical for reproducing the exact production error)

Edit `wdk-indexer-wrk-evm/config/xaut-eth.json`:

```json
{
  "chain": "ethereum",
  "token": "xaut",
  "decimals": 6,
  "tokenType": "erc20",
  "contractAddress": "0x68749665FF8D2d112Fa859AA293F07A622782F38",
  "mainRpc": {
    "rpcUrl": "https://mainnet.infura.io/v3/YOUR_INFURA_API_KEY"
  },
  "secondaryRpcs": [
    {"rpcUrl": "https://rpc.ankr.com/eth", "weight": 1}
  ],
  "txBatchSize": 20,
  "syncTx": "*/30 * * * * *"
}
```

---

## Step 4: Start Services in Order

### Terminal 1: EVM Indexer Proc (ETH)

```bash
cd /Users/alexa/Documents/repos/tether/_INDEXER_clean/wdk-indexer-wrk-evm
npm install
node worker.js --wtype wrk-evm-indexer-proc --env development --rack eth-proc --chain eth
```

**⚠️ CRITICAL**: Look for this in the logs:
```
Proc RPC Key: <COPY_THIS_KEY>
```

### Terminal 2: EVM Indexer Proc (XAUT)

```bash
cd /Users/alexa/Documents/repos/tether/_INDEXER_clean/wdk-indexer-wrk-evm
node worker.js --wtype wrk-evm-indexer-proc --env development --rack xaut-proc --chain eth --ccy xaut
```

**⚠️ CRITICAL**: Copy the Proc RPC Key from logs.

### Terminal 3: EVM Indexer API (ETH)

```bash
cd /Users/alexa/Documents/repos/tether/_INDEXER_clean/wdk-indexer-wrk-evm
node worker.js --wtype wrk-evm-indexer-api --env development --rack eth-api --chain eth --proc-rpc <ETH_PROC_KEY>
```

### Terminal 4: EVM Indexer API (XAUT)

```bash
cd /Users/alexa/Documents/repos/tether/_INDEXER_clean/wdk-indexer-wrk-evm
node worker.js --wtype wrk-evm-indexer-api --env development --rack xaut-api --chain eth --ccy xaut --proc-rpc <XAUT_PROC_KEY>
```

### Terminal 5: Data Shard Proc

```bash
cd /Users/alexa/Documents/repos/tether/_INDEXER_clean/wdk-data-shard-wrk
npm install
node worker.js --wtype wrk-data-shard-proc --env development --rack shard-proc
```

**⚠️ CRITICAL**: Copy the Proc RPC Key.

### Terminal 6: Data Shard API

```bash
cd /Users/alexa/Documents/repos/tether/_INDEXER_clean/wdk-data-shard-wrk
node worker.js --wtype wrk-data-shard-api --env development --rack shard-api --proc-rpc <SHARD_PROC_KEY>
```

---

## Step 5: Reproduce the Issue

### Understanding the Race Condition

From the diagnosis:
- **poolLinger** default: **300 seconds (5 minutes)**
- If no RPC calls to a specific indexer for 5 minutes, pool destruction begins
- If a new sync job fires during destruction → **"Pool was force destroyed"** error

### Reproduction Strategy

**Option A: Wait 5+ Minutes (Natural Trigger)**

1. Let all services run normally
2. Wait for 5 minutes without any RPC calls to XAUT indexer
3. The `syncWalletTransfersJob` will run (check data-shard worker schedule)
4. Watch for errors in **Terminal 6** (Data Shard API logs)

**Expected Error**:
```
Error: [HRPC_ERR]=Pool was force destroyed
    at NetFacility.handleInputError (/...hp-svc-facs-net/index.js:58:11)
    at async BlockchainService.getTransfersForWalletsBatch (blockchain.svc.js:408:5)
    at async WrkDataShardProc._walletTransferBatch (proc.shard.data.wrk.js:471:57)
```

**Option B: Trigger Manually (Faster)**

To trigger faster, you need to:
1. **Add test wallets** to the data shard
2. **Force a sync job** to run

Check `wdk-data-shard-wrk/workers/proc.shard.data.wrk.js` for the job configuration (likely a cron expression like `*/5 * * * * *` for every 5 minutes).

---

## Step 6: Monitor and Confirm the Issue

### What to Watch For

1. **In Data Shard Proc logs (Terminal 5)**:
   - Look for `syncWalletTransfersJob` starting
   - Look for batch processing logs

2. **In Data Shard API logs (Terminal 6)**:
   - **Error signature**: `[HRPC_ERR]=Pool was force destroyed`
   - Stack trace pointing to `hp-svc-facs-net/index.js:58`

3. **In XAUT Indexer logs (Terminals 2 & 4)**:
   - Should show **healthy operation** (processing blocks normally)
   - **No errors** — confirms it's NOT an indexer issue

4. **MongoDB**:
   ```bash
   mongosh "mongodb://mongo1:27017/?replicaSet=rs0" --quiet --eval "db.serverStatus().connections"
   ```
   - Should show healthy connections, no rejections

---

## Step 7: Confirming the Root Cause

### Evidence Checklist

✅ **Error originates from Hyperswarm RPC layer** (`hp-svc-facs-net`), NOT MongoDB
✅ **Indexers are healthy** (no restarts, processing blocks successfully)
✅ **MongoDB is healthy** (connections active, no rejections)
✅ **Errors occur simultaneously** across multiple wallets (batch job pattern)
✅ **All errors for same chain:token** (ethereum:xaut)
✅ **Timing**: Errors occur ~5 minutes after last RPC call (poolLinger timeout)

---

## Step 8: Adjust Configuration to Validate Fix

### Test Fix 1: Increase `poolLinger`

Edit `wdk-data-shard-wrk/config/common.json`:

```json
{
  "debug": 0,
  "dbEngine": "hyperdb",
  "topicConf": {
    "capability": "my-local-test-capability-secret",
    "crypto": {
      "algo": "hmac-sha384",
      "key": "my-local-test-encryption-key"
    }
  },
  "netOpts": {
    "poolLinger": 600000,
    "timeout": 60000
  }
}
```

**Then update** `tether-wrk-base/workers/base.wrk.tether.js` to pass these options to the facility (check if already implemented).

**Expected Result**: Errors should occur less frequently (now 10 minutes instead of 5).

### Test Fix 2: Reduce Sync Interval (Make Issue More Frequent)

Edit `wdk-data-shard-wrk/workers/proc.shard.data.wrk.js` — find the cron schedule for `syncWalletTransfersJob` and change it to run more frequently (e.g., every 30 seconds).

**Expected Result**: If interval < 5 minutes, the pool should never timeout, and errors should stop.

---

## Troubleshooting

### Services Can't Find Each Other

**Symptom**: Services start but no RPC communication.

**Fix**:
1. Verify all `config/common.json` have **identical** `topicConf.capability` and `topicConf.crypto.key`
2. Check Hyperswarm logs for topic join confirmations

### MongoDB Connection Errors

**Symptom**: "MongoServerSelectionError".

**Fix**:
```bash
# Check containers
docker ps | grep mongo

# Restart if needed
cd /Users/alexa/Documents/repos/tether/_INDEXER_clean/_wdk_docker_network
npm run start:db
npm run init:rs
```

### No Wallets to Sync

**Symptom**: `syncWalletTransfersJob` doesn't fire because no wallets exist.

**Fix**: You'll need to add test wallets through the data shard API. Check `wdk-data-shard-wrk/workers/lib/` for wallet creation methods.

---

## Summary

**To reproduce the issue locally, you need**:

1. ✅ **MongoDB replica set** running (3 nodes)
2. ✅ **EVM Indexer** for XAUT token (Proc + API)
3. ✅ **Data Shard** (Proc + API) making RPC calls to indexer
4. ✅ **Wait 5+ minutes** without RPC activity
5. ✅ **Trigger sync job** (`syncWalletTransfersJob`)
6. ✅ **Watch for "Pool was force destroyed" error** in data-shard logs

**The error confirms**:
- Hyperswarm RPC pool timeout race condition
- NOT a MongoDB or indexer issue
- Fix: Add retry logic + increase `poolLinger` to 10+ minutes

---

## Team Lead's Question

From the Slack message:
> "From your message, if no RPC calls have been made to a specific indexer for 5 minutes, the pool starts destruction (timeout), we should be able to configure this to something more frequent, like every 5 seconds?"

**Answer**: Yes, you can configure `poolLinger` to a shorter duration (e.g., 5 seconds = 5000ms), but this would cause the opposite problem:
- Pools would be destroyed very quickly after inactivity
- More frequent reconnections would be needed
- Higher overhead from constant pool creation/destruction

**Recommended approach instead**:
1. **Increase `poolLinger`** to 10-15 minutes (600000-900000ms) to give more time between sync jobs
2. **Add retry logic** to RPC calls in `blockchain.svc.js` (as detailed in DIAGNOSIS_REPORT.md Fix #1)
3. **Use `Promise.allSettled`** instead of `Promise.all` for better error handling in batch operations

This way, even if a pool is being destroyed, the retry logic will handle it gracefully.
