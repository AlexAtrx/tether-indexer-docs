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

## Important version note

The source `wdk-ork-wrk` repo already contains a fix:

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

That fix is commit `f58519a3` (`fix: handle empty array in RoundRobin.updateItems()`).
`rumble-ork-wrk` branches also appear to point at newer `wdk-ork-wrk` refs that
include it, but the local installed `node_modules` copy is stale and still has
the old bug. The deploy tooling starts the repo with pm2 and assumes
dependencies are already installed, so a staging host with stale `node_modules`
can still run the broken dependency even if `package.json` / `package-lock.json`
were updated.

## Recommended next checks

1. On `walletstg1`, inspect the live ORK dependency file:
   `rumble-ork-wrk/node_modules/@tetherto/wdk-ork-wrk/workers/lib/round.rubin.js`
   or `round.robin.js`.
2. Confirm whether `updateItems()` has the empty-array guard.
3. Check the ORK status file for `dataShardIdx`; if the old code ran after an
   empty shard discovery, the in-memory index can be poisoned until ORK restart.
4. Run a clean dependency install on the staging ORK repo (`npm ci` or the
   project deploy equivalent) and restart the ORK process.
5. Consider adding defensive guards in ORK:
   - filter non-string `shardId` values in `_setShards()`;
   - throw a mapped error before `resolveRpc()` if `shardId` is missing;
   - log `dataShardIdx.getItems()` and `dataShardIdx.index` when
     `lookupDataShard` fails.

## Likely fix

The code-level fix is already present in newer `wdk-ork-wrk`; the practical fix
is to ensure staging is actually running that dependency. If staging already is
running the fixed code, the next likely culprit is a corrupted or missing shard
ID in ORK shard discovery, and the defensive guards/logging above should make
that visible immediately.
