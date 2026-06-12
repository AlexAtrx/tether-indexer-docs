# WDK-1515 — analysis: ERR_WALLET_TRANSFER_RPC_FAIL ("RPC client closed")

## Summary

> The recurrence points to a Hyperswarm RPC connection lifecycle/resilience issue.
> Data-shard transfer polling has no effective reconnect/retry path when RPC client
> closed / CHANNEL_CLOSED happens, so transfer batches can keep failing until the
> client is evicted, the connection recovers, or the process is restarted. The durable
> fix should be in the shared net facility: detect these closed-channel errors,
> explicitly drop the cached client for that peer, refresh topic lookup where
> applicable, reconnect, and retry once; then add shard-level retry and alerting.

## Conclusion (short)

This is **not** just deploy/restart fallout. The recurrence points to a Hyperswarm
RPC connection lifecycle/resilience issue: data-shard transfer polling can keep using
a closed RPC client/channel without an effective reconnect path, so transfer batches
fail until the client is evicted or the process is restarted. The durable fix belongs
in the shared net facility — detect `RPC client closed` / `CHANNEL_CLOSED`, explicitly
drop the cached client for that peer/topic, reconnect, and retry once — plus
shard-level retry and alerting.

**Confidence:** the "no retry/reconnect on the transfer path" part is proven from the
code. The "a stale cached client is reused and never recovers" part is the **leading
hypothesis, not fully proven**. `@hyperswarm/rpc` does have a `'close'`-event
pool-eviction path (`index.js:95`, ClientRef `:146`), so the open question is *why
that eviction/reconnect does not recover in prod* during the affected window. That
needs a focused repro to confirm before we call it root-caused.

What is solid: my earlier "shard shutdown ordering during restart" hypothesis does not
fit the evidence. The fresh logs are from steady state (~2.5h after the restart) and
span five chains, which a restart-shutdown race would not explain.

## Evidence (fresh 5-minute export, 2026-05-29 ~20:05-20:09 UTC)

- 659 `ERR_WALLET_TRANSFER_RPC_FAIL` ("Wallet transfer RPC failed") + 309
  `txFetch:batch:partial`, almost all (946/968 lines) from **one** shard proc worker
  `wrk-data-shard-proc-w-1-1-...` on **one** box `walletprd2`. The sibling worker
  `w-1-0` logged 22 lines. -> the dead client lives in one process's pool, not a
  global peer outage.
- Failures span every chain/ccy the worker polls: bitcoin/btc (190),
  polygon/xaut (167), ethereum/usat (158), plasma/usdt (74), plasma/xaut (70).
  Not chain-specific.
- The 659 failures span **~39.4 seconds** by their embedded event `time` field
  (2026-05-29T20:04:54.902Z -> 20:05:34.274Z), at a sustained ~12-26 per second.
  (Do not read the Loki ingest-timestamp column for this — it buckets the whole burst
  into a single display minute, which is misleading.) So it is a steady high rate of
  fast failures across many poll cycles, consistent with a persistently-unhealthy
  client rather than a one-off spike. The rate alone does not prove the failures are
  pre-network synchronous throws; that follows from the code path, not the timing.
- `txFetch:batch:partial` mixes full failures (`successCount:0,failureCount:40-52`)
  with mostly-OK batches (`successCount:40-46,failureCount:1-6`): only the addresses
  whose `{chain}:{ccy}` topic resolves to the dead cached peer-key fail; the rest
  succeed.
- The **same transport error class** (`RPC client closed`) also appears at the
  **app-node -> ork** layer (`ERR_RPC_CALL_FAILED`, `[HRPC_ERR]=RPC client closed`,
  methods getUserBalance / getSeed / getUserWallets / getUserTransfers, with
  `attempt:1..3`, `channelState.freshKeyCount:9`). This shows the closed-client error
  is not unique to the shard; it is not proof that the identical stale-cached-client
  state occurred there. App-node already has ork failover for it
  (`ork.js:53`, `rpcCallWithRetryAndFailover`), which is why it self-recovers and only
  logged 27 failures.

## Mechanism (exact code path)

Stack in the log points at `@hyperswarm/rpc/index.js:257` (`Client.request`). Tracing it:

1. Shard transfer sync calls
   `BlockchainService._fetchGroupedTransfers` ->
   `_rpcCall(chain, ccy, 'queryGroupedTransfersByAddress', ...)`
   (`wdk-data-shard-wrk/workers/lib/blockchain.svc.js:470-479`).
2. With no `seed`, `_rpcCall` delegates to
   `ctx.net_r0.jTopicRequest(topic, method, payload, opts, cached = true)`
   (`blockchain.svc.js:115-121`).
3. `hp-svc-facs-net` resolves the topic to a peer key and calls
   `this.rpc.request(key, ...)` on a single shared `@hyperswarm/rpc` `RPC` instance
   (`node_modules/hp-svc-facs-net/index.js:69-92`).
