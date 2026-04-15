# Migration Reconciliation Job Analysis

## Summary

From the local code, the main issue is not just "wallets can mismatch after migration".

The bigger backend gap is:

1. The backend wallet APIs are designed to keep one canonical wallet record per user/channel and reject conflicting writes.
2. The backend does **not** currently persist the frontend's migrated wallet snapshot in a queryable form.
3. Because of that, a reconciliation job cannot reliably compare "frontend migrated addresses" vs "backend canonical addresses" from existing stored data alone.

So the reconciliation job is needed, but we first need a durable place to store the frontend migration snapshot.

## What The Current Backend Does

### 1. Wallet creation is canonical, not observational

`POST /api/v1/wallets` goes straight into `addWallet()` and tries to create canonical wallet records:

- `wdk-app-node/workers/lib/server.js:397-449`
- `wdk-app-node/workers/lib/services/ork.js:223-225`
- `wdk-data-shard-wrk/workers/proc.shard.data.wrk.js:155-321`

Important behaviors inside `addWallet()`:

- Only one `user` wallet is allowed per user.
- Only one `channel` wallet per `channelId` is allowed.
- `accountIndex` must be unique per user.
- Any address already owned by another active wallet is rejected.

Relevant code:

- duplicate wallet type/channel check: `wdk-data-shard-wrk/workers/proc.shard.data.wrk.js:172-185`
- account index uniqueness: `wdk-data-shard-wrk/workers/proc.shard.data.wrk.js:216-228`
- address uniqueness across active wallets: `wdk-data-shard-wrk/workers/proc.shard.data.wrk.js:230-270`

This means if migration recreates a wallet with a different address or wrong derivation index, the backend does **not** store that migrated value as a second dataset for later comparison. It just rejects it.

### 2. Existing wallet addresses are intentionally hard to change

`PATCH /api/v1/wallets/:id` allows limited updates, but changing an existing stored address is explicitly forbidden:

- route: `wdk-app-node/workers/lib/server.js:451-493`
- service: `wdk-app-node/workers/lib/services/ork.js:210-221`
- worker logic: `wdk-data-shard-wrk/workers/proc.shard.data.wrk.js:328-457`

Key restrictions:

- once `accountIndex` is set, it cannot be set again: `wdk-data-shard-wrk/workers/proc.shard.data.wrk.js:346-368`
- changing an already stored address throws `ERR_EXISTING_ADDRESS_UPDATE_FORBIDDEN`: `wdk-data-shard-wrk/workers/proc.shard.data.wrk.js:370-390`
- conflicting new addresses still throw `ERR_WALLET_ADDRESS_ALREADY_EXISTS`: `wdk-data-shard-wrk/workers/proc.shard.data.wrk.js:421-433`

The unit tests confirm this behavior:

- `wdk-data-shard-wrk/tests/unit/lib/utils.unit.test.js:69-90`
- `wdk-data-shard-wrk/tests/unit/proc.shard.data.wrk.unit.test.js:483-499`
- `wdk-data-shard-wrk/tests/proc.shard.data.wrk.intg.test.js:148-195`

So the current backend behavior matches the ticket statement that "the backend does not overwrite existing stored addresses".

### 3. Account index mismatch is a very plausible root cause

The meeting notes mention wrong derivation/account index as a root-cause candidate. That aligns well with the current code:

- `accountIndex` is stored on wallets: `wdk-data-shard-wrk/workers/lib/db/hyperdb/build.js:9-23`
- backend enforces uniqueness per user on create/update:
  - `wdk-data-shard-wrk/workers/proc.shard.data.wrk.js:216-228`
  - `wdk-data-shard-wrk/workers/proc.shard.data.wrk.js:353-365`
- tests prove duplicate `accountIndex` is rejected:
  - `wdk-data-shard-wrk/tests/proc.shard.data.wrk.intg.test.js:17-123`

If the frontend derives wallet `accountIndex = 1` while the backend canonical wallet is still `accountIndex = 0`, the resulting EVM and BTC addresses will differ, and the backend has no safe path today to reconcile them automatically.

### 4. Address ownership is globally enforced

Wallet lookup and ownership are built around the backend's canonical `wallets` store:

- Mongo active-wallet-by-address lookup: `wdk-data-shard-wrk/workers/lib/db/mongodb/repositories/wallets.js:137-183`
- HyperDB active-wallet-by-address lookup: `wdk-data-shard-wrk/workers/lib/db/hyperdb/repositories/wallets.js:50-87`

This matches the meeting symptom: if frontend-local wallets differ from backend-canonical wallets, downstream ownership checks can fail because the backend still trusts the canonical wallet table.

### 5. Address comparison must use backend normalization rules

The backend normalizes many addresses before storage/comparison:

- `wdk-data-shard-wrk/workers/lib/blockchain.svc.js:57-68`

For EVM chains, addresses are usually lowercased before comparison. That means the reconciliation job should reuse this same normalization logic, otherwise it will produce false mismatches on checksum/casing differences.

