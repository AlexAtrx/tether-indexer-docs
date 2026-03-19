# Migration Reconciliation — Build Plan

Reference: `analysis-final.md` in this directory for rationale and root-cause context.

This plan is execution-oriented and reflects the actual worker boundaries in this codebase:

- Writes and long-running jobs must execute in `wdk-data-shard-wrk/workers/proc.shard.data.wrk.js`
- `wdk-data-shard-wrk/workers/api.shard.data.wrk.js` should forward mutations/jobs to proc via `_procRpcCall(...)`
- `wdk-ork-wrk/workers/api.ork.wrk.js` can route user-scoped requests with `_rpcRequest(req, action)`, but cross-user admin endpoints must fan out across all shards and aggregate
- `wdk-app-node` currently authenticates users, not admins; admin authorization must be added explicitly before exposing reconciliation endpoints

---

## Phase 1: Structured Diagnostics

No schema changes. Goal: make every relevant wallet rejection visible in logs immediately.

### Step 1.1 — Ork-side logging

**File:** `wdk-ork-wrk/workers/api.ork.wrk.js`

**Where:** Inside `_validateWalletExistence()`, at the point where `ERR_ADDRESS_ALREADY_EXISTS` is thrown.

**Implementation notes:**
- Refactor the local address collection so it keeps chain context.
- Do not flatten to bare string addresses only.
- Collect entries like `{ chain, address }` so logs and metrics can label the chain correctly.

**What to add:**
- A structured `logger.warn` before throwing `ERR_ADDRESS_ALREADY_EXISTS`, capturing:
  - `event: 'MIGRATION_ADDRESS_CONFLICT_ORK'`
  - `error: 'ERR_ADDRESS_ALREADY_EXISTS'`
  - `userId`
  - `conflictingAddress`
  - `conflictingWalletId`
  - `chain`

**Metric (conditional):**
- If the ork worker already has metrics wiring, add `address_conflict_total` with labels `chain` and `env`.
- If ork has no metrics wiring in this repo/runtime, skip the counter for the first implementation and record that as a follow-up.

**Done when:**
- A create-wallet request with an already-registered address emits the structured warn log.
- If metrics wiring exists, the counter increments.

### Step 1.2 — Shard-side logging

**File:** `wdk-data-shard-wrk/workers/proc.shard.data.wrk.js`

**Where:** Rejection branches in `addWallet()` and `updateWallet()`.

**What to add at each branch:**

| Branch | Error | Minimum fields |
|--------|-------|----------------|
| `addWallet()` duplicate user/channel wallet | `ERR_WALLET_ALREADY_EXISTS` | `event`, `error`, `userId`, `type`, `channelId`, raw `addresses`, raw `accountIndex`, compact summary of `existingWallets` |
| `addWallet()` duplicate account index | `ERR_ACCOUNT_INDEX_ALREADY_EXISTS` | `event`, `error`, `userId`, `accountIndexInStr`, raw `addresses`, compact summary of `existingWallets` |
| `addWallet()` duplicate address | `ERR_WALLET_ADDRESS_ALREADY_EXISTS` | `event`, `error`, `userId`, `normalizedAddresses`, `accountIndexInStr`, `allVariants` |
| `updateWallet()` address overwrite forbidden | `ERR_EXISTING_ADDRESS_UPDATE_FORBIDDEN` | `event`, `error`, `userId`, `id`, `toUpdateWallet.addresses`, attempted `addresses` |
| `updateWallet()` duplicate address | `ERR_WALLET_ADDRESS_ALREADY_EXISTS` | `event`, `error`, `userId`, `id`, `toUpdateWallet.addresses`, attempted normalized addresses |

**Event names:**
- `MIGRATION_WALLET_REJECTED` for `addWallet()`
- `MIGRATION_WALLET_UPDATE_REJECTED` for `updateWallet()`

**Done when:**
- Each branch can be triggered in staging/test and emits a structured warn log with the right fields.

### Step 1.3 — Query existing logs

