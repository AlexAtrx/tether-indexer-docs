# Why the Test Is NOT Triggering RPC Calls

**Date:** November 27, 2025  
**Problem:** The pool destruction test runs, creates wallets, and the sync job executes - but **NO RPC calls are being made to the indexer**, so the "Pool was force destroyed" error never occurs.

---

## Evidence from Your Logs

Looking at the Terminal 3 logs you provided in `__task_debug_test_gem.sh`:

```json
{"msg":"started syncing wallet transfers for wallets 8749b653-0550-49e4-a21c-e048c140f595, 2025-11-27T14:56:10.004Z"}
{"msg":"finished syncing wallet transfers for wallets 8749b653-0550-49e4-a21c-e048c140f595, total: 0, 2025-11-27T14:56:10.018Z"}
```

**Key observations:**
1. ✅ The sync job IS running every 10 seconds
2. ✅ The wallet is being processed
3. ❌ **NO `[RPC_TRACE]` logs appear** - meaning no RPC calls are being made
4. ❌ The `total: 0` indicates no transfers were fetched (because no RPC call happened)

---

## Root Cause Analysis

### The Sync Job Flow

The `syncWalletTransfersJob` in the base class `@tetherto/wdk-data-shard-wrk` works like this:

1. **Get all enabled wallets** from the database
2. **For each wallet**, extract its blockchain addresses
3. **For each address**, call `blockchainSvc.getTransfersByAddress(blockchain, token, address)`
4. **The `blockchainSvc`** makes an RPC call through Hyperswarm to the appropriate indexer

### Why NO RPC Calls Are Being Made

There are several possible reasons:

#### 1. **No Blockchain Addresses Are Being Synced** (Most Likely)
   - Your test wallet has `"ethereum": "0x..."` address
   - But the sync job might only be configured to sync specific blockchain/token combinations
   - Check the `BLOCKCHAIN_CONFIG` or similar configuration that defines which blockchains to index

#### 2. **Wallet Doesn't Have Funded Addresses**
   - Some implementations skip empty wallets that have never had activity
   - Your randomly generated Ethereum address `0x$(openssl rand -hex 20)` is completely new and empty

#### 3. **Chain/Token Not Indexed**
   - The data shard might be configured to only sync specific chains
   - If you only started the **XAUT-ETH** indexer, it might only sync XAUT (Tether Gold) tokens, not regular ETH addresses

#### 4. **Indexer Not in Service Registry**
   - The blockchain service needs to know which indexer to call for which chain
   - If the indexer isn't properly registered, the RPC call is skipped silently

---

## How to Diagnose

### Step 1: Check What Chains Are Being Synced

Look at the blockchain service configuration or code to see what chains/tokens it iterates over during sync.

**Expected location:** 
- `rumble-data-shard-wrk/workers/lib/blockchain.svc.js`
- Or in the base class `@tetherto/wdk-data-shard-wrk/workers/lib/blockchain.svc.js`

**Look for:**
```javascript
const BLOCKCHAIN_CONFIG = {
  ethereum: ['usdt', 'usdc', ...],
  tron: ['usdt', 'usdc', ...],
  // ...
}
```

Or similar configuration that defines which blockchain/token combinations to fetch.

### Step 2: Enable Debug Logging

Add more verbose logging to see what's happening inside `syncWalletTransfersJob`:

```bash
# Check if there's a log level config
grep -r "LOG_LEVEL\|logLevel" rumble-data-shard-wrk/config/
```

### Step 3: Check Indexer Connection

Verify the indexer is actually discoverable:

```bash
# In your Terminal 2 (indexer-api) logs, look for:
# "Listening on public key: <KEY>"
# "RPC server started"
```

Then check if the data shard can find it:

```bash
# In Terminal 3 (data-shard-proc) logs, look for:
# "Connected to indexer" or similar
```

---

## The Fix: Use a Wallet with XAUT Address

Based on your setup (XAUT-ETH indexer running), you need to create a wallet with a **XAUT token address**, not just a regular Ethereum address.

### Why?

- Your indexer is `wrk-erc20-indexer-proc --chain xaut-eth`
- This is specifically for **XAUT (Tether Gold) on Ethereum**
- It won't index regular ETH addresses

### Updated Test Strategy

You have two options:

#### Option A: Create Wallet with XAUT Address (Aligned with Current Indexer)

Modify `test_pool_destruction_v4.sh` to create a wallet that the XAUT indexer will actually index:

```bash
# Instead of just ethereum address
"addresses": {
  "ethereum": "$RANDOM_ADDR"  # This won't be picked up by XAUT indexer
}

# Use this:
"addresses": {
  "xaut-eth": "$RANDOM_ADDR"  # This WILL be picked up
}
```

**But wait** - you also need to check if the blockchain service actually supports `xaut-eth` as a blockchain type.

#### Option B: Start a Regular ETH Indexer (More Reliable)

Instead of only running the XAUT indexer, also start a regular Ethereum indexer:

```bash
# Terminal 1 - Regular ETH Indexer Proc
cd /Users/alexa/Documents/repos/tether/_INDEXER/wdk-indexer-wrk-evm
node worker.js --wtype wrk-evm-indexer-proc --chain eth --env development --rack eth-proc

# Terminal 2 - Regular ETH Indexer API (use proc key from Terminal 1)
node worker.js --wtype wrk-evm-indexer-api --chain eth --env development --rack eth-api --proc-rpc <ETH_KEY>
```

Then your test wallet with `"ethereum": "0x..."` will actually get indexed.

---

## Improved Test Script

I'll create an improved test script that:
1. ✅ Checks which indexers are running
2. ✅ Creates wallets appropriate for those indexers
3. ✅ Monitors for `[RPC_TRACE]` logs to confirm RPC calls are happening
4. ✅ Provides clear diagnostic output

See: `test_pool_destruction_v5.sh`

---

## Quick Validation Test

Before running the full pool destruction test, validate that RPC calls are working:

```bash
# 1. Create a simple enabled wallet
curl --request POST \
  --url "http://127.0.0.1:3000/api/v1/wallets" \
  --header "authorization: Bearer test_auth-" \
  --header "content-type: application/json" \
  --data '[{
    "name": "quick-test",
    "type": "user",
    "enabled": true,
    "addresses": {
      "ethereum": "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb"
    }
  }]'

# 2. Wait 15 seconds for next sync job

# 3. Check Terminal 3 for [RPC_TRACE] logs
# You should see:
#   [RPC_TRACE] Initiating RPC request to...
#   [RPC_TRACE] RPC request successful to...

# If you see these, RPC is working and the pool test should work
# If you DON'T see these, the blockchain/token combination isn't being indexed
```

---

## Summary

**The core issue:** Your test wallet addresses aren't being synced because:
- The XAUT indexer only processes XAUT tokens
- Your wallet only has a generic `ethereum` address
- The blockchain service skips addresses it doesn't have an indexer for

**The solution:** Either:
1. Create wallets with addresses that match your running indexers (XAUT)
2. Start indexers that match your wallet addresses (regular ETH)

**Next steps:**
1. Run the quick validation test above
2. Check Terminal 3 for `[RPC_TRACE]` logs
3. If no RPC traces appear, we know the blockchain/token mismatch is the issue
4. Start appropriate indexers or adjust wallet creation accordingly
