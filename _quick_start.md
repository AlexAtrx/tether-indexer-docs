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
terminal 2
node worker.js --wtype wrk-evm-indexer-api --env development --rack eth-api --chain usdt-eth --proc-rpc e81d60d5d2721e9a113016604ebc174aed3eada8208f7c465c88c5a06abfd530

rumble-data-shard-wrk
terminal 1
node worker.js --wtype wrk-data-shard-proc --env development --rack shard-1
terminal 2
node worker.js --wtype wrk-data-shard-api --env development --rack shard-1-1 --proc-rpc 1d4bb5ac76c1c1a7f83dbe135bc6803960fc446a2f935db47c13e7e5a4d9977d

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