4. `RPC.request` returns a **pooled client keyed by peer publicKey**
   (`@hyperswarm/rpc/index.js:61-67`, `_getCachedClient` 122-136). If a `ref` is in
   `this._pool`, it is reused as-is.
5. `Client.request` (index.js:254-257):
   ```js
   if (this.closed) throw new Error('RPC client closed')   // closed = _closed || _rpc.closed
   ```
   `_rpc.closed` -> `protomux-rpc` `_channel.closed`. Once the channel is closed, every
   reuse of that pooled client throws here, synchronously, before any request is sent.

The pool *does* have an eviction path: it removes a closed client via the client
`'close'` event (`index.js:95` and ClientRef `:146` -> `_getCachedClient` `:128-131`).
Note also that under steady traffic the *idle*-linger eviction never fires (the linger
timer is cleared and rescheduled on every `active()` call, `index.js:161-172`), so
while traffic flows the `'close'`-event reconnect is the main recovery path.

**The unproven gap:** the multi-hour persistence implies that, for the affected
peer-key, this `'close'` -> evict -> reconnect path did not effectively recover in
prod. That is the leading hypothesis but it is not yet proven from the export alone.
Candidate explanations to test in a repro: the `'close'` event not firing on a
particular teardown ordering (e.g. keep-alive timeout vs. clean channel close); the
client closing before the ClientRef listener is wired; or a reconnect that
immediately re-closes. Pinning which one decides whether the fix is purely "facility
evicts + reconnects" or also needs an upstream `@hyperswarm/rpc` change.

## Why the symptoms fit the hypothesis

(Consistent with, not proof of, the leading hypothesis above.)

- **Restart fixes it:** a new process starts with an empty pool and reconnects cleanly.
- **Comes back ~2.5h later:** under the hypothesis, the next connection teardown for
  some peer re-creates the stuck-closed-client condition. Nothing about a deploy is
  required, which fits the steady-state recurrence the team observed.
- **One worker / one box:** a bad client would live in that single process's pool.
- **All chains at once:** the defect is at the transport layer, not in per-chain logic.

## Why the data-shard is hit hardest (and what the app-node already does)

`wdk-app-node/workers/lib/services/ork.js` was **already hardened** for this exact
error: `rpcCallWithRetryAndFailover` (lines 28-105) detects
`err.message.includes('RPC client closed') || err.code === 'CHANNEL_CLOSED'`
(`isChannelClosedError`) and, for retryable methods, **rotates to the next ork
peer-key** and retries (this is the source of the `ERR_RPC_CALL_FAILED` /
`channelState.freshKeyCount` log fields). That is why the app-node only logged 27
failures: it routes around the dead client by switching peer.

The **data-shard has no equivalent**. `getGroupedTransfersForWalletsBatch`
(`blockchain.svc.js:489-538`) runs `Promise.allSettled` over all addresses and, on
failure, only logs `ERR_WALLET_TRANSFER_RPC_FAIL` and increments a counter — no
retry, no failover, no reconnect. (Note the balance path *does* wrap calls in
`retryTask` for "immediate retries", `blockchain.svc.js:176-180`; transfers never got
that treatment.) So the shard has zero resilience to a closed client.

Important nuance: the app-node's "rotate to another peer" trick is only available
because there are multiple orks. For shard -> indexer topics (`{chain}:{ccy}`) there
may be only one healthy indexer peer per topic, so failover-to-another-peer is not
guaranteed to help. The shard genuinely needs the **same** peer connection
re-established. That means a caller-side retry on the same key is **not** sufficient
on its own unless the dead client is evicted from the pool first.

## Addendum (2026-06-02): app-node failover is incomplete for writes

A separate investigation into a user-facing "Backup Failed
[HRPC_ERR]=RPC client closed" on the cloud-backup flow found that the
"app-node already self-recovers" claim above (Evidence bullet 5, and the
"Why the data-shard is hit hardest" section) holds for **read methods only**.

`CORE_RETRYABLE_METHODS` in `wdk-app-node/workers/lib/services/ork.js:10-26` is
a reads-only allowlist. Write methods `storeEntropy` / `storeSeed` are not in
it, so `rpcCallWithRetryAndFailover` gives them `maxAttempts:1`
(`ork.js:65`) and they do **not** fail over on `RPC client closed`; the raw
error reaches the user. Staging logs show `method=storeSeed ... maxAttempts:1`
failing while sibling reads log `maxAttempts:9` and recover, under the same
transient channel-closed condition.

So the app-node mitigation referenced here is partial. The shared durable fix
(option 1 below: pool-level evict + reconnect in `hp-svc-facs-net`) would cover
the write path too. The contained fix for backups specifically is to make the
shard `storeEntropy` / `storeSeed` appends idempotent and then add them to the
failover allowlist.

