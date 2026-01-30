# Ticket: API v2 — Explicit Transaction Types for Tips & Rants

**Priority:** High
**Type:** Breaking Change / API v2
**Release:** v2.0.0

---

## Executive Summary

Replace the implicit field-based inference system for tips and rants with explicit transaction types. This is a **breaking change** that requires coordinated deployment of backend services and mobile apps as part of API v2.

---

## Background & Problem Statement

### Current Behavior (v1)

The notification API uses a single `type: "TOKEN_TRANSFER"` for all transfer operations. The backend infers the actual intent by examining optional fields:

**File:** `rumble-ork-wrk/workers/api.ork.wrk.js` (lines 250-272)

```javascript
if (payload.payload && payload.transactionHash) {
  // Treated as RANT
  type: WEBHOOK_TYPES.RANT;
} else if (payload.transactionHash && payload.dt && payload.id) {
  // Treated as TIP
  type: WEBHOOK_TYPES.TIP;
}
// Otherwise: silently ignored for webhook purposes
```

### Why This Is Problematic

1. **Silent Failures**: When a mobile client intends to send a TIP but omits `dt` or `id`, the backend silently skips webhook creation. No error is returned. The tip never appears in chat.

2. **No Validation**: The API accepts the request as successful even when critical fields are missing. The mobile team believes the request worked, but downstream effects never happen.

3. **Debugging Nightmare**: When tips don't appear in chat, there's no way to determine if the issue was:

   - Missing fields from the client
   - Backend processing failure
   - Webhook delivery failure
   - Rumble chat consumer issue

4. **Implicit Contract**: The relationship between fields and behavior is undocumented and enforced only through code inference.

### Root Cause Discovery (21-Jan-2026)

Investigation revealed the exact failure path:

| Step | What Happens                                                 |
| ---- | ------------------------------------------------------------ |
| 1    | Mobile sends `TOKEN_TRANSFER` missing `dt` or `id`           |
| 2    | `api.ork.wrk.js` condition fails silently (line 261)         |
| 3    | `_addTxWebhook()` is never called                            |
| 4    | No webhook stored in database                                |
| 5    | `_processTxWebhooksJob()` has nothing to process             |
| 6    | Rumble server never receives notification                    |
| 7    | Chat message never appears                                   |
| 8    | Mobile client shows success (transaction completed on-chain) |

---

## Solution: Explicit Transaction Types

### New API Contract

| Type                  | Purpose                            | Required Fields                                                                                     | Validation                          |
| --------------------- | ---------------------------------- | --------------------------------------------------------------------------------------------------- | ----------------------------------- |
| `TOKEN_TRANSFER`      | Regular wallet-to-wallet transfers | `blockchain`, `token`, `amount`, `from`, `to`/`toAddress`, `transactionHash`/`transactionReceiptId` | Existing                            |
| `TOKEN_TRANSFER_RANT` | Rant (tip with message) to channel | All TOKEN_TRANSFER fields + `payload`, `dt`, `id`                                                   | **Strict — returns 400 if missing** |
| `TOKEN_TRANSFER_TIP`  | Tip (no message) to channel        | All TOKEN_TRANSFER fields + `dt`, `id`                                                              | **Strict — returns 400 if missing** |

### Key Behavior Changes

1. **Explicit Declaration**: Client must declare intent via `type` field
2. **Strict Validation**: Missing required fields return HTTP 400 with descriptive error
3. **No Inference**: Backend does not guess intent from field combinations
4. **Clear Errors**: Client knows immediately when something is wrong

---

## Affected Services

### Service Dependency Graph

```
Mobile App
    ↓
rumble-app-node (HTTP API, schema validation)
    ↓
rumble-ork-wrk (business logic, webhook creation)
    ↓
rumble-data-shard-wrk (webhook storage & processing)
    ↓
Rumble Server (external, receives webhooks)
```

### Files Requiring Changes

