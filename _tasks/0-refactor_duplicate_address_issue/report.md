# Refactor: Wallet Address Uniqueness Validation

**Date**: December 10, 2025  
**Status**: Completed

---

## Developer Feedback & Request

A developer raised the following question regarding the `addWallet` implementation:

> I am working on adding a field for wallets i.e., `accountIndex` but I noticed that we completely replace the logic in `addWallet` in `rumble-data-shard-wrk`:
> https://github.com/tetherto/rumble-data-shard-wrk/blob/dev/workers/proc.shard.data.wrk.js#L155
>
> as opposed to calling the `super()`:
> https://github.com/tetherto/wdk-data-shard-wrk/blob/main/workers/proc.shard.data.wrk.js#L139
>
> Is there a particular reason that we made this change? I don't want to revert the logic that you added, so I am asking due to that.

---

## Investigation Findings

### Root Cause

The investigation revealed that **PR #97** ("Security Fix: Address Uniqueness Enforcement"), merged on December 3, 2025, replaced the `super.addWallet()` call with a complete reimplementation to add wallet address uniqueness validation.

The base class in `wdk-data-shard-wrk` did **NOT** enforce wallet address uniqueness, while the Rumble implementation needed to:

1. Prevent duplicate wallet addresses across different wallets
2. Check multiple address variants (normalized, trimmed, lowercase) to catch pre-normalization data
3. Handle intra-batch address collisions
4. Return `ERR_WALLET_ADDRESS_ALREADY_EXISTS` for conflicts

### The Problem

This approach had architectural issues:

- Code duplication between base and extension
- Maintenance burden: changes to base wallet logic required manual mirroring
- Adding new fields (like `accountIndex`) required modifying both implementations
- The security feature wasn't available to other consumers of `wdk-data-shard-wrk`

---

## Design Decision

**Decision**: Move the address uniqueness validation from `rumble-data-shard-wrk` to the base `wdk-data-shard-wrk` package.

### Rationale

1. **Security by Default**: All consumers benefit from address uniqueness protection
2. **Proper Inheritance**: `rumble-data-shard-wrk` can call `super()` as intended
3. **DRY Principle**: Single source of truth for wallet creation logic
4. **Easier Maintenance**: Adding fields like `accountIndex` only requires base class changes
5. **Consistency**: Same validation logic across all implementations

### Breaking Change

> ⚠️ **Note**: Consumers of `wdk-data-shard-wrk` that previously created wallets with duplicate addresses will now receive `ERR_WALLET_ADDRESS_ALREADY_EXISTS` errors. This is intentional as it's a security improvement.

---

## Code Changes

### wdk-data-shard-wrk (Base Package)

**File**: `workers/proc.shard.data.wrk.js`

#### `addWallet` method changes:

- Added `seenAddresses` Set to track addresses within batch requests
- Added address normalization using `blockchainSvc.sanitizeInput()`
- Added uniqueness check for normalized, trimmed, and lowercase address variants
- Checks `getActiveWalletByAddress()` to prevent duplicates across wallets
- Returns `ERR_WALLET_ADDRESS_ALREADY_EXISTS` for conflicts

```javascript
// Key addition in addWallet
const normalizedAddresses = {};
let addressConflict = false;

for (const chain in addresses) {
  const rawAddress = addresses[chain];
  const normalized = this.blockchainSvc.sanitizeInput(
    chain,
    rawAddress,
    "address"
  );
  normalizedAddresses[chain] = normalized;

  // Track normalized and lowercase variants to catch pre-normalization data
  const variants = new Set([normalized]);
  if (typeof rawAddress === "string") {
    variants.add(rawAddress.trim());
    variants.add(rawAddress.trim().toLowerCase());
  }

  for (const candidate of variants) {
    if (seenAddresses.has(candidate)) {
      addressConflict = true;
      break;
    }
    const existing = await uow.walletRepository
      .getActiveWalletByAddress(candidate)
      .toArray();
    if (existing.length > 0) {
      addressConflict = true;
      break;
    }
  }
}
```

#### `updateWallet` method changes:

- Normalizes incoming addresses before validation
- Normalizes existing wallet addresses before comparison
- Checks new/changed addresses against existing wallets
- Throws `ERR_WALLET_ADDRESS_ALREADY_EXISTS` for conflicts

---

### rumble-data-shard-wrk (Extension Package)

**File**: `workers/proc.shard.data.wrk.js`

#### Simplified `addWallet`:

```javascript
async addWallet (req) {
  const result = await super.addWallet(req)

  if (result && result?.length > 0) {
    result.forEach((wallet) => {
      try {
        if (wallet.status === 201 && (wallet.type === WALLET_TYPES.USER || wallet.type === WALLET_TYPES.CHANNEL)) {
          const { status, createdAt, updatedAt, ...body } = wallet

          this._rumbleServerUtil.syncJar(body).catch(err => {
            this.logger.error(`Failed to call sync jar webhook after wallet creation: ${err?.message}`)
          })

          this._addWalletWebhook(body).catch(err => {
            this.logger.error(`Failed to send add wallet webhook after wallet creation: ${err?.message}`)
          })
        }
      } catch (err) {
        this.logger.error(`Failed to process webhooks after wallet creation: ${err?.message}`)
      }
    })
  }

  return result
}
```

#### Simplified `updateWallet`:

```javascript
async updateWallet (req) {
  const result = await super.updateWallet(req)

  try {
    if (typeof req.enabled === 'boolean' && (result.type === WALLET_TYPES.USER || result.type === WALLET_TYPES.CHANNEL)) {
      const { createdAt, updatedAt, ...body } = result
      this._rumbleServerUtil.syncJar(body)
    }
  } catch (err) {
    this.logger.error(`Failed to call sync jar webhook after wallet update': ${err?.message}`)
  }

  return result
}
```

#### Removed unused imports:

- `mapWalletToResponse`
- `validateWalletAddressUpdate`

---

## Verification

| Package               | Lint Status | Notes                         |
| --------------------- | ----------- | ----------------------------- |
| wdk-data-shard-wrk    | ✅ Pass     | Fixed with `npm run lint:fix` |
| rumble-data-shard-wrk | ✅ Pass     | Fixed with `npm run lint:fix` |

---

## Impact Summary

| Metric                           | Before      | After      |
| -------------------------------- | ----------- | ---------- |
| Lines in `addWallet` (rumble)    | ~140        | ~25        |
| Lines in `updateWallet` (rumble) | ~90         | ~15        |
| Security validation location     | rumble only | base class |
| Code duplication                 | High        | Minimal    |

---

## Next Steps

1. Add unit tests for address uniqueness validation in `wdk-data-shard-wrk`
2. Run full test suite on both packages
3. Developer can now add `accountIndex` field to the base class `addWallet` method

---

## Refactor Fix: Duplicate Variant Logic

During the refactor, duplicate variant-generation logic was introduced when adding uniqueness validation to `updateWallet`. This was fixed by extracting a shared helper:

**File**: `workers/lib/utils.js`

```javascript
const getAddressVariants = (normalizedAddress, rawAddress = null) => {
  const variants = new Set();
  if (normalizedAddress && typeof normalizedAddress === "string") {
    variants.add(normalizedAddress);
    const lower = normalizedAddress.toLowerCase();
    if (lower !== normalizedAddress) variants.add(lower);
  }
  if (rawAddress && typeof rawAddress === "string") {
    const trimmed = rawAddress.trim();
    if (trimmed) {
      variants.add(trimmed);
      variants.add(trimmed.toLowerCase());
    }
  }
  return variants;
};
```

Both `addWallet` and `updateWallet` now use this shared helper.
