# Dependency bump required: wdk-ork-wrk retry must be published before rumble picks it up

> SUPERSEDED for the wdk-ork-wrk side. After review, wdk-ork-wrk no longer uses
> the hand-rolled retry loop / `SHARD_RETRY_OPTS` described below; it delegates to
> the net facility's `autoRetry`. See task
> `56-08-jun-26-RW-1862-.../FIX.md` for the current state. The rumble-side notes
> here (non-fatal balance guard, awaited addTxWebhook, data-shard dedupe, app-node
> retryability scoping, server-side idempotency) still hold.

## Context

Rant/tip transfers settle on-chain but never appear in chat when the ork's
`sendNotification` hits a transient `[HRPC_ERR]=RPC client closed` on the ork to
data-shard hop. Confirmed on walletstg2 for the Jun 5 staging test (XAUt
transfer, traceId `mob:235937692:6d13658e`): the ork's `_getWalletTokenBalance`
threw "RPC client closed" at 0.25ms, before `_addTxWebhook(RANT)` was reached,
and `sendNotification` is non-retryable so it 500'd with no failover.

Fix is split across four branches, all named
`fix/rant-notification-transient-rpc-closure`:

- **wdk-ork-wrk**: `_rpcRequest(req, action, opts)` gains a bounded retry on
  channel-closed errors (re-resolves the shard peer each attempt); `_getWallet`
  and `_getWalletTokenBalance` forward retry opts. Default `retries: 0` keeps
  every existing caller identical.
- **rumble-ork-wrk**: balance guard made non-fatal (skip on transient closure,
  it is a best-effort anti-spoof check), `_addTxWebhook` awaited + retried at all
  four call sites, V1 `sendNotification` deduped onto `_processTransferPayload`.
- **rumble-data-shard-wrk**: `storeTxWebhook` now gates the non-idempotent
  `rantTransactionInit` on an **atomic** `createIfAbsent` (new repo method) keyed
  on the unique `transactionHash`, so a re-delivered or concurrent notification
  cannot double-post the rant. Mongo uses a `$setOnInsert` upsert + duplicate-key
  catch; HyperDB uses a get-then-insert inside an exclusive transaction.
- **rumble-app-node**: `sendNotification` / `sendNotificationV2` added to
  `RUMBLE_EXTRA_RETRYABLE_METHODS` so the app node fails over to another ork on a
  channel-closed error.

## The bump dependency (the caveat)

rumble-ork-wrk does **not** use the local wdk-ork-wrk checkout. It consumes the
**published** `@tetherto/wdk-ork-wrk` from `node_modules` (currently the dev tip,
whose `_rpcRequest` still has the old `(req, action)` signature and silently
ignores the extra `opts` arg).

What that means until the bump lands:

- The non-fatal balance guard and the awaited `_addTxWebhook` **do work today**
  (pure rumble-ork-wrk logic). These alone already stop the exact drop we saw,
  because the staging failure was on the awaited balance read.
- The ork to shard **retry does not fire yet**. rumble-ork-wrk passes
  `SHARD_RETRY_OPTS` into the base helpers, but the installed base discards it,
  so transient closures on `_getWallet` / `addTxWebhook` are not yet retried.

To activate the retry:

1. Commit and push wdk-ork-wrk `fix/rant-notification-transient-rpc-closure`,
   merge to its dev, and get a commit hash.
2. Bump rumble-ork-wrk `package.json` `@tetherto/wdk-ork-wrk` git dependency to
   that commit, `npm install`, and commit the lockfile.

This is the same flow as WDK-1515: the wdk-data-shard-wrk transfer-RPC retry was
bumped into rumble-data-shard-wrk via PR #230. Until step 2, treat
rumble-ork-wrk's retry path as inert.

## Verification done (local, uncommitted)

- `node --check` clean on every changed file.
- rumble-ork-wrk: `test:unit` green (9/9). The orphaned `tests/unit/api.ork.wrk.unit.js`
  is pre-existing-broken on an `lru-cache` version mismatch in its own setup and
  is not wired into any npm script.
- rumble-data-shard-wrk: `proc.shard.data.wrk.unit.test.js` 32/32, including a new
  dedupe test. The `notification.util.unit.test.js` crash is pre-existing FCM test
  fragility (unrelated files).

Nothing committed.

## Required server-side change (rumble-server, outside these four repos)

The data-shard dedupe gates the non-idempotent `rantTransactionInit`
(`POST /-wallet/webhook/transaction-init`) on the durable `createIfAbsent` row.
The insert is durable BEFORE the init POST fires, so a worker crash in that
window makes the init at-most-once: the row already exists, every redelivery
dedupes out, and the rant init is lost permanently. We accept this window ONLY
on the contract that `transaction-init` is **idempotent on the rumble server**
(keyed on rant id / transactionHash), so a redelivery that does reach it is
harmless.

Action: confirm/implement idempotency of `POST /-wallet/webhook/transaction-init`
in rumble-server before this ships. If that endpoint cannot be made idempotent,
the data-shard gate must be reworked to an at-least-once init (insert PENDING,
run init, then set a separate `inited` marker; re-run init on redelivery while
the marker is unset) instead of relying on the dedupe row. Code comment marking
this lives at `rumble-data-shard-wrk/workers/proc.shard.data.wrk.js` in
`storeTxWebhook`.

## Retryability scoping (rumble-app-node, done locally)

`sendNotification` / `sendNotificationV2` are no longer blanket-retryable. They
fail over to another ork only when the payload carries a `transactionHash` /
`transactionReceiptId` (transfer, deduped by the data shard) or an
`idempotencyKey` (manual types, deduped by `sendUserNotification`). Types with
neither (e.g. `LOGIN`, `TOKEN_TRANSFER_COMPLETED`) are left non-retryable so a
failover cannot re-send an undeduped FCM push. See
`workers/lib/services/ork.js` (`notificationRetryableMethods`) and
`tests/ork-notification-retry.unit.test.js`.

## Loose end

`tether-wrk-ork-base` remote returns "Repository not found" on pull. If the
net-facility autoRetry (`hp-svc-facs-net`) is later wanted in the ork for true
peer reconnect (vs the current re-resolve-on-retry), that base is where the
`hp-svc-facs-net` bump belongs and its remote needs locating first.