| Service                   | File                                     | Change Type              |
| ------------------------- | ---------------------------------------- | ------------------------ |
| **rumble-app-node**       | `workers/lib/utils/constants.js`         | Add new types            |
| **rumble-app-node**       | `workers/lib/server.js`                  | Update schema validation |
| **rumble-ork-wrk**        | `workers/lib/constants.js`               | Add new types            |
| **rumble-ork-wrk**        | `workers/api.ork.wrk.js`                 | New validation logic     |
| **rumble-data-shard-wrk** | `workers/lib/utils/constants.js`         | Add new types            |
| **rumble-data-shard-wrk** | `workers/lib/utils/notification.util.js` | Add new types            |
| **rumble-data-shard-wrk** | `workers/proc.shard.data.wrk.js`         | Update processing logic  |

### Test Files Requiring Updates

| Service                   | File                                         |
| ------------------------- | -------------------------------------------- |
| **rumble-app-node**       | `tests/http.node.wrk.intg.test.js`           |
| **rumble-ork-wrk**        | `tests/unit/api.ork.wrk.unit.js`             |
| **rumble-data-shard-wrk** | `tests/proc.shard.data.wrk.unit.test.js`     |
| **rumble-data-shard-wrk** | `tests/lib/notification.util.unit.test.js`   |
| **rumble-data-shard-wrk** | `tests/lib/notification-dedupe.util.test.js` |

---

## Implementation Details

### 1. Constants Updates

#### rumble-app-node/workers/lib/utils/constants.js

```javascript
const NOTIFICATION_TYPES = Object.freeze({
  TOKEN_TRANSFER: "TOKEN_TRANSFER",
  TOKEN_TRANSFER_RANT: "TOKEN_TRANSFER_RANT", // NEW
  TOKEN_TRANSFER_TIP: "TOKEN_TRANSFER_TIP", // NEW
  TOKEN_TRANSFER_COMPLETED: "TOKEN_TRANSFER_COMPLETED",
  SWAP_STARTED: "SWAP_STARTED",
  TOPUP_STARTED: "TOPUP_STARTED",
  TOPUP_COMPLETED: "TOPUP_COMPLETED",
  CASHOUT_STARTED: "CASHOUT_STARTED",
  CASHOUT_COMPLETED: "CASHOUT_COMPLETED",
  LOGIN: "LOGIN",
});
```

#### rumble-ork-wrk/workers/lib/constants.js

Same additions to `NOTIFICATION_TYPES`. The `WEBHOOK_TYPES` (RANT/TIP) remain unchanged as they are internal identifiers for webhook processing.

#### rumble-data-shard-wrk/workers/lib/utils/constants.js

No changes needed — `WEBHOOK_TYPES` (RANT/TIP) remain as internal types.

#### rumble-data-shard-wrk/workers/lib/utils/notification.util.js

Add to `NOTIFICATION_TYPES`:

```javascript
TOKEN_TRANSFER_RANT: 'TOKEN_TRANSFER_RANT',
TOKEN_TRANSFER_TIP: 'TOKEN_TRANSFER_TIP',
```

---

### 2. API Schema Validation

#### rumble-app-node/workers/lib/server.js (lines 167-230)

Add new conditional validation blocks:

```javascript
allOf: [
  // Existing TOKEN_TRANSFER validation
  {
    if: {
      properties: {
        type: { const: constants.NOTIFICATION_TYPES.TOKEN_TRANSFER },
      },
    },
    then: {
      required: ["blockchain", "token", "amount", "from"],
      allOf: [
        { anyOf: [{ required: ["to"] }, { required: ["toAddress"] }] },
        {
          anyOf: [
            { required: ["transactionHash"] },
            { required: ["transactionReceiptId"] },
          ],
        },
      ],
    },
  },
  // NEW: TOKEN_TRANSFER_RANT validation
  {
    if: {
      properties: {
        type: { const: constants.NOTIFICATION_TYPES.TOKEN_TRANSFER_RANT },
      },
    },
    then: {
      required: [
        "blockchain",
        "token",
        "amount",
        "from",
        "payload",
        "dt",
        "id",
      ],
      allOf: [
        { anyOf: [{ required: ["to"] }, { required: ["toAddress"] }] },
        {
          anyOf: [
            { required: ["transactionHash"] },
            { required: ["transactionReceiptId"] },
          ],
        },
      ],
    },
  },
  // NEW: TOKEN_TRANSFER_TIP validation
  {
    if: {
      properties: {
        type: { const: constants.NOTIFICATION_TYPES.TOKEN_TRANSFER_TIP },
      },
    },
    then: {
      required: ["blockchain", "token", "amount", "from", "dt", "id"],
      allOf: [
        { anyOf: [{ required: ["to"] }, { required: ["toAddress"] }] },
        {
          anyOf: [
            { required: ["transactionHash"] },
            { required: ["transactionReceiptId"] },
          ],
        },
      ],
    },
  },
  // ... existing validations for other types
];
```

