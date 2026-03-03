wdk-indexer-wrk-evm

terminal 1
node worker.js --wtype wrk-erc20-indexer-proc --env development --rack eth-proc --chain usdt-eth

terminal 2
node worker.js --wtype wrk-erc20-indexer-api --env development --rack eth-api --chain usdt-eth --proc-rpc <PROC_RPC_KEY_FROM_TERMINAL_1>

---

rumble-data-shard-wrk

terminal 3
node worker.js --wtype wrk-data-shard-proc --env development --rack shard-1

terminal 4
node worker.js --wtype wrk-data-shard-api --env development --rack shard-1-1 --proc-rpc <PROC_RPC_KEY_FROM_TERMINAL_3>

---

rumble-ork-wrk
node worker.js --wtype wrk-ork-api --env development --rack ork-1

---

rumble-app-node
node worker.js --wtype wrk-node-http --env development --port 3000
