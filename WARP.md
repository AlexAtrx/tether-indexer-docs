# WARP.md

This file provides guidance to WARP (warp.dev) when working with code in this repository.

## Architecture Overview

This is a monorepo for the **WDK (Wallet Development Kit) Indexer** system - a distributed blockchain indexing infrastructure for multi-chain self-custodial wallets. The system uses **Hyperswarm** for P2P RPC communication and **HyperDB** for append-only blockchain data storage.

### Service Stack (Runtime Order)

The directories indicate the request flow through the system:

```
wdk-indexer-app-node     → HTTP REST API (port 3000)
wdk-ork-wrk              → Org service (API gateway/router)
wdk-data-shard-wrk       → Business logic & wallet data
wdk-indexer-wrk-evm      → Chain-specific indexers (EVM/BTC/Solana/etc.)
```

**Request Flow:** User → HTTP API → Org Service → Data Shard → Chain Indexer → Blockchain RPC

### Key Architectural Patterns

1. **Proc/API Worker Pattern**: Each service has two worker types:
   - **Proc worker** (writer): Handles mutations, syncs blockchain data, prints a unique RPC key
   - **API worker** (reader): Handles queries, requires the Proc worker's RPC key

2. **Hyperswarm Mesh**: All services communicate via P2P RPC using shared topics. All services **must** share identical:
   - `topicConf.capability` (handshake secret)
   - `topicConf.crypto.key` (encryption key)

3. **Chain Indexers**: Base functionality in `wdk-indexer-wrk-base`, extended by:
   - `wdk-indexer-wrk-evm` (Ethereum, Arbitrum, Polygon + ERC-20 tokens)
   - `wdk-indexer-wrk-btc` (Bitcoin)
   - `wdk-indexer-wrk-solana` (Solana + SPL tokens)
   - `wdk-indexer-wrk-ton` (TON)
   - `wdk-indexer-wrk-tron` (Tron)
   - `wdk-indexer-wrk-spark` (Spark)

4. **Rumble Extensions**: `rumble-*` directories extend base WDK services with notifications/webhooks.

## Common Commands

### Initial Setup (Any Service)

```bash
# 1. Install dependencies
npm install

# 2. Copy example configs to actual configs
./setup-config.sh

# 3. Edit config files before running:
#    - config/common.json (shared secrets, topics)
#    - config/facs/db-mongo.config.json (MongoDB connection)
#    - config/<chain>.json (chain-specific settings)
```

### Testing

```bash
# Run all tests
npm test

# Run tests with coverage
npm run test:coverage

# Run specific test types (where available)
npm run test:unit
npm run test:integration
npm run test:e2e
```

### Linting

```bash
# Check code style (uses standard.js)
npm run lint

# Auto-fix linting issues
npm run lint:fix
```

### Database Operations

```bash
# Build HyperDB schemas (indexer base only)
cd wdk-indexer-wrk-base/
npm run db:build

# Run MongoDB migrations (EVM indexer)
cd wdk-indexer-wrk-evm/
npm run db:migration
```

## Starting Workers

### MongoDB Prerequisite

All services require MongoDB. Start the local replica set:

```bash
# Add hostnames to /etc/hosts (one-time setup)
echo "127.0.0.1 mongo1 mongo2 mongo3" | sudo tee -a /etc/hosts

# Start MongoDB replica set
cd _mongo_db_local/
npm install
npm run start:db
npm run init:rs

# Connection string format:
# mongodb://mongo1:27017,mongo2:27017,mongo3:27017/DATABASE_NAME?replicaSet=rs0
```

### Boot Order (Minimal Working System)

Start services in this order. **IMPORTANT**: Note the Proc RPC keys printed in logs - you'll need them for API workers.

#### 1. Chain Indexer (e.g., Ethereum)

```bash
# Terminal 1: Start Proc worker (writer)
cd wdk-indexer-wrk-evm/
node worker.js --wtype wrk-evm-indexer-proc --env development --rack eth-proc --chain eth
# ⚠️ COPY THE "Proc RPC Key" FROM LOGS

# Terminal 2: Start API worker (reader)
node worker.js --wtype wrk-evm-indexer-api --env development --rack eth-api --chain eth --proc-rpc <PROC_RPC_KEY>
```

