# Findings — code investigation

Local grep of every repo under `_INDEXER/` against `address-book`, `addressBook`,
`address_book`, `tipping_enabled`, `/wallet/v1/`.

## `/wallet/v1/address-book` is NOT ours

Zero matches in any of our repos (`rumble-app-node`, `rumble-ork-wrk`,
`rumble-data-shard-wrk`, all `wdk-*`, all `tether-*`). Patricio's
`/wallet/v1/address-book` lives on the **Rumble side**, not on our app-node /
ork / shard.

## What WE own for "is this creator tippable"

`tipping_enabled` on our side is effectively "an enabled tip-jar wallet row
exists in the shard DB". The path:

1. `rumble-app-node/workers/lib/server.js:52,70`
   - `GET /api/v1/users/:userId/tip-jar`
   - `GET /api/v1/channels/:channelId/tip-jar`
2. `rumble-app-node/workers/lib/services/ork.js:21,28`
   - `getUserTipJar` / `getChannelTipJar` — plain RPC passthrough to the ork.
3. `rumble-ork-wrk/workers/api.ork.wrk.js:35,39`
   - `getChannelTipJar` first resolves the shard via `_shardUtil.resolveChannelShard(channelId)`, then RPCs the shard.
4. `rumble-data-shard-wrk/workers/api.shard.data.wrk.js:41,54`
   - `getUserTipJar`: `walletRepository.getActiveUserWallets(userId)` → filter `enabled === true && type === 'user'` → first row, or throw `ERR_USER_TIP_JAR_NOT_FOUND`.
   - `getChannelTipJar`: `walletRepository.getActiveChannelWallet(channelId)` → must be truthy and `enabled === true`, else throw `ERR_CHANNEL_TIP_JAR_NOT_FOUND`.

We do not store a `tipping_enabled` boolean — it's derived on every call from
the wallet row's `enabled` flag in the HyperDB shard.

## Likely failure modes for RW-1120

1. **Rumble-side cache (most likely).** Rumble's `/wallet/v1/address-book`
   fronts our tip-jar endpoint with a stale cache, so a freshly followed
   channel keeps returning `tipping_enabled=false` on Rumble's side even
   though our backend would answer correctly. Matches Andrei's "can take 10
   minutes" SLA claim — sounds like a Rumble cache TTL, not a wallet-side lag.

2. **Our side — wallet creation lag.** After the follow, the channel's tip-jar
   wallet row takes time to land in the shard DB with `enabled=true` (wallet
   provisioning lag, missed webhook, or shard-routing race). Looks identical
   to the Rumble-cache case from the app's POV.

The two are distinguishable with one test: hit
`GET /api/v1/channels/:channelId/tip-jar` on staging the moment the channel is
followed. If we return 200 with an enabled wallet immediately, the lag is
entirely Rumble's; if we return `ERR_CHANNEL_TIP_JAR_NOT_FOUND` for several
minutes, the lag is ours.

## How to get `fguuj`'s channelId (we can't resolve it locally)

Our schema stores `channelId` as an opaque string
(`rumble-data-shard-wrk/workers/lib/db/hyperdb/spec/hyperschema/schema.json:53`) —
there is no handle → channelId mapping in our code. Options, fastest first:

1. **Network inspection on the app.** Run a staging build of Rumble Wallet,
   follow `fguuj`, and capture the outgoing call to
   `GET /api/v1/channels/:channelId/tip-jar`. The channelId is right in the
   URL. No Rumble help needed.

2. **Rumble web page source.** On `web190181.rumble.com/user/fguuj` (or `/c/`),
   view-source or inspect network — Rumble's own FE embeds the channel's id
   in meta tags or the first XHR. Same trick for `gstaging65`.

3. **Ask Gohar / Andrei.** Gohar created the test accounts and is already in
   touch with Andrei on the Rumble side; one DM gets the ids.

4. **Staging app-node logs.** Grep for `/api/v1/channels/*/tip-jar` around
   the screenshot time (2026-02-23 ~15:57) — the channelId will be in the
   access log.

## If you have direct DB access to the shard data store

You can bypass the HTTP path entirely and inspect the wallet row for the
channel.

**Collection:** `@wdk-data-shard/wallets`
(`wdk-data-shard-wrk/workers/lib/db/hyperdb/spec/hyperdb/db.json:73`)

**Row fields**
(`wdk-data-shard-wrk/workers/lib/db/hyperdb/spec/hyperschema/schema.json:3-82`):
`id`, `type` (`"user"` | `"channel"`), `userId`, `channelId`, `enabled` (the
boolean that drives tippability), `addresses`, `createdAt`, `updatedAt`,
`deletedAt`, `name`, `accountIndex`, `meta`.

**Useful indexes** (`db.json:69-137`):
- `@wdk-data-shard/active-wallets-by-channel-id` — for channel tip-jar lookup.
- `@wdk-data-shard/active-wallets-by-user-id` — for user tip-jar lookup.
- `@wdk-data-shard/active-wallets-by-address` — if you only have an address.

**What the backend actually checks:**
- Channel
  (`rumble-data-shard-wrk/workers/api.shard.data.wrk.js:54-62`):
  `getActiveChannelWallet(channelId)` must return a row **and**
  `channelWallet.enabled === true`, else `ERR_CHANNEL_TIP_JAR_NOT_FOUND`.
- User
  (`rumble-data-shard-wrk/workers/api.shard.data.wrk.js:41-51`):
  any row with `type === 'user'` and `enabled === true`.

**Sharding caveat.** Wallets are sharded. `channelId → shard` is resolved via
`_shardUtil.resolveChannelShard(channelId)` in the ork
(`rumble-ork-wrk/workers/api.ork.wrk.js:40`). Querying the wrong shard returns
nothing even when the wallet exists. Options:
1. Query every shard and union the results,
2. Use the same shard-resolution util as the ork, or
3. Check recent ork logs for `resolveChannelShard` calls for that channelId.

**How the DB inspection decides RW-1120.** For `fguuj`'s channelId, pull the
wallet row via `active-wallets-by-channel-id`:

- **No row at all** → channel-wallet was never provisioned on follow →
  provisioning bug on our side (missed webhook / shard-routing race).
- **Row exists, `enabled === false`** → enablement flow is the lag; trace
  where `enabled` flips to `true`.
- **Row exists, `enabled === true`, `deletedAt` unset** → we would answer
  200 on `/api/v1/channels/:channelId/tip-jar`; the stale
  `tipping_enabled=false` is entirely on Rumble's side.

Also compare `createdAt` / `updatedAt` against the exact follow timestamp —
that measures the lag if any is on our side.

## Recommended next step

Reproduce on staging and call
`GET /api/v1/channels/<fguuj-channelId>/tip-jar` directly, bypassing the
Rumble frontend:

- **If we return 200 immediately** — this is a Rumble-side caching bug.
  Push back to Rumble with the evidence and ask them to reduce
  `/wallet/v1/address-book` TTL or invalidate on follow.
- **If we return `ERR_CHANNEL_TIP_JAR_NOT_FOUND` for minutes** — this is our
  wallet provisioning lag. Trace where channel-wallet rows are created on
  follow (likely an ork webhook or an on-demand create in the shard) and
  check for a missed event or a race around `enabled=true`.

Do NOT write any fix before this test — the answer determines whether this is
a backend fix at all.
