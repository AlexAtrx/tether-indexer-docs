# Migration Reconciliation Job - Final Analysis

---

## 1. The Problem

Users get stuck at the loading screen post-migration. The frontend recreates wallets locally from the user's mnemonic, then sends the derived addresses to the backend. The backend either rejects them or creates a mismatched record. In both cases, the frontend's submitted data is silently discarded — there is no durable record of what the frontend tried to send, and no mechanism to compare it against the backend's canonical state.

The backend wallet APIs are designed for canonical write-once storage, not for observational reconciliation. This is the root gap.

---

## 2. How The Current Backend Blocks Migration

### 2.1 Wallet creation rejects migration data

`POST /api/v1/wallets` routes through `addWallet()` which enforces strict uniqueness constraints. During migration, every one of these constraints fires before any comparison can happen:

**Constraint 1 — One user wallet per user**
`wdk-data-shard-wrk/workers/proc.shard.data.wrk.js:172-185`
```javascript
const isDup = (wallets) =>
  wallets.some(w =>
    (type === 'channel' && w.type === 'channel' && w.channelId === channelId) ||
    (type === 'user' && w.type === 'user')
  )
```
If a `type: 'user'` wallet already exists, the request is rejected with `ERR_WALLET_ALREADY_EXISTS` before addresses are even compared.

**Constraint 2 — Account index uniqueness**
`wdk-data-shard-wrk/workers/proc.shard.data.wrk.js:216-228`
```javascript
const isDupAccountIndex = (wallets) =>
  wallets.some(w =>
    (accountIndexInStr && w.accountIndex && w.accountIndex === accountIndexInStr)
  )
```
If the backend already has a wallet with the same `accountIndex`, the request fails with `ERR_ACCOUNT_INDEX_ALREADY_EXISTS`.

**Constraint 3 — Address uniqueness (two layers)**

Layer 1 — Ork checks lookup storage:
`wdk-ork-wrk/workers/api.ork.wrk.js:386-424`
```javascript
const existingWalletId = await this.getWalletIdByAddress({ address })
if (existingWalletId && existingWalletId !== excludeWalletId) {
  throw new Error('ERR_ADDRESS_ALREADY_EXISTS')
}
```

Layer 2 — Shard checks wallet repository:
`wdk-data-shard-wrk/workers/proc.shard.data.wrk.js:251-271`
```javascript
const existingWalletsWithAddress = await uow.walletRepository
  .getActiveWalletsByAddresses(allVariants)
  .toArray()
if (existingWalletsWithAddress.length > 0) {
  addressConflict = true  // → ERR_WALLET_ADDRESS_ALREADY_EXISTS
}
```

These two layers check different data sources (ork lookup store vs shard wallet repository). If these diverge — an address exists in one but not the other — the acceptance/rejection behavior becomes inconsistent.

**Net effect for migration:**
- If addresses **match** (correct migration) → rejected. Frontend data discarded.
- If addresses **differ** (incorrect migration) → the most common outcome is still **rejection**, because for `type: 'user'` wallets the duplicate-user-wallet guard (Constraint 1) fires first — before address comparison even runs. In narrower cases (e.g., different wallet type, or original wallet was deleted), a mismatched record could theoretically be created, but this is not the typical migration path.
- In **neither case** is the frontend's submission preserved for comparison.

### 2.2 Wallet update also blocks address changes

`PATCH /api/v1/wallets/:id` cannot fix the problem either:

- Once `accountIndex` is set, it cannot be changed: `wdk-data-shard-wrk/workers/proc.shard.data.wrk.js:346-368`
- Changing an already-stored address throws `ERR_EXISTING_ADDRESS_UPDATE_FORBIDDEN`: `wdk-data-shard-wrk/workers/proc.shard.data.wrk.js:370-390`
- Conflicting new addresses still throw `ERR_WALLET_ADDRESS_ALREADY_EXISTS`: `wdk-data-shard-wrk/workers/proc.shard.data.wrk.js:421-433`

Unit and integration tests confirm these restrictions:
- `wdk-data-shard-wrk/tests/unit/proc.shard.data.wrk.unit.test.js:483-499`
- `wdk-data-shard-wrk/tests/proc.shard.data.wrk.intg.test.js:148-195`

The backend deliberately prevents address overwrites. This is correct for normal operation, but it means there is **no write path** that can update a wallet to match the frontend's derivation.

