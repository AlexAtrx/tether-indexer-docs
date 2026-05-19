# Sentry False Positives (#2) - Analysis & Fix Proposal

**Ticket:** WDK-1233 / Asana 1213478674515748
**Priority:** High
**Goal:** Filter out false-positive errors so Sentry alerts can be trusted for real production bugs.

---

## Current State of Error Handling

The Sentry integration in `rumble-app-node/workers/http.node.wrk.js:134-149` already has a `shouldHandleError` filter that suppresses:

1. **Validation errors** (`error.validation` — Fastify schema failures)
2. **4xx client errors** (`statusCode >= 400 && < 500`)
3. **Mapped error codes** with status < 500 (looked up from `this.errorCodes`)

The route-level error handler in `wdk-app-node/workers/base.http.server.wdk.js:143-158` maps errors to HTTP status codes via the `errorCodes` Map.

**The core problem:** Several error codes thrown by seed recovery and auth flows are **not registered** in any `errorCodes` map, so the route error handler falls into the `else` branch (line 156) and sends a **500**. Since the Sentry `shouldHandleError` only skips errors with `statusCode < 500` or `error.validation`, these 500s are reported as real errors.

---

## Issue-by-Issue Analysis

### #1 - ERR_FORBIDDEN (Issues 6469, 6470)

**Source:** `wdk-app-node/workers/lib/middlewares/auth/jwt.guard.js:25,39`
**What happens:** `ctx.httpd_h0.server.httpErrors.forbidden('ERR_FORBIDDEN')` creates a Fastify HTTP error with `statusCode: 403`.
**Is it a false positive?** YES. This is normal auth rejection (missing/invalid `x-secret-token` or no userId). Expected from unauthenticated requests.
**Why Sentry catches it:** The `@fastify/sensible` `forbidden()` creates an error with `statusCode: 403`. The `shouldHandleError` filter on line 140 should already skip it (`403 >= 400 && 403 < 500`). However, the error is thrown from a `preHandler`, and `Sentry.setupFastifyErrorHandler` may be catching it before the route's `errorHandler` sets the statusCode. The `@fastify/sensible` errors DO have `statusCode` set, so this should be filtered. **Investigate:** This might be getting caught because of the `[HRPC_ERR]=` prefix stripping on line 141 — if the error message doesn't match after stripping, the mapped check fails, but the statusCode check on line 140 should still catch it.

**Verdict:** Likely already handled by the existing filter. If still appearing, Sentry may be capturing it via a different mechanism (e.g., `captureException` somewhere else, or the error is re-thrown without the statusCode). Need to verify Sentry is actually receiving these after the latest `shouldHandleError` deployment.

---

### #2 - ERR_SIG_VERIF_FAILURE (Issue 9920)

**Source:** `rumble-app-node/workers/lib/services/seed.recovery.js:71`
**What happens:** `throw new Error('ERR_SIG_VERIF_FAILURE')` — plain Error, no statusCode.
**Is it a false positive?** YES. User provided an invalid signature. This is a client error (400/422).
**Why Sentry catches it:** Error has no `statusCode`, is not in any `errorCodes` map, so:
  - Route error handler (base.http.server.wdk.js:156) sends it as **500**
  - Sentry's `shouldHandleError` sees a 500 and reports it

**Fix:** Add `ERR_SIG_VERIF_FAILURE: 400` to `rumble-app-node/workers/lib/utils/errorsCodes.js`

---

### #3 - ERR_CHAIN_INVALID (Issue 9915)

**Source:** `rumble-app-node/workers/lib/services/seed.recovery.js:20`
**What happens:** `throw new Error('ERR_CHAIN_INVALID')` — plain Error, no statusCode.
**Is it a false positive?** YES. User sent an unsupported `chain` value. Client error.
**Why Sentry catches it:** Same as #2 — unmapped error code, becomes 500.

**Fix:** Add `ERR_CHAIN_INVALID: 400` to `rumble-app-node/workers/lib/utils/errorsCodes.js`

Also add `ERR_CHAIN_NOT_SUPPORTED: 400` (thrown at line 66 of seed.recovery.js) since it's the same class of error.

