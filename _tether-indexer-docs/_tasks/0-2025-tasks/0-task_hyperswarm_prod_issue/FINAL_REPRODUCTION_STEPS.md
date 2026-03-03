# Final Reproduction Steps - [HRPC_ERR]=Pool was force destroyed

## Configuration Summary

✅ **Config updated**: `rumble-data-shard-wrk/config/common.json`
- `poolLinger`: 30000ms (30 seconds)
- `syncWalletTransfers`: Every 10 seconds
- `blockchains.ethereum.ccys`: ["usdt", "xaut"]

✅ **Code updated**: `tether-wrk-base` in node_modules now passes `poolLinger` and `timeout` to `hp-svc-facs-net`

---

## Services to Run

### Terminal 1: XAUT Indexer Proc (NOT USDT!)

```bash
cd /Users/alexa/Documents/repos/tether/_INDEXER_clean/wdk-indexer-wrk-evm
node worker.js --wtype wrk-evm-indexer-proc --env development --rack xaut-proc --chain eth --ccy xaut
```

**⚠️ CRITICAL**: Copy the Proc RPC Key from the logs!

Look for:
```
wrk-evm-indexer-proc-xaut-proc rpc public key: <COPY_THIS_KEY>
```

---

### Terminal 2: XAUT Indexer API

```bash
cd /Users/alexa/Documents/repos/tether/_INDEXER_clean/wdk-indexer-wrk-evm
node worker.js --wtype wrk-evm-indexer-api --env development --rack xaut-api --chain eth --ccy xaut --proc-rpc <XAUT_PROC_RPC_KEY>
```

Replace `<XAUT_PROC_RPC_KEY>` with the key from Terminal 1.

---

### Terminal 3: Rumble Data Shard Proc

```bash
cd /Users/alexa/Documents/repos/tether/_INDEXER_clean/rumble-data-shard-wrk
node worker.js --wtype wrk-data-shard-proc --env development --rack shard-1
```

**⚠️ CRITICAL**: Copy the Proc RPC Key from the logs!

---

### Terminal 4: Rumble Data Shard API

```bash
cd /Users/alexa/Documents/repos/tether/_INDEXER_clean/rumble-data-shard-wrk
node worker.js --wtype wrk-data-shard-api --env development --rack shard-1-1 --proc-rpc <DATA_SHARD_PROC_RPC_KEY>
```

Replace `<DATA_SHARD_PROC_RPC_KEY>` with the key from Terminal 3.

---

### Terminal 5: Rumble Org Service

```bash
cd /Users/alexa/Documents/repos/tether/_INDEXER_clean/rumble-ork-wrk
node worker.js --wtype wrk-ork-api --env development --rack ork-1
```

---

### Terminal 6: Rumble App Node

```bash
cd /Users/alexa/Documents/repos/tether/_INDEXER_clean/rumble-app-node
node worker.js --wtype wrk-node-http --env development --port 3000
```

---

## Run the Test

Once all services are running:

```bash
cd /Users/alexa/Documents/repos/tether/_INDEXER_clean/_docs/hyperswarm_prod_issue
./test_pool_timeout.sh
```

This script will:
1. Create a test wallet with XAUT address
2. Monitor for 60 seconds
3. Tell you when to expect the error

---

## Expected Timeline

```
0s   - Test script creates XAUT wallet
0s   - First sync job (pool created and used for XAUT)
10s  - Second sync job (pool still active)
20s  - Third sync job (pool still active)
30s  - Pool destruction STARTS (30s poolLinger timeout)
30s  - Fourth sync job fires → tries to use dying pool
     → ERROR: [HRPC_ERR]=Pool was force destroyed
```

---

## What to Watch For

### In Terminal 3 (rumble-data-shard-wrk proc):

**Every 10 seconds, you should see:**
```
started syncing wallet transfers for wallets <wallet-id>, 2025-11-24T...
```

**At ~30-40 seconds, THE ERROR:**
```json
{
  "level": 40,
  "err": {
    "message": "[HRPC_ERR]=Pool was force destroyed"
  },
  "msg": "ERR_WALLET_TRANSFER_RPC_FAIL: ethereum:xaut:0x68749665ff8d2d112fa859aa293f07a622782f38:1"
}
```

---

## Why This Setup Works

1. **poolLinger = 30s**: Pool destruction starts at 30s of inactivity
2. **sync every 10s**: Ensures pool is used initially, then goes idle
3. **XAUT indexer**: Test script creates XAUT wallet, so sync job queries XAUT
4. **Timing alignment**: Pool destruction at 30s, sync job at 30s → race condition!

---

## Key Differences from Failed Attempts

| Previous Attempts | This Setup |
|-------------------|------------|
| poolLinger: 5s | poolLinger: 30s ✅ |
| USDT indexer running | XAUT indexer running ✅ |
| Config not wired to net facility | Config now passed through ✅ |
| Pool destroyed and recreated cleanly | Pool caught mid-destruction ✅ |

---

## Verification Checklist

Before running the test, verify:

- [ ] XAUT indexer proc running (Terminal 1)
- [ ] XAUT indexer api running (Terminal 2)
- [ ] Data shard proc running (Terminal 3)
- [ ] Data shard api running (Terminal 4)
- [ ] Org service running (Terminal 5)
- [ ] HTTP app node running (Terminal 6)
- [ ] Config has `poolLinger: 30000`
- [ ] Config has `"xaut"` in ethereum ccys
- [ ] All workers restarted after config changes

---

## If You Still Don't See the Error

1. **Check config is loaded**: Look for startup logs showing the pool linger value
2. **Run check script**: `./check_setup.sh` to verify all settings
3. **Check timing**: The error happens in a narrow window at ~30s
4. **Try multiple times**: Run the test 2-3 times, timing can vary slightly
5. **Increase logging**: Add debug logs in `hp-svc-facs-net` if needed

---

## Success Criteria

✅ You see: `[HRPC_ERR]=Pool was force destroyed`
✅ In Terminal 3 (data-shard-proc)
✅ Around 30-40 seconds after startup
✅ For `ethereum:xaut` chain/token

**This confirms the exact production issue!**