**Action (manual, no code):** Search Sentry/log infrastructure for these five strings since the migration started:
- `ERR_WALLET_ALREADY_EXISTS`
- `ERR_ACCOUNT_INDEX_ALREADY_EXISTS`
- `ERR_WALLET_ADDRESS_ALREADY_EXISTS`
- `ERR_ADDRESS_ALREADY_EXISTS`
- `ERR_EXISTING_ADDRESS_UPDATE_FORBIDDEN`

Cross-reference with user IDs to build an initial affected-user list.

**Done when:**
- Affected user IDs have been extracted and shared.

---

## Phase 2: Frontend Migration Snapshot Capture

Goal: add a durable append-only store for frontend-derived wallet snapshots, separate from canonical wallets.

### Step 2.1 — Base repository contract

**File to create:** `wdk-data-shard-wrk/workers/lib/db/base/repositories/migration-snapshots.js`

**Methods:**
- `save(snapshot)`
- `getByUserId(userId)`
- `getLatestByUserId(userId)`
- `getLatestPerUser(cutoffTimestamp)`

**Document shape:**
```js
{
  id: UUID,
  userId: string,
  migrationSessionId: string,
  appVersion: string,
  wallets: [
    {
      type: string,
      channelId: string | null,
      name: string | null,
      accountIndex: string | null,
      addresses: Object,
      meta: Object | null
    }
  ],
  capturedAt: number,
  createdAt: number
}
```

**Done when:**
- The base repository exists with those methods.

### Step 2.2 — MongoDB repository

**File to create:** `wdk-data-shard-wrk/workers/lib/db/mongodb/repositories/migration-snapshots.js`

**Collection:** `wdk_migration_wallet_snapshots`

**Indexes:**
- `{ userId: 1, createdAt: -1 }`
- `{ migrationSessionId: 1 }`
- Add additional index only if needed for the exact query plan used by `getLatestPerUser()`

**Implementation notes:**
- `save()` must be transactional like other write repositories.
- `getLatestPerUser(cutoffTimestamp)` can use an aggregation pipeline grouped by `userId`.

**Done when:**
- Save, get-by-user, latest-by-user, latest-per-user work in tests.

### Step 2.3 — HyperDB schema, repository, and spec regeneration

**Files to create:**
- `wdk-data-shard-wrk/workers/lib/db/hyperdb/repositories/migration-snapshots.js`

**Files to modify:**
- `wdk-data-shard-wrk/workers/lib/db/hyperdb/build.js`

**What to add:**
- A new schema for `migration-wallet-snapshots`
- A collection keyed by `id`
- Secondary indexes needed for `userId` and snapshot-time access

**Implementation note:**
- `getLatestPerUser(cutoffTimestamp)` in HyperDB does not need to be over-optimized initially.
- A bounded scan with in-memory latest-per-user selection is acceptable for this migration-only/admin job, as long as it is clearly documented and tested.

**Required follow-up after changing `build.js`:**
- Regenerate the checked-in HyperDB spec artifacts:
  - `workers/lib/db/hyperdb/spec/hyperschema/*`
  - `workers/lib/db/hyperdb/spec/hyperdb/*`

**Done when:**
- HyperDB repository exists.
- `build.js` includes the collection/index definitions.
- Generated spec files have been refreshed.

### Step 2.4 — DB wiring

**Files to modify:**
- `wdk-data-shard-wrk/workers/lib/db/base/context.js`
- `wdk-data-shard-wrk/workers/lib/db/base/unit.of.work.js`
- `wdk-data-shard-wrk/workers/lib/db/mongodb/context.js`
- `wdk-data-shard-wrk/workers/lib/db/mongodb/unit.of.work.js`
- `wdk-data-shard-wrk/workers/lib/db/hyperdb/context.js`
- `wdk-data-shard-wrk/workers/lib/db/hyperdb/unit.of.work.js`