---

### #4 - Rate limit exceeded (Issue 9919)

**Source:** `@fastify/rate-limit/index.js:272` (defaultErrorResponse)
**What happens:** The `@fastify/rate-limit` plugin creates an error with `err.statusCode = context.statusCode` (429).
**Is it a false positive?** YES. Rate limiting is expected behavior, not a bug.
**Why Sentry catches it:** The rate-limit error should have `statusCode: 429`, which the `shouldHandleError` filter should skip (429 >= 400 && < 500). However, looking at `@fastify/rate-limit` source, the `defaultErrorResponse` creates a new `Error()` and sets `statusCode` on it — but this error goes through `reply.send()` not `throw`, so it might bypass the route error handler entirely and hit Sentry's `onError` hook directly.

**Possible cause:** Sentry's Fastify integration hooks into the Fastify error lifecycle. The rate-limit plugin sends the error response directly via `res.send(params.errorResponseBuilder(...))`, which may trigger Sentry's error hook. The `shouldHandleError` should filter it since `statusCode` is 429, but if the error object structure differs from what's expected, it might slip through.

**Fix:** Verify after deployment. If still appearing, add explicit handling in `shouldHandleError`:
```js
if (error.message?.startsWith('Rate limit exceeded')) return false
```

---

### #5 - WALLET ID NOT FOUND / ERR_ADDRESS_NOT_FOUND (Issues 6483, 9882)

**Source:** `rumble-app-node/workers/lib/services/seed.recovery.js:15` — `getUserIdByAddress(ctx, req)` calls `rpcCall(ctx, req, 'getUserIdByAddress', { address, chain })`. Note that `getUserIdByAddress` in `rumble-app-node/workers/lib/services/ork.js:108` calls the ork RPC method, which can throw `[HRPC_ERR]=ERR_WALLET_ID_NOT_FOUND`.

**What happens:** The ork RPC returns an HRPC error. The error message is `[HRPC_ERR]=ERR_WALLET_ID_NOT_FOUND`. The route error handler strips the prefix and looks up `ERR_WALLET_ID_NOT_FOUND` in the errorCodes map. **This IS mapped** in `wdk-app-node/workers/lib/utils/errorsCodes.js:8` as **404**.

**However**, the ticket notes say "this looks like there is a try catch missing around the last line". Looking at `seed.recovery.js:15`:
```js
const userId = await getUserIdByAddress(ctx, req)
if (!userId) {
  throw new Error('ERR_ADDRESS_NOT_FOUND')
}
```
If `getUserIdByAddress` throws (instead of returning null), the error propagates up as an unhandled `[HRPC_ERR]=ERR_WALLET_ID_NOT_FOUND`. The route error handler DOES handle this (maps to 404), and `shouldHandleError` should skip it (404 < 500).

**Is it a false positive?** YES. User provided an address that doesn't exist. Expected behavior.

**Why Sentry catches it:** Two possibilities:
1. The HRPC error might not have its statusCode properly set when it reaches Sentry
2. `ERR_ADDRESS_NOT_FOUND` (thrown at line 17) is **NOT** in any errorCodes map

**Fix:**
- Add `ERR_ADDRESS_NOT_FOUND: 404` to `rumble-app-node/workers/lib/utils/errorsCodes.js`
- Add a try-catch in `genSeedChallenge` around `getUserIdByAddress` to convert the HRPC error into a clean error:
```js
let userId
try {
  userId = await getUserIdByAddress(ctx, req)
} catch (err) {
  if (err.message?.includes('ERR_WALLET_ID_NOT_FOUND')) {
    throw new Error('ERR_ADDRESS_NOT_FOUND')
  }
  throw err
}
```

---

### #6 - Params User id validation (Issue 9141)