Full write-up:
[`48-...-rumble-cloud-backup-fails-rpc-client-closed-no-ork-failover-for-writes`](../48-02-jun-26-rumble-cloud-backup-fails-rpc-client-closed-no-ork-failover-for-writes/root-cause.md).

## Recommended durable fix (in priority order)

1. **Pool-level reconnect (best, shared, fixes everyone).** In `hp-svc-facs-net`
   `jRequest`, catch `RPC client closed` / `CHANNEL_CLOSED`, evict the cached client
   for that peer key from the underlying `@hyperswarm/rpc` pool, reconnect, and retry
   once. This fixes the shard, the app-node, the ork, and every other tetherto worker
   built on this facility, and makes the app-node's bespoke failover redundant.
   Requires a small PR to the shared `hp-svc-facs-net` (and possibly exposing a
   `dropClient(key)` / forcing `client.destroy()` so the pool re-creates it).
2. **Shard-level retry (fastest, contained).** Mirror `ork.js`: wrap `_rpcCall` (or
   `_fetchGroupedTransfers`) so a channel-closed error forces a reconnect and one
   retry before counting the address as failed. Only durable if combined with the
   eviction in (1), otherwise the retry hits the same sticky-closed client.
3. **Alerting (independent, do regardless).** Loki/Grafana alert on the rate of
   `errorCode=ERR_WALLET_TRANSFER_RPC_FAIL` (and `ERR_RPC_CALL_FAILED`) per
   host/worker over 1-5 min, so this pages before a human notices and manually runs
   the shard restart. The existing query (`{job="pm2", level="40"}` filtered to these
   error codes) is the basis.

## Verification still worth doing

- Confirm with holepunch / a focused repro whether `@hyperswarm/rpc` v3.4.0 fails to
  fire the client `'close'` -> pool-evict on the specific teardown path seen in prod
  (stream keep-alive timeout vs. clean channel close). This pins whether the true fix
  belongs in `hp-svc-facs-net` (evict + reconnect) or upstream `@hyperswarm/rpc`.
- Check how many indexer peers serve each `{chain}:{ccy}` topic in prod
  (`lookupTopicKeyAll`) to decide whether shard-side failover is even an option or
  reconnect-same-peer is mandatory.

## Source references

- `wdk-data-shard-wrk/workers/lib/blockchain.svc.js:115` (`_rpcCall`),
  `:470` (`_fetchGroupedTransfers`), `:489` (`getGroupedTransfersForWalletsBatch`),
  `:525` (`ERR_WALLET_TRANSFER_RPC_FAIL` log), `:176-180` (balance retryTask, for contrast).
- `hp-svc-facs-net/index.js:69` (`jRequest`), `:89` (`jTopicRequest`).
- `@hyperswarm/rpc/index.js:61` (`RPC.request`), `:122` (`_getCachedClient`),
  `:139` (`ClientRef`), `:254-257` (`Client.request` / the throw), `:242` (`closed` getter).
- `protomux-rpc/index.js:179` (`closed` getter), `:271-277` (`destroy`).
- `wdk-app-node/workers/lib/services/ork.js:28` (`isChannelClosedError`),
  `:53-105` (`rpcCallWithRetryAndFailover`) — the existing mitigation to mirror.

## Caveats on versions (confirm against prod before patching)

- **Worker code revision.** Production logs use `txFetch:batch:partial` with
  structured `successCount`/`failureCount` fields and
  `errorCode:"ERR_WALLET_TRANSFER_RPC_FAIL" / msg:"Wallet transfer RPC failed"`. The
  local checkouts log the same events as `txFetchGrouped:batch:partial success=..
  failures=..` strings. Same function and architecture (Promise.allSettled,
  per-address `_rpcCall`, no retry); only the log shape differs, so prod is on a
  different revision of this file. The prod stack path is
  `/srv/data/production/rumble-data-shard-wrk/...`, i.e. the deployed worker is
  **rumble-data-shard-wrk** (which extends wdk-data-shard-wrk). Confirm the exact prod
  branch/commit before writing the patch.
- **`@hyperswarm/rpc` version is not pinned.** The prod stack line `index.js:257`
  (`Client.request`) looks like the 3.4.x/3.5.x line layout, but local artifacts
  disagree: rumble-data-shard-wrk locks **3.5.0** (stale `node_modules` install shows
  3.4.0), wdk-data-shard-wrk locks **3.4.1**. The `request` / `_getCachedClient` /
  `closed`-getter logic referenced here is the same across the 3.4.x copies I read,
  but **do not assume prod runs exactly that**; confirm prod's `package-lock`. If the
  eviction path differs between 3.4.x and 3.5.x, that could itself be relevant to the
  unproven gap above.
