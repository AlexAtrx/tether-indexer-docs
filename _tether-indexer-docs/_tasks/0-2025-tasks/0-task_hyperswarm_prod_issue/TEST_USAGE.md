# Pool Destruction Test - Important Notes

## Key Discovery: One User Wallet Per User

The test was failing because **the API only allows ONE `user` type wallet per userId**.

Looking at the wallet creation code in `wdk-data-shard-wrk/workers/proc.shard.data.wrk.js`:

```javascript
const isDup = (wallets) =>
  wallets.some(w =>
    (type === 'channel' && w.type === 'channel' && w.channelId === channelId) ||
    (type === 'user' && w.type === 'user')  // ← Only ONE user wallet allowed!
  )
```

This means:
- ✅ A user can have multiple `channel` type wallets (differentiated by `channelId`)
- ❌ A user can only have **ONE** `user` type wallet
- The error `ERR_WALLET_ALREADY_EXISTS` is triggered when trying to create a second user wallet, **regardless of the wallet address**

## Running the Test

### Before Each Test Run

Since the test uses the same test user (`user-123` from `Bearer test_auth-` token), you need to clean up previous test wallets:

```bash
cd /Users/alexa/Documents/repos/tether/_INDEXER/_docs/task_hyperswarm_prod_issue
./cleanup_mongo_test_wallets.sh
```

Or manually via MongoDB:
```bash
mongosh "mongodb://localhost:27017/rumble_data_shard_wrk_data_shard_proc_shard_1" \
  --eval "db.wdk_data_shard_wallets.deleteMany({userId: 'user-123'})"
```

### Run the Test

```bash
./test_pool_destruction_v2.sh
```

### Check for the Error

Watch **Terminal 3** (data-shard-proc) for these log patterns:

**Normal operation:**
```json
{"msg":"[RPC_TRACE] Initiating RPC request to 1ab30ef0... method=queryTransfersByAddress..."}
{"msg":"[RPC_TRACE] RPC request successful to 1ab30ef0..., duration=50ms"}
```

**When pool destruction error occurs:**
```json
{"msg":"[RPC_TRACE] Initiating RPC request to 1ab30ef0... method=queryTransfersByAddress..."}
{"level":50,"msg":"[RPC_TRACE] RPC request FAILED to 1ab30ef0..., error=[HRPC_ERR]=Pool was force destroyed"}
```

## Files

- `test_pool_destruction_v2.sh` - Main test script
- `cleanup_mongo_test_wallets.sh` - MongoDB cleanup script (run before each test)
- `cleanup_test_wallets.sh` - API-based cleanup (doesn't work - no DELETE endpoint)

## Why We Need MongoDB Cleanup

The HTTP API doesn't expose a DELETE wallet endpoint in the test configuration, so we must use MongoDB directly to clean up test data between runs.

## Alternative: Use Different User IDs

Instead of cleaning up, you could modify the test to use a different userId each time by generating unique auth tokens, but that would require modifying the auth handler in the app node.