**Key Point**: Fastify schema validation will automatically return HTTP 400 with a descriptive error if required fields are missing.

---

### 3. Business Logic Updates

#### rumble-ork-wrk/workers/api.ork.wrk.js

Replace inference logic (lines 201-272) with explicit type handling:

```javascript
async sendNotification (req) {
  const { type, idempotencyKey, ...payload } = req

  this.logger.info(`Notification payload info: type - ${type}`)
  if (!NOTIFICATION_TYPES[type]) {
    throw new Error('ERR_NOTIFICATION_TYPE_INVALID')
  }

  let toUserId = payload.userId

  // Handle all transfer types
  if (type === NOTIFICATION_TYPES.TOKEN_TRANSFER ||
      type === NOTIFICATION_TYPES.TOKEN_TRANSFER_RANT ||
      type === NOTIFICATION_TYPES.TOKEN_TRANSFER_TIP) {

    // ... existing wallet lookup and balance check logic (lines 202-246) ...

    // Explicit type handling — no inference
    if (type === NOTIFICATION_TYPES.TOKEN_TRANSFER_RANT) {
      // RANT: payload is guaranteed by schema validation
      const { userId: fromUserId, ...notificationPayload } = { type, ...payload }
      this._addTxWebhook({
        toUserId,
        toAddress,
        fromUserId,
        fromAddress,
        isTransactionReceipt,
        ...notificationPayload,
        type: WEBHOOK_TYPES.RANT
      })
    } else if (type === NOTIFICATION_TYPES.TOKEN_TRANSFER_TIP) {
      // TIP: dt and id are guaranteed by schema validation
      const { userId: fromUserId, ...tipPayload } = { type, ...payload }
      this._addTxWebhook({
        toUserId,
        toAddress,
        fromUserId,
        fromAddress,
        isTransactionReceipt,
        ...tipPayload,
        type: WEBHOOK_TYPES.TIP
      })
    }
    // TOKEN_TRANSFER (regular): no webhook created — just a transfer notification
  }

  // ... rest of existing logic ...
}
```

**Key Changes:**

- Remove field-based inference (`if (payload.payload && payload.transactionHash)`)
- Use explicit type checks
- Schema validation guarantees required fields are present
- `TOKEN_TRANSFER` no longer creates rant/tip webhooks

---

### 4. Webhook Processing Updates

#### rumble-data-shard-wrk/workers/proc.shard.data.wrk.js

The `_processTxWebhooksJob()` (lines 287-329) and `storeTxWebhook()` (lines 384-408) functions already use `WEBHOOK_TYPES.RANT` and `WEBHOOK_TYPES.TIP` internally. These do not need changes because:

1. The internal `WEBHOOK_TYPES` enum remains the same
2. The `api.ork.wrk.js` maps external types to internal types before calling `_addTxWebhook()`
3. The processing logic checks `txHook.type` which is the internal type

**However**, consider adding logging to track the original notification type for debugging:

```javascript
// In storeTxWebhook, optionally store originalType for debugging
this.logger.info(
  `Store webhook: type=${type}, originalNotificationType=${req.originalNotificationType}`,
);
```

---