**What to add:**
- Instantiate the snapshot repository in DB context and unit-of-work classes for both engines.
- For MongoDB, include its `ready()` call in context open and `commitWrites()` in unit-of-work commit flow.

**Done when:**
- `this.db.migrationSnapshotRepository` and `uow.migrationSnapshotRepository` are available in both engines.

### Step 2.5 — Proc-side snapshot write RPC

**File to modify:** `wdk-data-shard-wrk/workers/proc.shard.data.wrk.js`

**What to add:**
- New proc method: `storeMigrationSnapshot(req)`
- New proc RPC action registration for `storeMigrationSnapshot`

**Method behavior:**
1. Validate `userId`, `migrationSessionId`, `appVersion`, `wallets`
2. Normalize every address with `this.blockchainSvc.sanitizeInput(chain, address, 'address')`
3. Coerce `accountIndex` to string when present
4. Generate `id` and `createdAt`
5. Persist in a transaction through `uow.migrationSnapshotRepository.save(...)`
6. Commit and return the saved snapshot or `{ id }`

**Important:**
- This write must happen in proc, not in shard API worker.

**Done when:**
- The proc RPC action exists and a direct RPC test can store a snapshot successfully.

### Step 2.6 — Shard API forwarder

**File to modify:** `wdk-data-shard-wrk/workers/api.shard.data.wrk.js`

**What to add:**
- Method `storeMigrationSnapshot(req)` that forwards to proc with `_procRpcCall('storeMigrationSnapshot', req)`
- Register `storeMigrationSnapshot` in the shard API RPC action list

**Important:**
- Do not write to the DB directly from the shard API worker.

**Done when:**
- Calling `storeMigrationSnapshot` on shard API reaches proc and persists successfully.

### Step 2.7 — Ork route-through action

**File to modify:** `wdk-ork-wrk/workers/api.ork.wrk.js`

**What to add:**
- Method `storeMigrationSnapshot(req)` that routes with `this._rpcRequest(req, 'storeMigrationSnapshot')`
- Register `storeMigrationSnapshot` in the ork RPC action list

**Done when:**
- App-node can call ork and ork routes the request to the correct shard.

### Step 2.8 — App-node service method

**File to modify:** `wdk-app-node/workers/lib/services/ork.js`

**What to add:**
- `storeMigrationSnapshot(ctx, req)`

**Behavior:**
- Build payload from authenticated `userId` plus request body
- Call ork RPC action `storeMigrationSnapshot`

**Done when:**
- The service method is callable from a route handler.

### Step 2.9 — HTTP route

**File to modify:** `wdk-app-node/workers/lib/server.js`

**Route:**
- `POST /api/v1/wallets/migration-snapshot`

**Auth:**
- Same auth guard pattern as wallet routes

**Body schema:**
- Require:
  - `migrationSessionId`
  - `appVersion`
  - `capturedAt`
  - `wallets`
- Wallet entries should allow:
  - `type`
  - `channelId`
  - `name`
  - `accountIndex`
  - `addresses`
  - `meta`

**Behavior:**
- Repeated submissions with the same payload must succeed.
- This endpoint never mutates canonical wallets.

**Done when:**
- Valid payload returns `201`
- Duplicate snapshot payloads are accepted
- Stored data remains append-only

---

## Phase 3: Reconciliation Job

Goal: compare frontend snapshots against canonical wallets, fetch balances for mismatches, and expose shard-aggregated reporting.

### Step 3.1 — Base repository contracts

**Files to create:**
- `wdk-data-shard-wrk/workers/lib/db/base/repositories/migration-reconciliation-runs.js`
- `wdk-data-shard-wrk/workers/lib/db/base/repositories/migration-reconciliation-results.js`

**Run repository methods:**
- `save(run)`
- `update(runId, shardId, fields)`
- `getAll()`
- `getByRunId(runId)`
- `getLatest()`

**Result repository methods:**
- `saveBatch(results)`
- `getByRunId(runId, filters)`
- `getByUserId(userId)`

