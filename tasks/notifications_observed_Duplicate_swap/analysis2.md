# Duplicate Swap Notifications - Root Cause Analysis

**Date:** 2025-12-02
**Status:** Investigation Complete

## Executive Summary

The duplicate swap notifications are caused by **architectural timing issues**, not FCM token duplication. The investigation reveals that the same transfer event can trigger multiple notification sends through overlapping code paths, particularly due to asynchronous event emission combined with concurrent scheduled jobs.

---

## Issue Description

Users occasionally receive duplicate swap notifications, including swap completion notifications (triggered by the backend, not the app). The issue is intermittent and cannot be reliably reproduced.

---

## Architecture Overview

The notification flow involves multiple components:

```
Blockchain → wdk-data-shard-wrk (proc) → rumble-data-shard-wrk (proc) → FCM
                    ↓
              new-transfer event
                    ↓
         _walletTransferDetected() → sendUserNotification() → FCM
```

Key files:
- **Parent class**: `@tetherto/wdk-data-shard-wrk/workers/proc.shard.data.wrk.js`
- **Child class**: `rumble-data-shard-wrk/workers/proc.shard.data.wrk.js`
- **FCM utility**: `rumble-data-shard-wrk/workers/lib/utils/notification.util.js`

---

## Root Causes Identified

### 1. PRIMARY CAUSE: Asynchronous Event Emission with `setImmediate()`

**Location:** `@tetherto/wdk-data-shard-wrk/workers/proc.shard.data.wrk.js:516`

```javascript
// In _walletTransferBatch method
for (const tx of walletTxs) {
  // ... save to database
  await uow.walletTransferRepository.save({
    ...tx,
    walletId: wallet.id,
    ts
  })

  setImmediate(() => this.emit('new-transfer', { wallet, tx }))
}
```

**Why this causes duplication:**

1. The `setImmediate()` schedules the event emission to run after the current operation completes, but **before I/O callbacks**
2. When processing multiple transfers in a batch, all `setImmediate` callbacks are queued up
3. If the `syncWalletTransfersJob` runs again before all events are processed (e.g., due to rapid polling or job overlap), the same transaction could be re-fetched from the blockchain (if checkpoint update is delayed) and re-emitted
4. The listener in the child class (`rumble-data-shard-wrk/workers/proc.shard.data.wrk.js:437`) handles each event:

```javascript
this.on('new-transfer', this._walletTransferDetected.bind(this))
```

**Why it's intermittent:** The timing depends on:
- Event loop task scheduling
- Batch size of transfers being processed
- Database write latency
- Network conditions

### 2. SECONDARY CAUSE: Checkpoint Update Race Condition

**Location:** `@tetherto/wdk-data-shard-wrk/workers/proc.shard.data.wrk.js:525-535`

```javascript
// persist per-address checkpoints AFTER processing all wallets
if (perAddressMaxTs && perAddressMaxTs.size) {
  uow ??= await this.db.unitOfWork()
  for (const [k, ts] of perAddressMaxTs.entries()) {
    const [chain, ccy, address] = k.split(':')
    await uow.addressCheckpointRepository.setTs(chain, ccy, address, ts)
  }
}

await uow?.commit()
```

**Problem:** The checkpoint (which tracks the last processed timestamp per address) is only updated at the **end** of the batch processing. If:
1. Job A starts processing and emits events
2. Job A takes time to finish due to many transfers
3. Job A's checkpoint update hasn't committed yet
4. Job B starts (if `*/5 * * * *` fires again or scheduler re-triggers)
5. Job B fetches the same transfers (checkpoint not updated)
6. Job B emits duplicate events

### 3. TERTIARY CAUSE: Missing Notification Idempotency

**Location:** `rumble-data-shard-wrk/workers/proc.shard.data.wrk.js:62-107`

```javascript
async _walletTransferDetected ({ wallet, tx }) {
  // ... validation checks

  if (isRecipient) {
    // No deduplication check before sending!
    this.sendUserNotification({
      toUserId: userId,
      type: NOTIFICATION_TYPES.TOKEN_TRANSFER_COMPLETED,
      amount,
      token,
      blockchain
    }).catch(err => {
      this.logger.error(`Failed to send transfer completion notification: ${err.message}`)
    })
  }
}
```