### 5. Error Messages

Define clear error messages for validation failures:

| Scenario                   | HTTP Status | Error Message                                          |
| -------------------------- | ----------- | ------------------------------------------------------ |
| Missing `payload` for RANT | 400         | `body must have required property 'payload'`           |
| Missing `dt` for RANT/TIP  | 400         | `body must have required property 'dt'`                |
| Missing `id` for RANT/TIP  | 400         | `body must have required property 'id'`                |
| Invalid `type`             | 400         | `body/type must be equal to one of the allowed values` |

Fastify's schema validation provides these automatically.

---

## Database Considerations

### Existing Schema

The `TxWebhookEntity` schema (in `rumble-data-shard-wrk/workers/lib/db/base/repositories/txwebhook.js`) already supports all required fields:

```javascript
/**
 * @typedef TxWebhookEntity
 * @property {string} transactionHash
 * @property {string} type - Internal webhook type (rant/tip)
 * @property {string} [dt]
 * @property {string} [id]
 * @property {string} [payload]
 * // ... other fields
 */
```

**No schema changes required** — the internal `type` field stores `WEBHOOK_TYPES.RANT` or `WEBHOOK_TYPES.TIP`, not the notification type.

### Data Migration

None required. Existing webhooks in the database will continue to process correctly since the internal `WEBHOOK_TYPES` are unchanged.

---

## Testing Requirements

### Unit Tests

#### rumble-ork-wrk/tests/unit/api.ork.wrk.unit.js

Add test cases:

- `TOKEN_TRANSFER_RANT` with all fields → webhook created with type RANT
- `TOKEN_TRANSFER_TIP` with all fields → webhook created with type TIP
- `TOKEN_TRANSFER` (regular) → no webhook created
- Verify `_addTxWebhook` called with correct internal type

#### rumble-data-shard-wrk/tests/proc.shard.data.wrk.unit.test.js

Existing tests should pass since internal webhook processing is unchanged.

### Integration Tests

#### rumble-app-node/tests/http.node.wrk.intg.test.js

Add test cases:

- `TOKEN_TRANSFER_RANT` with all required fields → 200 OK
- `TOKEN_TRANSFER_RANT` missing `payload` → 400 Bad Request
- `TOKEN_TRANSFER_RANT` missing `dt` → 400 Bad Request
- `TOKEN_TRANSFER_RANT` missing `id` → 400 Bad Request
- `TOKEN_TRANSFER_TIP` with all required fields → 200 OK
- `TOKEN_TRANSFER_TIP` missing `dt` → 400 Bad Request
- `TOKEN_TRANSFER_TIP` missing `id` → 400 Bad Request
- `TOKEN_TRANSFER` (regular) → 200 OK (no rant/tip fields required)

### End-to-End Tests

- Send `TOKEN_TRANSFER_RANT` → verify Rumble receives `rantTransactionInit` and `rantTransactionConfirm`
- Send `TOKEN_TRANSFER_TIP` → verify Rumble receives `rantTransactionConfirm`
- Verify chat message appears in Rumble live stream

---

## Deployment Plan

### Prerequisites

1. All affected services must be updated simultaneously
2. Mobile apps must be updated to use new types
3. Coordinate release as v2.0.0

### Deployment Order

Since this is a breaking change deployed together:

1. **Deploy backend services** (all at once):

   - rumble-app-node
   - rumble-ork-wrk
   - rumble-data-shard-wrk

2. **Deploy mobile apps** (coordinated release):
   - Update to use `TOKEN_TRANSFER_RANT` for rants
   - Update to use `TOKEN_TRANSFER_TIP` for tips
   - Keep `TOKEN_TRANSFER` for regular transfers

### Rollback Plan

If issues arise:

1. Rollback all backend services to v1
2. Mobile apps fall back to previous version
3. Investigate and fix before re-attempting

---

## Acceptance Criteria