**Implementation note:**
- Add `shardId` as an implementation field on runs/results.
- External APIs remain keyed by `runId`, but `shardId` is required internally so ORK can merge shard-local data for the same global run.

**Done when:**
- Base contracts exist.

### Step 3.2 — MongoDB repositories

**Files to create:**
- `wdk-data-shard-wrk/workers/lib/db/mongodb/repositories/migration-reconciliation-runs.js`
- `wdk-data-shard-wrk/workers/lib/db/mongodb/repositories/migration-reconciliation-results.js`

**Collections:**
- `wdk_migration_reconciliation_runs`
- `wdk_migration_reconciliation_results`

**Suggested indexes:**
- Runs:
  - `{ runId: 1, shardId: 1 }`
  - `{ startedAt: -1 }`
- Results:
  - `{ runId: 1, shardId: 1, status: 1 }`
  - `{ userId: 1 }`
  - `{ balanceStatus: 1 }`

**Done when:**
- CRUD and filtered queries work in tests.

### Step 3.3 — HyperDB schema, repositories, and spec regeneration

**Files to create:**
- `wdk-data-shard-wrk/workers/lib/db/hyperdb/repositories/migration-reconciliation-runs.js`
- `wdk-data-shard-wrk/workers/lib/db/hyperdb/repositories/migration-reconciliation-results.js`

**Files to modify:**
- `wdk-data-shard-wrk/workers/lib/db/hyperdb/build.js`

**What to add:**
- Schemas and collections for runs/results
- Indexes sufficient for run lookup and result filtering

**Required follow-up:**
- Regenerate checked-in HyperDB spec artifacts after `build.js` changes

**Done when:**
- HyperDB repositories exist and generated spec files are updated.

### Step 3.4 — DB wiring

**Files to modify:**
- `wdk-data-shard-wrk/workers/lib/db/base/context.js`
- `wdk-data-shard-wrk/workers/lib/db/base/unit.of.work.js`
- `wdk-data-shard-wrk/workers/lib/db/mongodb/context.js`
- `wdk-data-shard-wrk/workers/lib/db/mongodb/unit.of.work.js`
- `wdk-data-shard-wrk/workers/lib/db/hyperdb/context.js`
- `wdk-data-shard-wrk/workers/lib/db/hyperdb/unit.of.work.js`

**What to add:**
- Instantiate runs/results repositories in DB contexts and UoWs
- Wire Mongo `ready()` and `commitWrites()` for them

**Done when:**
- `this.db.migrationReconciliationRunsRepository`
- `this.db.migrationReconciliationResultsRepository`
- matching `uow.*` repositories
- are available in both engines

### Step 3.5 — Proc-side reconciliation core

**File to modify:** `wdk-data-shard-wrk/workers/proc.shard.data.wrk.js`

**What to add:**
- A proc method that performs a shard-local reconciliation run, for example:
  - `triggerMigrationReconciliation(req)` as proc RPC entrypoint
  - `_reconcileMigrationShard({ runId, snapshotCutoff, shardId })` as internal implementation
- Proc RPC registration for `triggerMigrationReconciliation`

**Run model:**
- `runId` is minted globally by ORK and passed to every shard
- `shardId` is stored locally with each run/result row
- Each shard processes only the users assigned to that shard

**Algorithm requirements:**
1. Select exactly one snapshot per user:
   - `getLatestPerUser(snapshotCutoff)`
2. Pair wallets by stable identity:
   - `type='user'` pairs to the user wallet
   - `type='channel'` pairs by `channelId`
3. Compare one EVM chain in priority order:
   - `ethereum`
   - `polygon`
   - `arbitrum`
   - `plasma`
4. Status rules for paired wallets:
   - If compared EVM address differs:
     - `OWNED_BY_OTHER_USER` if FE address belongs to another user
     - otherwise `MISMATCH`
   - Else if `backendAccountIndex !== frontendAccountIndex`:
     - `MISMATCH`
   - Else:
     - `MATCH`
