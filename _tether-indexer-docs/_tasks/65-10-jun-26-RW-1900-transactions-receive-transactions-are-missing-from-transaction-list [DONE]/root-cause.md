# Root cause — RW-1900 Receive transactions missing from transaction list

## Conclusion

This is a backend/staging incident, not an FE bug. The June 8 staging deploy
(15:22–15:50 UTC) switched the wallet backend to the new grouped-transactions
ingestion pipeline, and the consumer half of that pipeline never came up.
Receive transfers stopped being written into the shard stores; Sent entries
still appear because the send flow writes its own row synchronously at
broadcast time (`storeWalletTransfer`). The list endpoint reads only the local
shard store, so users see Sent-only history on every network.

It did not literally break "today": ingestion died with the June 8 deploy and
residual partial flow (two still-working processors plus the first wallets of
each timing-out poll run) kept some receives trickling in through June 9.
By June 10 the trickle no longer reached test wallets, which is when QA
noticed and filed it as a fresh regression.

## What is happening (stage by stage)

The transactions list is served by
`wdk-data-shard-wrk/workers/api.shard.data.wrk.js:313` (`getUserTransfers`),
which reads `walletTransferRepository` (Mongo
`wdk_data_shard_wallet_transfers_v2`) and derives sent/received by comparing
`tx.from` to the wallet's addresses (`:381`). Receive rows can only get into
that store via ingestion. Both ingestion paths are down:

### Stage 1 — indexer procs publish grouped transactions (mostly OK)

`@wdk/grouped-transactions:{chain}:{token}` streams are being produced:
bitcoin:btc len=125,144 (last entry 4 min old), ethereum:usdt len=52,259,
plasma:usdt len=11,446, spark:btc len=7,841. Producers are fine for
btc/evm/spark. Exceptions:

- **tron**: `idx-usdt-tron-proc-w-0` on walletstg3 is crash-looping (60,102
  restarts) with `TypeError: Cannot read properties of undefined (reading
  'forEach')` at `wdk-indexer-wrk-tron/workers/lib/chain.tron.client.js:35`
  (`ctx.conf.wrk.paymasters` missing from the deployed config). All six tron
  API workers across the cluster crash-loop the same way (36k–43k restarts).
  This predates the deploy: tron has been crash-looping since ~June 3 (tron
  repo last deployed June 3, "Promote dev to main (#127)" 69fd3d4). Same
  failure shape as WDK-1529. No tron grouped stream exists at all.
- **ton**: `idx-usdt-ton-proc-w-0` indexes blocks fine but its Redis publisher
  fails with ioredis connect timeouts, so no ton grouped streams exist either.
  The ton API workers are online but undiscoverable: the shard gets
  `ERR_TOPIC_LOOKUP_EMPTY` for `ton:usdt` / `ton:xaut` (~5,000 errors per 2h
  log, continuously since the June 8 restart).

### Stage 2 — processor (router) consumes per-chain streams (BROKEN for the big chains)

`wdk-indexer-processor-wrk` workers must consume the per-chain grouped streams
and route entries to per-shard streams. The consumer groups for
**bitcoin:btc, ethereum:usdt, plasma:usdt, spark:btc, arbitrum:xaut,
ethereum:usat** were never created. The processors are stuck in two failure
loops and never recover:

- `NOGROUP No such key '@wdk/grouped-transactions:bitcoin:btc' or consumer
  group` once per second forever (processor-bitcoin-btc on walletstg1) — group
  creation happens only at startup; startup hit the Redis outage window, and
  the consume loop has no NOGROUP recovery (re-create group and continue).
- `MaxRetriesPerRequestError` (processor-ethereum-usdt on walletstg2) — the
  client is wedged on a stale Redis master address.

Only arbitrum:usdt, ethereum:xaut, polygon:usdt and polygon:xaut routers are
alive (their groups exist and last-delivered is minutes old). That residual
flow is what kept polygon/arbitrum receives appearing on June 9 (e.g. shard
w-0-2 received a polygon transfer June 9 08:12).

### Stage 3 — shard procs consume their shard stream (BROKEN on walletstg1)

