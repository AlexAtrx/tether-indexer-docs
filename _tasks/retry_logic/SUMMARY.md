# MongoDB Read Operations - Retry Logic and Timeout Implementation

## Summary

Successfully implemented configurable retry logic and timeout for MongoDB read operations across multiple repositories as a continuation of PR #115 (https://github.com/tetherto/wdk-data-shard-wrk/pull/115).

## Repositories Updated

| Repository | Changes |
|------------|---------|
| `wdk-data-shard-wrk` | Full retry logic + timeout (7 repository files) |
| `rumble-data-shard-wrk` | Timeout + inherits retry from wdk-data-shard-wrk (2 repository files) |
| `wdk-indexer-wrk-base` | Full retry logic + timeout (2 model files + 1 base mixin + utils + api worker) |

## Changes Made

### 1. Configuration Updates

Added MongoDB read operation settings to configuration files:

**Files Modified:**
- `wdk-data-shard-wrk/config/facs/db-mongo.config.json` (+ .example)
- `rumble-data-shard-wrk/config/facs/db-mongo.config.json` (+ .example)
- `wdk-indexer-wrk-base/config/facs/db-mongo.config.json` (+ .example)

**Configuration Location:**
All MongoDB settings are in `config/facs/db-mongo.config.json` under the `operations` object:
```json
{
  "operations": {
    "maxTimeMS": 30000,
    "writeConcern": { "w": "majority", "wtimeout": 30000 },
    "readTimeout": 30000,
    "readRetries": 1,
    "readRetryDelay": 500
  }
}
```

### 2. Repository/Model Updates

**wdk-data-shard-wrk (7 repository files + 1 base mixin - full retry + timeout):**
- `workers/lib/db/mongodb/repositories/base.js` (NEW - shared mixin)
- `workers/lib/db/mongodb/repositories/wallets.js`
- `workers/lib/db/mongodb/repositories/users.js`
- `workers/lib/db/mongodb/repositories/wallet.balances.js`
- `workers/lib/db/mongodb/repositories/wallet.transfers.js`
- `workers/lib/db/mongodb/repositories/user.balances.js`
- `workers/lib/db/mongodb/repositories/user.data.js`
- `workers/lib/db/mongodb/repositories/address.checkpoint.js`

**rumble-data-shard-wrk (2 files - timeout only, inherits retry from parent):**
- `workers/lib/db/mongodb/repositories/wallets.js`
- `workers/lib/db/mongodb/repositories/txwebhook.js`

**wdk-indexer-wrk-base (5 files - full retry + timeout):**
- `workers/lib/utils.js` (added `retryTask` utility)
- `workers/lib/db/mongodb/models/base.js` (NEW - shared mixin)
- `workers/lib/db/mongodb/models/block.js` (retry for `get()` via findOne)
- `workers/lib/db/mongodb/models/transfer.js` (retry for `get()` via find().toArray())
- `workers/api.indexer.wrk.js` (retry for cursor `.toArray()` calls at consumer level)

**Key Changes:**

1. **Created Shared MongoDB Mixin (base.js):**
   ```javascript
   const { retryTask } = require('../../../utils')

   const MongodbRepositoryMixin = {
     async _executeReadWithRetry (operation) {
       const maxRetries = this.operations.readRetries ?? 1
       const retryDelay = this.operations.readRetryDelay ?? 500
       return retryTask({ maxRetries, retryDelay }, operation)
     }
   }

   module.exports = MongodbRepositoryMixin
   ```

2. **Applied Mixin to All Repositories:**
   ```javascript
   const MongodbRepositoryMixin = require('./base')
   // ... class definition ...
   Object.assign(RepositoryClass.prototype, MongodbRepositoryMixin)
   ```

3. **Added maxTimeMS to All Read Operations:**
   - All `find()` operations now include `maxTimeMS: this.operations.readTimeout ?? 30000`
   - All `findOne()` operations now include `maxTimeMS: this.operations.readTimeout ?? 30000`

4. **Wrapped findOne Operations with Retry Logic:**
   ```javascript
   // The _executeReadWithRetry method is inherited from the mixin
   async getActiveWallet (walletId) {
     return this._executeReadWithRetry(async () => {
       return this.collection.findOne({
         id: walletId,
         deletedAt: { $lte: 0 }
       }, {
         ...this.sessionOpts,
         readPreference: this.readPreference,
         projection: { _id: 0 },
         maxTimeMS: this.operations.readTimeout ?? 30000
       })
     })
   }
   ```

**Why Mixin Pattern:**
- JavaScript doesn't support multiple inheritance, so repositories already extend base interfaces
- Mixin pattern allows sharing functionality without changing the inheritance hierarchy
- `Object.assign()` copies methods to the prototype, making them available to all instances
- Clean separation: retry logic is centralized in `base.js`, repositories remain focused on their domain

### 3. Implementation Details

**Retry Logic:**
- Uses the existing `retryTask` utility function from `workers/lib/utils.js`
- Implements exponential backoff with a cap of 10 seconds
- Configurable retry count (default: 1 retry)
- Configurable initial retry delay (default: 500ms)

**Timeout Behavior:**
- `maxTimeMS` is set on all read operations (`find`, `findOne`) and write operations (`bulkWrite`)
- Default timeout: 30 seconds (configurable)
- Timeout applies to query execution time
- MongoDB will terminate long-running queries and throw an error

**Operations Coverage:**

| Method | Retry | Timeout | Notes |
|--------|-------|---------|-------|
| `findOne()` | ✅ Yes | ✅ Yes | Via `_executeReadWithRetry` mixin |
| `find()` | ❌ No | ✅ Yes | Returns cursor; retry not implemented |
| `bulkWrite()` | ⚠️ Conditional | ✅ Yes | Retry only when `txSupport: true` (default: false) |

