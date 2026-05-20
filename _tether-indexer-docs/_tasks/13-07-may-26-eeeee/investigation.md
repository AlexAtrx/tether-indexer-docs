# Investigation: `/api/v1/connect` 500 on Rumble Wallet login

## Summary

The frontend fails during `walletApiClient.connectWithToken()` because
`POST /api/v1/connect` returns a 500. The app-node stack only shows the app
receiving a serialized ORK RPC error:

```text
[HRPC_ERR]=The first argument must be of type string or an instance of Buffer, ArrayBuffer, or Array or an Array-like Object. Received undefined
```

The most likely backend failure chain is:

1. `rumble-app-node` handles `/api/v1/connect` through the inherited
   `wdk-app-node` route.
2. `wdk-app-node` calls `service.ork.resolveDataShard(ctx, req)`.
3. The app node calls ORK action `lookupDataShard`.
4. ORK calls `DataShardUtil.resolveUserShard(req.userId)`.
5. ORK attempts to resolve a data-shard topic with `undefined`, which reaches
   `hp-svc-facs-net` `encodeTopic()` and throws the exact `Buffer.from(undefined)`
   error seen in the logs.

## Evidence

- Frontend call site:
  - `tetherto/rumble-wallet-app-mobile:queries/auth.ts@main` decodes
    `tokens.id_token.sub` into `userId` and calls
    `walletApiClient.connectWithToken(tokens.access_token, userId)`.
  - `tetherto/rumble-wallet-app-mobile:api/clients/WalletApiClient.ts@main`
    sends `Authorization: Bearer ${accessToken}` and `x-trace-id:
    mob:${userId}:...` to `/api/v1/connect`.

- App-node route:
  - `wdk-app-node/workers/lib/server.js:60` defines `POST /api/v1/connect`.
  - `wdk-app-node/workers/lib/server.js:83` calls
    `service.ork.resolveDataShard(ctx, req)`.
  - `wdk-app-node/workers/lib/services/ork.js:112` calls ORK
    `lookupDataShard` with the authenticated `userId`.

- ORK lookup path:
  - `wdk-ork-wrk/workers/api.ork.wrk.js:224` implements `lookupDataShard`.
  - `wdk-ork-wrk/workers/lib/data.shard.util.js:52` resolves/assigns a user
    shard.
  - `wdk-ork-wrk/workers/lib/data.shard.util.js:105` resolves the shard topic
    via `ctx.net_r0.lookupTopicKey(shardId, cached)`.
  - `hp-svc-facs-net/lib/hyperdht.lookup.js:93` calls
    `Buffer.from(topic, 'utf-8')`; passing `undefined` produces the exact
    error message from Slack.

- Staging log correlation:
  - app-node `walletstg1` receives `/api/v1/connect` with trace
    `mob:282786612:9501419f-7ead-4fda-9531-1ec299aeffb8`;
  - ORK `walletstg2`, PM2 app `ork-w-1-1`, worker
    `wrk-ork-api-w-1-1-e4f1cec9-4a34-450b-acd1-e0a2e2d58cfd`, logs
    `action="lookupDataShard"` for the same trace;
  - the immediately following ORK response log is a Buffer-encoded
    `[HRPC_ERR]=...Received undefined` response. That response log loses
    `traceId`/`action`, but its timestamp is the request timestamp + 1 ns, so it
    pairs with the `lookupDataShard` request.
  - the same ORK has successful `lookupDataShard` responses for other users, so
    this is not a total ORK outage. It most likely affects shard assignment for
    users without an existing lookup, or a specific corrupted lookup path.

## Reproduction of the matching failure

The installed `rumble-ork-wrk/node_modules/@tetherto/wdk-ork-wrk` copy in this
workspace still has the old round-robin bug:

```js
updateItems (items) {
  this.items = items
  this.index %= this.items.length
}
```

If shard discovery ever returns `[]`, `index %= 0` makes the index `NaN`.
When shards appear later, `NaN % length` stays `NaN`, so `next()` returns
`undefined`. That causes `resolveRpc(undefined)`, then
`lookupTopicKey(undefined)`, then the observed `Buffer.from(undefined)` error.

Local reproduction:

```text
after empty update: NaN
after shard returns: NaN
next shard: undefined
matching error: The first argument must be of type string or an instance of Buffer, ArrayBuffer, or Array or an Array-like Object. Received undefined
```

## Version note / staging update

The source `wdk-ork-wrk` repo contains a fix:

```js
updateItems (items) {
  this.items = items
  if (this.items.length === 0) {
    this.index = 0
  } else {
    this.index %= this.items.length
  }
}
```

That fix is commit `f58519a3` (`fix: handle empty array in RoundRobin.updateItems()`),
and `wdk-ork-wrk@v0.2.0` includes it.

Staging update from Francesco:

- live `node_modules/@tetherto/wdk-ork-wrk/package.json` reports
  `"version": "0.2.0"`;
- PM2 process `created at` is `2026-05-06T22:02:28.715Z`;
- live `round.robin.js` mtime is `May 6 21:26`.
- live `round.robin.js` contains the empty-array guard;
- `walletstg2:/srv/data/staging/rumble-ork-wrk/status/wrk-ork-api-w-1-1.json`
  has finite `"dataShardIdx": 8`, not `null`/`NaN`;
