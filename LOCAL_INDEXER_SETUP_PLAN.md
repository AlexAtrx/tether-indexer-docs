# Local WDK Indexer Setup Plan

This document provides a comprehensive, step-by-step plan for running the WDK (Wallet Development Kit) Indexer locally. **This is a planning document only — no commands should be executed at this stage.**

---

## Table of Contents

1. [Components & Repos Map](#components--repos-map)
2. [Local Topology](#local-topology)
3. [MongoDB Setup](#mongodb-setup)
4. [Schema & Versioning](#schema--versioning)
5. [Boot Order & Health Checks](#boot-order--health-checks)
6. [Chain Configuration](#chain-configuration)
7. [Minimal Run Set](#minimal-run-set)
8. [CI/CD Hints (Optional)](#cicd-hints-optional)
9. [Caveats & Gaps](#caveats--gaps)

---

## Components & Repos Map

### 1. **Base Indexer Worker** (`wdk-indexer-wrk-base/`)

**Purpose:** Provides the base implementation for all chain-specific indexer workers. Contains shared code for blockchain data indexing, HyperDB integration, and RPC interfaces.

**Dependencies:**
- MongoDB (via `bfx-facs-db-mongo`)
- HyperDB/Hyperswarm for P2P networking
- `tether-wrk-base` (base worker framework)

**Key Environment Variables/Config:**
- `config/common.json`:
  - `debug`: Debug level (0-3)
  - `dbEngine`: Set to `hyperdb`
  - `topicConf.capability`: Handshake secret for P2P connections
  - `topicConf.crypto.key`: Encryption key for P2P communication
- `config/facs/db-mongo.config.json`:
  - MongoDB connection details (host, port, user, password, database)
- `config/facs/net.config.json`:
  - Network configuration for Hyperswarm

**Expected Ports:** 
- No fixed HTTP port (uses Hyperswarm RPC)

**Local Dev Commands:**
```bash
cd wdk-indexer-wrk-base/
npm install
./setup-config.sh  # Copy .example files to actual config files
# Edit config files before running
# (Base is extended by chain-specific workers, not run directly)
```

**Worker Types:**
- `proc.indexer.wrk.js`: Processor/writer worker (syncs blockchain data)
- `api.indexer.wrk.js`: API/reader worker (serves queries)

**Interconnects:** Base module — extended by chain-specific indexer workers.

---

### 2. **Chain-Specific Indexer Workers** 

All chain workers follow the same pattern and extend `wdk-indexer-wrk-base`:

#### a. **EVM Indexer** (`wdk-indexer-wrk-evm/`)

**Purpose:** Indexes Ethereum-compatible chains (Ethereum, Arbitrum, Polygon) and ERC-20 tokens (e.g., USDT, XAUT).

**Dependencies:**
- `@tetherto/wdk-indexer-wrk-base`
- `ethers` (v6.14.4) for blockchain interactions
- MongoDB for storing indexed data

**Key Config Files:**
- `config/common.json`: Same as base (HyperDB, topic config)
- `config/eth.json`, `config/usdt-eth.json`, etc.: Chain-specific configs
  - `chain`: Chain name (e.g., "ethereum", "arbitrum", "polygon")
  - `token`: Token symbol
  - `mainRpc.rpcUrl`: Primary RPC endpoint (e.g., Infura, Alchemy)
  - `secondaryRpcs`: Backup RPC endpoints with weights
  - `txBatchSize`: Number of transactions to process per batch
  - `syncTx`: Cron expression for sync schedule
  - `erc4337WalletConfig`: ERC-4337 wallet configuration (if applicable)

**Expected Ports:** None (RPC-based communication)

**Local Dev Commands:**
```bash
cd wdk-indexer-wrk-evm/
npm install
./setup-config.sh

# Start a Proc worker (writer) for native ETH
node worker.js --wtype wrk-evm-indexer-proc --env development --rack w-eth-proc-1 --chain eth

# Start API workers (readers) - note the proc-rpc key printed by proc worker
node worker.js --wtype wrk-evm-indexer-api --env development --rack w-eth-api-1 --chain eth --proc-rpc <PROC_RPC_KEY>
node worker.js --wtype wrk-evm-indexer-api --env development --rack w-eth-api-2 --chain eth --proc-rpc <PROC_RPC_KEY>

# For ERC-20 tokens (e.g., USDT on Ethereum)
node worker.js --wtype wrk-erc20-indexer-proc --env development --rack w-usdt-eth-proc-1 --chain usdt-eth
node worker.js --wtype wrk-erc20-indexer-api --env development --rack w-usdt-eth-api-1 --chain usdt-eth --proc-rpc <PROC_RPC_KEY>
```

**Worker Types:**
- `wrk-evm-indexer-proc`: Native token processor
- `wrk-evm-indexer-api`: Native token API
- `wrk-erc20-indexer-proc`: ERC-20 token processor
- `wrk-erc20-indexer-api`: ERC-20 token API

**Interconnects:** 
- Writes blockchain data to HyperDB
- API workers query proc workers via RPC
- Data shard queries indexer workers for blockchain data

#### b. **Bitcoin Indexer** (`wdk-indexer-wrk-btc/`)

**Purpose:** Indexes Bitcoin blockchain for BTC transactions.

**Dependencies:** Similar to base, plus Bitcoin-specific libraries.

**Config:** Similar pattern to EVM (chain-specific RPC, sync settings).

**Commands:** Same pattern as EVM (proc + api workers).

#### c. **Solana Indexer** (`wdk-indexer-wrk-solana/`)

**Purpose:** Indexes Solana blockchain.

**Dependencies:** Similar to base, plus Solana-specific libraries.

**Config:** Solana RPC endpoints, sync settings.

**Commands:** Same pattern (proc + api workers).

#### d. **TON Indexer** (`wdk-indexer-wrk-ton/`)

**Purpose:** Indexes TON blockchain.

**Config:** TON RPC endpoints, sync settings.

**Commands:** Same pattern (proc + api workers).

#### e. **Tron Indexer** (`wdk-indexer-wrk-tron/`)

**Purpose:** Indexes Tron blockchain.

**Config:** Tron RPC endpoints, sync settings.

**Commands:** Same pattern (proc + api workers).

#### f. **Spark Indexer** (`wdk-indexer-wrk-spark/`)

**Purpose:** Indexes Spark network.

**Config:** Spark RPC endpoints, sync settings.

**Commands:** Same pattern (proc + api workers).

---

### 3. **Data Shard Worker** (`wdk-data-shard-wrk/`)

**Purpose:** Core business logic service that stores user wallet data, encrypted seeds/entropy, and provides RPC methods for wallet operations. Handles ~100M users across multiple shard instances.

**Dependencies:**
- MongoDB (stores public user data, wallet addresses, balances)
- HyperDB/Hyperswarm (for P2P networking and RPC)
- `tether-wrk-base`
- Indexer workers (queries for blockchain data)

**Key Config Files:**
- `config/common.json`:
  - `shardTopic`: Topic for this shard (e.g., `@wdk/data-shard`)
  - `blockchains`: Supported chains and currencies
  - `maxConcurrency`, `retryDelay`, `maxRetries`: Queue settings
  - `fxRateUrl`: FX rate API endpoint
- `config/facs/db-mongo.config.json`:
  - MongoDB connection URI with auth
  - `txSupport`: false (no transactions)
  - `dedicatedDb`: true

**Expected Ports:** None (RPC-based)

**Local Dev Commands:**
```bash
cd wdk-data-shard-wrk/
npm install
./setup-config.sh

# Start Proc worker (writer)
node worker.js --wtype wrk-data-shard-proc --env development --rack shard-proc-1

# Start API workers (readers)
node worker.js --wtype wrk-data-shard-api --env development --rack shard-api-1 --proc-rpc <PROC_RPC_KEY>
node worker.js --wtype wrk-data-shard-api --env development --rack shard-api-2 --proc-rpc <PROC_RPC_KEY>
```

**Worker Types:**
- `proc.shard.data.wrk.js`: Processor (handles writes, syncs with indexers)
- `api.shard.data.wrk.js`: API (handles read queries)

**Interconnects:**
- Queries indexer workers for blockchain data
- Stores wallet data in MongoDB
- Queried by org service (wdk-ork-wrk)
- Exposes RPC methods via Hyperswarm

---

### 4. **Org Service / API Gateway** (`wdk-ork-wrk/`)

**Purpose:** Routes requests to the correct data shard instance. Acts as a load balancer and API gateway. **No authentication** — assumes trusted internal network.

**Dependencies:**
- HyperDB/Hyperswarm (for discovery and RPC to data shards)
- `tether-wrk-base`

**Key Config Files:**
- `config/common.json`:
  - `orkTopic`: Topic for org service (e.g., `@wdk/ork`)
  - `shardTopic`: Topic to discover data shards
  - `lookupItv`: Lookup interval for shard discovery (ms)

**Expected Ports:** None (RPC-based)

**Local Dev Commands:**
```bash
cd wdk-ork-wrk/
npm install
./setup-config.sh

# Start Org API worker
node worker.js --wtype wrk-ork-api --env development --rack ork-api-1
```

**Worker Types:**
- `api.ork.wrk.js`: API worker (routes to data shards)

**Interconnects:**
- Discovers and routes to data shard workers
- Queried by app node (wdk-indexer-app-node)

---

### 5. **Indexer App Node** (`wdk-indexer-app-node/`)

**Purpose:** HTTP REST API server for mobile apps. Provides proxy endpoints for third-party services, API key management, and user management.

**Dependencies:**
- Fastify (HTTP server)
- Redis (for rate limiting, caching)
- HyperDB/Hyperswarm (to communicate with org service and data shards)
- `tether-wrk-base`

**Key Config Files:**
- `config/common.json`:
  - API key management settings
  - `inactivityThresholdDays`: Days before API keys are revoked
  - `revokeInactiveKeysInterval`: Cron for background job
- Redis configuration (for rate limiting)

**Expected Ports:** 3000 (configurable via `--port`)

**Local Dev Commands:**
```bash
cd wdk-indexer-app-node/
npm install
./setup-config.sh

# Start HTTP server
node worker.js --wtype wdk-server-http-base --env development --port 3000
```

**Worker Types:**
- `base.http.server.wdk.js`: HTTP server worker

**Interconnects:**
- Queries org service for data
- Exposes HTTP REST API to external clients
- Manages API keys in internal storage

---

### 6. **Rumble Extensions**

The Rumble repos extend the base WDK services with additional features (e.g., Firebase notifications, webhooks).

#### a. **Rumble Data Shard** (`rumble-data-shard-wrk/`)

**Purpose:** Extends `wdk-data-shard-wrk` with notifications and webhooks.

**Dependencies:**
- `@tetherto/wdk-data-shard-wrk` (base data shard)
- `firebase-admin` (for push notifications)

**Note:** Any change to `wdk-data-shard-wrk` must be mirrored here.

#### b. **Rumble Org Worker** (`rumble-ork-wrk/`)

**Purpose:** Extends `wdk-ork-wrk` with Rumble-specific routing.

**Dependencies:**
- `@tetherto/wdk-ork-wrk`

#### c. **Rumble App Node** (`rumble-app-node/`)

**Purpose:** Extends `wdk-indexer-app-node` with Rumble-specific endpoints.

**Dependencies:**
- `@tetherto/wdk-app-node`
- Redis

**Note:** For local indexer testing, Rumble repos are **optional** unless you need notifications/webhooks.

---

## Local Topology

### Core Services Diagram (Words)

```
┌─────────────────┐
│  Mobile Client  │
└────────┬────────┘
         │ HTTP (port 3000)
         ▼
┌─────────────────────────────┐
│  wdk-indexer-app-node       │  (HTTP REST API)
│  - API key management       │
│  - Proxy endpoints          │
└────────┬────────────────────┘
         │ Hyperswarm RPC
         ▼
┌─────────────────────────────┐
│  wdk-ork-wrk (Org Service)  │  (API Gateway / Router)
│  - Routes to data shards    │
└────────┬────────────────────┘
         │ Hyperswarm RPC
         ▼
┌─────────────────────────────┐
│  wdk-data-shard-wrk         │  (Business Logic)
│  - Proc (writer)            │
│  - API (reader)             │
│  - Queries indexers         │
└────────┬────────────────────┘
         │ Hyperswarm RPC        ├──> MongoDB (user data)
         ▼
┌───────────────────────────────────────────────────┐
│  Chain-Specific Indexer Workers (per blockchain)  │
│  - wdk-indexer-wrk-evm (ETH, ARB, POL, ERC-20)    │
│    • Proc (syncs blockchain)                      │
│    • API (queries blockchain data)                │
│  - wdk-indexer-wrk-btc (Bitcoin)                  │
│  - wdk-indexer-wrk-solana (Solana)                │
│  - wdk-indexer-wrk-ton (TON)                      │
│  - wdk-indexer-wrk-tron (Tron)                    │
│  - wdk-indexer-wrk-spark (Spark)                  │
└────────┬──────────────────────────────────────────┘
         │ RPC to blockchain nodes
         ▼
┌─────────────────────────────┐
│  Blockchain Nodes (RPC)     │
│  - Infura, Alchemy, etc.    │
└─────────────────────────────┘
```

### Required Services for Local Indexing

**Mandatory:**
1. MongoDB (single node)
2. At least 1 chain-specific indexer worker (Proc + API)
3. Data shard worker (Proc + API)
4. Org service (API)

**Optional:**
- App node (only if testing HTTP REST API)
- Rumble services (only if testing notifications/webhooks)
- Additional chain workers (if testing multi-chain)

### HyperDB / Hyperswarm Notes

- **Hyperswarm:** P2P networking layer for RPC communication between services
- **HyperDB:** Append-only distributed database for blockchain data
- **Topics:** Services discover each other via topics (e.g., `@wdk/data-shard`, `@wdk/ork`)
- **Capability & Key Validation:** Each service must share the same `capability` (handshake secret) and `crypto.key` in `config/common.json` to communicate

**Important:** All services must use **identical** `topicConf.capability` and `topicConf.crypto.key` values for P2P communication to work.

---

## MongoDB Setup

### MongoDB Requirements

- **Version:** MongoDB 4.4+ (no replica set required for local dev)
- **Type:** Single node instance (replica sets optional for production)
- **Storage:** Local filesystem (default MongoDB storage)

### Installation

```bash
# Option 1: Docker (recommended for local dev)
docker run -d \
  --name wdk-mongodb \
  -p 27017:27017 \
  -v /path/to/local/data:/data/db \
  -e MONGO_INITDB_ROOT_USERNAME=admin \
  -e MONGO_INITDB_ROOT_PASSWORD=password123 \
  mongo:7.0

# Option 2: Native install (macOS with Homebrew)
brew tap mongodb/brew
brew install mongodb-community
brew services start mongodb-community
```

### Database Initialization

1. **Create databases:**
   - `wdk_indexer_evm` (for EVM indexer)
   - `wdk_indexer_btc` (for BTC indexer)
   - `wdk_data_shard` (for data shard)
   - Additional databases per chain worker

2. **Create users/roles (if auth enabled):**

```javascript
// Connect to MongoDB
mongosh mongodb://admin:password123@localhost:27017/admin

// Create application user
use wdk_data_shard
db.createUser({
  user: "wdk_app",
  pwd: "wdk_password",
  roles: [
    { role: "readWrite", db: "wdk_data_shard" },
    { role: "readWrite", db: "wdk_indexer_evm" },
    { role: "readWrite", db: "wdk_indexer_btc" }
  ]
})
```

3. **Connection URIs:**

```
# For wdk-data-shard-wrk
mongodb://wdk_app:wdk_password@127.0.0.1:27017/wdk_data_shard?authMechanism=DEFAULT&maxPoolSize=150&socketTimeoutMS=30000&serverSelectionTimeoutMS=30000&connectTimeoutMS=10000

# For wdk-indexer-wrk-evm
mongodb://wdk_app:wdk_password@127.0.0.1:27017/wdk_indexer_evm?authMechanism=DEFAULT

# For simple local dev (no auth)
mongodb://127.0.0.1:27017/wdk_data_shard
```

### Indexes & Migrations

**Indexes:** Most indexes are created automatically by the services on first run. Check service logs for any index creation errors.

**Migrations:** 
- Data shard migrations: `cd wdk-data-shard-wrk/ && npm run migration` (if available)
- EVM migrations: `cd wdk-indexer-wrk-evm/ && npm run db:migration`

### Data Separation

- **MongoDB:** Stores public user data (wallet addresses, balances, transaction history)
- **HyperDB:** Stores blockchain data (blocks, transactions, logs) — append-only
- **Client-side:** Encrypted seeds/entropy (user private keys) are encrypted client-side and stored in data shard, but the data shard never has access to decryption keys

**Important:** No sensitive cryptographic material (private keys) is stored unencrypted in MongoDB or HyperDB.

---

## Schema & Versioning

### HyperDB Schema Rules

1. **Append-only fields:** HyperDB schemas are append-only. You **cannot** insert fields in the middle of a schema.
2. **New fields must be added at the end** of the schema definition.
3. **Version bump required** for any schema change:
   - Update version in `package.json`
   - Update version in schema definition files
4. **Breaking changes:** Require migration scripts (if supported) or full re-sync.

### Version Bump Policy

- **Schema change in base repo:** 
  1. Increment version in `wdk-indexer-wrk-base/package.json`
  2. Update all child repos (per-chain workers) to use new base version
  3. Re-run `npm install` in all dependent repos
  
- **Schema change in data shard:**
  1. Increment version in `wdk-data-shard-wrk/package.json`
  2. Update Rumble data shard to match
  3. Run migrations (if required)

### Example: Adding a New Field

**Bad (will break HyperDB):**
```javascript
schema.field('id')
schema.field('newField')  // ❌ Inserted in middle
schema.field('address')
```

**Good (append at end):**
```javascript
schema.field('id')
schema.field('address')
schema.field('newField')  // ✅ Appended at end
```

---

## Boot Order & Health Checks

### Startup Sequence

1. **MongoDB:** Start MongoDB first and verify it's accepting connections
   ```bash
   # Health check
   mongosh mongodb://localhost:27017 --eval "db.adminCommand('ping')"
   ```

2. **Data Shard Proc Worker:** Start data shard processor
   ```bash
   cd wdk-data-shard-wrk/
   node worker.js --wtype wrk-data-shard-proc --env development --rack shard-proc-1
   # Wait for "Proc RPC Key: <key>" in logs
   ```

3. **Data Shard API Workers:** Start data shard API workers
   ```bash
   node worker.js --wtype wrk-data-shard-api --env development --rack shard-api-1 --proc-rpc <PROC_RPC_KEY>
   # Can start multiple API workers for load balancing
   ```

4. **Chain Indexer Proc Workers:** Start at least one chain indexer processor
   ```bash
   cd wdk-indexer-wrk-evm/
   node worker.js --wtype wrk-evm-indexer-proc --env development --rack w-eth-proc-1 --chain eth
   # Wait for "Proc RPC Key: <key>" in logs
   ```

5. **Chain Indexer API Workers:** Start chain indexer API workers
   ```bash
   node worker.js --wtype wrk-evm-indexer-api --env development --rack w-eth-api-1 --chain eth --proc-rpc <PROC_RPC_KEY>
   ```

6. **Org Service:** Start org service (discovers data shards)
   ```bash
   cd wdk-ork-wrk/
   node worker.js --wtype wrk-ork-api --env development --rack ork-api-1
   # Waits for data shards to be discovered via Hyperswarm
   ```

7. **App Node (Optional):** Start HTTP server
   ```bash
   cd wdk-indexer-app-node/
   node worker.js --wtype wdk-server-http-base --env development --port 3000
   # HTTP server starts on port 3000
   ```

### Health & Readiness Checks

**MongoDB:**
```bash
mongosh mongodb://localhost:27017 --eval "db.adminCommand('ping')"
```

**Services (check logs):**
- Look for: `Worker started successfully`
- Look for: `Connected to MongoDB`
- Look for: `Hyperswarm topic joined: <topic>`
- Look for: `RPC server listening`

**Hyperswarm RPC (using hp-rpc-cli):**
```bash
# Install hp-rpc-cli globally (if available)
npm install -g hp-rpc-cli

# Test data shard RPC
hp-rpc-cli -s <RPC_KEY> -cp <CAPABILITY> -m ping

# Test indexer RPC
hp-rpc-cli -s <INDEXER_RPC_KEY> -cp <CAPABILITY> -m getBlockHeight -d '{"chain":"ethereum"}'
```

**App Node (HTTP):**
```bash
curl http://localhost:3000/health
# Or check Swagger UI at http://localhost:3000/docs
```

### Smoke Tests

**Using Bruno (API client):**
- Load Bruno collection (if provided in repos)
- Test basic wallet operations:
  - Create wallet
  - Get wallet balance
  - Get transaction history

**Manual RPC tests:**
```bash
# Test data shard
hp-rpc-cli -s <SHARD_RPC_KEY> -cp <CAPABILITY> -m createWallet -d '{
  "userId": "test-user-1",
  "blockchain": "ethereum"
}'

# Test indexer
hp-rpc-cli -s <INDEXER_RPC_KEY> -cp <CAPABILITY> -m getBalance -d '{
  "address": "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb",
  "chain": "ethereum"
}'
```

---

## Chain Configuration

### Enabling Multiple Chains Locally

Each chain requires:
1. Chain-specific worker repo (e.g., `wdk-indexer-wrk-evm`, `wdk-indexer-wrk-btc`)
2. Chain configuration file (e.g., `config/eth.json`, `config/btc.json`)
3. RPC endpoint for blockchain node
4. Proc + API workers running

### RPC Endpoints

**Ethereum (and EVM chains):**
- Infura: `https://mainnet.infura.io/v3/YOUR_API_KEY`
- Alchemy: `https://eth-mainnet.g.alchemy.com/v2/YOUR_API_KEY`
- Public: `https://cloudflare-eth.com` (rate limited)

**Bitcoin:**
- BlockCypher: `https://api.blockcypher.com/v1/btc/main`
- Blockchain.info: `https://blockchain.info`
- Self-hosted Bitcoin node: `http://localhost:8332` (requires bitcoind)

**Solana:**
- Solana RPC: `https://api.mainnet-beta.solana.com`
- QuickNode: `https://your-endpoint.solana-mainnet.quiknode.pro/`

**TON:**
- TON Center: `https://toncenter.com/api/v2/jsonRPC`

**Tron:**
- TronGrid: `https://api.trongrid.io`

### Environment Secrets

**Store RPC API keys as environment variables:**
```bash
# .env file (DO NOT commit to git)
INFURA_API_KEY=your_infura_api_key
ALCHEMY_API_KEY=your_alchemy_api_key
BLOCKCYPHER_TOKEN=your_blockcypher_token

# Reference in config (if supported):
{
  "mainRpc": {
    "rpcUrl": "https://mainnet.infura.io/v3/${INFURA_API_KEY}"
  }
}
```

**Note:** Config files may not support env var interpolation. In that case, manually replace before starting workers.

### Rate Limits

- **Infura Free:** 100k requests/day
- **Alchemy Free:** 300M compute units/month
- **Public RPCs:** Highly rate limited (not recommended for indexing)

**Recommendation:** Use paid RPC providers or self-host blockchain nodes for production-like local testing.

### Block Range Backfill

**Initial sync:**
- Most indexers start from a configured block height (e.g., latest block - 1000)
- Full historical backfill requires setting `startBlock` in config

**Example (EVM):**
```json
{
  "chain": "ethereum",
  "startBlock": 18000000,  // Start from this block
  "syncTx": "*/30 * * * * *"
}
```

**Caution:** Full backfill from genesis can take days/weeks depending on chain size.

### Reorg Handling

- Indexers track block confirmations
- On reorg detection, indexer rewinds and re-processes affected blocks
- Configured via `confirmations` setting (if available)

### Pruning

- HyperDB data is append-only (no automatic pruning)
- For local dev, clear HyperDB data manually:
  ```bash
  rm -rf ~/.hyperdrive/storage  # Or configured storage path
  ```

---

## Minimal Run Set

### Smallest Set of Processes for Local Indexer

This minimal setup indexes **one blockchain** (Ethereum) with **one token** (native ETH).

#### 1. MongoDB
```bash
docker run -d --name wdk-mongodb -p 27017:27017 mongo:7.0
```

#### 2. EVM Indexer Proc Worker (Ethereum)
```bash
cd wdk-indexer-wrk-evm/
npm install && ./setup-config.sh
# Edit config/common.json and config/eth.json
node worker.js --wtype wrk-evm-indexer-proc --env development --rack eth-proc --chain eth
# Note the printed Proc RPC Key
```

#### 3. EVM Indexer API Worker (Ethereum)
```bash
cd wdk-indexer-wrk-evm/
node worker.js --wtype wrk-evm-indexer-api --env development --rack eth-api --chain eth --proc-rpc <ETH_PROC_RPC_KEY>
```

#### 4. Data Shard Proc Worker
```bash
cd wdk-data-shard-wrk/
npm install && ./setup-config.sh
# Edit config/common.json and config/facs/db-mongo.config.json
node worker.js --wtype wrk-data-shard-proc --env development --rack shard-proc
# Note the printed Proc RPC Key
```

#### 5. Data Shard API Worker
```bash
cd wdk-data-shard-wrk/
node worker.js --wtype wrk-data-shard-api --env development --rack shard-api --proc-rpc <SHARD_PROC_RPC_KEY>
```

#### 6. Org Service API Worker
```bash
cd wdk-ork-wrk/
npm install && ./setup-config.sh
# Edit config/common.json
node worker.js --wtype wrk-ork-api --env development --rack ork-api
```

#### Optional: HTTP App Node
```bash
cd wdk-indexer-app-node/
npm install && ./setup-config.sh
# Edit config/common.json
node worker.js --wtype wdk-server-http-base --env development --port 3000
```

### Total Processes: 6 (or 7 with app node)

1. MongoDB (Docker container)
2. EVM Indexer Proc
3. EVM Indexer API
4. Data Shard Proc
5. Data Shard API
6. Org Service API
7. **(Optional)** App Node HTTP

---

## CI/CD Hints (Optional)

### GitHub Actions Workflow Outline

**Build & Test Pipeline:**
```yaml
name: CI
on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    services:
      mongodb:
        image: mongo:7.0
        ports:
          - 27017:27017
    steps:
      - uses: actions/checkout@v3
      - uses: actions/setup-node@v3
        with:
          node-version: '18'
      - run: npm ci
      - run: npm test
      - run: npm run lint
```

**Deploy to K8s:**
```yaml
name: Deploy
on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: azure/setup-kubectl@v3
      - run: |
          kubectl apply -f k8s/mongodb.yaml
          kubectl apply -f k8s/data-shard.yaml
          kubectl apply -f k8s/indexer-evm.yaml
          kubectl apply -f k8s/ork-service.yaml
```

### Kubernetes Setup

**Architecture:**
- StatefulSet for MongoDB (persistent storage)
- Deployment for each worker type (stateless, horizontally scalable)
- Service for inter-service communication
- Ingress for HTTP app node

**Example K8s manifest (simplified):**
```yaml
# data-shard-proc.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: data-shard-proc
spec:
  replicas: 1
  selector:
    matchLabels:
      app: data-shard-proc
  template:
    metadata:
      labels:
        app: data-shard-proc
    spec:
      containers:
      - name: worker
        image: wdk-data-shard-wrk:latest
        command: ["node", "worker.js"]
        args: ["--wtype", "wrk-data-shard-proc", "--env", "production", "--rack", "shard-proc-1"]
        env:
        - name: MONGO_URI
          valueFrom:
            secretKeyRef:
              name: mongo-secrets
              key: uri
```

### Docker Compose (Alternative to K8s)

```yaml
version: '3.8'

services:
  mongodb:
    image: mongo:7.0
    ports:
      - "27017:27017"
    volumes:
      - mongo-data:/data/db

  data-shard-proc:
    build: ./wdk-data-shard-wrk
    command: node worker.js --wtype wrk-data-shard-proc --env development --rack shard-proc
    depends_on:
      - mongodb

  data-shard-api:
    build: ./wdk-data-shard-wrk
    command: node worker.js --wtype wrk-data-shard-api --env development --rack shard-api --proc-rpc ${PROC_RPC_KEY}
    depends_on:
      - data-shard-proc

  # ... additional services

volumes:
  mongo-data:
```

---

## Caveats & Gaps

### 1. **No Shared TypeScript/OpenAPI Spec**

**Problem:** App node and org service have no shared API specification. Consistency is maintained manually.

**Impact:** API contract changes require manual updates across multiple repos.

**Mitigation (for local dev):**
- Use Bruno collections to document expected API contracts
- Consider generating OpenAPI specs from code (if Fastify supports)
- Version API endpoints explicitly (e.g., `/v1/wallets`)

### 2. **Manual Deployment**

**Problem:** Current deployment is manual, one-by-one per service.

**Impact:** Slow deployments, potential for human error.

**Mitigation:**
- Use Docker Compose for local multi-service orchestration
- Plan CI/CD with GitHub Actions + K8s (see CI/CD section)

### 3. **Rumble Repo Sync**

**Problem:** Any change to base repos (e.g., `wdk-data-shard-wrk`) must be manually mirrored in Rumble repos.

**Impact:** Easy to forget syncing, leading to version drift.

**Mitigation:**
- Use git submodules or npm workspace monorepos to share code
- Automated tests that verify Rumble repos extend base correctly

### 4. **No Authentication in Org Service**

**Problem:** Org service has no authentication layer.

**Impact:** Security risk if exposed publicly.

**Mitigation:**
- Keep org service on internal network only
- Add authentication layer (e.g., JWT, API keys) before exposing externally
- Use network policies in K8s to restrict access

### 5. **Hyperswarm Topic & Key Validation**

**Problem:** All services must share identical `capability` and `crypto.key` for P2P communication. If misconfigured, services won't discover each other.

**Impact:** Silent failures — services start but can't communicate.

**Mitigation:**
- Use a shared config file or environment variables to ensure consistency
- Add health checks that verify Hyperswarm peer discovery
- Log warnings if no peers are discovered after startup

### 6. **Limited Backup in Staging**

**Problem:** Staging environment uses migrations only (no backups).

**Impact:** Data loss risk in staging.

**Mitigation:**
- For local dev, this is acceptable (ephemeral data)
- For staging/prod, implement MongoDB backups (e.g., mongodump, snapshots)

### 7. **Schema Versioning Complexity**

**Problem:** HyperDB append-only constraint makes schema evolution difficult.

**Impact:** Breaking changes require re-sync or complex migrations.

**Mitigation:**
- Plan schemas carefully upfront
- Use versioned APIs to support multiple schema versions
- Document schema changes rigorously

### 8. **Missing READMEs / Documentation**

**Problem:** Some repos have minimal READMEs (e.g., `wdk-indexer-wrk-base` only has "# wdk-indexer-wrk-base").

**Impact:** Steep learning curve for new developers.

**Mitigation:**
- Add comprehensive READMEs to each repo
- Document RPC methods, config options, and worker types
- Create architecture diagrams (beyond `diagram.png`)

### 9. **Unclear Ports & Endpoints**

**Problem:** Most services use Hyperswarm RPC (no fixed ports), making discovery and debugging challenging.

**Impact:** Hard to inspect traffic or debug connection issues.

**Mitigation:**
- Use `hp-rpc-cli` for manual RPC testing
- Consider adding optional HTTP debug endpoints (e.g., `/debug/peers`)
- Log all RPC calls at debug level

### 10. **Blockchain RPC Rate Limits**

**Problem:** Public RPC endpoints (Infura, Alchemy) have rate limits.

**Impact:** Indexing may fail or slow down if limits are hit.

**Mitigation:**
- Use multiple RPC endpoints with weights (already supported in EVM config)
- Monitor RPC usage and add backoff/retry logic
- Self-host blockchain nodes for unlimited access

---

## Summary

This plan provides a **step-by-step guide** to running the WDK Indexer locally. The minimal setup requires:

1. **MongoDB** (Docker or native)
2. **One chain indexer** (Proc + API workers)
3. **Data shard** (Proc + API workers)
4. **Org service** (API worker)
5. **(Optional)** App node (HTTP server)

All services communicate via **Hyperswarm RPC** and must share the same `capability` and `crypto.key` for P2P networking. Schema changes require version bumps and careful migration due to HyperDB's append-only constraint.

For production-like local testing, consider using **Docker Compose** to orchestrate all services. For CI/CD, plan **GitHub Actions** workflows with **Kubernetes** or **Docker Swarm** deployments.

**Next Steps:**
1. Set up MongoDB
2. Configure all `config/common.json` files with shared secrets
3. Start services in boot order
4. Test with RPC calls or HTTP API (if app node is running)
5. Monitor logs for errors and peer discovery

---

**End of Plan**
