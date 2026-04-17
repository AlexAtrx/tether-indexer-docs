# Project Overview

This repository is a monorepo for the **WDK (Wallet Development Kit)**, a distributed, multi-chain blockchain indexer and wallet management system. It uses a P2P mesh architecture (Hyperswarm) for communication between services, enabling a self-custodial wallet platform.

The system is composed of several independent Javascript/Typescript packages that function as microservices. The core architecture follows a specific data flow:

`Client -> wdk-indexer-app-node -> wdk-ork-wrk -> wdk-data-shard-wrk -> wdk-indexer-wrk-*`

- **`wdk-indexer-app-node`**: The public-facing HTTP REST API (Fastify).
- **`wdk-ork-wrk`**: An internal API gateway that routes requests to the appropriate data shard.
- **`wdk-data-shard-wrk`**: Handles business logic and manages user wallet data.
- **`wdk-indexer-wrk-*`**: A suite of per-chain indexers (EVM, BTC, Solana, etc.) that sync data from blockchains.

## Local Development Setup

Running the full stack locally is required for most development tasks. This involves running a MongoDB replica set and starting the services in a specific order.

### 1. Prerequisites

- **Docker & Docker Compose**: For running the local MongoDB replica set.
- **Node.js**: v16 or higher.
- **`/etc/hosts` entry**: Ensure the following line is in your `/etc/hosts` file:
  `127.0.0.1 mongo1 mongo2 mongo3`

### 2. Start MongoDB Replica Set

Navigate to the `_wdk_docker_network` directory to manage the database.

```bash
cd _wdk_docker_network/
npm install
npm run start:db # Starts the mongo containers
npm run init:rs  # Initializes the replica set
```

### 3. Configure Services

**Crucially, all services must share the same Hyperswarm secrets to communicate.**

1.  For each service (`wdk-indexer-wrk-evm`, `wdk-data-shard-wrk`, etc.), run `./setup-config.sh` to create `config` files from the `.example` templates.
2.  In each service's `config/common.json`, ensure the `topicConf.capability` and `topicConf.crypto.key` values are **identical**.
3.  In each service's `config/facs/db-mongo.config.json`, set the `mongoUrl` to point to the local replica set (e.g., `mongodb://mongo1:27017,mongo2:27017,mongo3:27017/DB_NAME?replicaSet=rs0`), ensuring you use a unique `DB_NAME` for each service (e.g., `wdk_indexer_evm`, `wdk_data_shard`).
4.  In the chain indexer configs (e.g., `wdk-indexer-wrk-evm/config/eth.json`), provide a valid RPC endpoint URL.

### 4. Boot Order

Services must be started in a specific order from their respective directories. Each command should be run in a separate terminal.

1.  **EVM Indexer (Proc)**: `cd wdk-indexer-wrk-evm && node worker.js --wtype wrk-evm-indexer-proc --chain eth`
    - **Note the `Proc RPC Key` from the logs.**
2.  **EVM Indexer (API)**: `cd wdk-indexer-wrk-evm && node worker.js --wtype wrk-evm-indexer-api --chain eth --proc-rpc <COPIED_EVM_KEY>`
3.  **Data Shard (Proc)**: `cd wdk-data-shard-wrk && node worker.js --wtype wrk-data-shard-proc`
    - **Note the `Proc RPC Key` from the logs.**
4.  **Data Shard (API)**: `cd wdk-data-shard-wrk && node worker.js --wtype wrk-data-shard-api --proc-rpc <COPIED_SHARD_KEY>`
5.  **Org Service**: `cd wdk-ork-wrk && node worker.js --wtype wrk-ork-api`
6.  **App Node (Optional)**: `cd wdk-indexer-app-node && node worker.js --wtype wdk-server-http-base --port 3000`

## Development Conventions

- **Linting**: All projects use `standard`. Run `npm run lint` to check and `npm run lint:fix` to fix.
- **Testing**: Frameworks vary. `wdk-core` uses `jest`, while most other services use `brittle`.
- **Proc/API Worker Pattern**: Most services use a writer/reader pattern. The "proc" worker is a singleton that handles writes and state changes, while multiple "api" workers can be scaled out to handle read requests. API workers require the "Proc RPC Key" from their corresponding proc worker to function.
- **P2P Communication**: Services use **Hyperswarm** for RPC and service discovery. A mismatch in the shared `topicConf` secrets will cause silent connection failures.
- **Database**: The primary database is **MongoDB**. **HyperDB** is also used as an append-only log for certain types of data.
- **Schema Changes**: HyperDB schemas are append-only. New fields must be added to the end of a schema definition, and any change requires a version bump in `package.json`.
- **Rumble Extensions**: The `rumble-*` repositories extend the functionality of the `wdk-*` packages (e.g., adding notifications). Any changes to a base `wdk-*` package must be manually mirrored in the corresponding `rumble-*` package.