# Test Fix Report: wdk-data-shard-wrk Unit Tests (Final)

## Summary

Fixed **6 remaining failing unit tests**. All **78/78 tests now pass**.

## Test Status

| Before     | After          |
| ---------- | -------------- |
| 72/78 pass | **78/78 pass** |

## Root Cause Analysis

### 1. Missing `blockchains` Configuration

Tests created `WrkDataShardProc` with empty config:

```javascript
{ blockchains: {}, targetCcy: 'USD' }
```

The `_walletTransferBatch` implementation stages checkpoints based on:

```javascript
const chainCcys = this.conf.blockchains?.[chain]?.ccys || [];
```

With empty `blockchains`, no checkpoints were ever staged.

### 2. Incorrect `perAddressMaxTs` Keys

Tests used fiat currency (`usd`) instead of token currency (`usdt`):

```javascript
// Wrong:
perAddressMaxTs: new Map([["ethereum:usd:0xabc", timestamp]]);
// Correct:
perAddressMaxTs: new Map([["ethereum:usdt:0xabc", timestamp]]);
```

### 3. Missing Mock Method

Two job tests lacked `walletTransferRepository.get()` which is called for deduplication checks.

## Files Modified

### `tests/unit/proc.shard.data.wrk.transfers.test.js`

- Added `blockchains: { ethereum: { ccys: ["usdt"] } }` to 4 tests
- Fixed 7 `perAddressMaxTs` keys: `ethereum:usd:...` → `ethereum:usdt:...`

### `tests/unit/proc.shard.data.wrk.jobs.test.js`

- Added `blockchains: { ethereum: { ccys: ['usdt'] } }` to 2 tests
- Added `walletTransferRepository.get: async () => null` to 2 tests

## Verification

```bash
cd wdk-data-shard-wrk
npm test
```

**Output:**

```
1..78
# tests = 78/78 pass
# asserts = 360/360 pass
# ok
```

## Notes

- No production code was modified—only test configurations
- Original RPC `CHANNEL_CLOSED` fixes from previous tasks remain intact
- Tests follow the `tether-svc-test-helper` pattern as documented in the ticket
