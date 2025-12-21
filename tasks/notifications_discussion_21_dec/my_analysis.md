Hi team,
This is about multiple/no notifications on swaps, which is also discussed here.

The issue spans both backend and mobile and it shows inconsistent swap notifications: duplicates in some cases, none in others.

Root causes (tech):

1. Device ID registration inconsistency:
   Some users have multiple active FCM tokens → duplicate notifications.  
   Others have zero tokens even after login → no notifications.  
   Likely due to missing or broken FCM registration flow in Rumble v2 (device ID not re‑posted after logout/login).

2. Backend filtering gap:
   The notification service sends to all tokens tied to a user without filtering for active or latest IDs.  
   No deduplication logic at dispatch level.

3. App version divergence:
   Rumble v1 triggers both local (`SWAP_STARTED`) and backend (`SWAP_COMPLETED`) notifications correctly.  
   Rumble v2 may have removed or altered the local trigger and device registration logic.

4. Production vs staging drift:
   Staging logs show correct `sendUserNotification` RPC calls.  
   Production logs missing `SWAP_COMPLETED` events, possibly due to expired tokens or outdated app builds.

Actions required:

Frontend (Mobile):
Verify FCM registration flow in v2 (ensure POST /device-id fires after login).  
Ensure each device maintains exactly one active token.  
Add retry logic if FCM token generation fails.

Backend (indexer + notification):
Add filtering to select only the latest active device ID per user.  
Log userId + deviceId on registration and notification dispatch for traceability.  
Implement deduplication and expiry cleanup for old tokens.

QA / Product:
Test on staging with v2 build (iOS, Android).  
Compare traceIds between successful and failed cases.  
Validate both SWAP_STARTED and SWAP_COMPLETED events end‑to‑end.

Goal: unify notification behavior across all app versions, ensure one‑to‑one mapping between device and FCM token, and confirm backend dispatch reliability before v2 launch.
