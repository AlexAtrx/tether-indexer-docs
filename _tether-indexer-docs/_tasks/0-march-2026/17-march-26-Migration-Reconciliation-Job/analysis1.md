# Migration Reconciliation Job - Analysis

## 1. Root Cause Analysis

### 1.1 The Core Problem

Users get stuck at the loading screen post-migration because the frontend generates a wallet that doesn't match the backend record. The backend rejects the session since the wallet address doesn't align with what's stored.

Three failure modes are involved, and the current codebase contributes to all three.

---

### 1.2 Failure Mode 1: Address/Account Index Mismatch

**Where it happens in code:**

The frontend derives wallet addresses from a mnemonic + account index using HD wallet derivation (BIP-44 paths). If the frontend picks a different account index than what the backend has stored, the derived address is completely different.

In `wdk-data-shard-wrk/workers/proc.shard.data.wrk.js:169`:
```javascript
const { type, channelId, name, addresses, enabled = false, accountIndex, meta } = newWallet
const accountIndexInStr = Number.isInteger(accountIndex) ? String(accountIndex) : undefined
```

The backend stores `accountIndex` as a string. If the frontend sends a non-integer (e.g., `"0"` as a string instead of `0` as a number), `Number.isInteger()` returns false and the index is silently dropped to `undefined`. This means:
- The wallet gets created without a stored account index
- Subsequent migration attempts can't match by account index
- The frontend may re-derive with index 0 and produce a different address

**Why it's risky:** A missing or mismatched account index means different derived addresses from the same mnemonic. One character difference in the derivation path produces a completely different wallet address.

---

### 1.3 Failure Mode 2: Duplicate Address Registration (ERR_ADDRESS_ALREADY_EXISTS)

**Where it happens in code:**

There are **two layers** of address uniqueness checking that both reject migration attempts, with slightly different logic:

**Layer 1 - Ork (`wdk-ork-wrk/workers/api.ork.wrk.js:386-424`):**
```javascript
async _validateWalletExistence (wallets, options = {}) {
  // Normalizes addresses, then checks each address in lookup storage
  const existingWalletId = await this.getWalletIdByAddress({ address })
  if (existingWalletId && existingWalletId !== excludeWalletId) {
    throw new Error('ERR_ADDRESS_ALREADY_EXISTS')
  }
}
```

**Layer 2 - Shard (`wdk-data-shard-wrk/workers/proc.shard.data.wrk.js:251-271`):**
```javascript
// Checks address variants against walletRepository
const existingWalletsWithAddress = await uow.walletRepository
  .getActiveWalletsByAddresses(allVariants)
  .toArray()
if (existingWalletsWithAddress.length > 0) {
  addressConflict = true  // → ERR_WALLET_ADDRESS_ALREADY_EXISTS
}
```

**The problem for migration:** When the frontend correctly re-derives the same address the backend already has, both layers **reject** the request. The backend treats "address already exists" as an error, not as a successful reconciliation signal. **The frontend-submitted migration data is discarded with no record of what was sent.**

Additionally, the ork lookup (`@wdk-ork/wallet-id-lookups`) and the shard wallet repository may have divergent data — an address could exist in one but not the other, causing inconsistent acceptance/rejection behavior.

---

### 1.4 Failure Mode 3: User Wallet Type Already Exists

**Where it happens in code (`wdk-data-shard-wrk/workers/proc.shard.data.wrk.js:172-185`):**
```javascript
const isDup = (wallets) =>
  wallets.some(w =>
    (type === 'channel' && w.type === 'channel' && w.channelId === channelId) ||
    (type === 'user' && w.type === 'user')
  )

if (isDup(existingWallets) || isDup(newWallets)) {
  newWallets.push({ ...newWallet, status: 400, error: 'ERR_WALLET_ALREADY_EXISTS' })
  continue
}
```

**The problem:** This check blocks creating **any** new `type: 'user'` wallet if one already exists. During migration, when the frontend tries to register the re-derived wallet, this check fires first (before address comparison even happens). The migration attempt fails with `ERR_WALLET_ALREADY_EXISTS`, and again — **the frontend's addresses are never stored or compared**.

---

### 1.5 Failure Mode 4: Address Normalization Inconsistency

**Where it happens in code:**

Both ork and shard normalize addresses, but they operate on different data at different times:

**Ork normalization (`wdk-ork-wrk/workers/api.ork.wrk.js:331-348`):**
```javascript
_normalizeAddress (chain, address) {
  address = address?.trim()
  const conf = this.blockchains[chain]
  if (!conf?.caseSensitive?.address) return address.toLowerCase()
  if (conf.caseSensitive.address instanceof RegExp) {
    return conf.caseSensitive.address.test(address) ? address : address.toLowerCase()
  }
  return address
}
```