5. Unpaired wallets:
   - backend only -> `MISSING_IN_FE`
   - frontend only -> `MISSING_IN_BE`
6. For `MISMATCH` and `OWNED_BY_OTHER_USER`:
   - fetch EVM balance for BE and FE address
   - fetch BTC balance for BE and FE BTC addresses if present
   - on BTC busy/failure, retry and then use `balance_unknown`
7. Store per-wallet results and shard-local aggregate metrics

**Important correction from the previous draft:**
- A paired wallet with equal EVM address but different account index is still a `MISMATCH`, not a `MATCH`.

**Concurrency guard:**
- Use the existing `_runJob(...)` pattern or equivalent proc flag to prevent concurrent local executions.

**Done when:**
- A shard-local reconciliation run can be triggered in tests and produces correct statuses and stored results.

### Step 3.6 — Shard API: trigger forwarder + shard-local reads

**File to modify:** `wdk-data-shard-wrk/workers/api.shard.data.wrk.js`

**What to add:**
- `triggerMigrationReconciliation(req)`
  - forwards to proc with `_procRpcCall('triggerMigrationReconciliation', req)`
- `getMigrationReconciliationRuns(req)`
  - returns shard-local runs from API worker DB context
- `getMigrationReconciliationResults(req)`
  - returns shard-local results for a run with optional filters
- `getMigrationReconciliationMetrics(req)`
  - returns shard-local metrics for the latest run or for a specified `runId`

**Important:**
- Only the trigger goes to proc.
- Read endpoints can stay in the shard API worker because they are DB reads.

**Done when:**
- Shard API exposes all four actions and they behave correctly.

### Step 3.7 — Ork: global fanout and aggregation

**File to modify:** `wdk-ork-wrk/workers/api.ork.wrk.js`

**What to add:**
- Global ork methods exposed to app-node:
  - `triggerMigrationReconciliation(req)`
  - `getMigrationReconciliationRuns(req)`
  - `getMigrationReconciliationResults(req)`
  - `getMigrationReconciliationMetrics(req)`
- Register all four in ork RPC action list

**Global trigger behavior:**
1. Mint `runId = crypto.randomUUID()`
2. Determine participating shards from `this._shardUtil.dataShardIdx.getItems()`
3. Fan out to every shard with:
   - `shardId`
   - `runId`
   - `snapshotCutoff`
4. Return:
   - `runId`
   - shard count
   - start timestamp

**Global read behavior:**
- Fan out to every shard and merge results

**Merge rules:**
- `/runs`
  - merge shard-local rows by `runId`
  - sum count metrics
  - `startedAt = min(startedAt)`
  - `finishedAt = max(finishedAt)`
  - include a derived count of contributing shards if useful
- `/runs/:runId/results`
  - concatenate shard-local results for the same `runId`
  - preserve optional `status` / `balanceStatus` filtering
- `/metrics`
  - derive from the latest merged global run

**Important:**
- Do not use `_rpcRequest(req, action)` for these global admin reads/triggers without fanout logic.
- They are not user-scoped and cannot rely on `userId`-based shard routing.

**Done when:**
- Trigger returns a single global `runId`
- Run/results/metrics endpoints aggregate correctly across all shards

### Step 3.8 — Admin authorization

**Files to modify:**
- `wdk-app-node/workers/lib/middlewares/auth/jwt.guard.js`
- `wdk-app-node/workers/lib/server.js`
- optionally add a dedicated helper/middleware under `wdk-app-node/workers/lib/middlewares/`

**Problem to solve:**
- Current JWT guard only exposes `user.id`
- There is no admin-role check in app-node today

**Implementation options:**
- Preferred:
  - preserve admin claims from JWT in `req._info.user` such as `roles` or `isAdmin`
  - add `requireMigrationReconciliationAdmin(ctx, req)` that checks the claim
- Fallback:
  - config allowlist, e.g. `conf.migrationReconciliation.adminUserIds`

**Requirement:**
- Reconciliation endpoints must be admin-only, not merely authenticated

