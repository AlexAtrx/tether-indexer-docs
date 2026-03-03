# /logs Endpoint - Shareable Summary

## What it is
A new API endpoint for the Rumble mobile app to send client-side logs to our backend so we can observe crashes, errors, and user flows.

## Who can use it
- Authenticated users: send logs with their normal `Authorization` token.
- Unauthenticated users: send logs with a `X-Device-Id` (UUID). This covers pre-login flows.

## What it does
- Accepts a batch of logs (up to 100 per request by default).
- Validates the payload and size (default max body size 256 KB).
- Writes logs to the existing server logger (Pino), which already feeds our log aggregation.
- Returns `200 OK` with the count of logs accepted.

## Safety and abuse protection
- Rate limiting per user or per device (default 60 requests/minute, configurable).
- Schema validation blocks malformed payloads.
- Optional app integrity checks can be added later when mobile attestation is ready.

## What it does NOT do (v1)
- No new infrastructure (no Loki/Redis Streams workers).
- No per-log counter; rate limiting is per request.

## Configuration (defaults)
- Max logs per request: 100
- Max body size: 256 KB
- Max requests per minute: 60 (configurable)
- App integrity: disabled by default

## Repos that will change
- `rumble-app-node` only:
  - Add a new route: `POST /api/v1/logs`
  - Add a new guard middleware for auth/device handling
  - Add config entries for limits and validation
  - Add integration tests

No changes are required in `wdk-app-node` or other repos; this design reuses existing libraries and logging.

## Schema Example (Annotated)

Request headers:
```json
{
  "Authorization": "Bearer <jwt>", // optional; required if no X-Device-Id
  "X-Device-Id": "550e8400-e29b-41d4-a716-446655440000", // optional; required if no Authorization
  "X-Trace-Id": "app-7f3a9b2c-acde-4c1a-9b2c-acde7f3a9b2c", // optional; client trace id
  "Content-Type": "application/json" // required
}
```

Request body:
```json
{
  "logs": [
    {
      "level": "error", // required; debug|info|warn|error|fatal
      "message": "Transaction failed", // required; human-readable message
      "timestamp": 1736956780000, // required; client time in ms
      "traceId": "tx_7f3a9b2c", // optional; client trace id per log
      "context": {
        "screen": "SendScreen", // optional; UI screen name
        "action": "submitTransaction", // optional; user action
        "error": {
          "code": "INSUFFICIENT_BALANCE", // optional; error code
          "stack": "Error: ...stack trace..." // optional; stack trace
        },
        "metadata": { "key": "value" } // optional; free-form extra data
      }
    }
  ],
  "device": {
    "platform": "ios", // optional; ios|android
    "osVersion": "17.2", // optional; OS version
    "model": "iPhone 15 Pro", // optional; device model
    "appVersion": "2.5.0" // optional; app version
  },
  "sessionId": "sess_xyz789" // optional; client session id
}
```

Success response:
```json
{
  "accepted": true, // server accepted the batch
  "count": 1 // number of log entries accepted
}
```
