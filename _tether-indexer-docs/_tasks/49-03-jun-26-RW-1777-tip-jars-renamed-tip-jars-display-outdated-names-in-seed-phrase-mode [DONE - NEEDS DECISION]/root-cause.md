# Root cause — RW-1777 (Renamed Tip Jars show outdated names in Seed Phrase mode)

## Classification

Backend bug, confirmed by code trace. It is a real BE defect (FE needs no
change, matching Ahsan's conclusion), but the fix that actually closes it lands
on the Rumble web server (`rumble-wallet-backend`), which is not cloned in this
workspace, and it depends on a design decision that Alex already raised in Slack
and that is still unanswered. So this is delivered as analysis with a
recommendation, not a speculative code change. See "Recommendation" and
"Decision / owner needed".

## Conclusion

`/api/v1/seed-phrases/connect/verify` returns the tip-jar / channel `name` that
is stored on the WDK wallet row. That stored name is a snapshot captured when
the wallet was created; nothing updates it when the channel is later renamed on
Rumble web. The canonical, up-to-date channel name lives only on the Rumble web
server, so after a rename the verify response is stale.

The username/password flow looks correct for a different reason: in that flow
the client (or the app-node, on the user's behalf) holds a Rumble bearer token
and reads fresh channel names from Rumble web via `/-wallet/v1/channels`. In
seed-phrase mode the user authenticates by signing a challenge with their wallet
key and has no Rumble bearer token, so that fresh-name path is not available and
the endpoint can only return the stale stored name.

There is no in-workspace, seed-phrase-only fix: the names that go stale are
owned by the Rumble side, and the seed-phrase request has no Rumble credential
to fetch them fresh at read time. The clean fix is to keep the stored WDK name
in sync when a channel is renamed (write-time sync), which is a change on the
rename owner (Rumble web), plus a one-time backfill of already-stale rows.

## What is happening (exact path)

1. Route: `POST /api/v1/seed-phrases/connect/verify`
   `rumble-app-node/workers/lib/server.js:925`.
2. Handler: `verifySeedChallenge`
   `rumble-app-node/workers/lib/services/seed.recovery.js:40`. After the
   signature check it builds an internal request from the resolved `userId` and
   returns `getUserWallets(...)`:
   `rumble-app-node/workers/lib/services/seed.recovery.js:82-85`.
3. `getUserWallets` (base app-node) forwards to the ork:
   `wdk-app-node/workers/lib/services/ork.js:144-149` (RPC method
   `getUserWallets`).
4. Ork maps `getUserWallets` to the shard's `getWallets`:
   `wdk-ork-wrk/workers/api.ork.wrk.js` (`async getUserWallets (req) { return
   this._rpcRequest(req, 'getWallets') }`).
5. Shard `getWallets` reads the stored wallet rows and maps each through
   `mapWalletToResponse`:
   `wdk-data-shard-wrk/workers/api.shard.data.wrk.js:201-211`.
6. `mapWalletToResponse` spreads the whole stored wallet (so it includes the
   stored `name`, `type`, `channelId`, `userId`, `accountIndex`):
   `wdk-data-shard-wrk/workers/lib/utils.js:67-73`. This is exactly the object
   shape Ahsan pasted from the verify response in Slack.

The stored `name` is only ever changed via `updateWallet`:
`wdk-data-shard-wrk/workers/proc.shard.data.wrk.js:398-414` (`if (name) {
toUpdateWallet.name = name }`). The only HTTP surface that reaches it is
`PUT /api/v1/wallets/:id` with `body.name`:
`wdk-app-node/workers/lib/server.js:559-600`. A rename done on Rumble web does
not call this path, so the stored name never moves and the verify response stays
stale.

Why the username/password flow is fresh: the channel-ownership / channel-name
data comes from Rumble web via
`makeRumbleRequest(ctx, '/-wallet/v1/channels', authToken)`
(`rumble-app-node/workers/lib/services/auth.js:115`, used by
`channelOwnershipHandler` at `:108-126`). That call requires the user's Rumble
bearer token (`authorization: Bearer <token>`, `auth.js:14-21`). Seed-phrase
login produces no such token, so verify cannot enrich with fresh names the way
the logged-in flow can. Rumble web base URL is configured at
`rumble-app-node/config/common.json:18` (`sso.baseUrl`).

## Evidence

- Slack root cause (Ahsan, 2026-05-26/27) and the stale verify payload are in
  `slack-thread.md`: renamed channels `AAAA1channel`/`AAA2channel` still come
  back under their pre-rename names from `seed-phrases/connect/verify`, while
  `/-wallet/v1/channels` (username/password) returns the new names.
- The pasted payload shape (`{ id, type, name, channelId, userId, accountIndex
  }`) matches `mapWalletToResponse` output exactly, confirming the names in the
  response are the stored WDK wallet names, not live Rumble channel names.
- Screenshot in `image-analysis.md`: same tip jar shows `13ChannellRenamed` in
  one view and the stale `13Channell` in the seed-phrase balance list.
- Device / build: Pixel 7 (Android 16), app v2.2.0 (686).

## Recommendation / next step

Preferred fix: write-time sync (keep the WDK stored name current on rename).

- When a channel is renamed on Rumble web, propagate the new name into the WDK
  wallet store by calling the existing `PUT /api/v1/wallets/:id` with
  `{ name }` (`wdk-app-node/workers/lib/server.js:559-600`), which already
  routes to `updateWallet` and sets `toUpdateWallet.name`
  (`wdk-data-shard-wrk/workers/proc.shard.data.wrk.js:412-413`). No new WDK
  endpoint is required; the change is on the rename owner (Rumble web), so it is
  out of this workspace.
- Add a one-time backfill to repair rows that are already stale, since
  write-time sync only fixes renames from the deploy forward.
- This fixes every consumer of the stored name at once (seed-phrase verify,
  channel/user tip-jar lookups, etc.) and needs no per-read Rumble call.

Why not read-time merge in verify (Alex's option 2): it is not implementable in
seed-phrase mode as the system stands. The only channel-name primitive in
rumble-app-node (`/-wallet/v1/channels` via `makeRumbleRequest`) needs the
user's Rumble bearer token, and seed-phrase verify has none. It could only work
if Rumble web added a service-auth or userId-keyed channel-name lookup that
rumble-app-node could call with client credentials; that endpoint does not exist
in this workspace and may not exist at all. If the team prefers read-time merge,
that new Rumble-web lookup is a prerequisite.

## Decision / owner needed (from Alex / team)

1. Pick the approach: write-time sync (recommended) vs read-time merge. Alex's
   Slack question to Francesco C. / Eddy WM on exactly this is still unanswered.
2. Write-time sync work lands on the Rumble web server (`rumble-wallet-backend`,
   not in this workspace): call `PUT /api/v1/wallets/:id` on rename. Confirm who
   owns that and whether Rumble web has the user context to do it.
3. Backfill: confirm we can run a one-time job to update existing stale wallet
   names (source of truth = Rumble channel names) and who runs it.
4. If read-time merge is chosen instead, Rumble web must first expose a
   service-auth / userId channel-name lookup; flag that as a dependency.

## Security note (carried from `slack-thread.md`)

A test-account username/password and a 12-word recovery seed phrase were posted
in plaintext in the Slack thread. They were redacted from `slack-thread.md`.
They should be scrubbed from Slack and that test account rotated.
