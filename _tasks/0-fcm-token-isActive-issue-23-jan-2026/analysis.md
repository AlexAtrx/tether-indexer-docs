# FCM Token / Device Registration - isActive Issue

**Date:** 23 January 2026
**Status:** Fix applied, but architectural improvement recommended

## Issue Summary

Developer reported: "there is issue while storing the fcm token for new user, it marks the status isActive: false by default"

## Root Cause Analysis

### The Bug

In `rumble-data-shard-wrk/workers/api.shard.data.wrk.js`, the `storeDevice` function had:

```javascript
const nextDevice = {
  ...existingDevice,
  ...deviceMeta,
  deviceId,
  fcmToken: fcmToken ?? existingDevice?.fcmToken ?? null,
  registeredAt: token ? now : (existingDevice?.registeredAt ?? now),
  lastNotifiedAt: existingDevice?.lastNotifiedAt ?? 0,
  isActive: existingDevice?.isActive ?? false  // <-- BUG: defaults to false
}
```

For new users, `existingDevice` is `null`, so `isActive` defaulted to `false`.

### Why V1 Accounts Worked

V1 accounts were stored **without** the `isActive` field. When read, `normalizeDevice()` converts missing `isActive` to `true`:

```javascript
const normalizeDevice = (device) => ({
  ...device,
  isActive: device?.isActive !== false  // undefined -> true
})
```

V2 code explicitly stored `isActive: false`, which persisted and couldn't be "fixed" by normalization.

### The Fix Applied

Changed default from `false` to `true`:

```javascript
isActive: existingDevice?.isActive ?? true
```

This ensures new device registrations default to active.

## Architectural Issue: `isLikelyFcmToken` Hack

### Current Behavior

The API accepts ambiguous input where clients can send FCM tokens in either the `deviceId` or `fcmToken` field. The code uses a heuristic to guess:

```javascript
const isLikelyFcmToken = (value) => {
  if (!value || typeof value !== 'string') return false
  return value.includes(':') || value.length >= 80
}

const token = fcmToken || (isLikelyFcmToken(deviceId) ? deviceId : null)
```

### Problems with This Approach

1. **Ambiguity**: The API guesses client intent instead of enforcing a contract
2. **Debugging difficulty**: Hard to trace issues when the system auto-corrects bad input
3. **False confidence**: Clients may think they're using the API correctly when they're not
4. **Heuristic failures**: The 80-char / colon detection can fail for edge cases

### Evidence from Testing

Tester's device data showed:
```json
{
  "deviceId": "dVqS-CxcQRuQZRCL5Jbf82:APA91bE...",
  "fcmToken": null,
  "isActive": true
}
```

The FCM token is in `deviceId`, not `fcmToken`. This worked only because `isLikelyFcmToken(deviceId)` returned `true`.

## Recommendation: Remove `isLikelyFcmToken`

### Proposed Change

1. Remove the `isLikelyFcmToken` function and fallback logic
2. Require `fcmToken` to be provided explicitly for push notifications
3. Treat `deviceId` as a device identifier only, not a token
4. Return clear error if `fcmToken` is missing/invalid

### Benefits

- **Clear API contract**: No guessing, no ambiguity
- **Easier debugging**: Issues are immediately apparent
- **Client accountability**: Forces correct implementation
- **Simpler code**: Remove heuristic complexity

### Trade-off

- **Breaking change**: Requires mobile app update to send `fcmToken` correctly
- Coordinate with mobile team before implementing

## Files Changed (Current Fix)

1. `rumble-data-shard-wrk/workers/api.shard.data.wrk.js` - Changed default `isActive` to `true`
2. `rumble-data-shard-wrk/tests/api.shard.data.wrk.unit.test.js` - Added 7 unit tests for device registration flow

## Test Cases Added

1. First-time registration yields `isActive: true`
2. First-time registration with FCM-like deviceId yields `isActive: true`
3. First-time registration without valid token defaults `isActive` to `true`
4. Re-registration preserves existing active state
5. Re-registration of inactive device with valid token reactivates it
6. Re-registration with expired token keeps device inactive
7. Registration deactivates other devices with same fcmToken
