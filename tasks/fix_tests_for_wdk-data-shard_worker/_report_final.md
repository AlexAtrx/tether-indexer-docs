# Test Fix Report for wdk-data-shard-wrk

## Summary

This report documents the fixes applied to the wdk-data-shard-wrk test suite to address test failures. The work focused on fixing integration tests and unit tests.

## Root Causes Identified

### 1. Database State Persistence Between Test Runs
**Problem**: The hyperdb database stored in the `store/` directory persisted between test runs, causing tests to fail with `ERR_WALLET_ALREADY_EXISTS` errors when attempting to create wallets that already existed.

**Fix**: Added `cleanupPreviousRun()` function in `tests/test-lib/hooks.js` that removes the `store/` directory at the start of each test run.

### 2. Sinon Stub Argument Mismatch
**Problem**: The blockchain service's `_rpcCall` method adds a `traceId` to the payload before calling `jTopicRequest`:
```javascript
const payloadWithTraceId = { traceId: getTraceId(), ...payload }
return ctx.net_r0.jTopicRequest(topic, method, payloadWithTraceId, opts, cached)
```

The test stubs were using exact argument matching without accounting for `traceId`, causing stubs to not match and return `undefined`.

**Fix**: Changed all stub argument matching from exact objects to partial matching using `sinon.match.has()`:
```javascript
// Before (fails):
.withArgs('ethereum:usdt', 'getBalance', { address: ethAddress })

// After (works):
.withArgs('ethereum:usdt', 'getBalance', sinon.match.has('address', ethAddress))
```

### 3. Incorrect Repository Method Names
**Problem**: Test code called non-existent methods like `userDataRepository.get()` and `userRepository.get()`.

**Fix**: Updated to use correct method names:
- `userDataRepository.get({ userId, key })` → `userDataRepository.getUserData(userId, key)`
- `userRepository.findOne()` → Direct database query via `wrk.db.db.findOne()`

### 4. Schema Field Name Mismatch
**Problem**: Test data used `fiatCurrency: null` but the hyperdb schema uses `fiatCcy`.

**Fix**: Changed `fiatCurrency` to `fiatCcy` in test data objects.

### 5. Missing Schema Fields
**Problem**: Test data objects were missing the `label` field which is returned by the database.

**Fix**: Added `label: null` to wallet transfer test objects.

### 6. Unique Test Data
**Problem**: The `proc.shard.data.wrk.intg.test.js` file used the same test data (user IDs, channel IDs, addresses) as `api.shard.data.wrk.intg.test.js`, causing conflicts.

**Fix**: Updated proc test data to use unique identifiers (e.g., `proc-test-user-1234`, `proc-channel-123`, etc.).

## Files Modified

1. **tests/test-lib/hooks.js**
   - Added `cleanupPreviousRun()` function
   - Added `fs` module import
   - Call cleanup in `setupHook()`

2. **tests/api.shard.data.wrk.intg.test.js**
   - Updated all `jTopicRequest` stubs to use `sinon.match.has()`

3. **tests/proc.shard.data.wrk.intg.test.js**
   - Updated test data to use unique identifiers
   - Fixed `userRepository.findOne()` → `wrk.db.db.findOne()`
   - Fixed `userDataRepository.get()` → `userDataRepository.getUserData()`
   - Changed `fiatCurrency` → `fiatCcy`
   - Added missing `label` field

4. **tests/unit/lib/blockchain.svc.unit.test.js**
   - Updated all `jTopicRequest` stubs to use `sinon.match.has()`

## Test Results

### Before Fixes
- Multiple test failures due to:
  - `ERR_WALLET_ALREADY_EXISTS` errors
  - `ERR_NUM_NAN` errors (from undefined stub returns)
  - `TypeError: ... is not a function` errors

### After Fixes
- **Integration tests**: 25/25 passing (including 1 skipped)
- **Unit tests (api.shard.data.wrk.unit.test.js)**: All passing
- **Unit tests (blockchain.svc.unit.test.js)**: 53 passing

## Remaining Issues

There are 6 failing tests in `proc.shard.data.wrk.unit.test.js` related to `syncWalletTransfersJob`:
- Test 65: `syncWalletTransfersJob writes and API sub-db can read`
- Test 66: `syncWalletTransfersJob writes for multiple wallets`
- Test 68: `wallet transfer batch emits only for newly inserted transfers`
- Test 71: `wallet transfer batch commits checkpoints before emitting and logs listener failures`
- Test 72: `wallet transfer batch advances checkpoints alongside intermediate transfer commits`
- Test 73: `checkpoint failure rolls back transfer and succeeds on retry without dupes`

These appear to be pre-existing test failures unrelated to the RPC/stub issues fixed above. They involve the wallet transfer synchronization job functionality and require separate investigation.

## Recommendations

1. **For the remaining 6 failing tests**: These tests appear to have issues with the `syncWalletTransfersJob` implementation or test setup. A deeper investigation is needed to understand if this is a bug in the test or the implementation.

2. **Best Practice**: Consider adding a `pretest` npm script that cleans the `store/` directory automatically:
   ```json
   "pretest": "rm -rf store"
   ```

3. **Stub Pattern**: All future RPC stub setups should use `sinon.match.has()` to account for dynamic fields like `traceId`.