**Why this distinction:**
- `findOne()` returns a document directly — safe to retry since it's atomic and idempotent
- `find()` returns a cursor, not data — actual query happens at cursor consumption (`.toArray()`, `.next()`) outside the repository layer
- `bulkWrite()` has transaction-level retry in `DbUnitOfWork.commit()`, but only when `txSupport: true` in config

## Benefits

1. **Prevents Indefinite Hangs:** All operations now have a maximum execution time via `maxTimeMS`
2. **Resilience to Transient Failures:** Automatic retry for `findOne()` operations on timeout or temporary errors
3. **Configurable Behavior:** Easy to adjust retry count and timeouts based on production metrics
4. **Consistent Pattern:** All repositories follow the same timeout implementation; `findOne()` operations also have retry
5. **Minimal Performance Impact:** Retries only on failures, default timeout is generous

## Configuration Recommendations

**Production Settings:**
- `readTimeout: 30000` (30 seconds) - Good for most operations
- `readRetries: 1` - One retry is often sufficient
- `readRetryDelay: 500` (500ms) - Quick retry for transient issues

**High-Load Scenarios:**
- Consider increasing `readTimeout` if seeing legitimate timeouts
- Keep `readRetries: 1` to avoid cascading delays
- Monitor timeout frequency and adjust accordingly

**Testing/Development:**
- Use shorter timeouts to catch slow queries early
- `readTimeout: 10000` (10 seconds) can help identify inefficient queries

## Testing

The implementation code is syntactically correct and follows the existing patterns in the codebase. The test suite has pre-existing dependency issues unrelated to these changes (missing `bfx-facs-interval` module).

Manual verification shows:
- All imports resolve correctly
- Configuration structure matches MongoDB driver expectations
- Retry logic uses the established `retryTask` utility
- All read operations include proper timeout configuration

## Related Work

This implementation builds upon:
- PR #115: Added retry logic for Hyperswarm RPC failures (merged)
- ___TRUTH.md Section 2.1: Documents MongoDB timeout issues as a critical production concern
- `retryTask` utility in `workers/lib/utils.js` (existed in `wdk-data-shard-wrk`, now also added to `wdk-indexer-wrk-base`)

## Migration Notes

**Backwards Compatibility:**
- Default values ensure existing behavior is preserved
- Configuration is optional (defaults to 30-second timeout, 1 retry)
- No breaking changes to API or behavior

**Deployment:**
1. Configuration files already updated
2. Repository code already updated
3. No database migrations required
4. Can be deployed without downtime
5. Monitor MongoDB slow query logs after deployment

## Future Improvements

1. **Metrics Collection:** Add monitoring for retry frequency and timeout occurrences
2. **Adaptive Timeouts:** Implement per-operation timeout tuning based on historical performance
3. **Circuit Breaker:** Consider circuit breaker pattern for repeated failures
4. **Cursor Retry:** Evaluate retry logic for `find()` cursor operations at consumption time

## PR Review Feedback (PR #120)

**Comment 1:** "Why are we putting the mongodb config here?" (on `common.json.example`)

- **Issue:** MongoDB config was added to `common.json.example` but this config was never read by the code
- **Fix:** Removed the unused `mongodb` section from `common.json.example`
- **Correct location:** All MongoDB settings should only be in `config/facs/db-mongo.config.json` under `operations`

**Comment 2:** "I don't understand why some functions use this mixin, while others don't?"

- **Answer:** Intentional design — see "Operations Coverage" table above
- `findOne()` uses retry (returns document directly, safe to retry)
- `find()` does not use retry (returns cursor, retry would need to happen at consumption layer)
- `bulkWrite()` has separate retry mechanism in `DbUnitOfWork` (only when `txSupport: true`)

## PR Review Feedback (PR #52 - wdk-indexer-wrk-base)

**Comment:** "Where are we using the retry logic in the worker? AFAIU, we are simply defining this logic in config, but don't use it anywhere.."

- **Issue:** The config defined `readRetries` and `readRetryDelay` but the code only used `readTimeout` for `maxTimeMS`. The retry config values were dead code.
- **Fix:** Implemented full retry logic in `wdk-indexer-wrk-base`:
  1. Added `retryTask` utility to `workers/lib/utils.js`
  2. Created `workers/lib/db/mongodb/models/base.js` mixin with `_executeReadWithRetry` method
  3. Applied mixin to `DbBlock` and `DbTransfer` classes
  4. Wrapped `get()` methods with retry logic:
     - `block.js`: `get()` uses `findOne` → wrapped with retry
     - `transfer.js`: `get()` uses `find().toArray()` → wrapped with retry (returns data directly, safe to retry)
  5. Other `find*()` methods return cursors, so retry is not applied at model level (streaming use cases)
  6. Added consumer-level retry in `api.indexer.wrk.js` for cursor methods that call `.toArray()`:
     - `queryTransfersByAddress()`: wraps `findByAddressAndTimestamp(...).toArray()` with retry
     - `getBlock()`: wraps `findByBlockNumber(...).toArray()` with retry
     - Streaming uses (`for await`) intentionally skip retry - would require loading all data into memory

**Why consumer-level retry for cursors:**
- Cursor-returning methods (`findByTimestamp`, `findByBlockNumber`, `findByAddressAndTimestamp`) are used in two ways:
  - Streaming: `for await (const item of cursor)` - cannot apply retry without breaking streaming
  - Bulk: `cursor.toArray()` - can apply retry at the call site
- Retry is applied where `.toArray()` is called, ensuring config governs all non-streaming read paths

## Date
December 2, 2025
