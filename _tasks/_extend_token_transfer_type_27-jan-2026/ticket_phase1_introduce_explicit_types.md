# Ticket: Introduce Explicit Transaction Types for RANT/TIP

**Priority:** High
**Type:** Feature / Backend Enhancement
**Affected Repos:** `rumble-ork-wrk`, `rumble-data-shard-wrk`

---

## Background & Problem Statement

### Current Behavior

The Rumble wallet API currently uses a single `type: "TOKEN_TRANSFER"` for all transfer operations (regular transfers, RANTs, and TIPs). The backend infers the actual transaction intent by examining optional fields:

| Scenario | Detection Logic |
|----------|-----------------|
| RANT | Has `payload` + `dt` + `id` + `transactionHash` |
| TIP | Has `dt` + `id` + `transactionHash` (no payload) |
| Regular Transfer | Neither of the above |

### Why This Is Problematic

1. **Silent Failures**: When a mobile client intends to send a TIP or RANT but omits a required field (e.g., `dt` or `id`), the backend silently skips webhook creation. No error is returned to the client, and the tip/rant never appears in the live chat.

2. **No Feedback Loop**: The mobile team believes they always send the required fields, but the backend has no way to tell them when something is missing. The request appears successful, but the downstream effect (chat message, notification) never happens.

3. **Debugging Difficulty**: When tips don't appear in chat, it's extremely difficult to diagnose whether the issue is:
   - Missing fields from the client
   - Backend processing bug
   - Webhook delivery failure
   - Rumble chat consumer issue

4. **Implicit Contract**: The API contract is implicit and undocumented—neither the client nor the backend can validate correctness at the boundary.

### Root Cause Investigation (21-Jan-2026)

An investigation into missing chat messages revealed:
- `api.ork.wrk.js` only calls `_addTxWebhook` when all required fields are present
- If `dt` or `id` is missing, the webhook is silently skipped
- `proc.shard.data.wrk.js` only sends the Rumble webhook for stored tx webhooks
- **Result**: Missing `dt` or `id` → no webhook stored → no Rumble notification → no chat entry

---

## Proposed Solution

Extend the `type` field to explicitly differentiate transaction types, enabling strict validation and clear error responses.

### New Types

| Type | Purpose | Required Fields |
|------|---------|-----------------|
| `TOKEN_TRANSFER` | Regular transfers (legacy, backward-compatible) | None strictly required |
| `TOKEN_TRANSFER_RANT` | Rant transactions with message | `payload`, `dt`, `id`, `transactionHash` |
| `TOKEN_TRANSFER_TIP` | Tip transactions without message | `dt`, `id`, `transactionHash` |

---

## Implementation Tasks

### 1. Update Constants (`rumble-ork-wrk`)

**File:** `workers/lib/constants.js`

Add new types to `NOTIFICATION_TYPES`:
```javascript
const NOTIFICATION_TYPES = Object.freeze({
  TOKEN_TRANSFER: 'TOKEN_TRANSFER',
  TOKEN_TRANSFER_RANT: 'TOKEN_TRANSFER_RANT',  // NEW
  TOKEN_TRANSFER_TIP: 'TOKEN_TRANSFER_TIP',    // NEW
  // ... existing types
})
```

### 2. Add Strict Validation (`rumble-ork-wrk`)

**File:** `workers/api.ork.wrk.js`

Implement validation for new types in the notification handler:

**For `TOKEN_TRANSFER_RANT`:**
- Require: `payload`, `dt`, `id`, `transactionHash`
- Return HTTP 400 with descriptive error if any field is missing
- Example error: `{ error: "TOKEN_TRANSFER_RANT requires payload, dt, id, and transactionHash" }`

**For `TOKEN_TRANSFER_TIP`:**
- Require: `dt`, `id`, `transactionHash`
- Return HTTP 400 with descriptive error if any field is missing
- Example error: `{ error: "TOKEN_TRANSFER_TIP requires dt, id, and transactionHash" }`

**For `TOKEN_TRANSFER` (legacy):**
- Keep existing inference behavior for backward compatibility
- Add deprecation warning to logs when used with rant/tip-like payloads
- Example log: `[DEPRECATED] TOKEN_TRANSFER used with rant/tip payload. Use TOKEN_TRANSFER_RANT or TOKEN_TRANSFER_TIP instead.`

### 3. Update Webhook Processing (`rumble-data-shard-wrk`)

**File:** `workers/proc.shard.data.wrk.js`

Update `_processTxWebhooksJob` to handle new types:
- Treat `TOKEN_TRANSFER_RANT` same as current RANT logic
- Treat `TOKEN_TRANSFER_TIP` same as current TIP logic
- Ensure type is passed through to Rumble webhook payload

### 4. Add Logging

Add clear log lines when:
- New explicit types are received (for monitoring adoption)
- Validation fails (for debugging client issues)
- Legacy type is used with rant/tip fields (deprecation tracking)

### 5. Update Tests

Add test cases for:
- `TOKEN_TRANSFER_RANT` with all required fields → success
- `TOKEN_TRANSFER_RANT` missing `payload` → 400 error
- `TOKEN_TRANSFER_RANT` missing `dt` → 400 error
- `TOKEN_TRANSFER_TIP` with all required fields → success
- `TOKEN_TRANSFER_TIP` missing `id` → 400 error
- `TOKEN_TRANSFER` legacy behavior unchanged

---

## Acceptance Criteria

- [ ] `TOKEN_TRANSFER_RANT` and `TOKEN_TRANSFER_TIP` types are accepted by the API
- [ ] Missing required fields return HTTP 400 with descriptive error message
- [ ] Existing `TOKEN_TRANSFER` behavior is unchanged (backward compatible)
- [ ] Deprecation warnings are logged for legacy type usage with rant/tip fields
- [ ] Webhooks are correctly created and processed for new types
- [ ] Unit tests cover all validation scenarios

---

## Communication Plan

After deployment:
1. Notify mobile teams of new types and validation behavior
2. Provide updated API documentation with required fields
3. Share example requests for RANT and TIP flows
4. Coordinate timeline for mobile app updates
5. Set target date for Phase 2 (deprecation)

---

## Benefits

1. **Explicit Contract**: Client declares intent, no inference needed
2. **Early Validation**: Errors returned at API boundary, not silent failures
3. **Better Debugging**: Clear type in logs makes tracing straightforward
4. **Backward Compatible**: Existing apps continue to work during transition
5. **Gradual Migration**: Mobile teams can update on their own release schedule

---

## Related Documentation

- Original investigation: `_docs/_tasks/_rumble-tip-test-21-jan-2026/`
- Solution proposal: `_docs/_tasks/_rumble-tip-test-21-jan-2026/solution-suggestion.md`
- Backend findings: `_docs/_tasks/_rumble-tip-test-21-jan-2026/backend-findings.md`
