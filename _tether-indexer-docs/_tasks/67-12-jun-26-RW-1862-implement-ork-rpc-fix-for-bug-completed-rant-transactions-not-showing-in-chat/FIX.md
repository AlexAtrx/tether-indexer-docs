# RW-1862 fix: rant/tip transfers not showing in chat (RPC client closed)

This is the current, post-review record of the fix. The older
`55-.../dependency-bump-required.md` describes the first approach (a hand-rolled
retry loop with `SHARD_RETRY_OPTS`) and is superseded by this doc for the
wdk-ork-wrk side.

## Bug

Rant/tip transfers settle on-chain and the recipient gets the funds, but the
rant never appears in chat. Seen on prod and staging. Root cause is a transient
`[HRPC_ERR]=RPC client closed` (CHANNEL_CLOSED) on the ork to data-shard hop:
`sendNotification` reads the sender balance and writes the tx-webhook over HRPC,
and a single closed channel there 500s the whole notification with no recovery,
so the chat write never happens. Confirmed on walletstg2 for the Jun 5 staging
test (XAUt transfer, traceId `mob:235937692:6d13658e`): `_getWalletTokenBalance`
threw "RPC client closed" before `_addTxWebhook(RANT)` was reached.

## Fix, by repo

Four branches, all `fix/rant-transfers-not-displayed-in-chat`.

### wdk-ork-wrk  (PR #144)
- `_rpcRequest(req, action, opts)` delegates the channel-closed retry to the net
  facility instead of a custom loop. `opts` is `{ autoRetry, autoRetryDelay }`;
  it calls `net_r0.jRequest(rpcKey, action, payload, reqOpts, autoRetry)` and the
  facility retries on `RPC client closed` / `CHANNEL_CLOSED`.
- `_getWallet(req, opts)` and `_getWalletTokenBalance(req, opts)` forward `opts`.
- `resolveUserShardRpc` is back to its original cached lookup (no cache bypass),
  so the user-to-shard path purgeUserData shares is untouched.
- No package.json version bump (the main pipeline owns the version).

Why the change from the first approach: reviewer (vigan-abd) pointed out the net
facility already has a built-in `autoRetry` on `jRequest` (added on
`hp-svc-facs-net` main, the WDK-1515 work), so the app-level loop was duplicating
it; and that bypassing the resolveRpc cache on retry risked a purge-user
concurrency issue. Both addressed by delegating to the facility and reverting the
cache change.

### rumble-ork-wrk  (PR #163)
- Sender balance guard made non-fatal: a transient closure on the best-effort
  anti-spoof balance read is skipped, not fatal.
- `_addTxWebhook` awaited and retried at all call sites.
- V1 `sendNotification` consolidated onto `_processTransferPayload`.
- Still passes the OLD opts shape `SHARD_RETRY_OPTS = { retries, retryDelayMs }`
  and still pins `@tetherto/wdk-ork-wrk` at `a7cf612` (2-arg `_rpcRequest`, no
  opts). See "What is still inert" below.

### rumble-data-shard-wrk  (PR #238)
- `storeTxWebhook` records the webhook once via an atomic `createIfAbsent` (new
  repo method) keyed on the unique `transactionHash`, then runs
  `rantTransactionInit` on EVERY delivery (not only the inserting one) so an init
  lost to a failed call or a crash-after-insert is recovered on re-delivery.
- Mongo: `$setOnInsert` upsert + 11000 duplicate-key catch. HyperDB:
  get-then-insert in an exclusive transaction.
- Relies on the rumble-server transaction-init endpoint being idempotent (see
  "Server-side dependency").

### rumble-app-node  (PR #238)
- `sendNotification` / `sendNotificationV2` fail over to another ork only when the
  payload is dedupeable downstream: a `transactionHash`, an `idempotencyKey`, or
  a `transactionReceiptId` for a transfer type that THAT method converts to a
  hash (V1 only `TOKEN_TRANSFER`; V2 also `TOKEN_TRANSFER_RANT` / `_TIP`). Types
  with none (e.g. `LOGIN`, `TOKEN_TRANSFER_COMPLETED`) stay non-retryable so a
  failover cannot re-send an undeduped FCM push. See
  `notificationRetryableMethods` and `tests/ork-notification-retry.unit.test.js`.

## What works today vs what is still inert

Works standalone (pure rumble-ork-wrk logic, no dependency bump needed):
- the non-fatal balance guard and the awaited `_addTxWebhook`. These alone stop
  the exact staging drop, which was on the awaited balance read.

Inert until dependencies catch up:
- the ork to shard `autoRetry`. Two version gaps:
  1. wdk-ork-wrk's own retry only fires when the net facility supports
     `autoRetry`. That param is on `hp-svc-facs-net` main only; wdk-ork-wrk pins
     `tether-wrk-base#v1.0.0` -> `hp-svc-facs-net@0d6b9a38`, both of which predate
     it (their `jRequest` is 4-arg and ignores the 5th `autoRetry` arg). Needs a
     facility release, a tether-wrk-base bump, then a wdk-ork-wrk bump.
  2. rumble-ork-wrk still pins wdk-ork-wrk at `a7cf612` and passes the old
     `{ retries, retryDelayMs }`. To activate: bump the `@tetherto/wdk-ork-wrk`
     pin to a #144 commit and change the call sites to `{ autoRetry: 2,
     autoRetryDelay: 200 }` (rename from `SHARD_RETRY_OPTS`).

## Server-side dependency (rumble-server, outside these repos)

The data-shard dedupe makes the row durable before the init POST fires. The init
now runs on every delivery, so correctness depends on
`POST /-wallet/webhook/transaction-init` being idempotent (keyed on rant id /
transactionHash) on the rumble server. Confirm/implement that before this ships.
If it cannot be made idempotent, rework the gate to an explicit at-least-once
init (insert PENDING, run init, set a separate `inited` marker; re-run while
unset).

## Tests (local)

- wdk-ork-wrk: `data.shard.util.unit.test.js` 7/7. The integration test cannot
  run locally because `@tetherto/tether-wrk-base` is not installed (the @tetherto
  registry-404 gotcha); it runs in CI.
- rumble-data-shard-wrk: `proc.shard.data.wrk.unit.test.js` 33/33, including the
  init-on-every-delivery dedupe tests.
- rumble-app-node: `ork-notification-retry.unit.test.js` covers the per-method
  receipt gating.
- rumble-ork-wrk: `test:unit` 9/9.

## PRs

- wdk-ork-wrk: https://github.com/tetherto/wdk-ork-wrk/pull/144
- rumble-ork-wrk: https://github.com/tetherto/rumble-ork-wrk/pull/163
- rumble-data-shard-wrk: https://github.com/tetherto/rumble-data-shard-wrk/pull/238
- rumble-app-node: https://github.com/tetherto/rumble-app-node/pull/238

#163 depends on #144 (pin bump); the other two are independent.