**For ERC-20 tokens** (e.g., USDT on Ethereum):
```bash
node worker.js --wtype wrk-erc20-indexer-proc --env development --rack usdt-proc --chain usdt-eth
node worker.js --wtype wrk-erc20-indexer-api --env development --rack usdt-api --chain usdt-eth --proc-rpc <PROC_RPC_KEY>
```

#### 2. Data Shard Worker

```bash
# Terminal 3: Start Proc worker
cd wdk-data-shard-wrk/
node worker.js --wtype wrk-data-shard-proc --env development --rack shard-proc
# ⚠️ COPY THE "Proc RPC Key" FROM LOGS

# Terminal 4: Start API worker
node worker.js --wtype wrk-data-shard-api --env development --rack shard-api --proc-rpc <SHARD_PROC_RPC_KEY>
```

#### 3. Org Service (API Gateway)

```bash
# Terminal 5
cd wdk-ork-wrk/
node worker.js --wtype wrk-ork-api --env development --rack ork-api
```

#### 4. App Node (HTTP Server - Optional)

```bash
# Terminal 6
cd wdk-indexer-app-node/
node worker.js --wtype wdk-server-http-base --env development --port 3000
# Access at http://localhost:3000
# Swagger UI at http://localhost:3000/docs
```

### Other Chain Workers

The pattern is identical for all chains:

```bash
# Bitcoin
cd wdk-indexer-wrk-btc/
node worker.js --wtype wrk-btc-indexer-proc --env development --rack btc-proc --chain btc
node worker.js --wtype wrk-btc-indexer-api --env development --rack btc-api --chain btc --proc-rpc <KEY>

# Solana (native)
cd wdk-indexer-wrk-solana/
node worker.js --wtype wrk-solana-indexer-proc --env development --rack sol-proc --chain sol
node worker.js --wtype wrk-solana-indexer-api --env development --rack sol-api --chain sol --proc-rpc <KEY>

# Solana (SPL tokens)
node worker.js --wtype wrk-spl-indexer-proc --env development --rack spl-proc --chain usdt-sol
node worker.js --wtype wrk-spl-indexer-api --env development --rack spl-api --chain usdt-sol --proc-rpc <KEY>

# TON, Tron, Spark follow the same pattern
```

## Critical Configuration Requirements

### Shared Hyperswarm Secrets

**ALL services must use identical values** in `config/common.json`:

```json
{
  "topicConf": {
    "capability": "<same-handshake-secret-everywhere>",
    "crypto": {
      "key": "<same-encryption-key-everywhere>"
    }
  }
}
```

If these don't match, services will start but cannot communicate (silent failure).

### MongoDB Configuration

Edit `config/facs/db-mongo.config.json` in each service:

```json
{
  "dbMongo_m0": {
    "name": "db-mongo",
    "opts": {
      "mongoUrl": "mongodb://mongo1:27017,mongo2:27017,mongo3:27017/wdk_data_shard?replicaSet=rs0",
      "dedicatedDb": true
    }
  }
}
```

Use different database names per service:
- Data shard: `wdk_data_shard`
- EVM indexer: `wdk_indexer_evm`
- BTC indexer: `wdk_indexer_btc`

### Chain RPC Endpoints

Edit chain-specific config files (e.g., `wdk-indexer-wrk-evm/config/eth.json`):

```json
{
  "chain": "ethereum",
  "token": "eth",
  "mainRpc": {
    "rpcUrl": "https://mainnet.infura.io/v3/YOUR_API_KEY"
  },
  "secondaryRpcs": [
    {"rpcUrl": "https://rpc.ankr.com/eth", "weight": 1},
    {"rpcUrl": "https://cloudflare-eth.com", "weight": 2}
  ],
  "txBatchSize": 20,
  "syncTx": "*/30 * * * * *"
}
```

**Recommended sync settings by chain:**
- Ethereum (12s blocks): `txBatchSize: 20`, `syncTx: */30 * * * * *`
- Arbitrum (0.3s blocks): `txBatchSize: 40`, `syncTx: */5 * * * * *`
- Polygon (2s blocks): `txBatchSize: 30`, `syncTx: */15 * * * * *`