**Done when:**
- Non-admin authenticated users are forbidden from the reconciliation endpoints
- Approved admin users can access them

### Step 3.9 — App-node service methods and routes

**File to modify:** `wdk-app-node/workers/lib/services/ork.js`

**Add service methods:**
- `triggerMigrationReconciliation(ctx, req)`
- `getMigrationReconciliationRuns(ctx, req)`
- `getMigrationReconciliationResults(ctx, req)`
- `getMigrationReconciliationMetrics(ctx, req)`

**File to modify:** `wdk-app-node/workers/lib/server.js`

**Add routes:**
- `POST /api/v1/admin/migration-reconciliation/trigger`
- `GET /api/v1/admin/migration-reconciliation/runs`
- `GET /api/v1/admin/migration-reconciliation/runs/:runId/results`
- `GET /api/v1/admin/migration-reconciliation/metrics`

**Route requirements:**
- auth guard
- admin guard from Step 3.8
- results route supports `status` and `balanceStatus` query filters

**Done when:**
- All four endpoints work end-to-end through app-node -> ork -> shards

### Step 3.10 — Scheduler (ORK master, not per-shard proc)

**Primary file to modify:** `wdk-ork-wrk/workers/api.ork.wrk.js`

**Why ORK master:**
- A shard-local proc scheduler would create unrelated run IDs on each shard
- The global run must be coordinated once and fan out across all shards

**What to add:**
- New ORK master schedule that calls the same global trigger logic from Step 3.7
- Guard behind config flag, for example:
  - `migrationReconciliation.enabled: false`
  - `migrationReconciliation.schedule: '0 3 * * *'`

**Config files to update:**
- the relevant ork config examples
- the relevant deployed runtime config

**Behavior:**
- When enabled on the ORK master instance, it launches one global run per schedule
- When disabled, manual trigger remains available

**Done when:**
- One scheduled global run is created per interval
- All shards receive the same `runId`

---

## Verification Matrix

Ship and verify in this order:

### Phase 1 verification
- Trigger ORK duplicate-address rejection
- Trigger all shard rejection branches
- Confirm logs contain the expected structured payloads

### Phase 2 verification
- Store a migration snapshot end-to-end through HTTP
- Repeat the same request and confirm it appends, not rejects
- Confirm latest-per-user query returns only the newest snapshot

### Phase 3 verification
- Seed two shards with snapshot + canonical wallet data
- Trigger one global run
- Confirm:
  - one global `runId` is returned
  - each shard stores local rows with the same `runId`
  - `/runs` returns one merged logical run
  - `/runs/:runId/results` returns concatenated rows from all shards
  - account-index drift with equal EVM address is classified as `MISMATCH`
  - `OWNED_BY_OTHER_USER` is detected correctly
  - non-admin users are forbidden

---

## Execution Order Summary

```text
Phase 1
  1.1  Ork-side logging
  1.2  Shard-side logging
  1.3  Query existing logs

Phase 2
  2.1  Base snapshot repository
  2.2  Mongo snapshot repository
  2.3  HyperDB snapshot repository + spec regeneration
  2.4  DB wiring
  2.5  Proc-side snapshot write RPC
  2.6  Shard API forwarder
  2.7  Ork route-through action
  2.8  App-node service method
  2.9  HTTP route

Phase 3
  3.1  Base runs/results repository contracts
  3.2  Mongo runs/results repositories
  3.3  HyperDB runs/results repositories + spec regeneration
  3.4  DB wiring
  3.5  Proc-side reconciliation core
  3.6  Shard API trigger/read handlers
  3.7  Ork global fanout + aggregation
  3.8  Admin authorization
  3.9  App-node service methods + routes
  3.10 ORK master scheduler
```

Deployment notes:
- Phase 1 can ship independently
- Phase 2 can ship independently and should ship before Phase 3
- Phase 3 manual trigger can ship before the scheduler
- The scheduler should be enabled only after the global trigger + aggregation path is verified in staging