---

## 3. Root Cause Candidates (Code-Level)

### 3.1 Account index mismatch

The most likely root cause. If the frontend derives with `accountIndex = 1` while the backend canonical wallet has `accountIndex = 0`, the resulting addresses are completely different.

**Defensive hardening note:** The shard code at `wdk-data-shard-wrk/workers/proc.shard.data.wrk.js:170` drops `accountIndex` when it is not a strict integer:
```javascript
const accountIndexInStr = Number.isInteger(accountIndex) ? String(accountIndex) : undefined
```
`Number.isInteger("0")` returns `false`. However, the HTTP schema at `wdk-app-node/workers/lib/server.js:414` declares `accountIndex: { type: 'integer', minimum: 0 }`, so Fastify's schema validation will coerce or reject non-integer values before they reach the shard on the normal HTTP path. This makes the shard-level drop a defensive backstop rather than a confirmed reachable bug during migration. It should still be hardened (see Section 10), but it is not a diagnosed root cause.

**Supporting code references:**
- `accountIndex` is stored on wallets: `wdk-data-shard-wrk/workers/lib/db/hyperdb/build.js:9-23`
- Backend enforces uniqueness per user: `wdk-data-shard-wrk/workers/proc.shard.data.wrk.js:216-228`, `:353-365`
- Tests prove duplicate `accountIndex` is rejected: `wdk-data-shard-wrk/tests/proc.shard.data.wrk.intg.test.js:17-123`

### 3.2 Address normalization inconsistency

Both ork and shard normalize addresses, but they load config independently and can drift:

**Ork** (`wdk-ork-wrk/workers/api.ork.wrk.js:331-348`):
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

**Shard** (`wdk-data-shard-wrk/workers/lib/blockchain.svc.js:62-68`):
```javascript
sanitizeInput (chain, input, type) {
  const check = this.ctx.conf.blockchains[chain]?.caseSensitive?.[type]
  if (!check || (check instanceof RegExp && !check.test(input))) {
    return input.toLowerCase()
  }
  return input
}
```

The logic mirrors each other, but:
- Ork loads config at `workers/api.ork.wrk.js:29-42` and converts regex strings to RegExp
- Shard loads config independently from its own `blockchains` config section
- If configs diverge (different regex patterns, missing chain entries), the same address normalizes differently at each layer

**Bitcoin is the most fragile chain:**
- Legacy P2PKH/P2SH (`^[13]...`) — case-sensitive
- Bech32 (`bc1...`) — case-insensitive, lowercased
- The regex `^[13][a-km-zA-HJ-NP-Z1-9]{25,34}$` determines which rule applies
- If the frontend uses a different regex or doesn't normalize at all, addresses won't match

**Chain case-sensitivity rules** (from `wdk-ork-wrk/tests/address-normalization.test.js`):

| Chain | Rule |
|-------|------|
| EVM (ethereum, arbitrum, polygon, spark) | Lowercase |
| Bitcoin P2PKH/P2SH (1, 3 prefix) | Case-sensitive |
| Bitcoin bech32 (bc1 prefix) | Lowercase |
| Solana | Case-sensitive |
| TON | Case-sensitive |
| Tron | Case-sensitive |

### 3.3 Frontend re-initialization

If local state is missing or corrupted, the app may generate a fresh wallet instead of reusing the migrated one. If the mnemonic is the same but the derivation path or account index differs, addresses are completely different.

### 3.4 Ork/shard data divergence

The ork maintains `@wdk-ork/wallet-id-lookups` (address → walletId mappings), while the shard maintains the canonical `wallets` repository. These are separate data stores. An address could exist in one but not the other due to partial failures, leading to inconsistent accept/reject behavior during migration.

---

## 4. Error String Correction

The meeting notes mention `ERR_ADDRESS_ALREADY_EXISTS`.

The actual error strings in the codebase are different:

