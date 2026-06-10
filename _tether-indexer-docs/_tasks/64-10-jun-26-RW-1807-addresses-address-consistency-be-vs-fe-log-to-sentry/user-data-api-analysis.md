# Can /api/v1/user-data be used for the FE address snapshot?

Question from the BE lead (2026-06-10): "can't we use the /user_data endpoints for this?"

## What the API actually is

`rumble-app-node` exposes POST / GET / DELETE `/api/v1/user-data` (`workers/lib/server.js:866-925`), auth-guarded, body `{ key, value }`. The call chain is:

```
rumble-app-node (service.ork.setUserData, userId injected server-side from req._info.user.id)
  -> rumble-ork-wrk api.ork.wrk.js:71 (shard routing by userId)
  -> rumble-data-shard-wrk api.shard.data.wrk.js:154 (validation) -> proc.shard.data.wrk.js:518
  -> Mongo collection `wdk_data_shard_user_data`, doc { userId, key, value }, unique index (userId, key)
```

Constraints enforced in `rumble-data-shard-wrk`:

- key must start with prefix `user_` (conf `userData.keyPrefix`), max 128 chars
- value max 64 KB JSON-stringified (conf `userData.valueMaxSize`)
- max 100 keys per user
- write is a latest-wins upsert (`user.data.js save()`); DELETE is exposed to the client
- same collection also holds internal keys (`devices` in rumble, `entropies`/`seeds` in wdk) but those have no `user_` prefix, so the prefix guard keeps client keys away from them

## Verdict: safe, but not suitable. Recommend a dedicated endpoint + collection.

Safe part: it writes only to the generic user-data KV collection, never to `walletRepository` / the wallets data, and userId cannot be spoofed (taken from the auth session, not the body). So the "must never overwrite backend addresses" requirement is met.

Why it still does not fit the snapshot use case:

1. **Client-owned semantics.** Latest-wins upsert plus a public DELETE: the client can replace or wipe the snapshot at any time. For reconciliation evidence we want write-once or append-only, controlled server-side.
2. **No server-side metadata or validation.** `value` is opaque JSON ({} schema), no fastify schema for the snapshot shape, no server timestamp, no app version. The analysis needs a trustworthy capture time and shape.
3. **64 KB cap.** Snapshot = all wallets x networks x tip jars; heavy channel owners could approach the cap, and raising it raises it for the whole KV.
4. **Painful offline extraction.** Snapshots would sit in a generic KV collection across all data shards under an agreed magic key, mixed with other user keys. A dedicated collection is trivial to dump, analyze, and drop afterwards ("temporary" storage per the ticket).

A dedicated endpoint follows the exact same app-node -> ork -> data-shard path as user-data, so the incremental effort is small: fastify `schema.body` at the HTTP boundary, one new repository + collection on the shard (staged writes via unit-of-work, append-only), server-stamped `createdAt`.

## Spec recorded in RW-1905 (subtask) on 2026-06-10

- New endpoint in rumble-app-node for the authenticated user to upload the FE address snapshot (wallet name, wallet type, index, network, address per entry).
- Persisted in its own dedicated collection, fully isolated from wallets data.
- Never overwrites or updates actual user wallet addresses; backend remains source of truth.
- Temporary storage: easy to export for offline analysis and to drop after the reconciliation exercise.
