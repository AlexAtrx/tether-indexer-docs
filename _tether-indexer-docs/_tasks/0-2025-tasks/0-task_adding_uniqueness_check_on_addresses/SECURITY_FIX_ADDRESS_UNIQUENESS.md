This is implemented mainly in the repo wdk-ork-wrk, secondarily in wdk-data-shard-wrk.

# Security Fix: Address Uniqueness Validation (Option 2 - Local Normalization)

## Summary
Fixed critical security vulnerability where attackers could bypass address uniqueness checks by using different casing (e.g., `0xABC...` vs `0xabc...`), allowing duplicate wallet creation and address-collision attacks.

## Vulnerability Details

**Before Fix:**
- `_validateWalletExistence` checked raw addresses from HTTP payload before normalization
- Addresses were only normalized later in data-shard worker (`blockchainSvc.sanitizeInput`)
- Attacker could submit same address with different casing to bypass validation
- Result: Duplicate wallet created, Autobase mapping overwritten, transactions redirected

**Attack Scenario:**
```javascript
// Wallet A created with: { ethereum: "0xabcdef..." }
// Wallet B attempts:     { ethereum: "0xABCDEF..." }
// Before fix: Validation passes ❌ → duplicate created
// After fix:  Validation fails ✅ → ERR_ADDRESS_ALREADY_EXISTS
```

## Solution Implemented: Option 2 (Local Normalization)

### Why Option 2?
- ✅ **Fail-closed by design** - No RPC dependency, always available
- ✅ **No security degradation** - Cannot be bypassed during service issues
- ✅ **Fast** - No network overhead, synchronous operation
- ✅ **Independent** - ork-wrk doesn't depend on data-shard availability
- ✅ **Simple** - ~50 lines of stable, well-tested code
- ❌ Code duplication acceptable for security-critical paths

### Changes Made

#### 1. Added `_normalizeAddress` Method (lines 220-243)
```javascript
_normalizeAddress (chain, address) {
  if (!address || typeof address !== 'string') return address
  address = address.trim()
  
  // Case-sensitive chains: bitcoin, solana, ton, tron
  const caseSensitiveChains = ['bitcoin', 'solana', 'ton', 'tron']
  if (caseSensitiveChains.includes(chain?.toLowerCase())) {
    return address
  }
  
  // All other chains (EVM, etc.): lowercase
  return address.toLowerCase()
}
```

**Logic matches data-shard's `blockchainSvc.sanitizeInput`:**
- Bitcoin, Solana, TON, Tron: Preserve case
- Ethereum, Arbitrum, Polygon, Spark: Lowercase

#### 2. Added `_normalizeWalletAddresses` Method (lines 245-270)
```javascript
_normalizeWalletAddresses (wallets) {
  return wallets.map(wallet => {
    const normalizedAddresses = {}
    for (const [chain, address] of Object.entries(wallet.addresses)) {
      normalizedAddresses[chain] = this._normalizeAddress(chain, address)
    }
    return { ...wallet, addresses: normalizedAddresses }
  })
}
```

#### 3. Updated `_validateWalletExistence` (lines 272-316)
- Now calls `_normalizeWalletAddresses` locally (no RPC)
- Validates normalized addresses against Autobase
- Removed `userId` parameter dependency
- Returns normalized wallets to caller

#### 4. Updated `addWallet` (line 320)
```javascript
// Before: await this._validateWalletExistence(req.wallets, { userId: req.userId })
// After:  await this._validateWalletExistence(req.wallets)
```

#### 5. Updated `updateWallet` (lines 354-356)
```javascript
// Before: { userId: req.userId, excludeWalletId: req.id }
// After:  { excludeWalletId: req.id }
```

## Security Validation

### Test Coverage
Created `tests/address-normalization.test.js` with 7 test suites, 20 assertions:
- ✅ EVM chains (lowercase)
- ✅ Case-sensitive chains (preserve case)
- ✅ Whitespace trimming
- ✅ Edge cases (null/undefined)
- ✅ Multiple chains
- ✅ **Security test: case-sensitivity bypass prevented**
- ✅ Empty/invalid inputs

**All tests pass** ✓

### Attack Prevention Verified
```javascript
test('_normalizeWalletAddresses - Security: case-sensitivity bypass prevented', (t) => {
  const existingWallet = [{ addresses: { ethereum: '0xabcdef123456' } }]
  const attackerWallet = [{ addresses: { ethereum: '0xABCDEF123456' } }]
  
  const normalizedExisting = wrk._normalizeWalletAddresses(existingWallet)
  const normalizedAttacker = wrk._normalizeWalletAddresses(attackerWallet)
  
  // Both normalize to '0xabcdef123456' → duplicate detected ✓
  t.is(normalizedExisting[0].addresses.ethereum, normalizedAttacker[0].addresses.ethereum)
})
```

## Deployment Checklist

- [x] Code implementation complete
- [x] Unit tests written and passing
- [x] Syntax validated
- [x] No RPC dependency (fail-closed)
- [ ] Integration testing on staging
- [ ] Verify with mixed-case addresses on all chains
- [ ] Monitor for `ERR_ADDRESS_ALREADY_EXISTS` after deployment
- [ ] Audit existing data for duplicates (see migration: `2025-01-27_10-01-00_remove-duplicate-ton-addresses.js`)

## Files Modified

1. `wdk-ork-wrk/workers/api.ork.wrk.js` - Core security fix
2. `wdk-ork-wrk/tests/address-normalization.test.js` - Test coverage (new)
3. `wdk-ork-wrk/SECURITY_FIX_ADDRESS_UNIQUENESS.md` - This document (new)

## Inherited by Rumble

The Rumble extension (`rumble-ork-wrk`) inherits from `wdk-ork-wrk` and doesn't override these methods, so the security fix automatically applies to the Rumble wallet application.

## References

- Task document: `_docs/tasks/adding_uniqueness_check_on_addresses.md`
- Related ticket: `_docs/_tickets/Ensure-uniqueness_of_addresses_in_wallet_creation_or_update.md`
- Migration evidence: `rumble-data-shard-wrk/migrations/2025-01-27_10-01-00_remove-duplicate-ton-addresses.js`
- Blockchain config: `wdk-data-shard-wrk/config/common.json.example` (lines 16-24)
- Original sanitization logic: `wdk-data-shard-wrk/workers/lib/blockchain.svc.js:sanitizeInput` (lines 61-67)

## Risk Assessment

**Before Fix:** ⚠️ **CRITICAL** - Active exploitation possible via case-sensitivity bypass  
**After Fix:** ✅ **LOW** - Address uniqueness enforced at validation layer with canonical comparison

**Additional Hardening (Optional):**
- Database-level unique constraint on normalized addresses
- Rate limiting on wallet creation attempts
- Alerting on `ERR_ADDRESS_ALREADY_EXISTS` spikes

---

**Date:** November 19, 2025  
**Implemented by:** Option 2 (Local Normalization)  
**Status:** ✅ Ready for staging deployment