| Error in code | Where thrown | What it means |
|---------------|-------------|---------------|
| `ERR_WALLET_ALREADY_EXISTS` | `proc.shard.data.wrk.js:179` | A user-type wallet already exists for this user |
| `ERR_ACCOUNT_INDEX_ALREADY_EXISTS` | `proc.shard.data.wrk.js:223` | This account index is already used by another wallet of this user |
| `ERR_WALLET_ADDRESS_ALREADY_EXISTS` | `proc.shard.data.wrk.js:265`, `:431` | This address is already owned by an active wallet |
| `ERR_ADDRESS_ALREADY_EXISTS` | `api.ork.wrk.js:412` | Ork-layer address uniqueness check (different string from shard) |
| `ERR_EXISTING_ADDRESS_UPDATE_FORBIDDEN` | `proc.shard.data.wrk.js:370-390` | Attempt to change an already-stored address via PATCH |

When searching logs, all five error strings must be included.

---

## 5. Likely Failure Sequence In Production

```
1. Frontend recreates wallets locally from mnemonic during migration
2. Frontend sends recreated wallets to POST /api/v1/wallets
3. Backend hits one of these walls:
   a. ERR_WALLET_ALREADY_EXISTS — user wallet type already exists (most common)
   b. ERR_ACCOUNT_INDEX_ALREADY_EXISTS — same account index on a different wallet
   c. ERR_WALLET_ADDRESS_ALREADY_EXISTS / ERR_ADDRESS_ALREADY_EXISTS — address owned
   d. ERR_EXISTING_ADDRESS_UPDATE_FORBIDDEN — tried to patch an existing address
4. Backend rejects the request. Frontend's data is discarded.
5. Backend keeps the old canonical wallet mapping unchanged.
6. Frontend now holds addresses that don't match the backend's canonical state.
7. Downstream ownership checks fail — user is stuck at loading screen.
```

---

## 6. What Is Missing Today

### 6.1 No durable store for frontend migration snapshots

There is no migration-specific endpoint, table, or collection. The generic `user-data` store exists (`wdk-data-shard-wrk/workers/lib/db/hyperdb/build.js:36-43`, `wdk-data-shard-wrk/workers/lib/db/mongodb/repositories/user.data.js:30-74`) but is only used for `entropies` and `seeds`.

Without a durable frontend snapshot, any reconciliation job would depend on transient logs rather than reliable data.

### 6.2 No reconciliation results tables

Current shard schema (`wdk-data-shard-wrk/workers/lib/db/hyperdb/build.js:7-95`) includes wallets, users, user-data, user-balances, wallet-balances, wallet-transfers, and address-checkpoints. There are no tables for reconciliation runs, per-wallet results, or migration metrics.

---

## 7. Solution

Three phases, ordered by urgency: diagnostics first (immediate visibility), then snapshot capture (prerequisite for the job), then the reconciliation job itself.

### Phase 1: Structured Diagnostics (Immediate — No Schema Changes)

Add structured logging at **both** the ork and shard layers so that every rejection path captures enough context for triage **now**, before the full reconciliation system is built.

**Why both layers:** `ERR_ADDRESS_ALREADY_EXISTS` is thrown by the ork at `wdk-ork-wrk/workers/api.ork.wrk.js:386-424` in `_validateWalletExistence()`, which runs *before* the request reaches the shard. This is the exact path called out in the meeting notes (`ERR_ADDRESS_ALREADY_EXISTS` since Thursday). If only shard-side logging is added, ork-level rejections remain invisible.

#### Ork-side diagnostics (`wdk-ork-wrk/workers/api.ork.wrk.js`)

Add structured logging inside `_validateWalletExistence()` when `ERR_ADDRESS_ALREADY_EXISTS` is thrown (around line 412). Also add the `address_conflict_total` counter metric proposed in the meeting notes.

**Pseudocode — fields to capture on ork-level address conflict:**
```
event:                 'MIGRATION_ADDRESS_CONFLICT_ORK'
error:                 'ERR_ADDRESS_ALREADY_EXISTS'
userId:                from request
conflictingAddress:    the address that triggered the conflict
conflictingWalletId:   the existing walletId returned by getWalletIdByAddress()
chain:                 the chain of the conflicting address (if available)
```

**Metric:** Expose `address_conflict_total` (labels: `chain`, `env`). Increment on every `ERR_ADDRESS_ALREADY_EXISTS` throw in ork. Implementation note: the chain indexers use Prometheus/Pushgateway hooks, but whether the ork layer has the same instrumentation wiring has not been verified in this workspace — treat this as an implementation assumption to confirm before building.

#### Shard-side diagnostics (`wdk-data-shard-wrk/workers/proc.shard.data.wrk.js`)

