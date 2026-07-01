# Handling — WDK-1522 support setting multiple user-data keys in one request

## Type
feature

## What was wanted
The user-data key/value API only operates on one key per request, so a client
persisting several keys makes N sequential POSTs, each its own ork + shard RPC
round-trip. WDK-1522 asks for a batch set and a batch get so several keys go in
one call.

## Scope decision (scope-feature gate)
The whole user-data feature (the `/api/v1/user-data` routes and the
`setUserData` / `getUserData` / `deleteUserData` RPC methods) lives entirely in
the `tether-wallet-*` fork, not in the `wdk-*` base and not in Rumble. The
ticket is labelled Open Source / Generic Support, and `tether-wallet-*` is that
generic wallet product layer. So the change is scoped to the three
`tether-wallet-*` repos, with no base or Rumble edits. Unambiguous, no ask
needed.

## Decisions confirmed with Alex (before coding)
- **New dedicated `/batch` endpoints**, existing single-key POST/GET/DELETE
  untouched (cleanest backward compat, no `oneOf` overloading).
- **All-or-nothing atomic** batch set: validate the whole batch up front, then
  write every entry in one proc unit of work committed once; retry re-applies
  the same idempotent upserts.
- **Object-map GET response** `{ values: { key: value|null } }`.

## Change
New endpoints, wired through all three layers, mirroring the single-key path:

- `POST /api/v1/user-data/batch` body `{ entries: [{ key, value }, ...] }` -> `{ success: true }`
- `GET  /api/v1/user-data/batch?keys=user_a&keys=user_b` -> `{ values: { user_a: <v|null>, user_b: <v|null> } }`

Path: app-node HTTP (fastify `schema.body` / `querystring`) -> `service.ork.*`
-> ork worker `resolveUserShardRpc` -> data-shard api (validation, forwards to
proc for writes) -> data-shard proc (atomic UoW write + `maxKeysPerUser`
enforcement). The batch GET is a read served on the api worker via the existing
`getUserDataMulti` repo method (a single Mongo query).

Key `file:line`:
- `tether-wallet-app-node/workers/lib/server.js` — the two `/user-data/batch` routes (after the DELETE route ~L903).
- `tether-wallet-app-node/workers/lib/services/ork.js:53` `setUserDataBatch`, `:63` `getUserDataBatch` (query `keys` normalized to an array; batch get added to `RETRYABLE_METHODS`).
- `tether-wallet-app-node/workers/lib/utils/appError.js:25` new 400 codes `ERR_INVALID_BATCH` / `ERR_BATCH_TOO_LARGE` / `ERR_DUPLICATE_KEY`.
- `tether-wallet-ork-wrk/workers/api.ork.wrk.js:55` `setUserDataBatch`, `:65` `getUserDataBatch`; both added to the `_registerRpcActionHandlers` list.
- `tether-wallet-data-shard-wrk/workers/api.shard.data.wrk.js:220` `setUserDataBatch` (per-key validation, dup-key + batch-size guards, forwards to proc), `:256` `getUserDataBatch` (validates keys, one `getUserDataMulti` query, builds the value map with null for unset); both registered in the api `rpcActions`.
- `tether-wallet-data-shard-wrk/workers/proc.shard.data.wrk.js:372` `setUserDataBatch` (counts new keys for `maxKeysPerUser`, LRU invalidation, one UoW committed once); registered in the proc `rpcActions`.

## Repos touched
- tether-wallet-app-node — 2 HTTP routes + swagger schema, 2 ork-service methods, 3 error-code mappings.
- tether-wallet-ork-wrk — 2 shard-routing methods + RPC action registration.
- tether-wallet-data-shard-wrk — api `setUserDataBatch`/`getUserDataBatch` (validation + read), proc `setUserDataBatch` (atomic write), RPC action registration on both.

## Layering / idempotency / separation notes
- Input-shape validation is on the app-node fastify `schema.body` / `querystring`
  (the API boundary). The internal HRPC path skips that schema, so the data-shard
  api worker re-validates every key (prefix/length), value size, batch size, and
  duplicate keys before forwarding, matching the existing single-key api-worker
  guards.
- Writes stay on the proc side. The proc `setUserDataBatch` opens one unit of
  work, upserts every entry, and commits once, so the batch is atomic
  (all-or-nothing) and idempotent on retry or at-least-once HRPC re-delivery
  (`save` is an upsert keyed by `(userId, key)`).
- `maxKeysPerUser` is enforced across the whole batch on proc: it counts only the
  keys the batch introduces (`getUserDataMulti` to find which already exist) and
  rejects when `existing + newKeyCount > max`, consistent with the single-key
  `>=` check. Batch size is also capped at `maxKeysPerUser` on the api worker.
- Only mutable `user_`-prefixed keys are reachable (immutable `seeds`/`entropies`
  are not `user_`-prefixed, so the prefix check rejects them), so the batch only
  touches `userDataRepository`. No HyperDB schema change (the fork is mongodb-only).
- Storage shape matches single-key exactly (`save({ value: { value }, userId, key })`),
  so the batch get's `d.value?.value` unwrap lines up with the single get.

## Tests
- tether-wallet-data-shard-wrk: `npm run test:unit` — pass (156/156 tests, 387/387 asserts). Added: api `setUserDataBatch` (forward, empty, oversize, bad-prefix, dup-key, value-too-large) + `getUserDataBatch` (value map with null, empty, bad-prefix); proc `setUserDataBatch` (single-UoW write, ERR_MAX_KEYS_EXCEEDED, skip-count-when-all-exist, rollback-on-save-throw, LRU invalidation); bumped the api/proc RPC-action count assertions (12->14, 5->6). Lint clean. One unrelated pre-existing failure in `wallets.unit.test.js` (`save preserves explicit deletedAt`), confirmed failing on baseline with my changes stashed.
- tether-wallet-ork-wrk: `brittle tests/unit/**/*.test.js` — my 2 new tests pass (51/52). Added `setUserDataBatch`/`getUserDataBatch` forwarding tests and the two actions to the `_start` expected-actions list. Lint clean. One unrelated pre-existing failure (`_setupMongodbLookupEngine uses default operations...`), confirmed on baseline.
- tether-wallet-app-node: `brittle tests/unit/services/ork.test.js` — pass (29/29). Added `setUserDataBatch` forwards-entries, `getUserDataBatch` single-key-normalized and array-passthrough. Lint clean. Also added HTTP integration tests for the two batch routes. The full `http.node.wrk.intg.test.js` suite can't complete locally (it needs a live Redis plus a compliance service, and a pre-existing compliance test hard-crashes the runner before the user-data tests). I verified the two new routes live via a standalone boot of the real worker (setupHook + mocked `net_r0.jRequest`): POST batch -> 200 forwarding `setUserDataBatch`; empty batch -> 422 (fastify schema rejection, the app-wide status, so the intg assertion expects 422); GET `?keys=a&keys=b` -> parsed to `['a','b']`; GET `?keys=a` -> normalized to `['a']`. All green (6/6). Temporary redis + generated config were cleaned up afterwards.

## Assumptions / open points
- Batch size is capped at `maxKeysPerUser` (100 by default) rather than a new
  `maxKeysPerBatch` config knob, since a user can never hold more keys than that
  anyway; no config change was needed.
- Empty-batch and other schema violations return **422** (this app's fastify
  schema-validation status), not 400. That is consistent with every other route
  in the app.
</content>
