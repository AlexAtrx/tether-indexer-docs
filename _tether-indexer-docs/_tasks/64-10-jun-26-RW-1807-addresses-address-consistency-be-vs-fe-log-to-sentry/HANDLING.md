# Handling: RW-1905 BE API for Address snapshot (subtask of RW-1807)

Implemented 2026-06-10. All work local, nothing committed or pushed, nothing posted to Asana.

## What was built

`POST /api/v1/address-snapshots` on rumble-app-node: the authenticated wallet user uploads all FE-derived addresses; the snapshot is persisted append-only in a dedicated Mongo collection on the user's data shard for later manual reconciliation. It never reads or writes the wallets data, so the backend addresses (source of truth) cannot be affected.

Request body: `{ addresses: [ { network, address, name?, type?, index? } ] }` (1..1000 entries, validated by fastify `schema.body` at the API boundary). Response: `{ stored: true }` on insert, `{ stored: false }` when the snapshot is identical to the user's latest one (idempotent re-upload on every app startup, no unbounded growth).

## Call chain

```
rumble-app-node POST /api/v1/address-snapshots (auth.guard, schema.body, userId from session)
  -> rumble-ork-wrk storeAddressSnapshot (resolves user shard)
  -> rumble-data-shard-wrk API storeAddressSnapshot (re-validates: non-empty array, conf addressSnapshot.maxEntries, default 1000)
  -> rumble-data-shard-wrk Proc storeAddressSnapshot (skip-if-unchanged, staged save via unit-of-work)
  -> Mongo `wdk_data_shard_address_snapshots` { userId, addresses, createdAt } (server-stamped), index { userId: 1, createdAt: -1 }
```

Shard-side validation is duplicated deliberately: internal HRPC callers skip the fastify schema (see workspace CLAUDE.md caveat).

## Files changed

rumble-app-node:
- `workers/lib/server.js` - new route (after the user-data routes)
- `workers/lib/services/ork.js` - storeAddressSnapshot service fn + export
- `workers/lib/middlewares/response.validator.js` - response schema entry
- `tests/address-snapshot-route.unit.test.js` - new

rumble-ork-wrk:
- `workers/api.ork.wrk.js` - storeAddressSnapshot (resolveUserShardRpc + forward) + rpcActions allowlist
- `tests/unit/address-snapshot.unit.test.js` - new

rumble-data-shard-wrk:
- `workers/lib/db/base/repositories/addresssnapshot.js` - new base interface
- `workers/lib/db/mongodb/repositories/addresssnapshot.js` - new repo (staged insertOne, commitWrites-only flush, getLatestSnapshot)
- `workers/lib/db/mongodb/context.js` - register repo + ready() index
- `workers/lib/db/mongodb/unit.of.work.js` - register repo + commitWrites
- `workers/api.shard.data.wrk.js` - validation + proc forward + allowlist
- `workers/proc.shard.data.wrk.js` - handler (dedupe vs latest, uow insert, rollback on error) + allowlist
- `config/common.json.example` - addressSnapshot.maxEntries
- `tests/addresssnapshot.repository.mongodb.unit.test.js` - new
- `tests/api.shard.data.wrk.unit.test.js`, `tests/proc.shard.data.wrk.unit.test.js` - new test blocks

## Design decisions

- Append-only insert (insertOne, never update/upsert/delete): snapshots are reconciliation evidence; no client-facing read or delete.
- Skip-if-unchanged in the Proc (compare against latest snapshot) answers the FE dev's infinite-growth concern; FE needs no read-modify-write.
- MongoDB only: `dbEngine` is `mongodb` in the deployed config since the Oct 2025 migration; no hyperdb repository or schema changes (a new hyperdb collection would require append-only spec changes and a rebuild for an engine no longer in use). Under the hyperdb engine the proc fails fast with `ERR_ADDRESS_SNAPSHOT_NOT_SUPPORTED` (review fix, 2026-06-10).
- Shard API also caps the serialized snapshot at conf `addressSnapshot.maxSize` (default 256 KB), measured with `Buffer.byteLength(..., 'utf8')` (not `.length`, which counts UTF-16 code units; note `setUserData`'s valueMaxSize check has that flaw), and rejects entries that are not objects with non-empty string `network` and `address` (`ERR_INVALID_ADDRESS_ENTRY`): unlike opaque userData values, those two fields are semantic and the offline reconciliation depends on them (review fixes, 2026-06-10). Review points on dedupe canonicalization/snapshotHash and app-vs-shard limit drift were rejected as over-engineering for append-only temporary diagnostic data; retention stays an open product question; the stale `dbEngine: "hyperdb"` default in common.json.example was left as a separate cleanup.
- Collection named `wdk_data_shard_address_snapshots` matching the existing `wdk_data_shard_*` naming.

## Test results

- rumble-data-shard-wrk: unit tests 37/37 (proc), 8/8 (api), 4/4 (new repo file); lint clean on touched files. Pre-existing failures in `tests/lib/rumble.server.util.unit.test.js` (rant logging asserts) confirmed present on a clean tree (git stash), unrelated.
- rumble-ork-wrk: npm test 10/10 + lint clean.
- rumble-app-node: unit tests 16/16 (incl. new route test, 14 asserts); lint clean on touched files. The intg test needs a booted stack, not run.

## Still open

- FE payload field vocabulary (`type` values such as tipjar/profile/unrelated) to be agreed with Aliaksei; schema accepts free-form strings on purpose.
- Retention: how long to keep snapshots after the reconciliation exercise (drop the collection when done).
