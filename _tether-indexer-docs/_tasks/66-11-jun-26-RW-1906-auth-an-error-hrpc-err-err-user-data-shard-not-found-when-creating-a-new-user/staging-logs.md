# Staging-side logs — RW-1906 (pulled 11 Jun 2026, ~11:46 UTC)

Searched all three boxes (walletstg1/2/3 via fcanessa PM2 logs under
`/srv/data/pm2/logs/`). The failing request landed on **walletstg2**,
ork API process `wrk-ork-api-w-1-1-e4f1cec9-4a34-450b-acd1-e0a2e2d58cfd`
(pm2 name `ork-w-1-1`). Server time is UTC; the FE log in the ticket is
UTC+3 (FE 14:10:12 = server 11:10:10).

## The failing trace (walletstg2, live ork-w-1-1 log)

```
2026-06-11T11:10:10: {"time":1781176210300,"hostname":"walletstg2","name":"wrk-ork-api-w-1-1-e4f1cec9-...","traceId":"mob:285052174:37891350-0d02-4136-9929-a0d1a860021b","action":"lookupDataShard","msg":"RPC action request"}
2026-06-11T11:10:10: {"time":1781176210300,"hostname":"walletstg2","name":"wrk-ork-api-w-1-1-e4f1cec9-...","traceId":"mob:285052174:205da86e-54e5-45b7-9d6b-b5db35c74a1b","action":"getUserWallets","msg":"RPC action request"}
2026-06-11T11:10:10: {"time":1781176210350,"hostname":"walletstg2","name":"wrk-ork-api-w-1-1-e4f1cec9-...","traceId":"mob:285052174:205da86e-...","action":"getUserWallets","elapsed":"49.78","rpcError":"\"[HRPC_ERR]=ERR_USER_DATA_SHARD_NOT_FOUND\"","msg":"RPC action response: error returned"}
2026-06-11T11:10:11: {"time":1781176211387,"hostname":"walletstg2","name":"wrk-ork-api-w-1-1-e4f1cec9-...","traceId":"mob:285052174:37891350-...","action":"lookupDataShard","elapsed":"1087.40","msg":"RPC action response: completed"}
```

Rumble user id: **285052174** (stg012). No hits for this user in shard-proc /
shard-api logs on stg2, and no occurrences of the error today on stg1 or in
app-node logs anywhere.

## Reading: new-user race, NOT the May UUID corruption

Both RPC actions hit the ork at the same millisecond (11:10:10.300):

- `lookupDataShard` → `DataShardUtil.resolveUserShard()` →
  `lookupStorage.setOrIgnoreLookup(USERS, userId, ...)` — this is the call that
  ASSIGNS a shard (round-robin) and creates the USERS lookup row for a brand-new
  user. It completed after **1087ms** (slow because it resolves the shard topic
  RPC key before saving).
- `getUserWallets` → `_rpcRequest` with no shardId →
  `DataShardUtil.resolveUserShardRpc()` — **read-only** `getLookup(USERS, userId)`,
  throws `ERR_USER_DATA_SHARD_NOT_FOUND` when the row is absent
  (`wdk-ork-wrk/workers/lib/data.shard.util.js:211`). It resolved after **50ms**,
  i.e. ~1s before the concurrent `lookupDataShard` committed the row → 404 to FE.

The FE then reconnected and retried; by 11:10:13-16 the lookup row existed and
`GET /api/v1/wallets` returned 200 `{"wallets":[]}` (visible in the ticket's FE
log). So the backend self-healed; the user-visible hang is the FE never issuing
the wallet-creation request after deciding "No backend wallets - new user,
automatically creating wallet".

## Prior occurrences (same pattern, sporadic)

`grep ERR_USER_DATA_SHARD_NOT_FOUND` across rotated ork logs on stg1 shows
sporadic single hits on 23 May, 26 May, 6 Jun, 10 Jun (e.g. 2026-06-10T14:30:45,
`wrk-ork-api-w-0-0`, action `getUserWallets`, user mob:285019192, 4.34ms — same
read-lost-the-race shape). stg2 has matches on 23 May / 6 Jun / 10 Jun rotated
logs too. This looks like a long-standing low-frequency new-user race, distinct
from the May `ERR_DATA_SHARD_NOT_FOUND` incident in
`_tasks/34-issue-ERR_DATA_SHARD_NOT_FOUND/` (that one was a Mongo UUID mismatch
affecting EXISTING users persistently; this one is transient and only on first
login).

## Method (for reproducibility)

- `ssh walletstgN 'sudo -iu fcanessa bash -s' <<'REMOTE' ... REMOTE` heredoc,
  grep over `/srv/data/pm2/logs/ork-w-*-out.log` (live) and
  `ork-w-*-out__2026-06-11_00-00-00.log` (rotated = Jun 10 content).
- Nothing was written to the servers.
