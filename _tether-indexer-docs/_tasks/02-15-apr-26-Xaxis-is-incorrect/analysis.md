# Root-Cause Analysis: `/api/v1/balance/trend` Returns Empty Data

## Executive Summary

The X-axis bug is a **symptom**, not the cause. The frontend chart shows incorrect/empty X-axis values because the backend `/api/v1/balance/trend` endpoint returns empty arrays — there are no balance snapshots in the database for the affected users. The root cause is a chain of failures in the `syncBalancesJob` that prevent snapshots from ever being written.

There are **5 interacting root causes**, not a single bug.

---

## Data Flow (How It Should Work)

```
syncBalancesJob (cron every 6h, 20min timeout)
  → iterateActiveUsers (paginated, 500/page)
    → _processUserBalanceIfMissing(userId)
      → _hasUserBalanceToday(userId)  — skip if snapshot exists for today
      → getActiveUserWallets(userId)
      → getAggregatedWalletBalance(wallets, concurrency=3)
        → getWalletBalanceWithAddress(wallet)       — per wallet
          → getAddressBalance(chain, address)       — per chain
            → _rpcCall(chain, ccy, 'getBalance')    — per currency
      → push entries to batch pipe
    → _saveBalanceBatch(pipe) when pipe.length >= 500
```

When a user hits `GET /api/v1/balance/trend?range=1m&tokens=usdt,btc`:

```
wdk-app-node: /api/v1/balance/trend
  → rpcCall('getUserBalanceHist', { range, tokens })
    → wdk-data-shard: getUserBalanceHist(req)
      → getTimeBuckets('1m') → 30 daily buckets
      → for each bucket: getLatestUserBalancesInRange(userId, from, to)
      → _getHistBalances(results, tokens)
      → return { usdt: [{ts, balance}, ...], btc: [...] }
```

If no snapshots exist in the DB → every bucket query returns null → `results.filter(r => r !== null)` is empty → response is `{ usdt: [], btc: [] }`.

---

## Root Cause 1: RPC Call Explosion (Scalability)

**File:** `wdk-data-shard-wrk/workers/lib/blockchain.svc.js`

Per-user RPC call count = `wallets × chains_per_wallet × ccys_per_chain`

From `config/common.json`, there are **10 chains with ~14 currency slots**:
- ethereum (usdt, xaut), sepolia (usdt0), plasma (usdt0, xaut0), arbitrum (usdt), polygon (usdt), tron (usdt), ton (usdt, xaut), solana (usdt), bitcoin (btc), spark (btc)

A user with 1 wallet covering all chains generates **~14 RPC calls** (each with 3 retries on failure).
With N active users, the job makes **N × W × ~14** RPC calls minimum.

The 20-minute timeout (`jobTimeouts.syncBalances = 20 * 60 * 1000`) is not enough when the user base grows. Staging already exceeds this (per March meeting notes). Production is now hitting the same wall.

**Impact:** Users processed after the timeout are never snapshotted on that run.

---

## Root Cause 2: Silent Null-Balance Skipping

**File:** `wdk-data-shard-wrk/workers/proc.shard.data.wrk.js:662`

```javascript
// In _processUserBalanceIfMissing:
const bal = await this.blockchainSvc.getAggregatedWalletBalance(wallets, 3)

if (bal.balance !== null) {  // ← THIS CHECK
    entries.push({
        type: 'user',
        entry: { balance: bal.balance, tokenBalances: bal.tokenBalances, ts, userId }
    })
}
```

If **any single currency** on **any single chain** fails its RPC call, `getAddressBalance` sets `ccyFailed = true` and returns `balance: null` (line 226 of `blockchain.svc.js`). This propagates up through `getWalletBalanceWithAddress` → `getAggregatedWalletBalance` → `bal.balance = null`.

The consequence: the `bal.balance !== null` check fails, and **no user balance entry is added**. The entire user is silently skipped with no dedicated error log for this specific condition.

**This is the most likely immediate cause of the bug.** Even a transient RPC failure on one obscure chain/currency pair (e.g., `spark:btc`) causes the user's entire snapshot to be dropped. The user's `tokenBalances` (which may have valid data for `usdt`, `btc`, etc.) are thrown away because the aggregated `balance` field is null.

---

## Root Cause 3: Timeout = Abandoned Users + Lost Pipe

