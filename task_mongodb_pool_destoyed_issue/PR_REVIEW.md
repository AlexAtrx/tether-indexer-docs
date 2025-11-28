# PR Review: Hyperswarm Pool Changes

## Summary
These PRs were created under the false belief that `[HRPC_ERR]=Pool was force destroyed` was a Hyperswarm/RPC issue. Now that we know it's actually a **MongoDB error** from the Indexer, we need to assess which changes have value.

---

## PR Analysis

### ❌ **PR #19 (tether-wrk-base)**: Pass netOpts to hp-svc-facs-net
**What it does:** Allows configuration of Hyperswarm RPC `poolLinger` and `timeout` via `netOpts` in config files

**Verdict: UNNECESSARY**
- The error is **not caused by Hyperswarm pool timeouts**
- Increasing `poolLinger` doesn't fix MongoDB connection pool destruction
- This adds configuration complexity for the wrong layer
- **Recommendation:** Close/reject this PR

---

### ✅ **PR #115 (wdk-data-shard-wrk)**: MongoDB Operation Timeouts & Logging
**What it does:**
1. Adds `maxTimeMS` (30s) and `writeConcern` timeouts to MongoDB operations
2. Adds better job execution logging (start/end times, duration)
3. Passes `operations` config to all MongoDB repositories
4. Wraps transaction commits in try/finally to ensure sessions are closed

**Verdict: KEEP WITH MODIFICATIONS**

**Keep:**
- ✅ MongoDB operation timeouts (`maxTimeMS`, `writeConcern`) - these are good defensive programming
- ✅ Better job logging - helps with debugging and monitoring
- ✅ Ensuring sessions are always closed (`finally` block)

**Don't Keep:**
- ❌ The hypothesis that this fixes the "pool destroyed" error (it won't)

**Why it's valuable despite wrong diagnosis:**
- MongoDB timeouts prevent operations from hanging indefinitely during DB issues
- Proper session cleanup prevents connection leaks
- Better logging aids in debugging any DB-related issues
- These are general MongoDB best practices that improve resilience

**Recommendation:** Merge, but update the PR description to reflect that these are **defensive improvements**, not a fix for the original error

---

### ❌ **PR #94 (rumble-data-shard-wrk)**: Increase poolLinger Config
**What it does:** Changes example config to increase Hyperswarm `poolLinger` from 300s to 600s

**Verdict: UNNECESSARY**
- Only changes an example config file
- Doesn't fix the actual MongoDB issue
- May give false sense of security
- **Recommendation:** Close/reject this PR

---

## What Actually Needs to Be Done

Based on our analysis, the **real fix** should be:

1. **Add retry logic to Indexer** (Priority: High)
   - Location: `wdk-indexer-wrk-base/workers/api.indexer.wrk.js`
   - Wrap MongoDB queries with exponential backoff retry logic
   - Handle transient errors like pool destruction gracefully

2. **Keep the MongoDB defensive improvements from PR #115**
   - These are good practices regardless of the root cause

3. **Don't touch Hyperswarm RPC settings** (PRs #19, #94)
   - The RPC layer is working fine; the error originates from MongoDB