**Shard normalization (`wdk-data-shard-wrk/workers/lib/blockchain.svc.js:62-68`):**
```javascript
sanitizeInput (chain, input, type) {
  const check = this.ctx.conf.blockchains[chain]?.caseSensitive?.[type]
  if (!check || (check instanceof RegExp && !check.test(input))) {
    return input.toLowerCase()
  }
  return input
}
```

While the logic mirrors each other, the configuration can drift:
- Ork loads config at `workers/api.ork.wrk.js:29-42` and converts regex strings to RegExp
- Shard loads config independently from its own `blockchains` config section
- If these configs ever diverge (different regex patterns, missing chain entries), the same address normalizes differently at each layer

**Bitcoin is particularly fragile:** Legacy P2PKH/P2SH addresses (`^[13]...`) are case-sensitive, while bech32 (`bc1...`) is case-insensitive. The regex pattern `^[13][a-km-zA-HJ-NP-Z1-9]{25,34}$` determines which rule applies. If the frontend uses a different regex or doesn't normalize at all, addresses won't match.

---

## 2. The Fundamental Gap

**There is no migration-specific endpoint or storage.** The current `POST /api/v1/wallets` endpoint is designed for wallet creation, not reconciliation. When the frontend sends migrated addresses:

1. If addresses match (correct migration) → rejected with `ERR_WALLET_ALREADY_EXISTS` or `ERR_WALLET_ADDRESS_ALREADY_EXISTS`
2. If addresses differ (incorrect migration) → either:
   - Rejected with `ERR_WALLET_ADDRESS_ALREADY_EXISTS` (if the wrong address belongs to another user)
   - Created successfully (if the wrong address is new) — **now the user has a mismatched wallet in the backend**

In **neither case** is the frontend's submitted data preserved for comparison. The system has no memory of what the frontend tried to send.

---

## 3. Proposed Solution

### 3.1 New Migration Reconciliation Endpoint

Create a dedicated endpoint that **receives** and **stores** frontend-migrated addresses without modifying the canonical wallet data:

**`POST /api/v1/wallets/migration-reconcile`**

```
Request Body:
{
  wallets: [
    {
      accountIndex: 0,
      addresses: { ethereum: "0x...", bitcoin: "bc1q...", ... }
    }
  ]
}
```

This endpoint should:
1. Accept the frontend-generated addresses
2. Normalize them using the same `_normalizeAddress()` logic
3. Store them in a dedicated migration reconciliation table (not the main wallet table)
4. **Not** reject on duplicates — just store what the frontend sent
5. Return the reconciliation status immediately (match/mismatch/missing)

### 3.2 Migration Reconciliation Storage

**New collection/table: `migration_reconciliation`**

```
{
  id: UUID,
  userId: string,
  walletId: string,           // backend wallet ID (if matched)
  walletName: string,
  walletType: string,
  accountIndex: string,
  backendAddresses: Object,   // { chain: address } from backend
  frontendAddresses: Object,  // { chain: address } from frontend
  status: 'match' | 'mismatch' | 'missing_in_be' | 'missing_in_fe',
  mismatchedChains: [string], // which chains differ
  balances: Object,           // { chain: { backend: amount, frontend: amount } }
  createdAt: number,
  resolvedAt: number | null,
  resolution: string | null   // manual resolution notes
}
```

### 3.3 Reconciliation Job (Background)

Add a new scheduled job to the existing shard scheduler infrastructure:

**Location:** `wdk-data-shard-wrk/workers/proc.shard.data.wrk.js`

**Schedule:** Run on-demand initially, then daily (`0 3 * * *`) during the migration window.

**Job logic:**

```
1. Query all users (or a batch of users who recently migrated)
2. For each user:
   a. Get backend wallets from walletRepository
   b. Get frontend-submitted addresses from migration_reconciliation table
   c. Compare EVM address (one address comparison is sufficient per ticket)
   d. Classify: match / mismatch / missing_in_fe / missing_in_be
   e. For mismatches: fetch balances for both addresses (EVM + BTC)
      - Zero balance = low risk
      - Non-zero balance on backend address = HIGH RISK (user's funds are inaccessible)
   f. Store result in migration_reconciliation table
3. Generate aggregate metrics
```

### 3.4 Implementation Plan

#### Step 1: Storage Layer
- **File:** `wdk-data-shard-wrk/workers/lib/db/base/repositories/` — add `migration-reconciliation.js`
- MongoDB collection: `wdk_migration_reconciliation`
- Indexes: `userId`, `status`, `createdAt`

#### Step 2: Migration Reconciliation Endpoint
- **File:** `wdk-app-node/workers/lib/server.js` — add `POST /api/v1/wallets/migration-reconcile`
- Route handler normalizes addresses, fetches existing wallets, compares, stores result
- Returns immediate reconciliation status

