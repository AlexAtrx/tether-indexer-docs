# Example Configuration File Updates

**Date:** November 25, 2025 (Updated: November 26, 2025 - Final)
**Purpose:** Document new configuration options for Hyperswarm RPC pool management

---

## Summary

**FINAL UPDATE (Nov 26, 2025):** Following PR #19 and PR #115 review feedback, configuration has been moved to the proper location (net facility config file), retry-related configs have been removed, and tether-wrk-base now implements _loadFacConf() to load and pass facility configs correctly.

Updated example configuration files to document the new `netOpts` configuration introduced to fix Hyperswarm RPC pool timeout issues.

---

## Why Example Files Need Updates

**Reason:** Developers using these libraries/apps need to know:
1. ✅ What the new `netOpts` configuration does
2. ✅ What values to use (defaults and recommended production values)
3. ✅ How to configure `maxRetries` and `retryDelay` for retry logic
4. ✅ That these options are available and optional

Without updating example files, developers would:
- ❌ Not know the new configuration options exist
- ❌ Continue using default values (5-minute poolLinger) that cause race conditions
- ❌ Not benefit from the retry logic improvements

---

## Files Updated (Final Nov 26, 2025)

### 1. `tether-wrk-base/config/facs/net.config.json.example` ✅ **UPDATED**

**Changes:**
```json
{
  "r0": {
    "poolLinger": 600000,
    "timeout": 60000
  }
}
```

