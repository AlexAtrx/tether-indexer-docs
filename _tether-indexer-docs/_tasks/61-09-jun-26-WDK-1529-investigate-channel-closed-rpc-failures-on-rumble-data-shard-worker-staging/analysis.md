# WDK-1529 analysis

## Summary

The `CHANNEL_CLOSED` errors in `rumble-data-shard-wrk` are a symptom, not the
root crash. The downstream Tron indexer workers on staging are restart-looping,
so data-shard transfer sync RPC calls lose their HRPC channel mid-request.

Root cause found on staging:

- `wdk-indexer-wrk-tron/workers/lib/chain.tron.client.js:35` unconditionally
  calls `ctx.conf.wrk.paymasters.forEach(...)`.
- Staging `wdk-indexer-wrk-tron/config/tron.json` and
  `config/usdt-tron.json` contain `gasFreeConfig` but do not contain
  `paymasters`.
- Every Tron API/proc startup then crashes with:
  `TypeError: Cannot read properties of undefined (reading 'forEach')`.
- PM2 immediately restarts those workers. Data-shard sees the peer disappear
  and logs `ERR_WALLET_TRANSFER_RPC_FAIL` with `CHANNEL_CLOSED` or
  `RPC client closed`.

## Evidence

- `walletstg1` `shard-proc-w-0-1` is stable since `2026-06-08T15:51:07Z`.
  The failing peer is downstream, not the shard process itself.
- `idx-usdt-tron-*` workers are restart-looping:
  - `walletstg1`: `idx-usdt-tron-api-w-0-0` had 11k+ restarts,
    `idx-usdt-tron-api-w-0-1` had 12k+ restarts.
  - `walletstg2`: same crash loop on both Tron API workers.
  - `walletstg3`: same crash loop on both Tron API workers and
    `idx-usdt-tron-proc-w-0`.
- Recent Tron logs repeatedly show:
  - `TypeError: Cannot read properties of undefined (reading 'forEach')`
  - `at new ChainTronClient (.../wdk-indexer-wrk-tron/workers/lib/chain.tron.client.js:35:29)`
- Config shape check on `walletstg2` and `walletstg3`:
  - `config/tron.json`: `hasGasFreeConfig=true`, `hasPaymasters=false`
  - `config/usdt-tron.json`: `hasGasFreeConfig=true`, `hasPaymasters=false`
- Local checked-in examples now include `paymasters`:
  - `wdk-indexer-wrk-tron/config/tron.json.example`
  - `wdk-indexer-wrk-tron/config/usdt-tron.json.example`
- The shard now calls grouped transfer RPC from
  `wdk-data-shard-wrk/workers/lib/blockchain.svc.js:481`
  (`queryGroupedTransfersByAddress`), so transfer sync exercises Tron indexer
  API frequently and exposes the restart loop as channel failures.

## Why this appeared after deploy

The staging deploy restarted the indexer and shard stack around
`2026-06-08T15:23Z` to `2026-06-08T15:53Z`. Restarting Tron loaded code that
requires `wrk.paymasters`, but the live staging config was not updated with the
new field. The newly deployed data-shard sync path then made frequent transfer
RPC calls, causing the shard logs/Grafana query to surface `CHANNEL_CLOSED`.

## Secondary issue seen in logs

The shard logs also show many non-Tron failures:

- `ERR_TOPIC_LOOKUP_EMPTY` for `ton:usdt` and `ton:xaut`.
- The deployed `wdk-indexer-wrk-ton` base package on `walletstg1` does not
  expose `queryGroupedTransfersByAddress`, while the shard now calls that
  method for grouped transfer sync.

That is a separate compatibility/deployment issue to handle after the Tron
crash loop, because the ticket's `CHANNEL_CLOSED` trace is explained by the
Tron workers dying.

## Recommended fix

1. Immediate staging remediation, with operator confirmation:
   add `paymasters` to `wdk-indexer-wrk-tron/config/tron.json` and
   `config/usdt-tron.json` on all staging hosts, matching the checked-in
   examples (`[gasFreeConfig.serviceProvider]`), then restart the Tron
   API/proc workers.
2. Code hardening:
   change `ChainTronClient` to treat missing `paymasters` as an empty array or
   validate config with an explicit startup error. Prefer defaulting to `[]`
   if the field is optional.
3. Deployment follow-up:
   align TON with the grouped transfer RPC contract or prevent data-shard from
   calling `queryGroupedTransfersByAddress` for chains whose deployed indexer
   API does not support it.