Add structured logging in `addWallet()` and `updateWallet()` at each rejection branch.

The logging snippets below are **pseudocode** showing the intent and fields to capture. The actual implementation must use the variables available in scope at each rejection branch — these vary by location:

- At line 179 (`ERR_WALLET_ALREADY_EXISTS`): `normalizedAddresses` is not yet computed (address normalization starts at line 231). Use the raw `addresses` from the destructured `newWallet`. `existingWallets` is an array, not a singular `existingWallet`.
- At line 223 (`ERR_ACCOUNT_INDEX_ALREADY_EXISTS`): `accountIndexInStr` and `existingWallets` are available.
- At line 265 (`ERR_WALLET_ADDRESS_ALREADY_EXISTS`): `normalizedAddresses` is available (computed at line 231).
- In `updateWallet()`: the existing wallet variable is `toUpdateWallet`, not `existingWallet`.

**Pseudocode — fields to capture per shard rejection (adapt to actual locals):**
```
event:                 'MIGRATION_WALLET_REJECTED' or 'MIGRATION_WALLET_UPDATE_REJECTED'
error:                 the specific ERR_ string
userId:                from request
attemptedAccountIndex: accountIndexInStr (if computed at that point)
attemptedAddresses:    normalizedAddresses or raw addresses (whichever is in scope)
existingWalletIds:     IDs from existingWallets array (for addWallet) or toUpdateWallet.id (for updateWallet)
existingAddresses:     addresses from the conflicting wallet(s)
```

**Also:** Query existing Sentry/log infrastructure for all five error strings since the migration began. Cross-reference with user IDs to build an initial list of affected users.

**Files to modify:**
- `wdk-ork-wrk/workers/api.ork.wrk.js` — structured logging in `_validateWalletExistence()`, `address_conflict_total` metric
- `wdk-data-shard-wrk/workers/proc.shard.data.wrk.js` — structured logging in `addWallet()`, `updateWallet()`

### Phase 2: Frontend Migration Snapshot Capture

#### 2.1 New storage: `migration-wallet-snapshots`

A dedicated appendable collection that stores the frontend's wallet data separately from canonical wallets. Must preserve history (multiple migration attempts per user).

**Schema:**

```
{
  id: UUID,
  userId: string,
  migrationSessionId: string,    // unique per migration attempt
  appVersion: string,            // frontend build that produced this snapshot
  wallets: [
    {
      type: string,              // 'user' | 'channel'
      channelId: string | null,
      name: string | null,
      accountIndex: string,
      addresses: Object,         // { chain: normalizedAddress }
      meta: Object | null
    }
  ],
  capturedAt: number,            // timestamp from frontend
  createdAt: number              // server receipt time
}
```

**Indexes:** `userId`, `migrationSessionId`, `createdAt`

**Storage implementations needed:**
- MongoDB: `wdk_migration_wallet_snapshots` collection
- HyperDB: `@wdk-data-shard/migration-wallet-snapshots` index

#### 2.2 New endpoint: `POST /api/v1/wallets/migration-snapshot`

**Request body:**
```json
{
  "migrationSessionId": "uuid",
  "appVersion": "2.1.0",
  "capturedAt": 1711411200000,
  "wallets": [
    {
      "type": "user",
      "accountIndex": 0,
      "addresses": { "ethereum": "0x...", "bitcoin": "bc1q...", "solana": "..." },
      "name": "Main Wallet",
      "meta": {}
    }
  ]
}
```

**Endpoint behavior:**
1. Authenticate the user (same auth as wallet endpoints)
2. Normalize all addresses using the same `_normalizeAddress()` / `sanitizeInput()` logic used by wallet storage
3. Coerce `accountIndex` to string (handle both `0` and `"0"`)
4. Store in `migration-wallet-snapshots` — never reject on duplicates, never touch canonical wallets
5. Return `201` with the stored snapshot ID

**Files to modify:**
- `wdk-app-node/workers/lib/server.js` — new route
- `wdk-app-node/workers/lib/services/ork.js` — new service method
- `wdk-ork-wrk/workers/api.ork.wrk.js` — new RPC action, route to shard
- `wdk-data-shard-wrk/workers/api.shard.data.wrk.js` — new RPC handler
- `wdk-data-shard-wrk/workers/lib/db/base/repositories/` — new `migration-snapshots.js`
- `wdk-data-shard-wrk/workers/lib/db/mongodb/repositories/` — MongoDB implementation
- `wdk-data-shard-wrk/workers/lib/db/hyperdb/build.js` — HyperDB index definition