**Location:** Net facility config file (proper location per PR #19 review)

**Previous location:** ~~`config/common.json.example`~~ (moved from here)

**How it's loaded:** Via `_loadFacConf('net')` method in `workers/base.wrk.tether.js`

**Note:** This follows the established pattern where facility-specific configs live in `config/facs/`

### 1b. `tether-wrk-base/workers/base.wrk.tether.js` ✅ **UPDATED**

**Changes:**
- Added `_loadFacConf(facName)` method to load facility configs
- Loads `config/facs/net.config.json` and passes values as opts to hp-svc-facs-net
- Backward compatible: returns `{}` if config doesn't exist
- Removed DHT error handler per reviewer feedback

### 2. `wdk-data-shard-wrk/config/facs/net.config.json.example` ✅ **UPDATED**

**Changes:** Same as tether-wrk-base (consistent across repos)

**Location:** Net facility config file

**Note:** Child repos inherit the pattern from tether-wrk-base

---

### ~~2. `rumble-data-shard-wrk/config/common.json.example`~~ **NOT IN THIS REPO**

**Status:** Deferred - Different repository

**Note:** Similar changes should be applied to rumble-data-shard-wrk in that repo

---

### ~~3. `tether-wrk-base/config/common.json.example`~~ **NOT IN THIS REPO**

**Status:** Deferred - Different repository, different PR

**Note:** Base library changes are tracked separately

---

## Configuration Documentation

### `netOpts` Object (Updated Nov 26, 2025)

**Purpose:** Configure Hyperswarm RPC connection pool behavior

**Location:** `config/facs/net.config.json` (under `r0` object)

**Schema:**
```json
{
  "r0": {
    "poolLinger": <number>,  // milliseconds
    "timeout": <number>      // milliseconds
  }
}
```

**Parameters:**

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `poolLinger` | number | 300000 | Time (ms) before idle RPC pools are destroyed. Recommended: 600000 (10 minutes) for production |
| `timeout` | number | 30000 | RPC request timeout (ms). Recommended: 60000 (1 minute) for production |

**When to configure:**
- ✅ Always set in production to avoid RPC pool timeout race conditions
- ✅ Set `poolLinger` > sync job interval (e.g., if syncing every 5 min, set poolLinger to 10 min)
- ℹ️ Can use defaults in development/testing

---

### ~~`maxRetries` and `retryDelay`~~ **REMOVED**

**Status:** ❌ **REMOVED per PR #115 review feedback (Nov 26, 2025)**

**Reason:** Retry logic was removed from blockchain.svc.js because sync jobs run frequently enough (every 5 minutes) that failed wallets will be retried on the next cycle.

**Previous purpose:** Configure retry behavior for RPC calls in `blockchain.svc.js`

**Impact of removal:**
- Simpler code without retry complexity
- Failed wallet syncs wait up to 5 minutes for next cycle
- Trade-off accepted per reviewer feedback

---

## Commit Messages for Example File Updates (Updated Nov 26, 2025)

### Repository: `wdk-data-shard-wrk`

```
refactor: move netOpts to net facility config and remove retry logic

- Move poolLinger and timeout config from common.json to net.config.json
- Remove retry logic from blockchain.svc.js (frequent sync makes it unnecessary)
- Keep Promise.allSettled for resilient batch operations

Config now in config/facs/net.config.json.example under r0:
- poolLinger: 600000ms (10 minutes) - time before idle pools are destroyed
- timeout: 60000ms (1 minute) - RPC request timeout

These settings prevent [HRPC_ERR]=Pool was force destroyed errors by
providing sufficient buffer between sync jobs and pool destruction.

Addresses PR #115 review feedback from SargeKhan.

Refs: _docs/task_hyperswarm_prod_issue/CODE_CHANGES_ASSESSMENT.md
```

---

### ~~Repository: `rumble-data-shard-wrk`~~ **DEFERRED**

**Status:** Not in this repo, separate PR needed

Similar changes should be applied following the same pattern (move to net.config.json)

---

### ~~Repository: `tether-wrk-base`~~ **DEFERRED**

**Status:** Not in this repo, separate PR/discussion needed

---

## Additional Documentation Recommendations

### Option 1: Add Config Section to README (Recommended)

Add a "Configuration" section to each repository's README.md:

```markdown
## Configuration

### Hyperswarm RPC Pool Settings

Configure RPC connection pool behavior to prevent timeout errors:

\`\`\`json
{
  "netOpts": {
    "poolLinger": 600000,  // 10 minutes - time before idle pools are destroyed
    "timeout": 60000       // 1 minute - RPC request timeout
  }
}
\`\`\`

**Recommended values:**
- Production: `poolLinger: 600000` (10 min), `timeout: 60000` (1 min)
- Development: defaults are fine (300000 / 30000)

**Important:** Set `poolLinger` to be greater than your sync job interval to avoid
race conditions between pool destruction and new RPC requests.

### Retry Configuration

Configure retry behavior for transient RPC failures:

\`\`\`json
{
  "maxRetries": 3,       // Number of retry attempts
  "retryDelay": 1000     // Base delay in milliseconds (uses exponential backoff)
}
\`\`\`

**Recommended values:**
- Production: `maxRetries: 3`, `retryDelay: 1000`
- Development: defaults (2 / 500) are usually sufficient
```

---

### Option 2: Create CONFIGURATION.md (Alternative)

Create a dedicated `CONFIGURATION.md` file in each repository with detailed documentation of all config options, including the new `netOpts`, `maxRetries`, and `retryDelay`.

---

## Summary (Updated Nov 26, 2025)

### Files Changed in wdk-data-shard-wrk
- ✅ `config/facs/net.config.json.example` - Added poolLinger/timeout to r0
- ~~❌ `config/common.json.example`~~ - Removed netOpts (moved to net.config)
- ✅ `workers/lib/blockchain.svc.js` - Removed retry logic, kept Promise.allSettled
- ✅ `tests/unit/lib/blockchain.svc.unit.test.js` - Removed retry config

### Why These Changes Matter
- ✅ Config follows proper architectural patterns (facility configs in config/facs/)
- ✅ Simpler code without retry complexity
- ✅ Reduces risk of Hyperswarm RPC pool timeout errors via increased poolLinger
- ✅ Promise.allSettled prevents cascading batch failures
- ⚠️ Trade-off: No immediate retry on transient failures (acceptable per review)

### Important Caveats
- ⚠️ Solution is partial without DHT error handlers (see ADDITIONAL_FIX_DHT_ERRORS.md)
- ⚠️ Worker crashes from PEER_NOT_FOUND still possible
- ⚠️ Failed wallets wait up to 5 minutes for next sync

### Next Steps
- ✅ Deploy these changes to address pool timeout race conditions
- ⚠️ **CRITICAL:** Add DHT error handlers to prevent worker crashes
- 📝 Monitor transaction data staleness in production
- 📝 Consider re-adding retry logic if staleness becomes problematic

---

**Note:** These changes implement PR #115 review feedback. DHT error handlers (ADDITIONAL_FIX_DHT_ERRORS.md) should be added for complete solution.