- [ ] `TOKEN_TRANSFER_RANT` accepted with all required fields
- [ ] `TOKEN_TRANSFER_RANT` returns 400 when `payload`, `dt`, or `id` missing
- [ ] `TOKEN_TRANSFER_TIP` accepted with all required fields
- [ ] `TOKEN_TRANSFER_TIP` returns 400 when `dt` or `id` missing
- [ ] `TOKEN_TRANSFER` works for regular transfers (no rant/tip fields required)
- [ ] `TOKEN_TRANSFER` does NOT create rant/tip webhooks (breaking change)
- [ ] Rant webhooks correctly sent to Rumble server
- [ ] Tip webhooks correctly sent to Rumble server
- [ ] Chat messages appear in Rumble live streams
- [ ] All unit tests pass
- [ ] All integration tests pass
- [ ] Error messages are descriptive and actionable

---

## API Documentation Updates

Update API documentation to reflect:

### POST /api/v1/notifications

#### TOKEN_TRANSFER_RANT

Send a rant (tip with message) to a Rumble channel.

**Required fields:**

- `type`: `"TOKEN_TRANSFER_RANT"`
- `blockchain`: Chain identifier (e.g., `"ethereum"`)
- `token`: Token identifier (e.g., `"USDT"`)
- `amount`: Transfer amount (number)
- `from`: Sender wallet ID
- `to` or `toAddress`: Recipient wallet ID or address
- `transactionHash` or `transactionReceiptId`: Transaction identifier
- `payload`: Rant message content (string)
- `dt`: Destination type (`"u"` for user, `"c"` for channel)
- `id`: Destination identifier

#### TOKEN_TRANSFER_TIP

Send a tip (no message) to a Rumble channel.

**Required fields:**

- `type`: `"TOKEN_TRANSFER_TIP"`
- `blockchain`: Chain identifier
- `token`: Token identifier
- `amount`: Transfer amount (number)
- `from`: Sender wallet ID
- `to` or `toAddress`: Recipient wallet ID or address
- `transactionHash` or `transactionReceiptId`: Transaction identifier
- `dt`: Destination type (`"u"` for user, `"c"` for channel)
- `id`: Destination identifier

#### TOKEN_TRANSFER

Send a regular wallet-to-wallet transfer (no Rumble chat integration).

**Required fields:**

- `type`: `"TOKEN_TRANSFER"`
- `blockchain`: Chain identifier
- `token`: Token identifier
- `amount`: Transfer amount (number)
- `from`: Sender wallet ID
- `to` or `toAddress`: Recipient wallet ID or address
- `transactionHash` or `transactionReceiptId`: Transaction identifier

---

## Summary of Breaking Changes

| Change                            | v1 Behavior                                   | v2 Behavior                          |
| --------------------------------- | --------------------------------------------- | ------------------------------------ |
| RANT detection                    | Inferred from `payload` + `transactionHash`   | Requires `type: TOKEN_TRANSFER_RANT` |
| TIP detection                     | Inferred from `dt` + `id` + `transactionHash` | Requires `type: TOKEN_TRANSFER_TIP`  |
| Missing fields                    | Silent skip, request succeeds                 | HTTP 400 error returned              |
| `TOKEN_TRANSFER` with rant fields | Creates RANT webhook                          | Does NOT create webhook              |
| `TOKEN_TRANSFER` with tip fields  | Creates TIP webhook                           | Does NOT create webhook              |

---

## Related Documentation

- Problem investigation: `_docs/_tasks/_rumble-tip-test-21-jan-2026/`
- Solution proposal: `_docs/_tasks/_rumble-tip-test-21-jan-2026/solution-suggestion.md`
- Backend findings: `_docs/_tasks/_rumble-tip-test-21-jan-2026/backend-findings.md`

## Imortant

Since as you know the API has versions, e.g. /api/v1/connect, etc, I want the changes you have introduced in this ticket to be on V2 on all the APIs. Because we want to give the front end an opportunity and a time to shift to V2 whenever they want in order to avoid backwater breaking changes. Review everything you have done and make sure that the changes you made are on the v2 version and v1 version is intact and still functioning the old way.
