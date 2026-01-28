# Solution: Explicit Transaction Types for RANT/TIP

## Problem Summary

The current API uses a single `type: "TOKEN_TRANSFER"` for all transfers (RANT, TIP, regular). The backend infers the actual flow from optional fields:

- Has `payload` → RANT
- Has `dt` + `id` (no payload) → TIP
- Neither → regular transfer

This leads to silent failures when required fields are missing - no webhook is created, no live chat entry appears, and no error is returned to the client.

## Proposed Solution

Extend the `type` field to explicitly differentiate transaction types:

- `TOKEN_TRANSFER` - regular transfers (backward compatibility)
- `TOKEN_TRANSFER_RANT` - rant transactions (strict validation: requires `payload`, `dt`, `id`, `transactionHash`)
- `TOKEN_TRANSFER_TIP` - tip transactions (strict validation: requires `dt`, `id`, `transactionHash`)

---

## Phase 1: Introduce New Types (Non-Breaking)

### Backend Changes

**1. `rumble-ork-wrk` (app node level)**

Add new types to `workers/lib/constants.js`:
```javascript
const NOTIFICATION_TYPES = Object.freeze({
  TOKEN_TRANSFER: 'TOKEN_TRANSFER',
  TOKEN_TRANSFER_RANT: 'TOKEN_TRANSFER_RANT',  // new
  TOKEN_TRANSFER_TIP: 'TOKEN_TRANSFER_TIP',    // new
  // ... existing types
})
```

**2. Add strict validation in `api.ork.wrk.js`**

For `TOKEN_TRANSFER_RANT`:
- Require: `payload`, `dt`, `id`, `transactionHash`
- Return error if any field is missing

For `TOKEN_TRANSFER_TIP`:
- Require: `dt`, `id`, `transactionHash`
- Return error if any field is missing

For `TOKEN_TRANSFER` (legacy):
- Keep existing behavior (infer from fields, no strict validation)
- Add deprecation warning in logs

**3. `rumble-data-shard-wrk`**

Update `_processTxWebhooksJob` to handle new types explicitly if needed.

### Frontend Changes

Mobile teams update to use new types:
- When user sends a rant → `type: "TOKEN_TRANSFER_RANT"`
- When user sends a tip → `type: "TOKEN_TRANSFER_TIP"`
- Regular transfers → `type: "TOKEN_TRANSFER"` (unchanged)

### Communication

- Notify mobile teams of new types
- Provide updated API documentation
- Set timeline for Phase 2

---

## Phase 2: Deprecate Legacy Type

### Timeline

After mobile apps using new types are deployed and adoption is confirmed (e.g., 2-3 release cycles):

### Backend Changes

1. Add `/deprecated` marker or warning header for `TOKEN_TRANSFER` when used for rant/tip scenarios
2. Monitor usage of legacy type
3. Eventually remove inference logic and require explicit types

### Frontend Changes

- Remove any remaining `TOKEN_TRANSFER` usage for rant/tip flows
- Only use `TOKEN_TRANSFER` for actual regular transfers

---

## Validation Rules Summary

| Type | Required Fields | Error on Missing |
|------|-----------------|------------------|
| `TOKEN_TRANSFER_RANT` | `payload`, `dt`, `id`, `transactionHash` | Yes |
| `TOKEN_TRANSFER_TIP` | `dt`, `id`, `transactionHash` | Yes |
| `TOKEN_TRANSFER` (legacy) | None strictly required | No (silent skip) |

---

## Benefits

1. **Explicit contract** - Client specifies intent, no inference needed
2. **Early validation** - Errors returned at API level, not silent failures
3. **Backward compatible** - Existing apps continue to work
4. **Gradual migration** - Teams can update on their own schedule
5. **Better debugging** - Clear type in logs and traces