#### Step 3: Reconciliation Job
- **File:** `wdk-data-shard-wrk/workers/proc.shard.data.wrk.js` — add to scheduler:
  ```javascript
  { name: 'migrationReconciliation', rule: '0 3 * * *', timeout: 30 * 60 * 1000 }
  ```
- Batch-process users, compare addresses, fetch balances for mismatches

#### Step 4: Metrics API
- **File:** `wdk-app-node/workers/lib/server.js` — add `GET /api/v1/admin/migration-reconciliation/metrics`
- Returns: total checked, matches, mismatches, missing, match accuracy %

#### Step 5: Balance Check for Mismatches
- For mismatched addresses, use existing balance fetch infrastructure
- EVM balances via indexer chain workers
- BTC balances via `scantxoutset` (note: fragile, per ___TRUTH.md)
- Flag high-risk users (non-zero balance on backend address that frontend can't access)

### 3.5 Files to Modify

| File | Change |
|------|--------|
| `wdk-data-shard-wrk/workers/lib/db/base/repositories/` | New `migration-reconciliation.js` repository |
| `wdk-data-shard-wrk/workers/lib/db/mongodb/repositories/` | MongoDB implementation |
| `wdk-data-shard-wrk/workers/proc.shard.data.wrk.js` | Add reconciliation job to scheduler, add `reconcileMigration()` method |
| `wdk-ork-wrk/workers/api.ork.wrk.js` | Add `reconcileMigration()` RPC action |
| `wdk-app-node/workers/lib/server.js` | Add reconciliation and metrics endpoints |
| Config files | Add reconciliation job schedule + feature flag |

### 3.6 Existing Infrastructure to Reuse

- **Scheduler:** `@bitfinex/bfx-facs-scheduler` — already used for `syncBalances`, `syncWalletTransfers`, etc.
- **Job execution pattern:** `_runJob(flag, func, timeout)` — prevents concurrent execution
- **Address normalization:** `_normalizeAddress()` / `sanitizeInput()` — use the same logic for frontend-submitted addresses
- **Balance fetching:** Existing balance sync infrastructure in shard workers
- **Wallet repository:** `getActiveUserWallets()` — fetch backend wallets for comparison

---

## 4. Immediate Quick Wins (Before Full Reconciliation Job)

### 4.1 Log Frontend Migration Attempts

Even before building the full reconciliation system, modify `POST /api/v1/wallets` to **log** (not just reject) migration attempts that fail:

```javascript
// In addWallet, when ERR_WALLET_ALREADY_EXISTS or ERR_WALLET_ADDRESS_ALREADY_EXISTS:
this.ctx.logger.warn({
  userId,
  attemptedAddresses: normalizedAddresses,
  existingWalletId: existingWallet?.id,
  existingAddresses: existingWallet?.addresses,
  error: 'MIGRATION_ADDRESS_MISMATCH',
  accountIndex: accountIndexInStr
})
```

This gives immediate visibility into migration failures via existing log infrastructure.

### 4.2 Query ERR_ADDRESS_ALREADY_EXISTS Logs

Use existing Sentry/log infrastructure to find all `ERR_WALLET_ADDRESS_ALREADY_EXISTS` errors since the migration began. Cross-reference with user IDs to identify affected users now.

---

## 5. Risk Assessment

| Risk | Severity | Mitigation |
|------|----------|------------|
| Mismatched address with non-zero balance on BE side | **Critical** — user's funds are in a wallet they can't access | Prioritize balance checks for mismatches; manual intervention for non-zero balances |
| Mismatched address with zero balance | **Low** — no fund risk | Auto-resolution: update backend to use frontend address |
| Missing in FE (backend has address, frontend didn't send) | **Medium** — user may have skipped migration step | Trigger re-migration for affected users |
| Missing in BE (frontend sent, backend doesn't have) | **Medium** — possible race condition or data loss | Investigate why the wallet was deleted/never created |
| BTC balance fetch unreliable (`scantxoutset` busy) | **Medium** — can't assess risk for BTC mismatches | Retry with backoff; flag as "balance unknown" if fetch fails |

---

## 6. Summary

The migration issue stems from a **fundamental architectural gap**: the `POST /api/v1/wallets` endpoint is designed for creation, not reconciliation. It rejects valid migration data (matching addresses) and silently discards the frontend's submission on failure. There is no mechanism to compare, record, or reconcile what the frontend derived versus what the backend stores.

The fix requires:
1. A **dedicated reconciliation endpoint** that stores frontend addresses separately
2. A **background reconciliation job** that compares and classifies
3. **Balance checking** for mismatches to assess fund risk
4. **Metrics/reporting** to monitor migration accuracy

All can be built using existing infrastructure (scheduler, repositories, normalization logic, balance fetching).
