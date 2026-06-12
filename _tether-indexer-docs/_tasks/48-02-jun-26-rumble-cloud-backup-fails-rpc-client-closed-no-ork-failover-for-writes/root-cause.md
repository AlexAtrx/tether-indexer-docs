# Cloud backup fails with "RPC client closed" - no ork failover for write methods

**Date:** 2026-06-02
**Environment:** staging (walletstg1/2/3), reproduced from mobile screenshot
**Related:** [`47-...-WDK-1515`](../47-02-jun-26-WDK-1515-investigate-rumble-prod-err-wallet-transfer-rpc-fail-rpc-client-closed-requiring-data-shard-restarts/root-cause.md)
(also folder `41-...-WDK-1515`). Same `RPC client closed` transport fault, different layer and symptom. See "Relationship to WDK-1515" below.

## Summary

Enabling **Cloud Backup** in the wallet app fails with a "Backup Failed"
sheet showing `[HRPC_ERR]=RPC client closed`. The backup step issues two
backend writes (`POST /api/v1/entropy`, `POST /api/v1/seed`). When the
CRC32-routed ork's Hyperswarm RPC channel is momentarily closed, these writes
fail immediately and surface to the user, because `storeEntropy` / `storeSeed`
are **excluded from the ork failover allowlist**. Read methods on the same
layer get up to 9-way failover and recover transparently; the write path gets
`maxAttempts:1` and no failover.

This is a transient-blip failure, not the multi-hour stuck-client case from
WDK-1515. It needs its own fix, and it also corrects WDK-1515's premise that
the app-node layer is "already hardened" for this error (it is, for reads
only).

## Symptom

Mobile screenshot (`images/backup-failed-screenshot.png`), staging build,
"Backup Your Wallet" -> Cloud Backup:

```
Backup Failed
[HRPC_ERR]=RPC client closed
[ Try Again ]  [ Skip ]
```

## Path (client -> backend)

1. `PasskeyRegistrationContainer.tsx:166` `migrateToCloudBackup(...)` with an
   `uploadToCloud` callback (`PasskeyRegistrationScreen`).
2. The callback (`:168`) calls `backupSeedToCloud`
   (`store/backend/wdk-backup-api.ts`).
3. `backupSeedToCloud` fires two backend writes in parallel via
   `Promise.allSettled` (`wdk-backup-api.ts:107-120`): `storeEncryptedEntropy`
   and `storeEncryptedSeed`.
4. Those map to `POST /api/v1/entropy` and `POST /api/v1/seed`
   (`store/backend/rumble-wallet-api-rtk.ts:307, :326`).
5. Backend routes (inherited from wdk-app-node base):
   `wdk-app-node/workers/lib/server.js:162` (entropy) -> `service.ork.storeEntropy`,
   `:214` (seed) -> `service.ork.storeSeed`.
6. `ork.storeEntropy` / `ork.storeSeed`
   (`wdk-app-node/workers/lib/services/ork.js:160, :175`) call
   `rpcCall(ctx, req, 'storeEntropy'|'storeSeed', ...)`.

If any write in step 3 rejects, `backupSeedToCloud` throws
`ERROR_CODES.SAVE_SEED_FAILED`, and the raw `[HRPC_ERR]=...` from the backend
is what the sheet renders.

## Root cause (exact code)

In `wdk-app-node/workers/lib/services/ork.js`:

- `CORE_RETRYABLE_METHODS` (`ork.js:10-26`) is a **reads-only** allowlist:
  `lookupDataShard`, `getWallet`, `getUserWallets`, `getEntropy`, `getSeed`,
  `getUserBalance`, `getWalletTransfers`, ... `storeEntropy` and `storeSeed`
  are not in it.
- `rpcCallWithRetryAndFailover` (`ork.js:65`):
  ```js
  const maxAttempts = retryableMethod ? orkRpcKeys.length : 1
  ...
  return await ctx.net_r0.jRequest(orkRpcKey, method, params, reqOpts, retryableMethod ? 0 : 2)
  ```
  For a non-retryable method (every write), `maxAttempts = 1`: it tries one ork
  and rethrows. The `jRequest` internal retry count of `2` only re-issues on the
  **same** (already-closed) channel, which is exactly what is failing, so it
  does not help.
- `isChannelClosedError` (`ork.js:28`) recognises
  `err.message.includes('RPC client closed') || err.code === 'CHANNEL_CLOSED'`
  and the failover branch only runs when `channelClosed && retryableMethod`.
  Writes never enter it.

`RPC client closed` is a known transient infra error: the codebase already
downgrades it to a Sentry warning (`rumble-app-node/workers/http.node.wrk.js:37`).
Reads route around it; writes do not.

## Why the writes were excluded (the real constraint for any fix)

The shard handlers are **non-idempotent appends**, not upserts
(`wdk-data-shard-wrk/workers/api.shard.data.wrk.js`):

```js
// :698
async storeEntropy (req) {
  const { userId, ...entropyData } = req
  const existing = (await this._getUserData({ ...req, collection: 'entropies' }))?.entropies
  const entropies = Array.isArray(existing) ? [...existing, entropyData] : [entropyData]
  return this._storeUserData({ userId, collection: 'entropies', entropies })
}
// :717 storeSeed is the identical shape for collection 'seeds'
```

`getEntropy` / `getSeed` return the full array. A blind failover retry where
the first write committed but its ack was lost would append a **duplicate**
entry. So the exclusion is deliberate: the current code traded backup
availability for write-correctness.

