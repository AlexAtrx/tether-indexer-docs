# How to Run the EVM Indexer Locally

Simple step-by-step guide for running the WDK Indexer locally with EVM (Ethereum) support.

---

## Prerequisites (Already Configured ✅)

- **MongoDB replica set** is running and healthy
- **Hostnames** (mongo1, mongo2, mongo3) are configured in `/etc/hosts`
- **Docker containers** (mongo1, mongo2, mongo3) are up

### Verify MongoDB is Running

```bash
mongosh "mongodb://mongo1:27017,mongo2:27017,mongo3:27017/?replicaSet=rs0" --quiet --eval "db.adminCommand('ping')"
```

Should return `{ ok: 1, ... }`

---

## Boot Order Overview

Services must be started in this order:

1. **EVM Indexer Proc** (writer) → prints RPC key
2. **EVM Indexer API** (reader) → requires proc RPC key
3. **Data Shard Proc** (writer) → prints RPC key
4. **Data Shard API** (reader) → requires proc RPC key
5. **Org Service API** (router) → discovers data shards
6. **(Optional)** **HTTP App Node** → REST API on port 3000

---

## Step 1: Start EVM Indexer (Ethereum)

### Terminal 1 - EVM Proc Worker (Writer)

```bash
cd /Users/alexa/Documents/repos/tether/INDEXER/4_wdk-indexer-wrk-evm_2-types/
npm install
./setup-config.sh  # Copy .example configs (if not done already)

# Edit configuration files:
# - config/common.json: Set topicConf.capability & topicConf.crypto.key
# - config/facs/db-mongo.config.json: MongoDB connection URI
# - config/eth.json: Ethereum RPC endpoint (Infura/Alchemy API key)

# Start the Proc worker
node worker.js --wtype wrk-evm-indexer-proc --env development --rack eth-proc --chain eth
```

**⚠️ CRITICAL: Look for "Proc RPC Key" in the logs - copy this key!**

Example log output:
```
Proc RPC Key: abc123def456...
```

### Terminal 2 - EVM API Worker (Reader)

```bash
cd /Users/alexa/Documents/repos/tether/INDEXER/4_wdk-indexer-wrk-evm_2-types/

# Start the API worker (replace <PROC_RPC_KEY> with the key from Terminal 1)
node worker.js --wtype wrk-evm-indexer-api --env development --rack eth-api --chain eth --proc-rpc <PROC_RPC_KEY>
```

---

## Step 2: Start Data Shard Worker

### Terminal 3 - Data Shard Proc (Writer)

```bash
cd /Users/alexa/Documents/repos/tether/INDEXER/3_wdk-data-shard-wrk_2-types/
npm install
./setup-config.sh  # Copy .example configs (if not done already)

# Edit configuration files:
# - config/common.json: Set SAME topicConf secrets as EVM indexer!
# - config/facs/db-mongo.config.json: MongoDB connection URI

# Start the Proc worker
node worker.js --wtype wrk-data-shard-proc --env development --rack shard-proc
```

**⚠️ CRITICAL: Copy the "Proc RPC Key" from these logs too!**

### Terminal 4 - Data Shard API (Reader)

```bash
cd /Users/alexa/Documents/repos/tether/INDEXER/3_wdk-data-shard-wrk_2-types/

# Start the API worker (replace <SHARD_PROC_RPC_KEY> with the key from Terminal 3)
node worker.js --wtype wrk-data-shard-api --env development --rack shard-api --proc-rpc <SHARD_PROC_RPC_KEY>
```

---

## Step 3: Start Org Service (API Gateway/Router)

### Terminal 5 - Org Service API

```bash
cd /Users/alexa/Documents/repos/tether/INDEXER/2_wdk-ork-wrk/
npm install
./setup-config.sh  # Copy .example configs (if not done already)

# Edit configuration files:
# - config/common.json: Set SAME topicConf secrets as other services!

# Start the Org API worker
node worker.js --wtype wrk-ork-api --env development --rack ork-api
```

This service discovers data shards via Hyperswarm and routes requests to them.

---

## Step 4 (Optional): Start HTTP API Server

### Terminal 6 - HTTP App Node

```bash
cd /Users/alexa/Documents/repos/tether/INDEXER/1_wdk-indexer-app-node/
npm install
./setup-config.sh  # Copy .example configs (if not done already)

# Edit configuration files:
# - config/common.json: Set SAME topicConf secrets as other services!

# Start the HTTP server
node worker.js --wtype wdk-server-http-base --env development --port 3000
```

**Access the API:**
- Base URL: http://localhost:3000
- Swagger UI: http://localhost:3000/docs
- Health check: `curl http://localhost:3000/health`

---

## Critical Configuration Requirements

### 🔐 Shared Hyperswarm Secrets (MUST BE IDENTICAL)

**All services must use the same values** in `config/common.json`:

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

**If these don't match, services will start but cannot communicate (silent failure).**

### 🗄️ MongoDB Configuration

Edit `config/facs/db-mongo.config.json` in each service:

