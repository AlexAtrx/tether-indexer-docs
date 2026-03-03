# `/logs` Endpoint - Design Document (Revision 2)

**Date**: 15 January 2026
**Status**: Design Draft (Repo-aligned)

---

## 1. Goals and Constraints

### Goals
- Accept client-side logs from the Rumble mobile app.
- Support both authenticated and unauthenticated sessions (pre-login flows).
- Protect the API with rate limiting and payload validation.
- Reuse existing runtime primitives in this repo (Fastify, Pino, Redis, SSO auth).

### Non-goals (for v1)
- No new ingestion infrastructure (no Loki/Redis Streams workers).
- No per-log counter in Redis (per-request limit only).
- App integrity checks are optional and gated until mobile attestation is ready.

---

## 2. Architecture (Current Repo Fit)

```
Mobile App
  -> rumble-app-node (HTTP)  [this endpoint]
    -> Pino logger (svc-facs-logging)
      -> existing log aggregation (stdout transport)
```

No new workers or external services are required for v1.

---

## 3. Endpoint Specification

### Route
```
POST /api/v1/logs
```

*Rationale: aligns with existing `/api/v1/*` conventions in `rumble-app-node/workers/lib/server.js`.*

### Request Headers
| Header | Required | Description |
|--------|----------|-------------|
| `Authorization` | Conditional | `Bearer <jwt>` for authenticated users |
| `X-Device-Id` | Conditional | UUID v4, required if no auth token |
| `X-Trace-Id` | Optional | Client trace ID; server generates if absent |

*Exactly one of `Authorization` or `X-Device-Id` must be present.*

### Request Body
```json
{
  "logs": [
    {
      "level": "error",
      "message": "Transaction failed",
      "timestamp": 1736956780000,
      "traceId": "tx_7f3a9b2c",
      "context": {
        "screen": "SendScreen",
        "action": "submitTransaction"
      }
    }
  ],
  "device": {
    "platform": "ios",
    "osVersion": "17.2",
    "appVersion": "2.5.0"
  },
  "sessionId": "sess_xyz789"
}
```

### Response
**Success (200 OK)**
```json
{
  "accepted": true,
  "count": 1
}
```

---

## 3.1 Request/Response Schema Example (Annotated)

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

## 4. Validation Schema (Fastify)

Schema mirrors the strict style used elsewhere in the repo (`additionalProperties: false`).

```javascript
const maxBatch = ctx.conf.logs?.validation?.maxBatch || 100
const maxMessageLength = ctx.conf.logs?.validation?.maxMessageLength || 2000
const maxStackLength = ctx.conf.logs?.validation?.maxStackLength || 5000
const maxBodyBytes = ctx.conf.logs?.validation?.maxBodyBytes || 256 * 1024

schema: {
  body: {
    type: 'object',
    additionalProperties: false,
    properties: {
      logs: {
        type: 'array',
        minItems: 1,
        maxItems: maxBatch,
        items: {
          type: 'object',
          additionalProperties: false,
          properties: {
            traceId: { type: 'string' },
            level: { type: 'string', enum: ['debug', 'info', 'warn', 'error', 'fatal'] },
            message: {
              type: 'string',
              minLength: 1,
              maxLength: maxMessageLength
            },
            timestamp: { type: 'integer' },
            context: {
              type: 'object',
              additionalProperties: false,
              properties: {
                screen: { type: 'string' },
                action: { type: 'string' },
                error: {
                  type: 'object',
                  additionalProperties: false,
                  properties: {
                    code: { type: 'string' },
                    stack: {
                      type: 'string',
                      maxLength: maxStackLength
                    }
                  }
                },
                metadata: { type: 'object', additionalProperties: true }
              }
            }
          },
          required: ['level', 'message', 'timestamp']
        }
      },
      device: {
        type: 'object',
        additionalProperties: false,
        properties: {
          platform: { type: 'string', enum: ['ios', 'android'] },
          osVersion: { type: 'string' },
          model: { type: 'string' },
          appVersion: { type: 'string' }
        }
      },
      sessionId: { type: 'string', minLength: 1 }
    },
    required: ['logs']
  }
}
```

Set `bodyLimit` on the route to `maxBodyBytes` (default 256 KB) for a hard payload size cap; this can be overridden via config.

---

## 5. Authentication and Guard

### Guard Responsibilities
- Try JWT auth first (`Authorization: Bearer ...`).
- If JWT fails or is missing, require `X-Device-Id` (UUID v4).
- Populate `req._info` with `authMode`, `user`, and/or `deviceId`.

### Guard Implementation
File: `rumble-app-node/workers/lib/middlewares/logs.guard.js`

```javascript
'use strict'

const middleware = require('@tetherto/wdk-app-node/workers/lib/middlewares')

const logsGuard = async (ctx, req) => {
  req._info = req._info || {}

  const authHeader = req.headers.authorization
  if (authHeader && authHeader.startsWith('Bearer ')) {
    try {
      await middleware.auth.guard(ctx, req)
      req._info.authMode = 'authenticated'
      return
    } catch (err) {
      // fall through to device-based auth
    }
  }

  const deviceId = req.headers['x-device-id']
  if (!deviceId) {
    throw ctx.httpd_h0.server.httpErrors.unauthorized('Device ID required')
  }

  const uuidV4Regex = /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i
  if (!uuidV4Regex.test(deviceId)) {
    throw ctx.httpd_h0.server.httpErrors.badRequest('Invalid device ID format')
  }

  req._info.authMode = 'unauthenticated'
  req._info.deviceId = deviceId
}

module.exports = { logsGuard }
```