Unlike the shard -> indexer path in WDK-1515, the app-node -> ork path has
**multiple ork peers** (9 on staging), so failover-to-another-peer is genuinely
available here. The only blocker to enabling it for writes is idempotency.

## Evidence (staging, walletstg1/2/3)

Same transient condition, two outcomes, side by side in the app-node error logs:

```
method=storeSeed          ... "maxAttempts":1   channelState:{freshKeyCount:9, selectedKeyFound:true}  -> ERR_ROUTE_UNHANDLED (user sees "Backup Failed")
method=getWalletTransfers ... "maxAttempts":9   channelState:{freshKeyCount:9, selectedKeyFound:true}  -> recovers via failover, no user impact
```

- `storeSeed` / `storeEntropy` channel-closed failures with `maxAttempts:1`
  recur across **2026-04-12, 04-23, 04-29, 05-04** on walletstg1 and walletstg3.
- `selectedKeyFound:true` on every one: the target ork was still discoverable,
  only the channel blipped. This is the case failover is meant to absorb.
- Read-side channel-closed flapping is **live today** (walletstg1, 2026-06-02
  ~12:19 UTC): a run of `getUserTransfers` / `getWalletTransfers` /
  `getUserWallets` all hit `RPC client closed` on the same ork key for ~17s and
  recovered via `maxAttempts:9` failover. A backup write landing in that window
  would have failed outright.
- Orks and shards are otherwise stable (2-4 PM2 restarts, ~3.7d uptime), so
  this is normal channel churn, not a crash loop.

The store-method failures are isolated single events (not sustained bursts) and
the surrounding reads recover within seconds, i.e. the plain **transient-blip**
flavor, distinct from WDK-1515's persistent-stuck-client case.

## Relationship to WDK-1515

Same `RPC client closed` / `CHANNEL_CLOSED` transport fault from a pooled
`@hyperswarm/rpc` client; different bug.

| | WDK-1515 | this (cloud backup) |
|---|---|---|
| Layer | shard -> indexer topic `{chain}:{ccy}` | app-node -> ork |
| Path | background transfer-polling cron | user-facing cloud-backup write |
| Methods | `queryGroupedTransfersByAddress` | `storeEntropy` / `storeSeed` |
| Existing resilience | none (no retry at all) | failover exists, excludes writes |
| Flavor | persistent stuck client, needs shard restart | single transient blip, no restart |
| Failover viable? | maybe not (often 1 indexer peer/topic) | yes (9 orks); blocker is idempotency |

Correction to WDK-1515: its root-cause.md states the app-node is "already
hardened" and "self-recovers" via `rpcCallWithRetryAndFailover`. That is true
for reads only. Writes (`storeEntropy` / `storeSeed`) fall through with
`maxAttempts:1`. A note recording this has been appended to the WDK-1515 doc.

**Shared durable fix:** WDK-1515 option 1 (pool-level evict + reconnect +
retry-once in `hp-svc-facs-net`) would resolve this case too and would make the
ork allowlist largely redundant.

## Recommended fix (in priority order)

1. **Idempotent shard writes + add to failover allowlist (contained, unblocks
   backups now).** Dedupe in `storeEntropy` / `storeSeed`
   (`wdk-data-shard-wrk/.../api.shard.data.wrk.js:698, :717`) by a stable key,
   either a content hash of the encrypted blob or a client-supplied backup id
   in `metadata`, so re-applying the same backup is a no-op. Then add
   `storeEntropy` / `storeSeed` to `CORE_RETRYABLE_METHODS`
   (`wdk-app-node/workers/lib/services/ork.js:10`) so they inherit the 9-way
   failover the reads already have. Propagates to rumble-data-shard-wrk /
   rumble-app-node via dependency bump.
2. **Pool-level reconnect in `hp-svc-facs-net` (shared, fixes everyone).** Same
   as WDK-1515 option 1. Larger blast radius; do it as the durable fix, but it
   is not required to unblock backups if (1) lands.
3. **Client-side retry in `backupSeedToCloud` (weakest alone).** Without (1) a
   retry can still double-append, and it papers over the layer that already
   owns failover. Only as defense in depth.

Recommendation: ship (1). It is the right layer, mirrors how reads already
behave, and removes the user-facing failure without waiting on the shared
facility change.

## Repos touched by the recommended fix

- `wdk-data-shard-wrk` (idempotent append in `storeEntropy` / `storeSeed`)
- `wdk-app-node` (add the two methods to `CORE_RETRYABLE_METHODS`)
- `rumble-data-shard-wrk` / `rumble-app-node` (inherit via dependency bump)

## Source references

- Mobile: `rumble-wallet-app-mobile/src/app/features/wallet-setup-v2/PasskeyRegistrationScreen/PasskeyRegistrationContainer.tsx:166`,
  `:168`; `store/backend/wdk-backup-api.ts:107-120`;
  `store/backend/rumble-wallet-api-rtk.ts:307, :326`.
- Backend ork: `wdk-app-node/workers/lib/services/ork.js:10` (allowlist),
  `:28` (`isChannelClosedError`), `:65` (`maxAttempts`), `:71` (`jRequest`),
  `:160` (`storeEntropy`), `:175` (`storeSeed`);
  `wdk-app-node/workers/lib/server.js:162, :214` (routes).
- Backend shard: `wdk-data-shard-wrk/workers/api.shard.data.wrk.js:698`
  (`storeEntropy`), `:717` (`storeSeed`), `:125` (`_storeUserData`).
- Transient handling: `rumble-app-node/workers/http.node.wrk.js:37`.
