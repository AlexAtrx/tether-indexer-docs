# HANDLING — RW-1777 (Renamed tip jars show stale names in seed-phrase mode)

## Decision taken

Implemented the **write-time sync** fix (the recommended default in `root-cause.md`),
since both candidate fixes require a Rumble-web change and write-time sync fixes
every consumer of the stored name at once with no per-read Rumble call. The
read-time merge option was rejected: seed-phrase verify has no Rumble bearer
token, so it would need a brand-new Rumble-web service lookup that does not exist.

This change builds the **receiving side only** on our side: a service-to-service
endpoint that updates the stored WDK channel-wallet name, keyed by `channelId`.
The Rumble-web rename hook that calls it, plus the one-time backfill, are still
owned/approved work on the Rumble-web side (see "Still pending").

## Why a new endpoint (the existing one is not usable)

The existing `PATCH /api/v1/wallets/:id` cannot be called from a Rumble-web rename
hook for two independent reasons:

1. It is keyed by the WDK wallet `id`. Rumble web holds `channelId`, not the WDK id.
2. It is Bearer-only and enforces `userId` ownership on the shard
   (`wdk-data-shard-wrk` proc `updateWallet`). A rename event carries no user
   bearer token.

The data-layer primitive needed already existed: `getActiveChannelWallet(channelId)`
(used today by `getChannelTipJar`). The change wires a channel-keyed,
secret-authed update path on top of it.

## Contract for Rumble web (the caller they own)

```
PATCH /api/v1/admin/channel-wallets/:channelId
Auth:  x-secret-token   (the existing 'secret' guard, same as /api/v1/admin/wallets)
Body:  { "name": "<new channel name>" }   // 1..100 chars
200:   the updated wallet (mapWalletToResponse shape)
Errors: ERR_CHANNEL_WALLET_NOT_FOUND when no active wallet for that channelId
```

Rumble web should call this on every channel rename. It is idempotent (re-sending
the same name is a no-op write).

## Files changed (all on the Rumble overlay, no `wdk-*` base touched)

- `rumble-app-node/workers/lib/server.js` — new `PATCH /api/v1/admin/channel-wallets/:channelId` route (secret auth, body `{ name }`).
- `rumble-app-node/workers/lib/services/ork.js` — `updateChannelWalletName(ctx, req)` -> RPC `updateChannelWalletName`.
- `rumble-ork-wrk/workers/api.ork.wrk.js` — `updateChannelWalletName(req)`: resolves the channel shard, forwards over HRPC; added to the ork RPC allowlist.
- `rumble-data-shard-wrk/workers/api.shard.data.wrk.js` — `updateChannelWalletName(req)` -> `_procRpcCall`; added to the API RPC allowlist.
- `rumble-data-shard-wrk/workers/proc.shard.data.wrk.js` — `updateChannelWalletName(req)`: resolves by `channelId`, sets `name`, persists, returns `mapWalletToResponse`; added to the proc RPC allowlist.
- `rumble-data-shard-wrk/tests/proc.shard.data.wrk.unit.test.js` — 2 unit tests (rename + commit; missing wallet -> throw + rollback).

## Design notes

- The new proc method deliberately does **not** call `syncJar`. `syncJar` is the
  existing WDK -> Rumble push on `updateWallet`; this endpoint is the inbound
  Rumble -> WDK direction, so echoing back would be redundant and risk a loop.
- Contained entirely to the Rumble overlay because the rename concern is
  Rumble-owned and the channel-lookup primitive already lives there. No `wdk-*`
  base change, so no shared-lib version bumps or cross-repo mirroring were needed.
- Auth boundary is on the app-node (the ork has no auth, per conventions).

## Validation

- Lint (standard): clean on all changed files in the 3 repos.
- `rumble-data-shard-wrk` proc unit suite: 31/31 pass (incl. the 2 new tests).
- `rumble-ork-wrk` unit suite: 8/8 pass.
- `rumble-app-node` unit suite: 9/9 pass. The one failing test,
  `tests/http.node.wrk.intg.test.js` (balance), fails identically on a clean tree
  (it needs the live stack); not related to this change.

## Still pending (not in our repos / needs approval)

1. **Rumble-web rename hook** — call the contract above on channel rename. Owned
   by the Rumble-web team. This is the half that actually closes the ticket for
   future renames.
2. **One-time backfill** — repair already-stale rows. Should reuse the same
   channel-keyed path and run only after the rename hook is live (otherwise rows
   re-drift). Confirm who runs it.
3. **Team confirmation** on the write-time-sync direction (Slack question still
   open as of handling).

## Security carry-over

A test-account password and a 12-word seed phrase were posted in the Slack thread
(redacted in `slack-thread.md`). Scrub from Slack and rotate that account.

## Status

Local only. Not committed, not pushed, nothing posted to Asana/GitHub.