`wdk-data-shard-wrk/workers/proc.shard.data.wrk.js:1449` creates the consumer
group only at startup; the xreadgroup loop at `:1122` has no NOGROUP/reconnect
recovery. The stg1 shard procs (w-0-0/w-0-1/w-0-2) booted into the Redis
outage and have logged `ERR_REDIS_STREAM_CONSUME_FAILED` +
`ECONNREFUSED 172.18.0.1:6380` continuously since June 8 13:47 UTC. Their
shard streams have no consumer group. The stg2/stg3 shard procs created their
groups and would consume, but stage 2 sends them almost nothing.

The `172.18.0.1:6380` address is the docker-bridge IP that Redis Sentinel
announced for the master during the deploy window; it is unreachable.
Sentinel currently reports the master at `100.101.155.20:6380` (reachable; a
fresh client connects fine), but the wedged worker processes never re-resolved.

### Stage 4 — polling fallback starves (BROKEN since the deploy)

The fallback `syncTransfersExec` job (proc:965,
`getGroupedTransfersForWalletsBatch` → live `queryGroupedTransfersByAddress`
per wallet) has hit `ERR_JOB_FAILED: Job timeout after 1200000ms` on **every
run since June 8**, with `ERR_JOB_ALREADY_RUNNING` piling up (~10–20 per 2h
log). The 20-minute window is consumed by:

- mega-wallets (one ethereum wallet on shard w-1-2 has 801,454 transfer rows
  and is re-synced continuously — the insert histogram shows w-1-2 inserting
  ~150–300 rows/h around the clock while most other shards insert nothing);
- tron retries (`RPC client closed` against the crash-looping tron APIs,
  3 attempts each with backoff);
- ton retries (`ERR_TOPIC_LOOKUP_EMPTY`, 3 attempts each).

Wallets behind the mega-wallet in the iteration order never get synced, so for
most shards (w-0-0, w-0-1, w-1-0, w-1-1, w-2-2) there have been essentially
**zero transfer inserts since June 8** (verified via `_id`-timestamp histogram
on `wdk_data_shard_wallet_transfers_v2`).

### Why "Sent" still shows

Sent rows are written synchronously by the send flow (shard action
`storeWalletTransfer`, registered at `api.shard.data.wrk.js:863`) when the
user broadcasts. They never depend on ingestion. Receives do. Hence the exact
reported symptom: only Sent visible, all networks, all users.

Note: `getUserTransfersV2` / `wallet_transfers_processed` (the new processed
store, gated by `processedTransfersEnabled`, wdk-data-shard-wrk #235
`49e4444`) is empty in every shard database — the V2 store has never been
populated on staging.

## When it started (timeline, all UTC)