### Phase 3: Reconciliation Job

#### 3.1 New storage: two tables for results

**Table 1: `migration-reconciliation-runs`**

Stores aggregate metrics per reconciliation run.

```
{
  runId: UUID,
  startedAt: number,
  finishedAt: number,
  snapshotCutoff: number,          // only process snapshots created before this time
  totalWalletsChecked: number,
  matches: number,
  mismatches: number,
  missingInFrontend: number,
  missingInBackend: number,
  ownedByOtherUser: number,
  matchAccuracy: number            // matches / totalWalletsChecked * 100
}
```

**Table 2: `migration-reconciliation-results`**

Stores per-wallet comparison detail.

```
{
  id: UUID,
  runId: string,                   // links to the run
  userId: string,
  walletId: string | null,         // backend wallet ID (if matched)
  walletName: string | null,
  walletType: string,
  channelId: string | null,
  backendAccountIndex: string | null,
  frontendAccountIndex: string | null,
  comparisonChain: string,         // which chain was used for the status decision
  backendAddresses: Object,        // full { chain: address } from backend
  frontendAddresses: Object,       // full { chain: address } from frontend
  backendAddress: string | null,   // the specific compared address (BE side)
  frontendAddress: string | null,  // the specific compared address (FE side)
  status: string,                  // MATCH | MISMATCH | MISSING_IN_FE | MISSING_IN_BE | OWNED_BY_OTHER_USER
  conflictWalletId: string | null, // if OWNED_BY_OTHER_USER, whose wallet owns the address
  backendEvmBalance: string | null,
  frontendEvmBalance: string | null,
  backendBtcBalance: string | null,
  frontendBtcBalance: string | null,
  balanceStatus: string | null,    // 'zero_risk' | 'at_risk' | 'balance_unknown'
  mismatchedChains: [string],      // all chains where addresses differ
  createdAt: number,
  resolvedAt: number | null,
  resolution: string | null        // manual resolution notes
}
```

**Indexes:** `runId`, `userId`, `status`, `balanceStatus`, `createdAt`

#### 3.2 Reconciliation job logic

**Location:** `wdk-data-shard-wrk/workers/proc.shard.data.wrk.js`

**Schedule:** On-demand initially via an admin RPC call. Once validated, add to scheduler as daily during the migration window:
```javascript
{ name: 'migrationReconciliation', rule: '0 3 * * *', timeout: 30 * 60 * 1000 }
```

**Existing job infrastructure to reuse:**
- Job scheduling/config: `proc.shard.data.wrk.js:84-99`
- Generic job runner (`_runJob`): `proc.shard.data.wrk.js:724-746`
- Scheduler registration: `proc.shard.data.wrk.js:1279-1293`
- Balance fetching: `blockchain.svc.js:194-229`, `:238-270`

**Algorithm:**

```
1. Create a new run record with startedAt = now

2. Load migration snapshots — one per user (latest by createdAt).
   Historical snapshots are preserved in storage for drill-down, but only
   the most recent snapshot per user is used for the reconciliation run.
   This prevents double-counting retried users and distorting headline metrics.

3. For each selected snapshot:
   a. Load the user's canonical backend wallets via walletRepository.getActiveUserWallets(userId)

   b. PAIR wallets by stable identity — NOT by accountIndex:
      - type='user'  → pair with the backend's user wallet (at most one per user)
      - type='channel' → pair by channelId
      This ensures that if the frontend derives with a wrong accountIndex, the
      wallet still pairs as a single MISMATCH (with differing accountIndex values),
      rather than splitting into MISSING_IN_FE + MISSING_IN_BE.

   c. For each paired wallet, COMPARE:
      - One EVM address (priority: ethereum → polygon → arbitrum → plasma)
        as per the ticket: "compare one address is enough like one of the EVM addresses"
      - accountIndex: store backendAccountIndex and frontendAccountIndex separately
        so index drift is visible in the results even when addresses happen to match
      - Store FULL address maps on both sides regardless of which chain decided the status

   d. Classify each wallet pair:
      - MATCH: frontend address equals backend address (on the comparison chain)
      - MISMATCH: addresses differ, or accountIndex differs
      - MISSING_IN_FE: backend wallet exists, no frontend wallet with matching identity in snapshot
      - MISSING_IN_BE: frontend wallet in snapshot, no matching backend wallet
      - OWNED_BY_OTHER_USER: frontend address is owned by a different user's wallet
        (check via walletRepository.getActiveWalletsByAddresses or ork lookup)

   e. For MISMATCH and OWNED_BY_OTHER_USER:
      - Fetch EVM balance for both backend and frontend addresses
      - Fetch BTC balance for both backend and frontend addresses
      - Note: BTC balance via scantxoutset is fragile (ERR_SCANTXOUTSET_BUSY)
        → retry with backoff, flag as 'balance_unknown' if all retries fail
      - Classify: 'zero_risk' (both zero), 'at_risk' (non-zero on BE side), 'balance_unknown'

   f. Store per-wallet result in migration-reconciliation-results

4. Compute aggregate metrics and store in migration-reconciliation-runs

5. Log summary: total, matches, mismatches, missing, accuracy %, at-risk count
```

