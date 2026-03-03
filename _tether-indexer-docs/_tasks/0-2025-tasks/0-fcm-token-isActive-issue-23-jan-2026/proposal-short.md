# Proposal: Strict FCM Token Handling

Our API currently guesses when clients send FCM tokens in the wrong field (`deviceId` instead of `fcmToken`). This was added for legacy support but makes notification bugs hard to debug because the system silently corrects bad input.

**Suggestion:** Remove this guessing logic. Require clients to send FCM tokens in the `fcmToken` field only. If they don't, no push notifications — simple and predictable.

**Affected Endpoint:** `POST /api/v1/device-ids`
- `deviceId` — unique device identifier only (e.g., UUID)
- `fcmToken` — Firebase Cloud Messaging token (required for push notifications)

**Warning:** This is a breaking change. All clients sending tokens incorrectly will need to update before we roll this out.