### App Integrity (Optional, Future)
If app attestation becomes available, enforce it only for unauthenticated traffic:

```javascript
if (req._info.authMode === 'unauthenticated' && ctx.conf.logs?.appIntegrity?.enabled) {
  await appIntegrity.validate(ctx, req)
}
```

This reuses the existing placeholder middleware in `rumble-app-node/workers/lib/middlewares/app.integrity.js`.

---

## 6. Rate Limiting Strategy

### Approach
Use the existing `@fastify/rate-limit` plugin already registered in `wdk-app-node/workers/base.http.server.wdk.js`. We configure the rate limit at the route level to avoid changing shared Lua scripts.

### Key Point: Hook Order
`@fastify/rate-limit` runs on `onRequest` by default, which is too early (before `logsGuard`). To use `req._info.user.id`, set the hook to `preHandler` so it runs after `logsGuard`.

### Route Config
```javascript
config: {
  rateLimit: {
    max: ctx.conf.logs?.rateLimit?.maxRequestsPerMinute || 60,
    timeWindow: 60000,
    hook: 'preHandler',
    keyGenerator: (req) => {
      if (req._info?.user?.id) {
        return `logs:user:${req._info.user.id}`
      }
      return `logs:device:${req.headers['x-device-id'] || req.ip}`
    }
  }
}
```

### Per-request vs Per-log
The current plugin increments by **request**, not by **log entry**. If you want to cap logs per minute, tune the request limit relative to `maxBatch`.

Example:
- If `maxBatch = 100` and you want a max of ~3,000 logs/min, set `maxRequestsPerMinute = 30`.
- For strict per-log accounting, you would need a custom Redis counter or extend the shared Lua command (out of scope for v1).

---

## 7. Handler and Log Enrichment

Use the existing logger (`ctx.logger`) and trace utilities (`getTraceId`) from `wdk-app-node`.

```javascript
const { getTraceId } = require('@tetherto/wdk-app-node/workers/lib/utils/traceId')

handler: async (req, rep) => {
  const { logs, device, sessionId } = req.body
  const requestTraceId = getTraceId()
  const serverTimestamp = Date.now()

  for (const log of logs) {
    const enriched = {
      source: 'rumble-mobile',
      authMode: req._info.authMode,
      userId: req._info.user?.id || null,
      deviceId: req._info.deviceId || null,
      sessionId,
      traceId: log.traceId || requestTraceId,
      clientTimestamp: log.timestamp,
      serverTimestamp,
      context: log.context || {},
      device: device || {}
    }

    const logFn = ctx.logger[log.level] || ctx.logger.info
    logFn.call(ctx.logger, enriched, `[CLIENT] ${log.message}`)
  }

  return rep.status(200).send({
    accepted: true,
    count: logs.length
  })
}
```

This keeps ingestion simple and compatible with existing logging pipelines.

---

## 8. Route Registration (Repo Aligned)

File: `rumble-app-node/workers/lib/server.js`

```javascript
const { logsGuard } = require('./middlewares/logs.guard')
const { appIntegrity } = require('./middlewares')
const maxBodyBytes = ctx.conf.logs?.validation?.maxBodyBytes || 256 * 1024

{
  method: 'POST',
  url: '/api/v1/logs',
  bodyLimit: maxBodyBytes,
  schema: { /* see Section 4 */ },
  config: { /* see Section 6 */ },
  preHandler: async (req, rep) => {
    await logsGuard(ctx, req)

    if (req._info.authMode === 'unauthenticated' && ctx.conf.logs?.appIntegrity?.enabled) {
      await appIntegrity.validate(ctx, req)
    }
  },
  handler: async (req, rep) => {
    // see Section 7
  }
}
```

---

## 9. Configuration (New Block)

File: `rumble-app-node/config/common.json`

```json
{
  "logs": {
    "enabled": true,
    "rateLimit": {
      "maxRequestsPerMinute": 60
    },
    "validation": {
      "maxBatch": 100,
      "maxMessageLength": 2000,
      "maxStackLength": 5000,
      "maxBodyBytes": 262144
    },
    "appIntegrity": {
      "enabled": false
    }
  }
}
```

If `logs.enabled` is false, the route can return 404 or 503 (implementation choice).

---

## 10. Error Handling

Use existing `httpErrors.*` helpers. No new `errorsCodes.js` entries are required because Fastify already returns the correct status codes.

- Missing device ID: `401`
- Invalid device ID: `400`
- Schema validation: `422`
- Rate limit: `429`

---

## 11. Testing Plan (Brittle)

Add integration tests in `rumble-app-node/tests/http.node.wrk.intg.test.js` using the existing hook harness:

- Accepts authenticated request (with `Authorization`).
- Accepts unauthenticated request with `X-Device-Id`.
- Rejects request with neither auth nor device ID.
- Rejects invalid `X-Device-Id`.
- Enforces rate limit (adjust max to small value in test config).
- Validates schema (missing fields -> 422).

---

## 12. Files Summary

| File | Action |
|------|--------|
| `rumble-app-node/workers/lib/middlewares/logs.guard.js` | Create |
| `rumble-app-node/workers/lib/server.js` | Add route |
| `rumble-app-node/config/common.json` | Add `logs` config block |
| `rumble-app-node/tests/http.node.wrk.intg.test.js` | Add integration tests |

---

## 13. Open Questions

1. Should rate limiting be per-user, per-token, or per-device for authenticated sessions?
2. Do we want a hard request body limit (e.g., 512 KB) at the route level?
3. When will mobile attestation be ready to enable `logs.appIntegrity.enabled`?
