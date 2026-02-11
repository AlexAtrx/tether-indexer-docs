# Ethereum Sepolia Indexer - Deployment Guide

## Overview

This guide covers the deployment of the Ethereum Sepolia testnet indexer for the USDT0 token within the WDK Indexer system.

## Implementation Summary

The Sepolia indexer implementation uses the existing `wdk-indexer-wrk-evm` repository with new configuration files for the Sepolia testnet. No new repository was created, following the established pattern for EVM-compatible chains.

### Repository
- **Repo:** `wdk-indexer-wrk-evm`
- **Branch:** `feature/add-sepolia-indexer`
- **Config Files Added:**
  - `config/sepolia.json.example` - Native Sepolia ETH configuration template
  - `config/sepolia.json` - Native Sepolia ETH configuration (gitignored)
  - `config/usdt0-sepolia.json.example` - USDT0 token configuration template
  - `config/usdt0-sepolia.json` - USDT0 token configuration (gitignored)

## Token Details

- **Token Name:** USDT0
- **Contract Address:** `0xd077A400968890Eacc75cdc901F0356c943e4fDb`
- **Chain:** Sepolia (Ethereum testnet)
- **Decimals:** 6
- **HyperDHT Topic:** `sepolia:usdt0`

## Configuration

### RPC Endpoints

The configuration supports multiple RPC providers for Sepolia testnet:

**Supported Providers:**
- Infura: `https://sepolia.infura.io/v3/{API_KEY}`
- Alchemy: `https://eth-sepolia.g.alchemy.com/v2/{API_KEY}`
- QuickNode: `https://{endpoint}.ethereum-sepolia.quiknode.pro/{API_KEY}`
- Ankr (public): `https://rpc.ankr.com/eth_sepolia`
- PublicNode: `https://ethereum-sepolia.publicnode.com`
- 1RPC: `https://1rpc.io/sepolia`

### Indexer Settings

Following Ethereum mainnet patterns (12s block time):
- **txBatchSize:** 20
- **syncTx:** `*/30 * * * * *` (every 30 seconds)
- **blockQueryBatchSize:** 10 (for ERC-20 indexing)

### MongoDB Configuration

The indexer requires a dedicated MongoDB database:
- **Database Name:** `wdk_indexer_sepolia` (recommended)
- **Connection URI:** Standard MongoDB replica set connection string
- **Collections:** Auto-created by the indexer workers

### Hyperswarm Configuration

The indexer must use the same Hyperswarm secrets as other WDK services:
- **topicConf.capability:** Shared capability secret (in `config/common.json`)
- **topicConf.crypto.key:** Shared encryption key (in `config/common.json`)

## Deployment Steps

### 1. Prerequisites

- Access to `wdk-indexer-wrk-evm` repository
- Sepolia RPC endpoint (Infura, Alchemy, or QuickNode API key)
- MongoDB replica set or cluster
- Shared Hyperswarm secrets from existing WDK deployment

### 2. Setup Configuration

```bash
cd wdk-indexer-wrk-evm/

# Run setup script to copy .example configs
./setup-config.sh

# Edit the Sepolia USDT0 configuration
vi config/usdt0-sepolia.json
```

**Required edits in `config/usdt0-sepolia.json`:**
- Set `mainRpc.rpcUrl` to your Sepolia RPC endpoint
- (Optional) Add additional RPC endpoints to `secondaryRpcs`
- (Optional) Configure `bundlerRpcs` if using ERC-4337

**Required edits in `config/common.json`:**
- Ensure `topicConf.capability` matches other services
- Ensure `topicConf.crypto.key` matches other services
- Set `debug` level as needed

**Required edits in `config/facs/db-mongo.config.json`:**
- Set MongoDB connection URI with proper database name
- Configure connection pool settings

### 3. Install Dependencies

```bash
npm install
```

### 4. Deploy Proc Worker (Writer)

The Proc worker syncs blockchain data and writes to MongoDB.

**Staging:**
```bash
node worker.js --wtype wrk-erc20-indexer-proc --env staging --rack sepolia-usdt0-proc-1 --chain usdt0-sepolia
```

**Production:**
```bash
node worker.js --wtype wrk-erc20-indexer-proc --env production --rack sepolia-usdt0-proc-1 --chain usdt0-sepolia
```

**Important:** Copy the `Proc RPC Key` from the worker output. This will be needed for API workers.

Example output:
```
[INFO] Worker started successfully
[INFO] Connected to MongoDB: wdk_indexer_sepolia
[INFO] Hyperswarm topic joined: sepolia:usdt0
[INFO] Proc RPC Key: abc123def456789...
```

### 5. Deploy API Workers (Readers)

API workers serve queries and must connect to the Proc worker using the RPC key.

**Start multiple API workers for load balancing:**

```bash
# API Worker 1
node worker.js --wtype wrk-erc20-indexer-api --env staging --rack sepolia-usdt0-api-1 --chain usdt0-sepolia --proc-rpc <PROC_RPC_KEY>

# API Worker 2
node worker.js --wtype wrk-erc20-indexer-api --env staging --rack sepolia-usdt0-api-2 --chain usdt0-sepolia --proc-rpc <PROC_RPC_KEY>

# API Worker 3 (optional, for higher load)
node worker.js --wtype wrk-erc20-indexer-api --env staging --rack sepolia-usdt0-api-3 --chain usdt0-sepolia --proc-rpc <PROC_RPC_KEY>
```

### 6. Integration with Existing Services

The Sepolia indexer automatically integrates with existing WDK services:

1. **Data Shard (`wdk-data-shard-wrk`)**: Automatically discovers and queries the Sepolia indexer via Hyperswarm
2. **Org Service (`wdk-ork-wrk`)**: Routes requests to data shards, which then query the Sepolia indexer
3. **App Node (`wdk-indexer-app-node`)**: Exposes HTTP REST API endpoints for Sepolia queries

**No code changes required** in data shard, org service, or app node - they discover the new indexer via HyperDHT.

## Verification & Testing

### 1. Check Worker Logs

**Proc Worker:**
- ✅ `Worker started successfully`
- ✅ `Connected to MongoDB`
- ✅ `Hyperswarm topic joined: sepolia:usdt0`
- ✅ `Syncing blocks from Sepolia network`
- ✅ `Indexed block {number}` (incremental block indexing)

**API Workers:**
- ✅ `Worker started successfully`
- ✅ `Connected to Proc worker via RPC`
- ✅ `Hyperswarm topic joined: sepolia:usdt0`
- ✅ `Ready to serve queries`

### 2. MongoDB Verification

```bash
# Connect to MongoDB
mongosh "mongodb://mongo1:27017,mongo2:27017,mongo3:27017/wdk_indexer_sepolia?replicaSet=rs0"

# Check collections
show collections

# Check indexed blocks
db.blocks.countDocuments()

# Check indexed transactions
db.transactions.countDocuments()

# Check token transfers (for USDT0)
db.token_transfers.countDocuments({"token": "usdt0"})
```

### 3. HyperDHT Discovery

Verify the indexer announces on the correct topic:

```bash
# Use hp-rpc-cli or similar tool to check HyperDHT announcements
hp-rpc-cli --list-topics | grep sepolia
```

Expected output should include: `sepolia:usdt0`

### 4. WDK API Testing

Once integrated with the App Node, test the HTTP API endpoints:

**Token Balance Query:**
```bash
curl "https://api.staging.wdk.example.com/api/v1/balance/{SEPOLIA_ADDRESS}?chain=sepolia&token=usdt0"
```

**Token Transfers Query:**
```bash
curl "https://api.staging.wdk.example.com/api/v1/transfers/{SEPOLIA_ADDRESS}?chain=sepolia&token=usdt0"
```

Replace `{SEPOLIA_ADDRESS}` with a valid Sepolia testnet address.

### 5. Integration Testing

**Test Scenarios:**
1. Query balance for a Sepolia address with USDT0 tokens
2. Query transfer history for a Sepolia address
3. Verify real-time updates as new transactions occur on Sepolia
4. Test with addresses that have zero balance (should return 0, not error)
5. Test with invalid addresses (should return appropriate error)

## Monitoring & Maintenance

### Health Checks

**Worker Health:**
- Monitor worker process uptime
- Check for error logs indicating RPC failures, DB connection issues
- Verify block sync is progressing (check latest indexed block vs. Sepolia network block height)

**MongoDB Health:**
- Monitor database size growth
- Check index performance
- Verify replica set health

**RPC Provider Health:**
- Monitor RPC request success rate
- Track rate limit errors
- Measure RPC response times

### Common Issues & Troubleshooting

**Issue: Indexer not syncing blocks**
- Check RPC endpoint is accessible and API key is valid
- Verify network connectivity to Sepolia RPC provider
- Check for rate limiting errors in logs

**Issue: API workers can't connect to Proc worker**
- Verify `--proc-rpc` key is correct
- Check Hyperswarm connectivity (firewall, NAT issues)
- Ensure `topicConf.capability` and `crypto.key` match

**Issue: Data not appearing in WDK API**
- Verify data shard is discovering the Sepolia indexer
- Check Hyperswarm topic matching (`sepolia:usdt0`)
- Verify org service is routing to the correct data shard

**Issue: MongoDB connection errors**
- Check replica set status: `rs.status()`
- Verify connection URI format and credentials
- Check network connectivity between workers and MongoDB

## Rollback Plan

If issues occur after deployment:

1. **Stop API Workers:** Gracefully shutdown API workers (SIGTERM)
2. **Stop Proc Worker:** Gracefully shutdown Proc worker (SIGTERM)
3. **Verify Data Shard:** Ensure data shard falls back to other indexers
4. **Investigate Issues:** Review logs, check configuration
5. **Fix and Redeploy:** Apply fixes and redeploy following the deployment steps

**Data Preservation:**
- MongoDB data is preserved (append-only)
- Re-deploying workers will resume from last synced block
- No data loss expected during rollback

## Production Deployment Checklist

- [ ] Configuration files reviewed and validated
- [ ] RPC endpoints tested and API keys verified
- [ ] MongoDB database created with proper permissions
- [ ] Hyperswarm secrets match other production services
- [ ] Proc worker deployed and syncing successfully
- [ ] API workers deployed and connected to Proc worker
- [ ] Worker logs reviewed for errors
- [ ] MongoDB contains indexed data (blocks, transactions, transfers)
- [ ] HyperDHT topic announcement verified
- [ ] Data shard discovers and queries Sepolia indexer
- [ ] WDK API returns valid responses for Sepolia queries
- [ ] Monitoring and alerting configured
- [ ] Documentation updated with deployment details
- [ ] Rollback plan reviewed and understood

## Support & Contact

For issues or questions:
- Review logs: `/path/to/wdk-indexer-wrk-evm/logs/`
- Check documentation: `wdk-indexer-wrk-evm/README.md`
- Reference ticket: `_docs/_tickets/Add Support for Ethereum Sepolia Indexer.md`

---

**Document Version:** 1.0
**Last Updated:** 2025-11-17
**Author:** WDK Backend Team
