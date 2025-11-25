# Example Configuration File Updates

**Date:** November 25, 2025
**Purpose:** Document new configuration options for Hyperswarm RPC pool management

---

## Summary

Updated example configuration files across 3 repositories to document the new `netOpts` configuration introduced to fix Hyperswarm RPC pool timeout issues.

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

## Files Updated

### 1. `wdk-data-shard-wrk/config/common.json.example`

**Changes:**
```json
{
  "netOpts": {
    "poolLinger": 600000,
    "timeout": 60000
  }
}
```

**Location in file:** After `topicConf`, before `shardTopic`

**Note:** `maxRetries` and `retryDelay` were already present in this example file

---

### 2. `rumble-data-shard-wrk/config/common.json.example`

**Changes:**
```json
{
  "netOpts": {
    "poolLinger": 600000,
    "timeout": 60000
  },
  "maxRetries": 3,
  "retryDelay": 1000
}
```

**Location in file:** After `topicConf`, before `shardTopic`

**Note:** Added both `netOpts` AND `maxRetries`/`retryDelay` (these were missing)

---

### 3. `tether-wrk-base/config/common.json.example`

**Changes:**
```json
{
  "debug": 0,
  "netOpts": {
    "poolLinger": 600000,
    "timeout": 60000
  }
}
```

**Location in file:** After `debug`

**Note:** This is the base library that passes netOpts to hp-svc-facs-net, so documenting here is important

---

## Configuration Documentation

### `netOpts` Object

**Purpose:** Configure Hyperswarm RPC connection pool behavior

**Schema:**
```json
{
  "netOpts": {
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

### `maxRetries` and `retryDelay`

**Purpose:** Configure retry behavior for RPC calls in `blockchain.svc.js`

**Schema:**
```json
{
  "maxRetries": <number>,
  "retryDelay": <number>  // milliseconds
}
```

**Parameters:**

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `maxRetries` | number | 2 | Number of retry attempts for failed RPC calls. Uses exponential backoff |
| `retryDelay` | number | 500 | Base delay (ms) between retries. Actual delay: `retryDelay * 2^attemptNumber` |

**Example retry timing with defaults:**
- Attempt 1: Immediate
- Attempt 2: 500ms delay
- Attempt 3: 1000ms delay

**When to configure:**
- ✅ Set `maxRetries: 3` in production for high reliability
- ✅ Set `retryDelay: 1000` for slower but more reliable retries
- ℹ️ Defaults (2 retries, 500ms) are reasonable for most cases

---

## Commit Messages for Example File Updates

### Repository: `wdk-data-shard-wrk`

```
docs: add netOpts to common.json.example

Document new netOpts configuration for Hyperswarm RPC pool management:
- poolLinger: 600000ms (10 minutes) - time before idle pools are destroyed
- timeout: 60000ms (1 minute) - RPC request timeout

These settings prevent [HRPC_ERR]=Pool was force destroyed errors by
providing sufficient buffer between sync jobs and pool destruction.

Note: maxRetries and retryDelay were already documented in this example.

Refs: _docs/hyperswarm_prod_issue/CODE_CHANGES_ASSESSMENT.md
```

---

### Repository: `rumble-data-shard-wrk`

```
docs: add netOpts, maxRetries, and retryDelay to common.json.example

Document new configuration options for Hyperswarm RPC resilience:

1. netOpts - Hyperswarm RPC pool management:
   - poolLinger: 600000ms (10 minutes)
   - timeout: 60000ms (1 minute)

2. Retry configuration:
   - maxRetries: 3
   - retryDelay: 1000ms

These settings prevent transient RPC failures and pool timeout race
conditions in production.

Refs: _docs/hyperswarm_prod_issue/CODE_CHANGES_ASSESSMENT.md
```

---

### Repository: `tether-wrk-base`

```
docs: add netOpts to common.json.example

Document netOpts configuration that is now passed to hp-svc-facs-net:
- poolLinger: 600000ms (10 minutes) - idle time before pool destruction
- timeout: 60000ms (1 minute) - RPC request timeout

This base library spreads netOpts from config to the net facility,
allowing downstream services to configure Hyperswarm RPC pool behavior.

Related: Fix for [HRPC_ERR]=Pool was force destroyed production errors.

Refs: _docs/hyperswarm_prod_issue/CODE_CHANGES_ASSESSMENT.md
```

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

## Summary

### Files Changed
- ✅ `wdk-data-shard-wrk/config/common.json.example` - Added netOpts
- ✅ `rumble-data-shard-wrk/config/common.json.example` - Added netOpts + maxRetries/retryDelay
- ✅ `tether-wrk-base/config/common.json.example` - Added netOpts

### Why These Changes Matter
- ✅ Developers will know about new configuration options
- ✅ Production deployments will use correct values by default
- ✅ Reduces risk of Hyperswarm RPC pool timeout errors
- ✅ Documents the retry logic configuration

### Next Steps (Optional)
- Consider adding a Configuration section to README.md files
- Document these options in any internal wikis or deployment guides
- Update any infrastructure-as-code (Terraform, Ansible, etc.) to include these settings

---

**Note:** These example file updates should be committed along with the code changes that introduced the netOpts functionality.
