# EVM Indexer Local Quick Start

- **Prereqs:** Mongo replica set running with `mongo1/2/3` in `/etc/hosts`; Docker containers up. Verify: `mongosh "mongodb://mongo1:27017,mongo2:27017,mongo3:27017/?replicaSet=rs0" --quiet --eval "db.adminCommand('ping')"` should return `{ ok: 1 }`.
- **Config (all services):** run `./setup-config.sh` once per service; set identical `topicConf.capability` and `topicConf.crypto.key` in each `config/common.json`; set Mongo URL in `config/facs/db-mongo.config.json` (use different DB names: `wdk_indexer_evm`, `wdk_data_shard`); set Ethereum RPC in `wdk-indexer-wrk-evm/config/eth.json`.
- **Boot order (separate terminals):**
  1) `cd wdk-indexer-wrk-evm && node worker.js --wtype wrk-evm-indexer-proc --env development --rack eth-proc --chain usdt-eth` → copy “Proc RPC Key”.
  2) Same dir: `node worker.js --wtype wrk-evm-indexer-api --env development --rack eth-api --chain eth --proc-rpc <PROC_KEY>`.
  3) `cd wdk-data-shard-wrk && node worker.js --wtype wrk-data-shard-proc --env development --rack shard-proc` → copy “Proc RPC Key”.
  4) Same dir: `node worker.js --wtype wrk-data-shard-api --env development --rack shard-api --proc-rpc <SHARD_PROC_KEY>`.
  5) `cd wdk-ork-wrk && node worker.js --wtype wrk-ork-api --env development --rack ork-api`.
  6) Optional HTTP API: `cd wdk-indexer-app-node && node worker.js --wtype wdk-server-http-base --env development --port 3000`.
- **What to watch for:** “Proc RPC Key” plus “Worker started successfully”, “Connected to MongoDB”, “Hyperswarm topic joined”. Optional health check: `curl http://localhost:3000/health`.

---

## Quick example for usdt-eth (4 repos)

wdk-indexer-wrk-evm
terminal 1
node worker.js --wtype wrk-evm-indexer-proc --env development --rack eth-proc --chain usdt-eth
node worker.js --wtype wrk-evm-indexer-proc --env development --rack eth-proc --chain xaut
terminal 2
node worker.js --wtype wrk-evm-indexer-api --env development --rack eth-api --chain usdt-eth --proc-rpc <PROC_RPC_KEY>
node worker.js --wtype wrk-evm-indexer-api --env development --rack eth-api --chain xaut --proc-rpc

rumble-data-shard-wrk
terminal 1
node worker.js --wtype wrk-data-shard-proc --env development --rack shard-1
terminal 2
node worker.js --wtype wrk-data-shard-api --env development --rack shard-1-1 --proc-rpc <DATA_SHARD_PROC_RPC_KEY>

rumble-ork-wrk
node worker.js --wtype wrk-ork-api --env development --rack ork-1

rumble-app-node
node worker.js --wtype wrk-node-http --env development --port 3000

---

## Quick start Sepolia testnet (4 repos)

wdk-indexer-wrk-evm
Terminal 1 (proc): 
node worker.js --wtype wrk-erc20-indexer-proc --env development --rack sepolia-usdt0-proc --chain usdt-sepolia
Terminal 2 (api, use the Proc RPC Key printed by the proc):
node worker.js --wtype wrk-erc20-indexer-api --env development --rack sepolia-usdt0-api --chain usdt-sepolia --proc-rpc <PROC_RPC_KEY>

rumble-data-shard-wrk
Terminal 1:
node worker.js --wtype wrk-data-shard-proc --env development --rack shard-1
Terminal 2:
node worker.js --wtype wrk-data-shard-api --env development --rack shard-1-1 --proc-rpc <DATA_SHARD_PROC_RPC_KEY>

rumble-ork-wrk
node worker.js --wtype wrk-ork-api --env development --rack ork-1

rumble-app-node
node worker.js --wtype wrk-node-http --env development --port 3000

----

## Quick start with xaut-eth and run Hyperswarm pool test

1. Make sure all workers are stopped first

2. Start XAUT Indexer

### Terminal 1: XAUT Indexer Proc
wdk-indexer-wrk-evm
node worker.js --wtype wrk-erc20-indexer-proc --env development --rack xaut-proc --chain xaut-eth
⚠️ Copy the RPC key!

### Terminal 2: XAUT Indexer API
wdk-indexer-wrk-evm
node worker.js --wtype wrk-erc20-indexer-api --env development --rack xaut-api --chain xaut-eth --proc-rpc <XAUT_PROC_KEY>

3. Start Data Shard

### Terminal 3: Data Shard Proc
rumble-data-shard-wrk
node worker.js --wtype wrk-data-shard-proc --env development --rack shard-1
⚠️ Copy the RPC key!

### Terminal 4: Data Shard API
rumble-data-shard-wrk
node worker.js --wtype wrk-data-shard-api --env development --rack shard-1-1 --proc-rpc <DATA_SHARD_PROC_KEY>
0209ee88cade0f6c9631da92e52dd14aee6b5f138029afc8ca37e267a4dac83a

4. Start Org Service (REQUIRED!)

### Terminal 5: Org Service
rumble-ork-wrk
node worker.js --wtype wrk-ork-api --env development --rack ork-1

5. Start HTTP App Node (REQUIRED!)

### Terminal 6: HTTP App Node
rumble-app-node
node worker.js --wtype wrk-node-http --env development --port 3000

6. Run the Test

hyperswarm_prod_issue
./reproduce_exact_error.sh

7. Watch Terminal 3

At ~30-35 seconds, look for:
[HRPC_ERR]=Pool was force destroyed
ERR_WALLET_TRANSFER_RPC_FAIL: ethereum:xaut:0x68749665FF8D2d112Fa859AA293F07A622782F38

----