**Address normalization:** The job MUST use the same normalization as the wallet storage path (`sanitizeInput()` / `_normalizeAddress()`). This is critical to avoid false mismatches on casing differences (especially EVM checksum encoding).

#### 3.3 Metrics API

**`GET /api/v1/admin/migration-reconciliation/runs`**
Returns list of reconciliation runs with aggregate metrics.

**`GET /api/v1/admin/migration-reconciliation/runs/:runId/results`**
Returns per-wallet results for a specific run. Supports filtering by `status` and `balanceStatus`.

**`GET /api/v1/admin/migration-reconciliation/metrics`**
Returns latest run metrics:
- Total wallets checked
- Matches / Mismatches / Missing in FE / Missing in BE / Owned by other user
- Match accuracy %
- At-risk count (non-zero balance on mismatched backend address)
- Balance-unknown count

**Files to modify:**
- `wdk-app-node/workers/lib/server.js` — admin routes
- `wdk-app-node/workers/lib/services/ork.js` — service methods
- `wdk-ork-wrk/workers/api.ork.wrk.js` — RPC actions
- `wdk-data-shard-wrk/workers/api.shard.data.wrk.js` — RPC handlers for reads
- `wdk-data-shard-wrk/workers/proc.shard.data.wrk.js` — job logic, scheduler entry
- `wdk-data-shard-wrk/workers/lib/db/base/repositories/` — new repos for runs + results
- `wdk-data-shard-wrk/workers/lib/db/mongodb/repositories/` — MongoDB implementations
- `wdk-data-shard-wrk/workers/lib/db/hyperdb/build.js` — HyperDB index definitions
- Config files — job schedule, feature flag

---

## 8. Complete File Change Map

| File | Phase | Change |
|------|-------|--------|
| `wdk-ork-wrk/workers/api.ork.wrk.js` | 1 | Structured logging in `_validateWalletExistence()`, `address_conflict_total` metric |
| `wdk-data-shard-wrk/workers/proc.shard.data.wrk.js` | 1 | Structured warn logs on wallet rejection in `addWallet()`, `updateWallet()` |
| `wdk-data-shard-wrk/workers/proc.shard.data.wrk.js` | 3 | Add `migrationReconciliation` job, scheduler entry |
| `wdk-data-shard-wrk/workers/api.shard.data.wrk.js` | 2, 3 | RPC handlers for snapshot storage, result reads |
| `wdk-data-shard-wrk/workers/lib/db/base/repositories/` | 2, 3 | New `migration-snapshots.js`, `migration-reconciliation-runs.js`, `migration-reconciliation-results.js` |
| `wdk-data-shard-wrk/workers/lib/db/mongodb/repositories/` | 2, 3 | MongoDB implementations of the above |
| `wdk-data-shard-wrk/workers/lib/db/hyperdb/build.js` | 2, 3 | HyperDB index definitions for new collections |
| `wdk-ork-wrk/workers/api.ork.wrk.js` | 2, 3 | RPC actions: `storeMigrationSnapshot`, `reconcileMigration`, result queries |
| `wdk-app-node/workers/lib/server.js` | 2, 3 | New routes: snapshot endpoint, admin metrics/results endpoints |
| `wdk-app-node/workers/lib/services/ork.js` | 2, 3 | Service methods calling ork RPC |
| Config files | 3 | Job schedule, feature flag |

