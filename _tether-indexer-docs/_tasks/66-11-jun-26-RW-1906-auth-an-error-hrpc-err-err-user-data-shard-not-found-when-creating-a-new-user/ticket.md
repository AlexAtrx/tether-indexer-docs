# [Auth] An error [HRPC_ERR]=ERR_USER_DATA_SHARD_NOT_FOUND when creating a new user

- **URL:** https://app.asana.com/1/45238840754660/project/1212521145936484/task/1215625579507658
- **GID:** 1215625579507658
- **Project:** Rumble Wallet
- **Section:** To Triage
- **Assignee:** Alex Atrash (inbox)
- **Status:** open
- **Created:** 2026-06-11T11:12:21.522Z
- **Modified:** 2026-06-11T11:30:42.843Z
- **Due:** —
- **Tags:** —
- **Custom fields:** Priority: Critical (Bugs only), Sprint: Sprint 4, Rumble Area: Authentication, Stack: BE - Backend, Task Type: Bug, RW: RW-1906, Support Type: Bug

## Related (recurrence)

This is a recurrence of the staging shard-lookup failure investigated in May 2026:
`_tasks/34-issue-ERR_DATA_SHARD_NOT_FOUND/` (Slack thread #wallet-rumble-dev, 13–21 May 2026).

- Old error code: `ERR_DATA_SHARD_NOT_FOUND` (existing users, login). New code:
  `ERR_USER_DATA_SHARD_NOT_FOUND` (new user, `GET /api/v1/wallets`). Both are thrown
  from the same file: `wdk-ork-wrk/workers/lib/data.shard.util.js` — the new one from
  `resolveUserShardRpc` (line ~211) when the USERS lookup has no shard id for the user.
- May root cause: UUID mismatch in Mongo `tw_ork.wdk_ork_lookups` /
  `tw_ork.wdk_ork_wallet_id_lookups` — stored shard process UUID did not match the live
  process UUID (suspected corruption during a failed staging deployment).