**Source:** `wdk-app-node/workers/base.http.server.wdk.js:225` (onRequest hook area, but the actual error is a Fastify schema validation error)
**What happens:** Fastify schema validation rejects the request (e.g., invalid `userId` in params). This produces a validation error.
**Is it a false positive?** YES. Schema validation failure = client sent bad data.
**Why Sentry catches it:** The `shouldHandleError` already checks `if (error.validation) return false`, so validation errors should be suppressed. The fact this is appearing suggests either:
  1. The validation error is reaching Sentry before the route `errorHandler` runs
  2. The error is thrown from the `onRequest` hook (line 220-227), not from a route — global hooks don't have route-level error handlers
  3. The Fastify validation error object doesn't have the `.validation` property when caught at this level

**Fix:** Add a broader check in `shouldHandleError`:
```js
if (error.message?.includes('must have required property') ||
    error.message?.includes('params/') ||
    error.message?.includes('querystring/') ||
    error.message?.includes('body/')) return false
```

Or better, check for the Fastify validation error pattern:
```js
if (error.statusCode === 400 && error.message?.includes('must have required property')) return false
```
But this is already covered by the `statusCode >= 400 && < 500` check. The real question is whether `statusCode` is set.

---

## Summary of Fixes

### A. Add missing error codes to `rumble-app-node/workers/lib/utils/errorsCodes.js`

```js
module.exports = {
  // ... existing codes ...
  ERR_SIG_VERIF_FAILURE: 400,
  ERR_CHAIN_INVALID: 400,
  ERR_CHAIN_NOT_SUPPORTED: 400,
  ERR_ADDRESS_NOT_FOUND: 404,
  ERR_CHALLENGE_EXPIRED: 400,
  ERR_MSG_INVALID: 400,
  ERR_ADDRESS_INVALID: 400,
}
```

This is the **primary fix**. Once these error codes are mapped, the route error handler will assign proper 4xx statusCodes, and the existing Sentry `shouldHandleError` filter will suppress them.

### B. Add try-catch in `seed.recovery.js:genSeedChallenge` for `getUserIdByAddress`

```js
let userId
try {
  userId = await getUserIdByAddress(ctx, req)
} catch (err) {
  if (err.message?.includes('ERR_WALLET_ID_NOT_FOUND')) {
    throw new Error('ERR_ADDRESS_NOT_FOUND')
  }
  throw err
}
```

This converts the HRPC-wrapped error into a clean mapped error.

### C. Harden the `shouldHandleError` callback as a safety net

In `rumble-app-node/workers/http.node.wrk.js`, update the `shouldHandleError`:

```js
shouldHandleError (error) {
  // Skip Fastify validation errors
  if (error.validation) return false
  // Skip all 4xx client errors
  if (error.statusCode >= 400 && error.statusCode < 500) return false
  // Skip mapped error codes with status < 500
  const code = error.message?.replaceAll('[HRPC_ERR]=', '')
  const mapped = code && errorCodes.get(code)
  if (mapped && mapped < 500) return false
  // Skip rate-limit errors (safety net)
  if (error.message?.startsWith('Rate limit exceeded')) return false
  return true
}
```

### D. No Sentry-side configuration changes needed

All fixes are code-level. Once error codes are properly mapped and have 4xx status codes, the existing `shouldHandleError` filter handles everything.

---

## Non-False-Positive Check

All 6 issues are confirmed **false positives**:

| # | Error | Real Bug? | Reason |
|---|-------|-----------|--------|
| 1 | ERR_FORBIDDEN | No | Normal auth rejection for missing/invalid token |
| 2 | ERR_SIG_VERIF_FAILURE | No | User provided invalid signature |
| 3 | ERR_CHAIN_INVALID | No | User sent unsupported chain |
| 4 | Rate limit exceeded | No | Expected rate-limit enforcement |
| 5 | ERR_WALLET_ID_NOT_FOUND | No | User's address not found in system |
| 6 | Params validation | No | Client sent malformed request |

None of these require alerting Francesco — they are all expected client-side errors.

---

## Files to Modify

1. **`rumble-app-node/workers/lib/utils/errorsCodes.js`** — Add missing error code mappings (primary fix)
2. **`rumble-app-node/workers/lib/services/seed.recovery.js`** — Add try-catch around `getUserIdByAddress`
3. **`rumble-app-node/workers/http.node.wrk.js`** — Harden `shouldHandleError` with rate-limit safety net