---

## 9. Risk Assessment

| Scenario | Severity | Mitigation |
|----------|----------|------------|
| Mismatched address with **non-zero balance** on backend side | **Critical** — user's funds are in a wallet they cannot access from the frontend | Prioritize balance checks; manual intervention required; flag in metrics as `at_risk` |
| Mismatched address with **zero balance** on both sides | **Low** — no immediate fund risk | Lower-priority manual remediation candidate. Note: the current worker explicitly forbids address mutation (`ERR_EXISTING_ADDRESS_UPDATE_FORBIDDEN` at `proc.shard.data.wrk.js:370-390`), so rewriting the canonical record requires a deliberate migration script or admin override, not an automatic fix. Zero balance lowers fund risk but does not prove that rewriting wallet ownership is operationally safe (transaction history, lookups, and other associations may still reference the old address). |
| `MISSING_IN_FE` — backend has wallet, frontend didn't send snapshot | **Medium** — user may have skipped migration or app crashed before snapshot sent | Trigger re-migration for affected users; verify frontend sends snapshot reliably |
| `MISSING_IN_BE` — frontend sent wallet, backend has no record | **Medium** — possible race condition, data loss, or user was deleted | Investigate via logs; check if user was cleaned up by `deleteInactiveUsers` job |
| `OWNED_BY_OTHER_USER` — frontend address belongs to a different user | **High** — indicates duplicate address derivation across users or a shared mnemonic | Investigate immediately; likely indicates a derivation bug or compromised mnemonic |
| BTC balance fetch unreliable (`scantxoutset` busy) | **Medium** — can't assess risk for BTC mismatches | Retry with backoff; store `balance_unknown` status; don't block the run |
| `accountIndex` shard-level `Number.isInteger()` drop | **Low** — HTTP schema validates as integer before reaching shard, so not reachable on normal HTTP path | Defensive hardening: accept both string and integer in shard code (see Section 10). Not a diagnosed migration root cause. |
| Ork/shard lookup data divergence | **Low-Medium** — inconsistent accept/reject for same address | Surface via reconciliation results; reconcile lookup stores as separate maintenance task |

---

## 10. Defensive Hardening: accountIndex Type Coercion

The HTTP schema at `wdk-app-node/workers/lib/server.js:414` declares `accountIndex` as `{ type: 'integer', minimum: 0 }`, so Fastify will coerce or reject non-integer values before they reach the shard on the normal HTTP path. This means the shard-level `Number.isInteger()` check is not reachable as a bug during standard migration.

However, as a defensive hardening measure (in case the shard receives requests from non-HTTP paths such as direct RPC calls), the shard code could be tightened:

**Current** (`wdk-data-shard-wrk/workers/proc.shard.data.wrk.js:170`):
```javascript
const accountIndexInStr = Number.isInteger(accountIndex) ? String(accountIndex) : undefined
```

**Hardened:**
```javascript
const parsedIndex = typeof accountIndex === 'string' ? parseInt(accountIndex, 10) : accountIndex
const accountIndexInStr = Number.isInteger(parsedIndex) ? String(parsedIndex) : undefined
```

This is not a migration root-cause fix — it is a defense-in-depth improvement for non-HTTP code paths.

---

## 11. Existing Infrastructure Reused

| Capability | Existing Code | Used In |
|-----------|---------------|---------|
| Job scheduler | `@bitfinex/bfx-facs-scheduler` | Phase 3 |
| Job runner pattern | `_runJob(flag, func, timeout)` in `proc.shard.data.wrk.js` | Phase 3 |
| Address normalization | `_normalizeAddress()` in ork, `sanitizeInput()` in shard | Phase 2, 3 |
| Address variant generation | `getAddressVariants()` in `wdk-data-shard-wrk/workers/lib/utils.js` | Phase 3 |
| Balance fetching | `blockchain.svc.js:194-229`, `:238-270` | Phase 3 |
| Wallet repository | `getActiveUserWallets()`, `getActiveWalletsByAddresses()` | Phase 3 |
| Address ownership lookup | `getWalletIdByAddress()` in ork | Phase 3 |
| Unit of work / transactions | `db.unitOfWork()` pattern in shard | Phase 2, 3 |

No new dependencies are needed. All three phases build on existing patterns and infrastructure.
