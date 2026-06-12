# Next steps for WDK-1515 (ERR_WALLET_TRANSFER_RPC_FAIL on prod shards)

**Ticket:** https://app.asana.com/1/45238840754660/project/1210540875949204/task/1215216504545662

## What we know
- Rumble prod data-shard workers started logging `ERR_WALLET_TRANSFER_RPC_FAIL` with `err.message="RPC client closed"` from `@hyperswarm/rpc/index.js:257` (`Client.request`).
- Sample failure: chain `polygon`, ccy `usdt`, host `walletprd3`, shard worker `wrk-data-shard-proc-w-2-2-...`, traceId `shard-f273431d-...`.
- Mitigation in place: full restart of every PM2 process whose name starts with `shard-` (`pm2 jlist | jq ... | xargs pm2 restart`).
- Priority: High, Sprint 3. Assigned by Francesco Canessa.
- The investigation is open: root cause, durable fix, and alerting are all asks.

## Evidence captured here
- 0 images analysed
- 0 non-image attachments
- 0 user comments (3 system events captured in `comments.md`)

## What's missing (from `missing-context.md`)
- Slack thread C0A5DFYRNBB/p1779986078317469 — original timeline + screenshots + log export.
- Grafana/Loki dump over the incident window — the URL is shared but not exported.
- Confirmation of which prod boxes/shards were affected and exact restart timing.
- Incident timeline correlating with any upstream event (deploy, peer crash, network flap).
- Identity of the peer the shard worker was calling when the RPC closed (likely the chain indexer, but the log doesn't name it).

## Before starting work
If picking this up, ask Alex for the Slack thread export and a copy of the Grafana
query results before reading code. Then likely entry points in the indexer
workspace:

- `rumble-data-shard-wrk` — the failing process; check how it instantiates the
  `@hyperswarm/rpc` Client and whether there's any reconnect/retry around
  `Client.request` (the stack trace points straight at line 257 of the vendored
  index.js, which is the call site, not the cause).
- `wdk-indexer-wrk-polygon` — the most likely peer based on the request path
  in `architecture.md`. Check its Proc availability / restart history around the
  incident window.
- Hyperswarm shared config (`topicConf.capability` / `topicConf.crypto.key`) —
  if the peer rotated keys without the shard, you'd see "RPC client closed"
  silently. Ruling this out should be quick.
- Consider: should the shard treat a closed RPC client as recoverable (open a
  new client and retry the request once) instead of bubbling the error up to
  the transfer? That, plus a Loki-level alert on `errorCode=ERR_WALLET_TRANSFER_RPC_FAIL`
  rate, is probably the durable fix Francesco is asking for.
