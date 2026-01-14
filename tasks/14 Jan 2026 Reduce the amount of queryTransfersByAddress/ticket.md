## Title

Rumble: Reduce the amount of queryTransfersByAddress in the job config

## Description

queryTransfersByAddress event happening in production ~2000 times a second!!!

We're hammering the DB and we need to reduce this configuration

JOB: syncWalletTransfersJob - firing ~120 times a second

syncWalletTransfersJob
https://github.com/tetherto/wdk-data-shard-wrk/blob/204fd2ce2daeb11bc89d3b7672b143b1ef013efd/workers/proc.shard.data.wrk.js#L611

log2026-01-09T18:32:44: {"level":30,"time":1767983564813,"pid":127839,"hostname":"walletprd2","name":"wrk:http:wrk-data-shard-proc:127839","traceId":"shard-0cf1ac1f-cbed-49d0-9dbb-2003623bcb73","msg":"started syncing wallet transfers for wallets 5ed0da82-1d8d-483a-9971-dc4708a50d27, 5f567f5c-5120-490d-b336-3a6d339472b5, 5f5bd214-3c33-4abe-9fcb-a0882261bdc6, 5f74ddcf-a92b-4c89-ab87-2cb2cb14dd69, 601136f9-f0c0-4087-833c-71581038fd4c, 2026-01-09T18:32:44.813Z"}

\_walletTransferBatch
https://github.com/tetherto/wdk-data-shard-wrk/blob/204fd2ce2daeb11bc89d3b7672b143b1ef013efd/workers/proc.shard.data.wrk.js#L673
(
Important to see the code this link is pointing to. The same log exists here locally.
The line goes to:
``          this.logger.info(`started syncing wallet transfers for wallets ${ids}, ${new Date().toISOString()}`)
   ``
but check the full file.
)

Francecso in the ticket commented:
"Vigan reminded us that a quick fix would be to reduce syncTransfersExec timer in the config and restart the service"