**File:** `wdk-data-shard-wrk/workers/proc.shard.data.wrk.js:784`

```javascript
for await (const user of this.db.userRepository.iterateActiveUsers(0, Date.now())) {
    if (getSignal()?.aborted) return  // ← clean exit on timeout
    // ...
    if (pipe.length >= this.dbWriteBatchSize) {
        await this._saveBalanceBatch(pipe)
        pipe = []
    }
}

// Save remaining entries
if (pipe.length > 0) {
    await this._saveBalanceBatch(pipe)  // ← NEVER REACHED if aborted above
}
```

When the 20-minute timeout fires:
1. `getSignal()?.aborted` becomes true
2. The loop does `return`, jumping past the final `_saveBalanceBatch`
3. Any entries accumulated in `pipe` (up to 499 entries) are **lost**
4. All users not yet iterated get **no snapshot** on this run

Since `iterateActiveUsers` sorts by `id` (ascending), and the job always starts from the beginning, users with IDs late in the sort order are **systematically disadvantaged** — they're more likely to be past the timeout cutoff every single run.

---

## Root Cause 4: Batch Save Failure = Silent Data Loss

**File:** `wdk-data-shard-wrk/workers/proc.shard.data.wrk.js:800-804`

```javascript
if (pipe.length >= this.dbWriteBatchSize) {
    try {
        await this._saveBalanceBatch(pipe)
        pipe = []
    } catch (err) {
        this.logger.error({ errorCode: 'ERR_BALANCE_BATCH_SAVE_FAILED', err }, '...')
        pipe = []  // ← CLEARS THE PIPE, entries are lost forever
    }
}
```

If `_saveBalanceBatch` fails (e.g., DB write timeout, connection issue), the entire batch of up to 500 user snapshots is discarded. The error is logged but there's no retry mechanism within the same run. The "will retry in next run" comment is optimistic — the next run may skip these users because `_hasUserBalanceToday` could still return false (the day hasn't changed) but a different failure may prevent them from being saved again.

---

## Root Cause 5: "All" Range Bootstrap Problem

**File:** `wdk-data-shard-wrk/workers/api.shard.data.wrk.js:228-231`

```javascript
if (range.toLowerCase() === 'all') {
    const balanceData = await this.db.userBalanceRepository
        .getLatestUserBalancesInRange(userId, 0, Date.now(), false)
    createdAt = balanceData?.ts || null
}
const buckets = getTimeBuckets(range, createdAt)
```

For `range=all`, the code looks for the **earliest** existing snapshot to determine the start of the time range. If no snapshots exist:
- `createdAt = null`
- `getTimeBuckets('all', null)` uses `new Date(0)` (Jan 1, 1970) as startDate
- Creates 10 buckets spanning 1970–2026
- Every bucket query returns null → empty response

For other ranges (`1d`, `7d`, `1m`), the buckets are relative to `now`, so they also return empty when no snapshots exist — but at least the time range is sensible.

---

## What Usman's PR #186 Fixed (and Didn't Fix)

### Fixed
1. **MongoDB cursor issue:** Replaced `getActiveUsers()` (single long-lived cursor) with `iterateActiveUsers()` (paginated, 500/page). This prevents "pool destroyed" errors when the cursor outlives the connection pool timeout.
2. **Abort signal:** Added `getSignal()?.aborted` check so the job can exit cleanly on timeout instead of hanging.

### Left Unaddressed
1. RPC call explosion — still O(N × W × C) calls per run
2. Null-balance silent skipping — a single RPC failure voids the entire user
3. Timeout pipe loss — abort discards unsaved entries
4. Batch failure data loss — no retry on save failure
5. No backfill — users who were missed have no catch-up mechanism
6. No observability — no metric for "users skipped due to null balance" vs "users skipped because already had today's snapshot"

---

## Proposed Fix

### Phase 1: Immediate Fix (Stop the Bleeding)

**A. Save snapshots even with partial balance data**

The most impactful single change. In `_processUserBalanceIfMissing`, save the snapshot even if `bal.balance` is null, as long as `tokenBalances` has at least one non-null value:

