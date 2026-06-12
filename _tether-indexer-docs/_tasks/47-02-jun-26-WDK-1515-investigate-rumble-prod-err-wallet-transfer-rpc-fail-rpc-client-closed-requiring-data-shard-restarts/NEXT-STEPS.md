# Next steps for WDK-1515 — rumble prod ERR_WALLET_TRANSFER_RPC_FAIL

**Ticket:** https://app.asana.com/1/45238840754660/project/1210540875949204/task/1215216504545662

## Status: analyzed, leading hypothesis (see `root-cause.md`)

Investigation done from the fresh 5-min log export + screenshot + code. The shutdown-
ordering hypothesis is refuted; the team's "persistent issue" reading is correct.

**Proven:** the data-shard transfer path (`blockchain.svc.js`
`getGroupedTransfersForWalletsBatch` -> `_rpcCall` -> `net_r0.jTopicRequest`) has no
retry/failover/reconnect on `RPC client closed`. The app-node already mitigated the
same transport error in `ork.js` (`rpcCallWithRetryAndFailover`) by rotating ork
peer-keys.

**Leading hypothesis (not fully proven):** a closed `@hyperswarm/rpc` pooled client is
reused and the `'close'`-event eviction/reconnect path does not recover in prod, so a
dead peer connection breaks a worker until restart and recurs on the next teardown.
Needs a focused repro to confirm why eviction fails to recover.

## Recommended fix (detail in root-cause.md)
1. Pool-level reconnect in `hp-svc-facs-net.jRequest` (evict closed client for the
   key, reconnect, retry once) — fixes shard + app-node + ork at once. Best.
2. Shard-level retry mirroring `ork.js` (only durable combined with #1, since
   shard->indexer topics may have a single peer so failover isn't always possible).
3. Loki alert on `ERR_WALLET_TRANSFER_RPC_FAIL` / `ERR_RPC_CALL_FAILED` rate per
   host/worker — independent, do regardless.

## Before writing the patch
- Get the prod branch/rev of `wdk-data-shard-wrk` (prod logs differ in shape from
  local `dev` — `txFetch:batch:partial` vs `txFetchGrouped:batch:partial`). Patch
  must target what's deployed.
- Confirm peer count per `{chain}:{ccy}` indexer topic to decide failover vs
  reconnect-same-peer.
- Optional repro to confirm whether `@hyperswarm/rpc` v3.4.0 fails to evict on the
  prod teardown path -> decides whether the fix belongs in `hp-svc-facs-net` or
  upstream `@hyperswarm/rpc`.

## Still missing (nice-to-have, not blocking)
- The Slack root-cause message Alex posted (`p1779991695497499`) — would confirm/extend
  this analysis.
- Grafana/Loki access for ad-hoc queries.

## Housekeeping
- Duplicate task folder `41-28-may-26-WDK-1515-...` exists (earlier fetch, no
  analysis). This folder (47) supersedes it; 41 can be archived.
