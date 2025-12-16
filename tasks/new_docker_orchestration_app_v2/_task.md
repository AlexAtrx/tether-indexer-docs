This Docker orchestration repo is not running fine for me \_wdk_docker_network

Create a new repo \_wdk_docker_network_v2 that is clear and it does:

- Spin MongoDB replicas like in \_wdk_docker_network (this works)
- Spin a complete backend flow of 6 services, which (if ran manually) is:

```
cd wdk-indexer-wrk-evm
terminal 1
node worker.js --wtype wrk-erc20-indexer-proc --env development --rack eth-proc --chain usdt-eth
terminal 2
node worker.js --wtype wrk-erc20-indexer-api --env development --rack eth-api --chain usdt-eth --proc-rpc <PROC_RPC_KEY_FROM_TERMINAL_1>

cd rumble-data-shard-wrk
terminal 3
node worker.js --wtype wrk-data-shard-proc --env development --rack shard-1
terminal 4
node worker.js --wtype wrk-data-shard-api --env development --rack shard-1-1 --proc-rpc <PROC_RPC_KEY_FROM_TERMINAL_3>

cd rumble-ork-wrk
node worker.js --wtype wrk-ork-api --env development --rack ork-1

cd rumble-app-node
node worker.js --wtype wrk-node-http --env development --port 3000
```

Note:

- In each app, you need to run 'npm i'.
- Not that in wdk-indexer-wrk-evm and in rumble-data-shard-wrk, the 2nd run needs the key from the previous run (check the commands).
- The above commands run fine locally if MongoDB replica is span (which is the case now, you can check Docker to see what's running).
- The current app \_wdk_docker_network is working but I can see errors in some services. I tried debugging but failed. Something is wrong. This is why I'm asking for V2.

Required:
'make up' to run the entire network and the API is ready.
'make clean' to bring all down.
'make logs' to see all logs in terminal.