| Time | Event |
|---|---|
| ~Jun 3 | tron repo deployed (#127). tron proc + all tron API workers begin crash-looping on missing `conf.wrk.paymasters` (WDK-1529 shape). tron receives die. |
| Jun 8 13:47 | First `ECONNREFUSED 172.18.0.1:6380` in shard proc logs (Redis Sentinel master flap begins). |
| Jun 8 15:22–15:50 | Staging deploy: rumble-data-shard-wrk #235 (pins wdk-data-shard-wrk 54a9fb7 = dev→main #236), rumble-app-node #235, rumble-ork-wrk #160; net configs rewritten 15:49; full PM2 restart ~15:25. Old pipeline (`@wdk/transactions:*` + router consumer) stops at 15:20. New grouped pipeline starts half-broken. |
| Jun 8 15:22 onward | `syncTransfersExec` times out on every run; most shards stop inserting transfer rows entirely. ton `ERR_TOPIC_LOOKUP_EMPTY` begins. |
| Jun 8–9 | Residual receives still land via the few working routers (polygon, arbitrum:usdt, ethereum:xaut) and the head of each timing-out poll run. QA perceives "working". |
| Jun 10 | Effectively nothing fresh reaches test wallets. QA files RW-1900 12:08 UTC. Someone (`vabdurrahmani`) was investigating the tron workers ~16:18 (log ownership changed). |

## Evidence

- PM2: tron api w-0-0/w-0-1 on stg1 = 38,017/41,647 restarts, uptime seconds;
  stg3 tron proc 60,102 restarts. Everything else 0 restarts since Jun 8 15:25.
- `chain.tron.client.js:35` — `ctx.conf.wrk.paymasters.forEach` on undefined;
  deployed `usdt-tron.json` lacks `paymasters`.
- Redis (via sentinel `mystreams`): stream/group inventory as listed above;
  old `@wdk/transactions:*` router group last-delivered = Jun 8 15:20.
- shard-proc-w-0-0 logs: `ERR_REDIS_STREAM_CONSUME_FAILED` 76–2,140 per log
  file continuously since Jun 8 16:50; `ERR_TOPIC_LOOKUP_EMPTY` ~5k per file;
  `ERR_JOB_FAILED Job timeout after 1200000ms` on `syncTransfersExec` ~10/2h.
- Mongo insert histograms (`wdk_data_shard_wallet_transfers_v2`, `_id` hex
  timestamps): w_0_0/w_0_1/w_1_0/w_1_1/w_2_2 = zero inserts since Jun 7–8;
  w_1_2 = continuous mega-wallet churn; w_0_2 = single insert Jun 9 08h.
- `wallet_transfers_processed` empty in all 9 shard DBs.
- Deployed git: rumble-* FETCH_HEAD all Jun 8 15:22:50–53.

## Recommendation / next steps

Immediate (ops, restores receives; needs approval to touch staging):

1. Fix tron config: add the `paymasters` array (and any other missing keys vs
   `usdt-tron.json.example`) to the deployed tron configs on all three boxes,
   then restart tron proc + APIs. (Repeat of the WDK-1529 fix.)
2. Restart the stuck processors (bitcoin-btc, spark-btc, ton-usdt, ton-xaut on
   stg1; ethereum-usdt, plasma-usdt, arbitrum-xaut, ethereum-usat on stg2) and
   the three stg1 shard procs. On boot they re-resolve the Sentinel master and
   create their consumer groups (`MKSTREAM`), then drain the 125k/52k/11k
   backlogs.
3. Investigate the ton proc Redis publisher (connect timeouts) and why the ton
   API workers are not discoverable; a restart will likely clear both.
4. Fix the Sentinel announce so a failover can never publish the docker-bridge
   `172.18.0.1` address (set announce-ip to the Wireguard 100.x address on
   each redis-streams container).

Durable (code, prevents recurrence):

5. `wdk-indexer-processor-wrk` and `wdk-data-shard-wrk` stream consumers: on
   `NOGROUP`, re-create the group and continue (currently only created at
   startup, `proc.shard.data.wrk.js:1449`); recreate/reconnect the duplicated
   consumer connection on persistent `MaxRetriesPerRequestError`.
6. `syncTransfersExec`: per-wallet/per-chain time budget so one mega-wallet or
   one dead chain cannot starve the rest of the queue; skip-and-continue on
   per-chain failure (tron/ton being down must not block btc/eth receives).
7. Boot-time validation for required config (tron `paymasters`) so a missing
   key fails loud at deploy time instead of crash-looping for a week.

Ownership: backend/infra. Nothing for FE here; the app renders what the API
returns, and the API returns what ingestion stored.

---

## Recovery log (2026-06-10 18:50-19:10 UTC)

What was done:

1. **Tron config fix (me, approved by Alex):** added the missing
   `"paymasters": ["TLntW9Z59LYY5KEi9cmwk3PKjQga828ird"]` (value from the
   maintainer-shipped `usdt-tron.json.example`, PR #122) to
   `/srv/data/staging/wdk-indexer-wrk-tron/config/usdt-tron.json` on all three
   boxes at ~18:56-18:58 UTC. All tron workers (proc on stg3, APIs everywhere)
   went from 5-second crash-loops to stable. NOTE: the newly deployed tron code
   (#130) still dereferences `conf.wrk.paymasters` unguarded
   (`chain.tron.client.js:35`), so this key is REQUIRED and must be folded into
   whatever config management the deploy uses. Removing it re-breaks tron.
2. **Team redeploy (tech lead, ~18:47-18:52 UTC):** rumble-data-shard-wrk #241,
   rumble-app-node #240, rumble-ork-wrk #165 ("both RPC fixes"), full PM2
   restart. This restart recreated the missing consumer groups.

Verified after recovery:

- Consumer groups now exist on the previously dead streams and are draining:
  bitcoin:btc 125,144 -> 104,255; plasma:usdt 11,446 -> 5,861; spark:btc fully
  drained (len 0, lag 0). ethereum:usdt group attached, draining slowly
  (lag ~53k) - watch it.
- ton `ERR_TOPIC_LOOKUP_EMPTY`: zero occurrences post-restart (was ~5k/2h).
- tron `ERR_WALLET_TRANSFER_RPC_FAIL`: last occurrence 18:59:55, none since.
- shard-proc stream consume errors: zero in post-restart logs.
- No files or scripts left on any staging host; /tmp clean on all three. The
  only persistent change is the tron `paymasters` config key (required, above).

Still open:

- **Sentinel announce is still broken and actively flapping**: at 19:05 UTC a
  fresh sentinel-routed client from stg1 was handed `172.18.0.1:6380`
  (docker-bridge, unreachable) and could not connect in 3 attempts, while
  long-lived consumer connections kept working. Next failover or process
  restart can re-wedge the pipeline. Fix: set announce-ip on the redis-streams
  containers to the Wireguard 100.x address of each box. Cluster-wide change,
  needs its own window and infra-owner sign-off.
- `wallet_transfers_processed` (V2 store) is still empty everywhere; mass
  inserts into `wallet_transfers_v2` have not resumed yet (backlog messages
  for non-wallet addresses are dropped legitimately; a real QA send/receive
  test is the definitive end-to-end check).
- Durable code fixes still recommended: NOGROUP recovery in the processor and
  shard consume loops, per-wallet budget in `syncTransfersExec`, boot-time
  config validation for tron.

---

## Sentinel-fix verification (2026-06-11 09:45-10:00 UTC)

DevOps (ndemchenko) reported the sentinel troubleshot "around 10:45pm" Jun 10.
Verified on all three boxes: **the claim is true and the fix is exactly the
announce-ip change recommended above.**

What was changed (per file mtimes and kept backups):

- Jun 10 20:23 UTC, `/srv/redis-ha/redis-streams/redis.conf` on all 3 boxes:
  added `replica-announce-ip <box 100.x address>` + `replica-announce-port
  6380` (`.bak-20260610-2023` kept; diff shows only these two lines added).
- Jun 10 20:28 UTC, `/srv/redis-ha/sentinel/sentinel.conf` rewritten clean on
  all 3 boxes (`.broken-20260610-2028` kept): `sentinel announce-ip` set per
  box, monitors re-pointed at `100.101.155.20`, epochs reset,
  `down-after-milliseconds` raised 5000 -> 15000. The broken backup still
  contains the smoking gun `known-replica mystreams 172.18.0.1 6380`; the
  current config has no `172.18.0.1` anywhere.
- redis-streams + sentinel containers restarted ~20:45 UTC; all PM2 workers
  restarted after that (13-14h uptime at check time, 1-3 restarts).

Health verified after the fix:

- Sentinel announces master `100.101.155.20:6380` (stg2); a fresh authed
  client from stg1 connects fine (the pre-fix repro from 19:05 Jun 10 was a
  fresh client being handed `172.18.0.1:6380`). Replication: 2 slaves online
  via 100.x addresses, lag 1.
- All `@wdk/grouped-transactions:*` streams fully drained: len 0, lag 0,
  router groups attached - including ethereum:usdt (was lag ~53k) and both
  ton streams (now exist and consumed). tron:usdt routers consuming (6
  consumers; small in-flight pending).
- Zero NOAUTH/NOGROUP/ECONNREFUSED/consume errors in shard-proc and
  processor logs since the fix on stg1; tron proc + APIs stable 14h.
- Mongo (`rws0` replicaset, dbs `wdk_shard_wrk_data_shard_proc_w_*`):
  transfer inserts resumed on 7 of 9 shards since 20:45 Jun 10, and the
  previously-empty `wallet_transfers_processed` (V2) store is now populating
  (w_1_2 +2,843, w_2_2 +2,136). w_0_1 and w_2_1 show zero new rows - likely
  just no overnight traffic on those shards; QA send/receive remains the
  definitive end-to-end check.

Still open (NOT sentinel-related):

- `syncTransfersExec` still hits `ERR_JOB_FAILED: Job timeout after
  1200000ms` on stg2 shard procs (seen 00:20 and 06:20 Jun 11) - the
  mega-wallet starvation; per-wallet budget fix still needed.
- Durable NOGROUP recovery + boot-time config validation still recommended.

Note: port 6380 requires AUTH (requirepass was already present pre-fix, not
added by this change); use the password from the deployed redis.conf when
querying streams manually.
