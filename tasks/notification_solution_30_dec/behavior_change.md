## Behavior Change: Device Registration + Notification Status

### What changed
- `POST /api/v1/device-ids` now returns **200** with a JSON status instead of 201.
- `DELETE /api/v1/device-ids` and `DELETE /api/v1/device-ids/remove` now return **200** with a JSON status instead of 204.
- `POST /api/v1/notifications` now returns **200** with a JSON status instead of 204.

### Status values
- `ok`: registration/send succeeded.
- `missing`: no usable token found for delivery (or no devices exist for delete/purge).
- `expired`: token was rejected by FCM (invalid/not-registered).
- `deleted`: device(s) removed.

### Device registration semantics
- `deviceId` should be **deterministic** (hashed device info). It is the primary key used to upsert devices.
- `fcmToken` should be sent when available; it is treated as the effective delivery token.
- Existing device records are updated rather than duplicated. If a duplicate `fcmToken` is registered for the same user, the older entry is marked inactive to avoid duplicates.
- Stored device fields now include:
  - `deviceId`, `fcmToken`, `registeredAt`, `lastNotifiedAt`, `isActive`

### Notification send behavior
- Tokens are grouped by `deviceId`, and the most recent **active** token per device is chosen.
- `lastNotifiedAt` is updated on successful send.
- FCM errors like **invalid/expired tokens** mark the device inactive and return `expired` status.

### Client expectations
- Always send `deviceId` + `fcmToken` at login and on token refresh.
- If response status is `missing` or `expired`, refresh the FCM token and re-register.
