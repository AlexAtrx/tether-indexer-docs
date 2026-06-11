# Next steps for RW-1906 — ERR_USER_DATA_SHARD_NOT_FOUND on new-user creation

**Ticket:** https://app.asana.com/1/45238840754660/project/1212521145936484/task/1215625579507658

## What we know
- New user `stg012` on staging build 2.4.0 (586), Pixel 10 / Android 16: onboarding
  hangs forever on "Setting up your wallet".
- FE log shows `GET /api/v1/wallets` → 404 `[HRPC_ERR]=ERR_USER_DATA_SHARD_NOT_FOUND`
  at 14:10:12, FE reconnects and the retry succeeds with `{"wallets":[]}`; FE then
  decides to auto-create a wallet but no creation request is ever logged and the UI
  waits forever.
- The error is thrown by `wdk-ork-wrk/workers/lib/data.shard.util.js` →
  `resolveUserShardRpc` (~L211) when `lookupStorage.getLookup(USERS, userId)` returns
  nothing.
- **Recurrence:** same family of failure as the May 2026 incident in
  `_tasks/34-issue-ERR_DATA_SHARD_NOT_FOUND/` (error `ERR_DATA_SHARD_NOT_FOUND`, same
  util file). Root cause then: Mongo `tw_ork.wdk_ork_lookups` /
  `wdk_ork_wallet_id_lookups` held a stale shard-process UUID vs the live process
  (suspected failed-deployment corruption). The fix applied in May is not recorded in
  that folder.

## Evidence captured here
- 1 image analysed in `image-analysis.md` (plus a log walk-through in the same file)
- 1 non-image attachment under `attachments/` (`rumble-wallet-2026-06-11.log`, FE log)
- 0 user comments in `comments.md`

## Staging logs pulled (11 Jun 2026) — see `staging-logs.md`
The failing request hit walletstg2 ork-w-1-1 at 11:10:10 UTC. Root-cause picture
changed: this is a **new-user race**, not the May UUID corruption. `lookupDataShard`
(assigns the shard via `setOrIgnoreLookup`, took 1087ms) and `getUserWallets`
(read-only `resolveUserShardRpc`, 50ms) arrived in the same millisecond for user
285052174 (stg012); the read lost the race and 404'd. The retry succeeded 3s later.
Same sporadic pattern appears in rotated ork logs on 23 May / 26 May / 6 Jun / 10 Jun.
The backend self-healed; the user-visible hang is the FE never issuing the
wallet-creation request after "No backend wallets - new user, automatically creating
wallet".

## What's missing (from `missing-context.md`)
- What remediation was applied after the May incident (still useful for folder 34
  closure, but no longer blocking this ticket — different root cause)

## Before starting work
Two candidate fixes to weigh: (a) backend — make the getUserWallets path tolerate a
concurrent first-login shard assignment (e.g. retry/await the in-flight
`setOrIgnoreLookup`, or have `resolveUserShardRpc` fall back to `resolveUserShard`
on the connect-authenticated path), and (b) FE — the onboarding state machine gets
stuck after the transient 404 even though the retry succeeded; that part is an FE
bug regardless of the backend fix. Check with FE whether they want a ticket split.