## What Is Missing Today

### 1. No durable store for frontend migration snapshots

I did **not** find an existing migration-specific endpoint, table, or collection that stores the frontend's recreated wallet dataset.

What exists today:

- canonical wallets table/collection: `wdk-data-shard-wrk/workers/lib/db/hyperdb/build.js:143-199`
- generic user-data store: `wdk-data-shard-wrk/workers/lib/db/hyperdb/build.js:36-43`, `wdk-data-shard-wrk/workers/lib/db/mongodb/repositories/user.data.js:30-74`

But the generic user-data store is currently only used for:

- `entropies`: `wdk-data-shard-wrk/workers/api.shard.data.wrk.js:644-660`
- `seeds`: `wdk-data-shard-wrk/workers/api.shard.data.wrk.js:663-693`

The public WDK API exposes wallet create/update, but no migration snapshot endpoint:

- `wdk-app-node/workers/lib/server.js:397-493`

So unless another service outside this workspace is persisting the frontend migration payload, the data required by the ticket does not currently exist in a durable/queryable backend store.

### 2. No reconciliation-results table exists

Current shard schema includes:

- wallets
- users
- user-data
- user-balances
- wallet-balances
- wallet-transfers
- address-checkpoints

See:

- `wdk-data-shard-wrk/workers/lib/db/hyperdb/build.js:7-95`

There is no dedicated collection/table for:

- reconciliation runs
- per-wallet reconciliation results
- migration mismatch metrics

### 3. The meeting's error string does not match the current code

The meeting notes mention `ERR_ADDRESS_ALREADY_EXISTS`.

In this codebase, the actual wallet-conflict error emitted by the shard worker is:

- `ERR_WALLET_ADDRESS_ALREADY_EXISTS`

See:

- `wdk-data-shard-wrk/workers/proc.shard.data.wrk.js:264-269`
- `wdk-data-shard-wrk/workers/proc.shard.data.wrk.js:430-431`

So when checking logs in this backend, the search should include:

- `ERR_WALLET_ADDRESS_ALREADY_EXISTS`
- `ERR_ACCOUNT_INDEX_ALREADY_EXISTS`
- `ERR_WALLET_ALREADY_EXISTS`

not only `ERR_ADDRESS_ALREADY_EXISTS`.

## Likely Failure Mode In Production

Based on the local code, the likely sequence is:

1. The frontend recreates wallets locally during migration.
2. It sends those wallets to the backend through the normal wallet creation/update path.
3. If the recreated wallet uses a different `accountIndex` or derives a different address than the backend canonical record:
   - create may fail with `ERR_WALLET_ALREADY_EXISTS`
   - create may fail with `ERR_ACCOUNT_INDEX_ALREADY_EXISTS`
   - create/update may fail with `ERR_WALLET_ADDRESS_ALREADY_EXISTS`
   - update may fail with `ERR_EXISTING_ADDRESS_UPDATE_FORBIDDEN`
4. The backend keeps the old canonical wallet mapping.
5. Downstream reads/ownership checks still use the backend canonical mapping, while the frontend may now hold a different local wallet.
6. The user gets stuck because frontend-local state and backend-canonical state have diverged.

## Recommended Solution

Implement this as a two-part feature:

1. Persist the frontend migration snapshot separately from canonical wallets.
2. Run a reconciliation job against canonical wallets and store the results in a dedicated results table.

This is safer than trying to make the canonical wallet APIs do double duty as both write-path and audit trail.

### Part 1: Store the frontend migration snapshot

Add a new backend endpoint specifically for migration reconciliation input.

Suggested behavior:

- authenticated user sends full migrated wallet snapshot
- backend sanitizes addresses with the same normalization used by wallet storage
- backend stores the snapshot without mutating canonical wallet records

Suggested payload per wallet:

- `type`
- `channelId` when relevant
- `name`
- `accountIndex`
- `addresses`
- optional `meta`

Suggested envelope fields:

- `migrationSessionId`
- `appVersion`
- `capturedAt`

### Where to store it

Two options:

#### Option A: Fastest path

Reuse `user-data` with a new key such as `migration-wallet-snapshot`.

Why it works:

- the generic repository already exists
- it is keyed by `(userId, key)`
- no new storage engine code is needed for the input side

Why it is not ideal:

- it stores only one logical document per user/key
- weak queryability across all users
- poor fit for historical analysis and multiple migration attempts

#### Option B: Recommended path

Create a dedicated appendable collection/table, for example:

- `migration-wallet-snapshots`

Suggested fields:

- `id`
- `userId`
- `migrationSessionId`
- `wallets`
- `appVersion`
- `createdAt`

This is better because it preserves history and supports targeted analysis.

### Part 2: Add a reconciliation job in the shard worker

The best home for the job is `wdk-data-shard-wrk/workers/proc.shard.data.wrk.js` because it already owns:

- canonical wallet storage
- iteration over all active wallets
- the background job scheduler
- blockchain balance fetching primitives

