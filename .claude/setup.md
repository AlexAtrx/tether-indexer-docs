# Local dev setup

Condensed from `_tether-indexer-docs/WARP.md` and `app_setup/*`.

## Per-service bootstrap

```bash
cd <service>/
npm install
./setup-config.sh           # copies examples to real configs
# edit: config/common.json, config/facs/db-mongo.config.json, config/<chain>.json
```

## MongoDB replica set (required)

Single-node Mongo does not work.

```bash
# one-time hosts mapping
echo "127.0.0.1 mongo1 mongo2 mongo3" | sudo tee -a /etc/hosts

cd _mongo_db_local/
npm install
npm run start:db
npm run init:rs
```

Connection string template:
`mongodb://mongo1:27017,mongo2:27017,mongo3:27017/<DB>?replicaSet=rs0`

Per-service DB name:
- `wdk-data-shard-wrk` → `wdk_data_shard`
- `wdk-indexer-wrk-evm` → `wdk_indexer_evm`
- `wdk-indexer-wrk-btc` → `wdk_indexer_btc`
- etc.

## Boot order (minimal working stack)

Proc first, then API (API needs Proc's RPC key from logs).

1. **Chain indexer** (e.g. ETH):
   ```bash
   cd wdk-indexer-wrk-evm/
   node worker.js --wtype wrk-evm-indexer-proc --env development --rack eth-proc --chain eth
   # copy "Proc RPC Key"
   node worker.js --wtype wrk-evm-indexer-api  --env development --rack eth-api  --chain eth --proc-rpc <KEY>
   ```

   ERC-20 on ETH (e.g. USDT):
   ```bash
   node worker.js --wtype wrk-erc20-indexer-proc --env development --rack usdt-proc --chain usdt-eth
   node worker.js --wtype wrk-erc20-indexer-api  --env development --rack usdt-api  --chain usdt-eth --proc-rpc <KEY>
   ```

2. **Data shard:**
   ```bash
   cd wdk-data-shard-wrk/
   node worker.js --wtype wrk-data-shard-proc --env development --rack shard-proc
   # copy "Proc RPC Key"
   node worker.js --wtype wrk-data-shard-api  --env development --rack shard-api --proc-rpc <KEY>
   ```

3. **Ork:**
   ```bash
   cd wdk-ork-wrk/
   node worker.js --wtype wrk-ork-api --env development --rack ork-api
   ```

4. **App node (HTTP):**
   ```bash
   cd wdk-indexer-app-node/
   node worker.js --wtype wdk-server-http-base --env development --port 3000
   # http://localhost:3000/docs  (Swagger)
   ```

Other chains follow the same pattern (`wrk-btc-indexer-*`, `wrk-solana-indexer-*`, `wrk-spl-indexer-*`, `wrk-ton-indexer-*`, `wrk-tron-indexer-*`, `wrk-spark-indexer-*`).

## Docker local orchestration

`_wdk_docker_network_v2/` is a Rumble-focused local stack (Mongo + Redis + local DHT bootstrap + one USDT/EVM indexer + Rumble shard/ork/app).

**Docs drift warning:** the README says `make up`, but that only brings up Mongo + Redis. Use `make up-all` for the full stack.

It does **not** run the full multi-chain stack.

## RPC smoke tests

```bash
npm install -g hp-rpc-cli

# ping data shard
hp-rpc-cli -s <SHARD_RPC_KEY> -cp <CAPABILITY> -m ping

# create API key via app node
hp-rpc-cli -s <APP_RPC_KEY> -cp <CAPABILITY> -m createApiKey -d '{
  "owner": "test@example.com",
  "label": "Test Key"
}'
```

## Health signals in logs

- `Worker started successfully`
- `Connected to MongoDB`
- `Hyperswarm topic joined: <topic>`
- `RPC server listening`
- `Proc RPC Key: <key>` (proc workers only)