```json
{
  "dbMongo_m0": {
    "name": "db-mongo",
    "opts": {
      "mongoUrl": "mongodb://mongo1:27017,mongo2:27017,mongo3:27017/<DATABASE_NAME>?replicaSet=rs0",
      "dedicatedDb": true
    }
  }
}
```

**Use different database names per service:**
- Data shard: `wdk_data_shard`
- EVM indexer: `wdk_indexer_evm`

### 🌐 Ethereum RPC Endpoint

Edit `4_wdk-indexer-wrk-evm_2-types/config/eth.json`:

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

**You'll need:**
- Infura API key: https://infura.io (free tier available)
- OR Alchemy API key: https://alchemy.com (free tier available)
- OR use public endpoints (rate limited, not recommended)

---

## Health Checks

### MongoDB

```bash
mongosh "mongodb://mongo1:27017,mongo2:27017,mongo3:27017/?replicaSet=rs0" --quiet --eval "db.adminCommand('ping')"
```

### Service Logs

Check each terminal for these success indicators:
- ✅ `Worker started successfully`
- ✅ `Connected to MongoDB`
- ✅ `Hyperswarm topic joined: <topic>`
- ✅ `RPC server listening`
- ✅ `Proc RPC Key: <key>` (for Proc workers)

### HTTP API (if running)

```bash
curl http://localhost:3000/health
```

---

## Process Summary

**Minimal setup requires 6 processes** (7 with HTTP API):

1. ✅ **MongoDB** (already running - Docker containers)
2. 🔷 **EVM Indexer Proc** (Terminal 1) → prints RPC key
3. 🔷 **EVM Indexer API** (Terminal 2) → uses proc key
4. 🟦 **Data Shard Proc** (Terminal 3) → prints RPC key
5. 🟦 **Data Shard API** (Terminal 4) → uses proc key
6. 🟩 **Org Service API** (Terminal 5)
7. 🟨 **(Optional)** **HTTP App Node** (Terminal 6) → port 3000

---

## Troubleshooting

### Services Can't Find Each Other

**Problem:** Services start but can't communicate.

**Solution:** Verify all `config/common.json` files have **identical**:
- `topicConf.capability`
- `topicConf.crypto.key`

### API Worker Can't Connect to Proc

**Problem:** API worker says "Cannot connect to proc worker".

**Solution:** 
1. Make sure Proc worker is running **first**
2. Copy the exact "Proc RPC Key" from Proc worker logs
3. Paste it into the `--proc-rpc` argument for API worker

### MongoDB Connection Errors

**Problem:** "MongoServerSelectionError" or "Connection refused".

**Solution:**
```bash
# Check if containers are running
docker ps | grep mongo

# If not, start MongoDB
cd /Users/alexa/Documents/repos/tether/INDEXER/_mongo_db_local/
npm run start:db
npm run init:rs
```

### RPC Rate Limit Errors

**Problem:** "Rate limit exceeded" from Infura/Alchemy.

**Solution:**
- Use multiple RPC endpoints with `secondaryRpcs`
- Get a paid plan for higher limits
- Self-host an Ethereum node

---

## Quick Start Commands (Copy-Paste)

Once configs are set up, use these commands in separate terminals:

```bash
# Terminal 1 - EVM Proc
cd /Users/alexa/Documents/repos/tether/INDEXER/4_wdk-indexer-wrk-evm_2-types/
node worker.js --wtype wrk-evm-indexer-proc --env development --rack eth-proc --chain eth

# Terminal 2 - EVM API (replace <KEY>)
cd /Users/alexa/Documents/repos/tether/INDEXER/4_wdk-indexer-wrk-evm_2-types/
node worker.js --wtype wrk-evm-indexer-api --env development --rack eth-api --chain eth --proc-rpc <KEY>

# Terminal 3 - Data Shard Proc
cd /Users/alexa/Documents/repos/tether/INDEXER/3_wdk-data-shard-wrk_2-types/
node worker.js --wtype wrk-data-shard-proc --env development --rack shard-proc

# Terminal 4 - Data Shard API (replace <KEY>)
cd /Users/alexa/Documents/repos/tether/INDEXER/3_wdk-data-shard-wrk_2-types/
node worker.js --wtype wrk-data-shard-api --env development --rack shard-api --proc-rpc <KEY>

# Terminal 5 - Org Service
cd /Users/alexa/Documents/repos/tether/INDEXER/2_wdk-ork-wrk/
node worker.js --wtype wrk-ork-api --env development --rack ork-api

# Terminal 6 - HTTP API (optional)
cd /Users/alexa/Documents/repos/tether/INDEXER/1_wdk-indexer-app-node/
node worker.js --wtype wdk-server-http-base --env development --port 3000
```

---

## Next Steps

Once running:

1. **Test the setup** using the HTTP API or RPC calls
2. **Monitor logs** in all terminals for errors
3. **Add more chains** by starting additional chain workers (BTC, Solana, etc.)
4. **See WARP.md** for detailed architecture and advanced configuration

---

**For detailed architecture and troubleshooting, see:**
- `WARP.md` - Comprehensive architecture guide
- `wdk-indexer-local-diagram.mmd` - System diagram
- `APP_RELATIONS.md` - Service relationships