```javascript
// BEFORE (line 662):
if (bal.balance !== null) {
    entries.push({ type: 'user', entry: { ... } })
}

// AFTER:
const hasAnyTokenBalance = Object.values(bal.tokenBalances).some(v => v !== null)
if (bal.balance !== null || hasAnyTokenBalance) {
    entries.push({
        type: 'user',
        entry: {
            balance: bal.balance ?? '0',
            tokenBalances: bal.tokenBalances,
            ts,
            userId
        }
    })
}
```

This ensures that a user with valid USDT and BTC balances doesn't lose their snapshot just because the `spark:btc` RPC timed out.

**B. Flush pipe on abort**

Save accumulated entries before exiting on timeout:

```javascript
// BEFORE (line 784):
if (getSignal()?.aborted) return

// AFTER:
if (getSignal()?.aborted) {
    if (pipe.length > 0) {
        try { await this._saveBalanceBatch(pipe) } catch (e) {
            this.logger.error({ errorCode: 'ERR_BALANCE_ABORT_FLUSH_FAILED', err: e }, 'Failed to flush pipe on abort')
        }
    }
    this.logger.warn({ processedCount, skippedCount, pipeFlushed: pipe.length }, 'syncBalancesJob aborted by timeout')
    return
}
```

**C. Add observability**

Log distinct counters for: processed, skipped (already exists), skipped (null balance), skipped (no wallets), failed (save error). This makes it possible to diagnose the problem from logs without code archaeology.

### Phase 2: Scalability Fix

**D. Reduce RPC calls with caching/batching**

- Cache `getAddressBalance` results for addresses that haven't received new transactions since the last snapshot. Use the indexed transaction data (already available in the system) to determine which addresses are "stale" and can reuse yesterday's balance.
- Batch RPC calls per chain instead of per-address. If the indexer supports multi-address balance queries, use them.

**E. Increase timeout or make it dynamic**

- The 20-minute timeout is arbitrary. Calculate expected runtime based on user count and scale accordingly.
- Or: split the user iteration into shards/pages and run them as separate micro-jobs that each fit within the timeout.

**F. Randomize iteration order**

Currently `iterateActiveUsers` sorts by `id` ascending. Users with late-alphabetical IDs are systematically more likely to be skipped on timeout. Randomize or rotate the starting point each run so all users get fair coverage over multiple runs.

### Phase 3: Robustness

**G. Backfill job**

Add a separate job (or extend `syncBalancesJob`) that identifies users with zero snapshots in the past N days and prioritizes them. This catches users who were missed due to timeouts or failures.

**H. On-demand snapshot creation**

When the trend endpoint is called and finds no data, trigger an immediate snapshot creation for that user (async, best-effort). This provides a self-healing mechanism.

---

## Related Task Confirmation

The related Asana task (`1213243397743073`) is very likely the same root cause. If it's also about empty/missing balance data for users who have confirmed on-chain balances, the underlying issue is identical: `syncBalancesJob` isn't creating snapshots for those users due to the failures described above.

---

## Key Files

| Component | File | Lines |
|---|---|---|
| Trend endpoint handler | `wdk-app-node/workers/lib/services/ork.js` | 180-188 |
| Balance hist query | `wdk-data-shard-wrk/workers/api.shard.data.wrk.js` | 224-242 |
| Time bucket generation | `wdk-data-shard-wrk/workers/lib/utils.js` | 103-163 |
| syncBalancesJob | `wdk-data-shard-wrk/workers/proc.shard.data.wrk.js` | 771-827 |
| _processUserBalanceIfMissing | `wdk-data-shard-wrk/workers/proc.shard.data.wrk.js` | 642-694 |
| **Null balance skip (primary bug)** | `wdk-data-shard-wrk/workers/proc.shard.data.wrk.js` | **662** |
| getAggregatedWalletBalance | `wdk-data-shard-wrk/workers/lib/blockchain.svc.js` | 280-334 |
| getAddressBalance (RPC calls) | `wdk-data-shard-wrk/workers/lib/blockchain.svc.js` | 201-228 |
| MongoDB balance repository | `wdk-data-shard-wrk/workers/lib/db/mongodb/repositories/user.balances.js` | 79-93 |
| Chain/currency config | `wdk-data-shard-wrk/config/common.json` | 20-31 |
| Job scheduler registration | `wdk-data-shard-wrk/workers/proc.shard.data.wrk.js` | 1279-1283 |
| PR #186 (Usman's partial fix) | git merge commit `706c2c2` | — |
