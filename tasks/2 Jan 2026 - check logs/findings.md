# Investigation Findings: Wallet Types and channelId Behavior

**Date**: 2 Jan 2026
**Investigator**: Alex Atrash

---

## Summary

The tester's question about `type: "unrelated"` with `channelId: null` is **expected behavior**. This is correct and working as designed.

---

## Wallet Types

The system defines three valid wallet types in `wdk-app-node/workers/lib/schemas/common.js:57`:

```javascript
const walletEnum = ['user', 'channel', 'unrelated']
```

| Type | Purpose | channelId | Duplicate Rules |
|------|---------|-----------|-----------------|
| `user` | Personal user wallet | Not allowed | Only ONE per user |
| `channel` | Channel-specific tip jar | Required | One per channelId |
| `unrelated` | External/imported wallet | Not allowed | Multiple allowed |

---

## channelId Validation Logic

From `wdk-app-node/workers/lib/server.js:306-321`:

```javascript
// channelId is conditionally required
if: { properties: { type: { const: 'channel' } } },
then: { required: ['type', 'addresses', 'channelId'] },
else: {
  properties: {
    channelId: false  // Explicitly disallowed for non-channel types
  }
}
```

**Key points:**
1. `channelId` is **required** only when `type === 'channel'`
2. `channelId` is **disallowed** for `user` and `unrelated` wallet types
3. When the API returns `channelId: null`, this is the database representation of an unset field

---

## Why `channelId: null` Appears in Response

Looking at the tester's wallet response:

```json
{
  "type": "unrelated",
  "channelId": null,
  ...
}
```

This happens because:
- The database schema includes `channelId` as an optional field (`wdk-data-shard-wrk/workers/lib/db/base/repositories/wallets.js:12`)
- For non-channel wallets, the field is stored as `null` (or undefined)
- The API serializes this as `channelId: null` in the response

---

## Duplicate Detection Logic

From `wdk-data-shard-wrk/workers/proc.shard.data.wrk.js:168-172`:

```javascript
const isDup = (wallets) =>
  wallets.some(w =>
    (type === 'channel' && w.type === 'channel' && w.channelId === channelId) ||
    (type === 'user' && w.type === 'user')
  )
```

Notice: `unrelated` type has NO duplicate check - users can create multiple unrelated wallets.

---

## Answer to Tester's Question

> "I got the response for one of my account in the staging, where the channel id is null, and channel type is unrelated, is it ok?"

**Yes, this is expected behavior.**

- `type: "unrelated"` is a valid wallet type for external/imported wallets
- `channelId: null` is correct for non-channel wallets
- The `unrelated` type is designed for wallets that aren't tied to the user's primary wallet or any channel

Dev2's assessment was correct: "channelId only appears in channel wallets".

---

## Additional Note on Shard Assignment Issue (Dev1)

The separate issue raised by Dev1 about users being assigned to different shards needs further investigation:

> "how is it possible that the same user gets assigned to different shards when doing /connect?"

This could be related to:
1. Missing migrations (as Dev2 mentioned - Autobase lookups use exact string matching)
2. Multiple emulators causing test confusion (as Dev1 acknowledged)

The migration warning in `wdk-ork-wrk` README is relevant:
> "Autobase lookups use exact string matching - skipping migrations causes address lookup failures and allows duplicate wallet creation."

**Recommendation**: Verify all pending migrations have been applied on staging environment.
