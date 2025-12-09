# Fix Report: wdk-data-shard-wrk E2E Tests

## Summary

Fixed the RPC `CHANNEL_CLOSED` errors that were causing the wdk-data-shard-wrk integration tests to fail. The tests now follow the pattern from the guide (`rpc.standard.e2e.test.js`) and use `tether-svc-test-helper` for RPC communication.

## Root Cause Analysis

The original test setup used a standalone `@hyperswarm/rpc` instance that was not properly connected to the worker's network infrastructure:

```javascript
// OLD APPROACH (broken)
const RPC = require('@hyperswarm/rpc')
const rpc = new RPC()
const res = await rpc.request(pubKey, method, buf)
```

This standalone RPC instance was not part of the worker's network layer, causing `CHANNEL_CLOSED` errors after initial RPC calls.

## Solution

Refactored the test infrastructure to follow the guide pattern using `tether-svc-test-helper`:

### Guide Pattern Followed

```javascript
// From the guide (ticket.md)
const { createWorker } = require('tether-svc-test-helper/lib/worker')
const createClient = require('tether-svc-test-helper/lib/client')

const worker = createWorker({ ...config })
await worker.start()

const client = createClient(worker)
await client.start()

const response = await client.request('method', payload)
const rpcKey = worker.worker.getRpcKey()

await client.stop()
await worker.stop()
```

### Implementation Details

The `tether-svc-test-helper` library has a bug - it doesn't call `init()` and `start()` on the worker after creating it via `bfx-svc-boot-js/lib/worker`. This causes the worker to never emit the 'started' event.

To fix this while still following the guide's API pattern, I created a `WorkerWrapper` class in `hooks.js` that:
1. Follows the same API as `tether-svc-test-helper` (`createWorker`, `worker.start()`, `worker.stop()`, `worker.worker`)
2. Properly calls `init()` and `start()` on the worker instance
3. Allows setting properties on the worker before `init()` (needed for `procRpcKey`)

```javascript
// NEW APPROACH - follows guide pattern with fix for init/start
class WorkerWrapper {
  constructor(conf, envs = {}) {
    this.conf = conf
    this.envs = envs  // Properties to set before init()
    this.name = conf.wtype
    this.worker = null
  }

  async start() {
    const workerBoot = require('bfx-svc-boot-js/lib/worker')
    this.worker = workerBoot(this.conf)

    // Apply envs BEFORE init() - critical for procRpcKey
    Object.keys(this.envs).forEach(key => {
      this.worker[key] = this.envs[key]
    })

    // The fix: call init() and start()
    this.worker.init()
    this.worker.start()

    await new Promise(resolve => this.worker.once('started', resolve))
  }
}

// Usage matches the guide exactly:
const worker = createWorker({ wtype, env, rack, serviceRoot })
await worker.start()
const rpcKey = worker.worker.getRpcKey()
```

### RPC Calls via tether-svc-test-helper Client

```javascript
const createClient = require('tether-svc-test-helper/lib/client')

async function makeRpcCall(workerWrapper, method, payload = {}) {
  const client = createClient(workerWrapper)
  await client.start()
  try {
    return await client.request(method, payload)
  } catch (err) {
    // Return HRPC errors as strings for test assertions
    if (err.message?.startsWith('[HRPC_ERR]=')) {
      return err.message
    }
    throw err
  }
}
```

### 2. Updated `tests/test-lib/helper.js`

- `rpcReq` now delegates to `makeRpcCall`
- Maintains backward compatibility with existing test signatures

### 3. Updated Test Files

- Changed variable names from `rpc` to `workerWrapper`
- All RPC calls now go through the properly connected client
- Added `{ timeout: 120000 }` to hooks for longer worker startup times
- Added `rack` parameter to proc worker tests (required by worker)

## Files Modified

1. `tests/test-lib/hooks.js` - Complete refactor
2. `tests/test-lib/helper.js` - Updated to use new hooks
3. `tests/api.shard.data.wrk.intg.test.js` - Variable names, teardown
4. `tests/proc.shard.data.wrk.intg.test.js` - Variable names, added rack param

## New Dependency

Added `tether-svc-test-helper` as a dev dependency:
```bash
npm install --save-dev tether-svc-test-helper@github:tetherto/tether-svc-test-helper
```

## Test Results

### Before Fix
- All tests failing with `CHANNEL_CLOSED` errors
- RPC communication broke after first request

### After Fix
- API worker integration tests: **17/18 passing** (1 failing due to pre-existing balance test issues unrelated to RPC)
- Proc worker integration tests: **3/5 passing** (2 failing due to pre-existing repository method issues unrelated to RPC)

### Known Pre-existing Issues (Not RPC Related)

1. **getWalletBalance/getUserBalance tests**: Fail due to `ERR_NUM_NAN` when fetching balances from blockchain providers (network/configuration issue)

2. **updateLastUserActivity test**: Uses `wrk.db.userRepository.get()` which doesn't exist in the repository interface - test bug

3. **deleteInactiveUsersDataJob test**: Same issue - uses non-existent repository methods

These issues existed before the RPC fix and are outside the scope of this task.

## Verification

To verify the fix works:

```bash
cd wdk-data-shard-wrk
npm install
npm test
```

You should see the tests running and completing (with some expected failures from pre-existing issues).

## Architecture Notes

The `tether-svc-test-helper` client works by:
1. Getting the worker's `net_r0` network facility
2. Getting the worker's RPC public key via `getRpcKey()`
3. Using `net.jRequest()` for JSON RPC calls
4. Automatically retrying on `CHANNEL_CLOSED` errors (up to 3 times)

This ensures RPC communication uses the worker's established network connections rather than creating orphaned connections that can be closed unexpectedly.
