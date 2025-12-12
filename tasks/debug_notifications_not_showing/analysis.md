# Analysis: Swap Notifications Not Reaching Mobile App on Staging

**Date:** 2025-12-12
**Issue:** SWAP_STARTED notifications are emitted by the backend (logs visible in Grafana) but the mobile app on staging (V2) does not receive them. Production V1 works correctly.

## PRs Deployed to Staging

- [wdk-data-shard-wrk PR #122](https://github.com/tetherto/wdk-data-shard-wrk/pull/122) - Merged
- [rumble-app-node PR #94](https://github.com/tetherto/rumble-app-node/pull/94) - Merged
- [rumble-data-shard-wrk PR #104](https://github.com/tetherto/rumble-data-shard-wrk/pull/104) - Merged
- [rumble-ork-wrk PR #63](https://github.com/tetherto/rumble-ork-wrk/pull/63) - Merged

---

## Summary of Code Changes

### 1. wdk-data-shard-wrk (PR #122)

**Purpose:** Gate transfer-triggered pushes on new inserts to prevent duplicate notifications.

**Key Changes:**
- Added `get()` method to `wallet.transfers` repository to check if transfer exists before saving
- Modified `_walletTransferBatch()` to only emit `new-transfer` for truly new rows
- Added FX price fetch retry/timeout/fallback logic
- Commits checkpoints before emitting notifications

**Files Modified:**
- `workers/proc.shard.data.wrk.js`
- `workers/lib/db/*/repositories/wallet.transfers.js`
- `workers/lib/price.calculator.js`

### 2. rumble-app-node (PR #94)

**Purpose:** Pass idempotency keys through the notifications API.

**Key Changes:**
- Added `idempotencyKey` and `requestId` to `/api/v1/notifications` schema (optional fields)
- These are forwarded to the ork layer

**Files Modified:**
- `workers/lib/server.js` (schema update)

### 3. rumble-data-shard-wrk (PR #104)

**Purpose:** Add per-notification deduplication for transfer pushes with telemetry.

**Key Changes:**
- Added `NotificationDedupeCache` class using `bfx-facs-lru`
- Dedupe key format: `${toUserId}:${transactionHash}:${transferIndex}:${type}`
- **Important:** For notifications without `transactionHash`/`transferIndex` (like SWAP_STARTED), the dedupe key is `null` and deduplication is bypassed
- Added telemetry logging for sent/suppressed/skipped counts

**Files Modified:**
- `workers/proc.shard.data.wrk.js`
- `workers/lib/utils/notification-dedupe.util.js` (new file)

### 4. rumble-ork-wrk (PR #63)

**Purpose:** Make manual notification types idempotent to prevent upstream retries from fanning out duplicate pushes.

**Key Changes:**
- Added LRU-backed idempotency for `SWAP_STARTED`, `TOPUP_STARTED`, `CASHOUT_STARTED`
- Idempotency key format: `${toUserId}:${type}:${idempotencyKey}`
- **Important:** Idempotency only applies when `idempotencyKey` is provided in the request
- TTL: 10 minutes (configurable via `notifications.idempotency.windowMs`)

**Files Modified:**
- `workers/api.ork.wrk.js`

---

## Notification Flow Analysis

```
Mobile App
    |
    v
POST /api/v1/notifications (rumble-app-node)
    |
    | Validates schema, extracts userId from auth token
    | Forwards: { userId, type, amount, token, blockchain, idempotencyKey?, requestId? }
    v
sendNotification (rumble-ork-wrk)
    |
    | Logs: "Notification payload info: type - SWAP_STARTED"  <-- THIS IS WHAT APPEARS IN GRAFANA
    |
    | IF idempotencyKey provided AND type in [SWAP_STARTED, TOPUP_STARTED, CASHOUT_STARTED]:
    |   Check lru_n1 cache for duplicate
    |   IF cached: return { success: true, deduped: true }  <-- NOTIFICATION BLOCKED
    |   ELSE: mark as in-flight, proceed
    |
    v
_sendUserNotification (rumble-ork-wrk)
    |
    | Resolves user's data shard via RPC
    v
sendUserNotification (rumble-data-shard-wrk)
    |
    | For SWAP_STARTED: dedupe key is null (no txHash/transferIndex)
    | Deduplication bypassed for manual notification types
    |
    | Gets user devices from DB
    | IF no FCM tokens: return { success: true }  <-- NO NOTIFICATION SENT
    |
    | Generates message from NOTIFY_MESSAGES template
    v
sendNotification (notification.util.js)
    |
    | IF !this.initialized: throw ERR_NOTIFICATION_NOT_INITIALIZED
    | Sends FCM multicast to device tokens
    v
Firebase Cloud Messaging --> Mobile App
```

---

## Pre-existing Bug Found (Not Caused by These PRs)

**Location:** `rumble-ork-wrk/workers/api.ork.wrk.js:42-45`

```javascript
init () {
  super.init()
  // ...
  this.setInitFacs([
    ['fac', 'bfx-facs-lru', 'n0', 'n0', { maxAge: balanceFailuresWindow }, 1],
    ['fac', 'bfx-facs-lru', 'n1', 'n1', { maxAge: idempotencyWindowMs, max: idempotencyMaxKeys }, 1]
  ])
}
```

**Issue:** `setInitFacs()` **replaces** (doesn't append to) the parent's facility array. This means:
- `lru_lookup` from wdk-ork-wrk is NOT initialized
- `scheduler_0` from wdk-ork-wrk is NOT initialized

**Impact:** This bug existed BEFORE PR #63 (which only added `n1`). The ork has been running without these facilities. This is not the cause of the new issue but should be fixed.

**Fix:** Use `this.initFacs.push(...)` instead of `this.setInitFacs([...])` to append facilities.

---

## Potential Root Causes

### 1. Idempotency Key Collision (Most Likely)

**Hypothesis:** Mobile app V2 is sending the same `idempotencyKey` for multiple requests.

**Evidence Required:** Check if `idempotencyKey` is being sent and if it's unique per request.

**Code Path:**
```javascript
// rumble-ork-wrk/workers/api.ork.wrk.js:268-274
if (idempotencyCacheKey) {
  const cached = this.lru_n1?.get(idempotencyCacheKey)
  if (cached) {
    this.logger.info(`Notification deduped for user ${toUserId}...`)
    return { success: true, deduped: true }  // NOTIFICATION BLOCKED
  }
  this.lru_n1?.set(idempotencyCacheKey, true)
}
```

**What to Check:**
- Is the mobile app sending `idempotencyKey`?
- If yes, is it generating unique keys per swap request?
- Look for logs: `"Notification deduped for user X and type SWAP_STARTED"`

### 2. Firebase Configuration Missing on Staging

**Hypothesis:** `firebaseServiceAccount` is not configured in staging environment.

**Code Path:**
```javascript
// notification.util.js:18-24
constructor (ctx) {
  this.initialized = false
  if (ctx.conf && ctx.conf.firebaseServiceAccount) {
    this.app = initializeApp({ credential: cert(ctx.conf.firebaseServiceAccount) })
    this.initialized = true
  }
}

// notification.util.js:39-41
async sendNotification ({ tokens, title, body }) {
  if (!this.initialized) {
    throw new Error('ERR_NOTIFICATION_NOT_INITIALIZED')  // SILENT FAILURE?
  }
  // ...
}
```

**What to Check:**
- Verify `firebaseServiceAccount` is in staging config
- Look for `ERR_NOTIFICATION_NOT_INITIALIZED` errors in logs

### 3. User Devices Not Registered in Staging DB

**Hypothesis:** Test users don't have FCM device tokens registered in the staging database.

**Code Path:**
```javascript
// rumble-data-shard-wrk/workers/proc.shard.data.wrk.js:573-587
const devices = await this._getUserDevices(req.toUserId)
const tokens = [...new Set(devices.map(d => d.fcmToken || d.deviceId).filter(Boolean))]

if (!tokens.length) {
  return { success: true }  // NO NOTIFICATION SENT - RETURNS SUCCESS!
}
```

**What to Check:**
- Query staging DB for user devices: `userData` collection, key `devices`
- Verify FCM tokens are present for test users

### 4. RPC Call Failing Between Ork and Data Shard

**Hypothesis:** The RPC call from ork to data shard is failing silently.

**What to Check:**
- Look for RPC timeout errors
- Check data shard logs for `rpc action request: sendUserNotification`
- Verify network connectivity between services

---

## Recommended Debugging Steps

### Step 1: Check Ork Logs for Idempotency Hits
```
Search for: "Notification deduped for user"
```
If this appears frequently, the issue is idempotency key reuse.

### Step 2: Check Data Shard Logs
```
Search for: "sendUserNotification"
```
If these logs don't appear, the RPC call from ork to data shard is failing.

### Step 3: Check Device Token Count
```
Search for: "using X tokens for notification"
```
If X is 0, users don't have devices registered.

### Step 4: Check Firebase Initialization
```
Search for: "ERR_NOTIFICATION_NOT_INITIALIZED"
```
If this appears, Firebase config is missing.

### Step 5: Check FCM Send Errors
```
Search for: "Notification send failed" or "Error sending notification to"
```

### Step 6: Verify Staging Configuration
Check that these config values are present in staging:
```json
{
  "firebaseServiceAccount": { ... },
  "notifications": {
    "idempotency": {
      "windowMs": 600000,
      "maxKeys": 5000
    }
  }
}
```

---

## Code Changes That Could Cause Silent Failures

### 1. Successful Return on No Tokens
```javascript
// rumble-data-shard-wrk/workers/proc.shard.data.wrk.js:583-587
if (!tokens.length) {
  this._notificationDedupeCache.release(dedupeKey)
  this._notificationDedupeCache.recordTelemetry({ status: 'skipped-no-tokens' })
  return { success: true }  // <-- Returns success even though nothing was sent!
}
```

### 2. Successful Return on Deduplication
```javascript
// rumble-ork-wrk/workers/api.ork.wrk.js:268-274
if (cached) {
  this.logger.info(`Notification deduped...`)
  return { success: true, deduped: true }  // <-- Returns success but notification blocked
}
```

### 3. Optional Chaining on LRU Cache
```javascript
// rumble-ork-wrk/workers/api.ork.wrk.js:269, 277, 289
this.lru_n1?.get(...)
this.lru_n1?.set(...)
this.lru_n1?.delete(...)
```
If `lru_n1` is undefined (facility not initialized), these operations silently fail and idempotency doesn't work - but notifications still proceed.

---

## Conclusion

The code logic in all four PRs appears correct and should not prevent notifications from being sent. The most likely causes are:

1. **Idempotency key collision** - Mobile app V2 sending duplicate keys
2. **Configuration issue** - Firebase not configured on staging
3. **Data issue** - User devices not registered in staging DB
4. **Deployment issue** - Services not properly deployed or connected

The fact that "SWAP_STARTED logs appear in Grafana" confirms the ork is receiving requests. The issue is downstream - either in the RPC to data shard, or in the data shard's notification sending.

**Recommended immediate action:** Add info-level logging to track the notification path and identify where notifications are being dropped.
