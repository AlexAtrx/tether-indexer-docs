# Root Cause

## Conclusion

The captured `ERR_WALLET_TRANSFER_RPC_FAIL` spike is deploy/restart fallout from
in-flight `syncWalletTransfers` jobs, not evidence that the chain-indexer
Hyperswarm peers independently died.

Francesco initiated the shard restart as part of production deploy activity.
During that PM2 restart, old data-shard proc workers kept executing wallet
transfer batches while their process resources were already being torn down:

- Mongo-backed shard DB context was closed, so checkpoint reads failed with
  `MongoNotConnectedError: Client must be connected before running operations`.
- Hyperswarm RPC clients were destroyed during net facility shutdown, so in-flight
  chain RPC calls failed with `RPC client closed`.

The scary log message is misleading for the Mongo case: `ERR_WALLET_TRANSFER_RPC_FAIL`
wraps any per-address transfer-fetch failure inside `txFetch`, including the local
checkpoint read that happens before the actual chain-indexer RPC call.

## Evidence

Exported log file:
`_tether-indexer-docs/_tasks/40-minor-incident-prod/Explore-logs-2026-05-28 18_36_10.txt`

Parsed export summary:

- 1000 JSON log rows parsed.
- 878 rows are `ERR_WALLET_TRANSFER_RPC_FAIL`.
- All 878 parsed transfer-fail rows have:
  - `err.type = MongoNotConnectedError`
  - `err.message = Client must be connected before running operations`
- 21 rows are `txFetch:batch:partial`.
- 101 rows are `ERR_JOB_ALREADY_RUNNING`.

The failures are concentrated on old `walletprd1` PIDs, then those same named
workers appear under new PIDs shortly afterwards:

```text
wrk-data-shard-proc-w-0-1...
  old pid 977103: 16:29:32.267Z -> 16:29:32.315Z ERR_WALLET_TRANSFER_RPC_FAIL / txFetch:batch:partial
  new pid 994744: 16:29:45.001Z -> 16:31:00.002Z ERR_JOB_ALREADY_RUNNING

wrk-data-shard-proc-w-0-2...
  old pid 977182: 16:29:44.380Z -> 16:29:44.424Z ERR_WALLET_TRANSFER_RPC_FAIL / txFetch:batch:partial
  new pid 994821: 16:30:10.001Z -> 16:31:00.001Z ERR_JOB_ALREADY_RUNNING
```

The Slack sample has the same shape for `walletprd3`:

```text
old pid 902267, worker wrk-data-shard-proc-w-2-2..., 16:29:35Z:
ERR_WALLET_TRANSFER_RPC_FAIL, err.message = RPC client closed

exported post-restart pid for the same worker name:
new pid 917535, 16:30:10Z onward
```

So the sample `RPC client closed` row is also from a worker that was replaced
during the restart window.

## Code Path

Production `rumble-data-shard-wrk` depends on `wdk-data-shard-wrk` commit
`f130150d1b383b6565e44391c60efd17ce31497b`.

In that version, `txFetch` reads the per-address checkpoint before it calls the
chain indexer:

```js
const addrTs = await this.ctx.db.addressCheckpointRepository.getTs(chain, ccy, address)
...
const res = await this._rpcCall(chain, ccy, 'queryTransfersByAddress', ...)
```

Any rejection in that block is logged as `ERR_WALLET_TRANSFER_RPC_FAIL`, even if
the rejection came from the local Mongo checkpoint read rather than `_rpcCall`.

The Mongo checkpoint read is:

```js
return this.collection.findOne({ chain, ccy, address }, ...)
```

The shard proc stop path closes the DB while nothing waits for any active
`syncWalletTransfers` job to quiesce first:

```js
_stop (cb) {
  async.series([
    async () => {
      this._consuming = false
      if (this._consumerConnection) {
        this._consumerConnection.disconnect()
      }
      await this.db.close()
    },
    next => { super._stop(next) }
  ], cb)
}
```

`this.db.close()` closes the Mongo client. With MongoDB driver 6.x, subsequent
operations against a previously closed client throw:

```text
MongoNotConnectedError: Client must be connected before running operations
```

The net facility stop then destroys the RPC client:

```js
if (this.rpc) {
  await this.rpc.destroy()
}
```

`@hyperswarm/rpc` throws `RPC client closed` when a request is made after that
client is closed.

## Final RCA

The immediate trigger was production deploy/restart activity. The software bug is
that shard proc shutdown is not job-aware: it closes Mongo and destroys network
RPC clients before active scheduled jobs have stopped using them.

The attached `ERR_WALLET_TRANSFER_RPC_FAIL` rows are therefore not a
Hyperswarm/network root cause. The bulk of captured failures are local
Mongo-client-closed errors from old processes during PM2 replacement, and the
provided `RPC client closed` sample is consistent with the same restart teardown.

## Durable Fix

1. Make shard shutdown job-aware:
   - stop schedulers first;
   - abort active jobs;
   - wait for `syncWalletTransfersExec`/other job flags to clear or hit a short
     drain timeout;
   - only then close DB and net facilities.

2. Make `ERR_WALLET_TRANSFER_RPC_FAIL` more precise:
   - log checkpoint-read failures separately from chain-indexer RPC failures;
   - include `phase: checkpoint_read | rpc_request` in the structured log.

3. Lower alert noise:
   - do not alert on `ERR_WALLET_TRANSFER_RPC_FAIL` during expected PM2 shutdown
     if the worker is stopping;
   - alert on sustained post-start failures from stable PIDs.

4. For future prod deploys, either drain/disable `syncWalletTransfers` before
   restarting shard procs or ship the shutdown fix first.