Relevant existing job infrastructure:

- job scheduling/config: `wdk-data-shard-wrk/workers/proc.shard.data.wrk.js:84-99`
- generic job runner: `wdk-data-shard-wrk/workers/proc.shard.data.wrk.js:724-746`
- scheduler registration: `wdk-data-shard-wrk/workers/proc.shard.data.wrk.js:1279-1293`

### Matching logic

For each stored frontend migration wallet, match against backend canonical wallets by:

1. `userId`
2. `type`
3. `channelId` for channel wallets
4. `accountIndex` when present

`accountIndex` should be the primary key for matching because the meeting notes explicitly suspect derivation/index drift, and the backend already treats `accountIndex` as a significant uniqueness field.

If `accountIndex` is missing, fallback matching can use:

- one deterministic EVM chain address, in priority order:
  - `ethereum`
  - `polygon`
  - `arbitrum`
  - `plasma`

But even if one EVM address is enough for the status decision, the job should still store the full FE and BE address maps for debugging.

### Reconciliation statuses

At minimum:

- `MATCH`
- `MISMATCH`
- `MISSING_IN_FE`
- `MISSING_IN_BE`

Useful extra status:

- `OWNED_BY_OTHER_USER`

That extra status is not in the ticket, but it would make duplicate-address incidents much easier to investigate.

### Balance lookup for risky mismatches

The current code already has the primitives needed to fetch balances for mismatched addresses:

- per-address balance: `wdk-data-shard-wrk/workers/lib/blockchain.svc.js:194-229`
- per-wallet address-level balance view: `wdk-data-shard-wrk/workers/lib/blockchain.svc.js:238-270`

When a mismatch is found, fetch:

- backend EVM address balance
- frontend EVM address balance
- backend BTC address balance
- frontend BTC address balance

This matches the ticket requirement to distinguish zero-risk mismatches from mismatches with funds.

## Suggested Output Schema

Create a dedicated results store, for example:

- `migration-wallet-reconciliation-runs`
- `migration-wallet-reconciliation-results`

### `migration-wallet-reconciliation-runs`

Suggested fields:

- `runId`
- `startedAt`
- `finishedAt`
- `snapshotCutoff`
- `totalWalletsChecked`
- `matches`
- `mismatches`
- `missingInFrontend`
- `missingInBackend`
- `ownedByOtherUser`
- `matchAccuracy`

### `migration-wallet-reconciliation-results`

Suggested fields:

- `runId`
- `userId`
- `walletId`
- `walletName`
- `walletType`
- `channelId`
- `accountIndex`
- `comparisonChain`
- `backendAddresses`
- `frontendAddresses`
- `backendAddress`
- `frontendAddress`
- `status`
- `conflictWalletId`
- `backendEvmBalance`
- `frontendEvmBalance`
- `backendBtcBalance`
- `frontendBtcBalance`
- `createdAt`

This satisfies the ticket and also gives enough detail for ops follow-up.

## Minimal Viable Implementation Plan

### Phase 1: Capture the missing input

Add a migration snapshot ingestion endpoint and store the normalized frontend payload without changing canonical wallets.

### Phase 2: Build the reconciliation run

Add a proc-worker job that:

1. loads stored frontend snapshots
2. loads backend canonical wallets
3. matches wallets by user/type/accountIndex
4. computes statuses
5. fetches balances for mismatches
6. stores per-wallet results and run summary

### Phase 3: Add diagnostics

Add structured logs for:

- `ERR_WALLET_ADDRESS_ALREADY_EXISTS`
- `ERR_ACCOUNT_INDEX_ALREADY_EXISTS`
- `ERR_WALLET_ALREADY_EXISTS`

with fields such as:

- `userId`
- `accountIndex`
- `normalizedAddresses`
- `conflictingWalletId`

This will help identify failures before the reconciliation feature is fully rolled out.

## Concrete Code Areas To Change Later

If we implement this, the likely touch points are:

- `wdk-app-node/workers/lib/server.js`
- `wdk-app-node/workers/lib/services/ork.js`
- `wdk-data-shard-wrk/workers/api.shard.data.wrk.js`
- `wdk-data-shard-wrk/workers/proc.shard.data.wrk.js`
- `wdk-data-shard-wrk/workers/lib/db/hyperdb/build.js`
- new MongoDB/HyperDB repositories for reconciliation results

## Final Conclusion

The local code supports the **comparison mechanics** we need:

- canonical wallet storage
- account-index-aware wallet records
- address normalization
- address ownership lookup
- wallet iteration
- background job scheduling
- per-address balance fetching

But it does **not** support the reconciliation job end-to-end yet, because the frontend migration dataset is not currently stored separately from canonical wallet writes.

So the real fix is:

1. persist frontend migration snapshots first
2. then run a scheduled/manual reconciliation job against canonical wallets
3. store results in a dedicated results table

Without step 1, the requested reconciliation job will be incomplete or dependent on transient logs instead of reliable backend data.