**Problem:** There is no mechanism to track whether a notification was already sent for a specific `(transactionHash, userId, transferIndex)` combination. If the same event is received twice, two notifications are sent.

---

## Why FCM Token Duplication Was Ruled Out

The team correctly identified that FCM token duplication would cause **consistent** duplication for affected users, not intermittent issues. The code also includes token deduplication at send time:

**Location:** `rumble-data-shard-wrk/workers/proc.shard.data.wrk.js:359-362`

```javascript
const tokens = [...new Set(devices
  .map(d => d.fcmToken || d.deviceId)
  .filter(Boolean)
)]
```

This ensures that even if duplicate tokens exist in storage, they are deduplicated before sending.

---

## Notification Flow Analysis

### Flow 1: Transfer Detection (Current Issue Location)

```
syncWalletTransfersJob (every 5 minutes)
    ↓
_walletTransferBatch()
    ↓
for each tx: save + setImmediate(emit 'new-transfer')
    ↓
_walletTransferDetected() listener
    ↓
sendUserNotification() → FCM
```

### Flow 2: TX Webhook Processing (Parallel Path)

```
_processTxWebhooksJob (every 10 seconds)
    ↓
for each pending webhook: check if completed
    ↓
If completed: call rumbleServerUtil → (may trigger notifications via Rumble server)
```

**Note:** These two flows can run concurrently for the same transaction, potentially causing duplication if both paths trigger notifications.

---

## Evidence Summary

| Finding | Location | Impact |
|---------|----------|--------|
| `setImmediate()` event emission | Parent proc.shard.data.wrk.js:516 | Primary cause - async timing |
| Checkpoint update at batch end | Parent proc.shard.data.wrk.js:525-535 | Allows re-fetch of same txs |
| No notification deduplication | Child proc.shard.data.wrk.js:62-107 | No protection against re-sends |
| Job overlap protection only per-flag | Parent proc.shard.data.wrk.js:354-372 | Single instance protected, not cluster |

---

## Recommendations

### Immediate Fixes (Short-term)

1. **Add notification deduplication cache**
   - Track recently sent notifications by `(txHash:userId:transferIndex)`
   - Use Redis or in-memory TTL cache (e.g., 5-minute window)
   - Skip sending if key exists

2. **Update checkpoint before emitting events**
   - Move checkpoint commit before the `setImmediate()` emissions
   - Ensures next job run won't re-fetch same transactions

3. **Use synchronous event emission**
   - Replace `setImmediate(() => this.emit(...))` with direct `this.emit(...)`
   - Or batch all emissions after commit completes

### Architectural Fixes (Long-term)

4. **Implement distributed locking for jobs**
   - Use Redis-based lock for `syncWalletTransfersJob`
   - Prevents multiple instances from processing simultaneously

5. **Add notification delivery tracking table**
   - Store sent notifications with compound key
   - Query before sending to prevent duplicates

6. **Consolidate notification triggers**
   - Single source of truth for swap notifications
   - Remove parallel notification paths if any exist

---

## Affected Files

| File | Role |
|------|------|
| `@tetherto/wdk-data-shard-wrk/workers/proc.shard.data.wrk.js` | Event emission source (parent class) |
| `rumble-data-shard-wrk/workers/proc.shard.data.wrk.js` | Event listener & notification sender |
| `rumble-data-shard-wrk/workers/lib/utils/notification.util.js` | FCM integration |
| `rumble-data-shard-wrk/workers/api.shard.data.wrk.js` | Device/token management |

---

## Conclusion

The duplicate notifications are caused by a combination of:
1. **Asynchronous event emission** (`setImmediate`) creating timing windows
2. **Late checkpoint updates** allowing re-processing of transactions
3. **Missing idempotency** at the notification layer

This explains why the issue is intermittent - it requires specific timing conditions where either the same job re-fetches transactions before checkpoint update, or event handlers process the same transfer multiple times due to async scheduling.

The fix should prioritize adding notification deduplication as an immediate safeguard, followed by addressing the checkpoint update timing and considering synchronous event emission.