## Schema & Versioning Rules

### HyperDB Append-Only Constraint

**CRITICAL**: HyperDB schemas are append-only. You **CANNOT** insert fields in the middle.

❌ **WRONG** (breaks HyperDB):
```javascript
schema.field('id')
schema.field('newField')  // ❌ Inserted in middle
schema.field('address')
```

✅ **CORRECT** (append at end):
```javascript
schema.field('id')
schema.field('address')
schema.field('newField')  // ✅ Appended at end
```

### Version Bump Policy

Any schema change requires:

1. **Increment version** in `package.json`
2. **Update all dependent repos**:
   - Base repo change → update all chain workers
   - `wdk-data-shard-wrk` change → update `rumble-data-shard-wrk`
3. **Re-run** `npm install` in dependent repos
4. **Consider migration scripts** for breaking changes

## Health Checks

### MongoDB
```bash
mongosh mongodb://mongo1:27017,mongo2:27017,mongo3:27017/?replicaSet=rs0 --eval "db.adminCommand('ping')"
```

### Service Logs
Check logs for these indicators:
- ✅ `Worker started successfully`
- ✅ `Connected to MongoDB`
- ✅ `Hyperswarm topic joined: <topic>`
- ✅ `RPC server listening`
- ✅ `Proc RPC Key: <key>` (for Proc workers)

### HTTP API (if running app node)
```bash
curl http://localhost:3000/health
```

### RPC Testing (using hp-rpc-cli)
```bash
# Install globally
npm install -g hp-rpc-cli

# Test data shard
hp-rpc-cli -s <SHARD_RPC_KEY> -cp <CAPABILITY> -m ping

# Create API key (app node)
hp-rpc-cli -s <APP_RPC_KEY> -cp <CAPABILITY> -m createApiKey -d '{
  "owner": "test@example.com",
  "label": "Test Key"
}'
```

## Key Gotchas

1. **Proc RPC Keys**: API workers cannot start without their Proc worker's RPC key. Always start Proc first and copy the key from logs.

2. **Topic Discovery**: Services discover each other via Hyperswarm topics. If a service can't find peers, verify:
   - All services have identical `topicConf.capability` and `crypto.key`
   - Proc workers are running before API workers
   - Correct topic names in configs (e.g., `@wdk/data-shard`, `@wdk/ork`)

3. **No Authentication in Org Service**: The org service has no auth layer. Keep it on internal networks only.

4. **Rumble Sync**: Any change to base repos (`wdk-*`) must be manually mirrored in Rumble repos (`rumble-*`).

5. **MongoDB Replica Set Required**: Single-node MongoDB won't work. Use the provided Docker setup in `_mongo_db_local/`.

6. **RPC Rate Limits**: Public RPC endpoints (Infura, Alchemy) have rate limits. Use multiple endpoints with weights or self-host nodes.

## Directory Structure

- **Core service directories (app, ork, data-shard, indexers)**: Production service variants used together in deployments
- **Non-numbered directories**: Base libraries and additional chain workers
- **`rumble-*` directories**: Extensions with notifications/webhooks (optional for local dev)
- **`wdk-*` directories**: Core WDK infrastructure
- **`tether-wrk-*` directories**: Base worker framework libraries
- **`svc-facs-*` directories**: Shared service facilities (HTTP, logging)
- **`_mongo_db_local/`**: Local MongoDB Docker setup for development

## Documentation References

- **Setup Guide**: `LOCAL_INDEXER_SETUP_PLAN.md` - Comprehensive setup documentation
- **Architecture**: `APP_RELATIONS.md` - Service dependencies and relationships
- **Diagram**: `wdk-indexer-local-diagram.mmd` - Mermaid diagram of local topology
- **Quick Setup**: `setup.txt` - Step-by-step minimal setup
- **App Node API**: `wdk-indexer-app-node/README.md` - RPC methods and HTTP endpoints
- **MongoDB Testing**: `_mongo_db_local/README.md` - Replica set failure scenarios