- sibling ORKs have finite indexes too: `w-1-0` = 7, `w-1-2` = 7.
- staging `config/common.json` uses `"lookupEngine": "mongodb"`;
- staging Mongo config points ORK lookups at database `wdk_ork`.
- querying `wdk_ork.wdk_ork_lookups` for the failing user
  `{ type: "users", key: { $in: ["282786612", 282786612] } }` returned `[]`.
- querying `wdk_ork.wdk_ork_lookups` for malformed `users` records with missing
  `key`, `value`, or `userId` also returned `[]`.
- all staging `rumble-data-shard-wrk/status/*.json` files currently show
  `"shardGroup": null`, but the data-shard API code sets `this.shardGroup` in
  memory from the proc worker and does not persist it back into the status JSON,
  so this does not prove the live shard groups are null.
- Grafana query `{agent="alloy", env="staging"} |= "Announced shard group"`
  returned no logs in the selected range. The log is emitted at data-shard API
  startup, so the query needs a range covering the last data-shard restart.
- exported Grafana `getShardGroup` logs from `2026-05-07 13:16:25` to
  `13:20:25` show 500 `getShardGroup` requests and 500 completed responses
  across all 27 shard API PM2 apps (`walletstg1/2/3`). Those logs prove data
  shard discovery is actively receiving responses, but they do not include the
  returned shard group value, so they cannot rule out a completed response with
  `undefined`.
- live staging `wdk-ork-wrk@0.2.0` contains:
  `return res.value.value` in
  `workers/lib/db/mongodb/lookup.storage.js:setOrIgnoreLookup()`.
- a direct staging Mongo driver check against an existing `users` lookup showed
  `findOneAndUpdate(..., { returnDocument: "after" })` returns the document
  directly:
  - `res.value` is the shard id string;
  - `res.value.value` is `undefined`.
  This reproduces the value that flows into `resolveRpc(undefined)`.
- after applying the `includeResultMetadata: true` hotfix on staging and
  restarting `ork-w-1-1`, a fresh `POST /api/v1/connect` returned `200` with:
  `{ "id": "wrk-data-shard-proc-w-0-1-d795338c-d372-491e-afcd-9b470a649e40",
  "userId": "dR_A34JEQLs" }`.

Assuming the server `ls` timestamp is UTC, the dependency file predates the PM2
process start. If the live `round.robin.js` also contains the empty-array guard,
the stale-dependency / stale-in-memory-code theory is unlikely. The status file
also rules out the old `NaN`-index failure mode. The empty Mongo lookup result
means the current error happens before the user lookup can be inserted.

## Recommended next checks

1. On `walletstg1`, inspect the live ORK dependency file:
   `rumble-ork-wrk/node_modules/@tetherto/wdk-ork-wrk/workers/lib/round.rubin.js`
   or `round.robin.js`.
2. Confirm whether `updateItems()` has the empty-array guard.
3. Inspect the live shard discovery result for `ork-w-1-1`:
   `dataShardIdx.getItems()` and `dataShardIdx.index` at runtime. The persisted
   index is valid, but the status file does not show the in-memory item list.
4. Check whether there are enough valid shard groups to justify index `8`, and
   whether any discovered shard group is missing/non-string.
5. Inspect the persisted Mongo lookup for the failing user:
   `db.wdk_ork_lookups.find({ type: "users", key: "282786612" })`. Staging does
   not have `mongosh`/`mongo` installed, so run the same query through a short
   Node script using the service's installed MongoDB driver. A malformed
   existing record with missing/null `value` would make `setOrIgnoreLookup()`
   return `undefined` and then `resolveRpc(undefined)` would hit the observed
   `Buffer.from(undefined)` error. A restart would not fix that because the
   lookup is persisted. This check returned `[]` for `282786612`, so this is not
   the direct cause for that user.
6. Query Grafana over a range that includes data-shard startup:
   `{agent="alloy", env="staging"} |= "\"action\":\"getShardGroup\""` and
   `{agent="alloy", env="staging"} |= "Announced shard"`. The former should show
   which data-shard API workers are answering ORK discovery. The latter should
   show the in-memory `shardGroup` values announced by each data-shard API.
7. Add temporary staging-only ORK logging around `_setShards()` and/or the
   `dataShardIdx.next()` call in `resolveUserShard()` to print:
   `rawShardResponses`, `shardItems`, `shardIndex`, selected `shardId`, and
   `typeof shardId`. This is the first check that will expose the actual bad
   value, because current `getShardGroup` response logs do not print payloads.
8. Consider adding defensive guards in ORK:
   - filter non-string `shardId` values in `_setShards()`;
   - throw a mapped error before `resolveRpc()` if `shardId` is missing;
   - log `dataShardIdx.getItems()` and `dataShardIdx.index` when
     `lookupDataShard` fails.

## Likely fix

Staging is running fixed `wdk-ork-wrk@0.2.0`, and there is no existing Mongo
lookup for `282786612` or malformed `users` lookup. The root cause is now
confirmed as a MongoDB driver v6 return-shape mismatch in
`MongodbLookupStorage.setOrIgnoreLookup()`: the code uses
`return res.value.value`, but MongoDB Node driver 6 returns the updated document
directly by default, not a `ModifyResult` with a `.value` wrapper. In staging,
`res.value` is the shard id string and `res.value.value` is `undefined`;
`resolveUserShard()` then calls `resolveRpc(undefined)` and hits the observed
`Buffer.from(undefined)` error. `saveWalletIdLookup()` has the same old-shape
assumption via `return res.value.walletId` and should be fixed in the same
patch.
