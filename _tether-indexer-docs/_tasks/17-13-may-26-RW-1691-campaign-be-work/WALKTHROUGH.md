# RW-1691 — Live walkthrough cheat sheet

PR: https://github.com/tetherto/rumble-promo-wrk/pull/46
Branch: `feat/rw-1691-campaign-builder-v2` → `dev`
Head: `cd665c6`

## TL;DR

Rumble now owns codes, budgets, eligibility, geo rules. Wallet-BE is a thin
payout executor: receive an accepted claim, pay USAT/USDT on Ethereum, report
back. V1 is removed.

## Contract (settled / failed are mutually exclusive per claim)

- `settled` callback fires only after a status=1 receipt is observed on chain
  (clarified by Andre on 2026-05-20, see `latest-specs-changes.md` §3).
- `failed` callback fires on: pre-broadcast failure, post-broadcast revert,
  post-broadcast tx dropped from mempool, or persistent pending past the cap.

## State machine

```
normal:        queued -> paying -> broadcast -> mined -> notified
revert:        paying|broadcast -> failed
dropped tx:    broadcast -> paying  (recovery retries, eventually cancels)
exhausted:     paying -> cancelling -> failed  (or mined if a late tx landed)
stuck pending: broadcast -> cancelling -> failed  (same cancel path)
```

## File map

| File | Purpose |
|---|---|
| `workers/api.promo.wrk.js` | HTTP-facing api worker; one method `claimCodeV2`, pass-through to proc |
| `workers/proc.promo.wrk.js` | The brain: schedulers, recovery loops, observers |
| `workers/lib/queries/payouts.v2.js` | All SQL against `promo_payouts_v2` |
| `workers/lib/queries/payout_callbacks.v2.js` | All SQL against `promo_payout_callbacks_v2` (outbox) |
| `workers/lib/schema.js` | Table definitions |
| `workers/lib/constants.js` | Status / kind enums |
| `workers/lib/wallet.bot.evm.v2.js` | Multi-token wallet bot (USAT + USDT), sign/broadcast/cancel |
| `workers/lib/rumble.admin.client.js` | HMAC-signed POST to Rumble admin API |

## Scheduler ticks (proc worker)

| Tick | Functions |
|---|---|
| `v2-process-payouts` | `_processV2Payouts`, `_recoverStuckV2Payouts`, `_observeBroadcastedV2Payouts`, `_finalizeCancellingV2Payouts` |
| `v2-dispatch-callbacks` | `_reconcileV2MissingCallbacks`, `_dispatchV2Callbacks` |
| `collect-metrics` | `_collectV2Metrics` |

---

## 1. Entry point: `claimCodeV2`

`workers/proc.promo.wrk.js:93`

The wallet app calls this via the api worker. We resolve the wallet address,
forward to Rumble's redeem endpoint, then queue a payout. Once Rumble has
issued a `claimId`, **any** subsequent rejection must enqueue a `failed`
callback so Rumble releases the reserved budget.

```js
async claimCodeV2 ({ code, userId, clientIp, wallet }) {
  // ...validate inputs, resolve wallet address...
  const res = await this.rumbleAdminClient.redeem({ code, userId, clientIp })

  // 5xx/network -> retryable error to the client (Rumble owns budget truth)
  // 4xx -> map Rumble's errorCode straight back to the client
  // 2xx -> data.claimId is the durable key

  const failPostAccept = async (reason) => {
    await this._ensureCallback({ claimId, kind: FAILED, walletAddress, reason })
    this.slackNotification.sendAlert(...)
  }

  // Validate amount/token/chain after claimId is issued; any failure -> failPostAccept
  // insertPayout is idempotent on claimId so client retries are safe.
  await payoutsV2.insertPayout(this.db, { claimId, userId, walletAddress, ... })
}
```

**Why:** the redeem call commits Rumble-side state. From that moment, the
contract requires a callback either way. Pre-accept rejections (4xx/5xx) get
mapped to wallet-app errors; post-accept rejections enqueue `failed`.

---

## 2. Sign-then-persist-then-broadcast

`workers/proc.promo.wrk.js:210`

```js
async _broadcastPayoutTx ({ payoutId, token, to, amount, nonce, gas }) {
  const { signed, hash } = await this.walletBotV2.signTransfer(...)
  await payoutsV2.appendAttemptHash(this.db, { id: payoutId, hash })
  await this.walletBotV2.broadcast(signed)
  return hash
}
```

**Why:** the hash is deterministic from `(nonce, payload, signature)`. We
persist it **before** broadcasting. If the process dies between sign and
broadcast, recovery can still query the chain by that hash. No "user paid but
DB doesn't know" window.

The hash column is a JSON array of attempted hashes (parsed via
`parseTxHashes`). Each resubmit / cancel appends; mining collapses to the
canonical hash.

---

## 3. Happy path: `_processV2Payouts`

`workers/proc.promo.wrk.js:296`

For each configured token (USAT, USDT):
1. Pull queued rows up to batch size.
2. Rate-limit gate. If skipped, log and increment the persistent-skip alert.
3. Balance check (token + native gas).
4. Atomic batch-transition queued -> paying with assigned nonces.
5. Sign + broadcast each row concurrently. `setPayoutBroadcast` flips the row
   and stamps `broadcastedAt`.

No callback is enqueued here. The observer drives the settled callback when
the receipt lands.

---

## 4. Schema (key columns)

`workers/lib/schema.js`

```
promo_payouts_v2(
  id, claimId UNIQUE, userId, walletAddress, chain, token, amount,
  status, nonce, txHash (JSON array), lastError,
  retries, cancelRetries,
  broadcastedAt,            -- timestamp of most recent broadcast attempt
  createdAt, updatedAt
)

promo_payout_callbacks_v2(
  id, claimId, kind ('settled'|'failed'),
  walletAddress, txHash, reason,
  status ('pending'|'delivered'|'dead'),
  retries, nextAttemptAt, lastError,
  createdAt, updatedAt,
  UNIQUE(claimId, kind)
)
```

`broadcastedAt` is new on this PR and is what drives the pending-stuck cap.
The schema uses `CREATE TABLE IF NOT EXISTS`; pre-merge dev DBs need to be
wiped if they had V2 rows from earlier iterations.

---

## 5. Idempotent claim insert

`workers/lib/queries/payouts.v2.js:5`

```js
async function insertPayout (db, params) {
  await db.runAsync(
    `INSERT OR IGNORE INTO promo_payouts_v2 (claimId, ..., status, ...)
     VALUES (?, ..., 'queued', ...)`,
    [params.claimId, ...]
  )
  const row = await getPayoutByClaimId(db, params.claimId)
  return { inserted: result.changes > 0, row }
}
```

claimId is UNIQUE. INSERT OR IGNORE makes retries a no-op. We return the
existing row either way so the response shape is stable.

---

## 6. Outbox + dedup: `_ensureCallback`

`workers/proc.promo.wrk.js:273`

```js
async _ensureCallback (params) {
  try {
    await callbacksV2.ensureEnqueued(this.db, params)
  } catch (err) {
    if (err.code === 'ERR_CALLBACK_CONFLICT') {
      this.slackNotification.sendAlert(...)
      this.logger.error(...)
      return
    }
    throw err
  }
}
```

`ensureEnqueued` (`workers/lib/queries/payout_callbacks.v2.js:9`):

- Same-kind duplicate: no-op via `UNIQUE(claimId, kind)` + `INSERT OR IGNORE`.
- Opposite-kind exists: throws `ERR_CALLBACK_CONFLICT`. That should never
  happen in healthy flow because settled and failed are mutually exclusive
  per claim. If it does, we Slack-alert and leave both rows for operators.

---

## 7. Dispatcher with HMAC-signed POST

`workers/proc.promo.wrk.js:716` + `workers/lib/rumble.admin.client.js`

```js
async _dispatchV2Callbacks () {
  const due = await callbacksV2.getDue(this.db, { limit })
  for (const cb of due) {
    const res = cb.kind === 'settled'
      ? await this.rumbleAdminClient.settled({ claimId, txHash, walletAddress })
      : await this.rumbleAdminClient.failed({ claimId, reason, walletAddress })

    if (2xx) markDelivered + (if settled) transition payout to NOTIFIED
    else if (retries < max) exponential backoff via reschedule
    else markDead + Slack alert
  }
}
```

HMAC scheme matches the existing transaction-init / jar-sync calls in
rumble-data-shard-wrk: `HMAC-SHA256(secret, timestamp + payload)`, headers
`x-signature` + `x-signed-on`.

---

## 8. Receipt classification (the most important helper)

`workers/proc.promo.wrk.js:243`

```js
async _classifyHashes (hashes) {
  for (const h of hashes) {
    const receipt = await this.walletBotV2.getTransactionReceipt(h).catch(() => null)
    if (!receipt) continue
    if (receipt.status !== 1 && receipt.status !== 0) continue
    const to = (receipt.to || '').toLowerCase()
    const kind = this._v2TokenContracts.has(to) ? 'payout' : 'cancel'
    return { kind, status: receipt.status, hash: h }
  }
  return null
}
```

A row's `txHash` array can contain both payout-tx hashes and cancel-tx hashes
(if a previous `_cancelExhaustedPayout` partially completed before a crash).
Classifying by `receipt.to`:

- `receipt.to` matches a configured token contract -> payout tx.
- `receipt.to` matches our own wallet (0-value self-transfer) -> cancel tx.

A cancel tx mining with status=1 is technically successful on chain, but it
means the payout did **not** happen. Without this classification we'd
mis-report `settled` for a 0-value self-transfer.

---

## 9. The classifier's matching resolver

`workers/proc.promo.wrk.js:389`

```js
async _resolveClassifiedReceipt (p, classified, phase) {
  const { kind, status, hash } = classified

  if (kind === 'payout' && status === 1) {
    // mined + settled callback
  }
  if (kind === 'payout' && status === 0) {
    // failed + failed callback (reverted on chain)
  }
  // kind === 'cancel': crash leftover, payout did not happen -> failed
}
```

`phase` ('V2 recovery' / 'V2 observer' / 'V2 cancel exhaust') is tagged on
the alert so operators can tell which loop saw the state.

---

## 10. Stuck-paying recovery

`workers/proc.promo.wrk.js:354`

For each PAYING row older than the stale threshold (5 min default):

1. `_classifyHashes` -> if any receipt is final, resolve and continue.
2. Otherwise, if `getTransaction` knows any hash (still in mempool), heal the
   row back to BROADCAST and let the observer drive next steps.
3. Otherwise, if retries >= max -> `_cancelExhaustedPayout`.
4. Otherwise -> `_resubmitPayout` at the same nonce with bumped gas.

`_resubmitPayout` bumps fees to `max(fresh estimate, 1.5 * last attempt)` and
catches broadcast failures via `recordPayoutAttempt` (which bumps retries).

---

## 11. Broadcast observer

`workers/proc.promo.wrk.js:498`

For each BROADCAST row older than stale threshold:

1. `_classifyHashes` -> mined? revert? cancel-leftover? -> resolve and continue.
2. `getTransaction` known? -> check `broadcastedAt`. If pending past
   `broadcastPendingMaxMs` (30 min default), call `_cancelExhaustedPayout`.
   Otherwise touch updatedAt and wait.
3. Tx dropped from mempool -> `rollbackBroadcastToPaying` (increments retries
   so accept-then-drop cycles converge to cancel/failed).

---

## 12. Nonce-cancel with proper fee bump

`workers/proc.promo.wrk.js:435`

```js
async _cancelExhaustedPayout (p, hashes) {
  const classified = await this._classifyHashes(hashes)
  if (classified) { ... return }   // late-landed receipt covers this

  const lastTx = await this._findHighestFeeKnownTx(hashes)

  const cancelHash = await this._broadcastCancelTx({
    payoutId: p.id, nonce: p.nonce, lastTx
  })
  await payoutsV2.setPayoutCancelling(...)
}
```

`_findHighestFeeKnownTx` (`workers/proc.promo.wrk.js:226`) iterates the
hashes and returns the live tx with the highest `maxFeePerGas`. That seeds
`signCancel` so the cancel beats the replacement-underpriced rule against
whatever attempt is currently competing for the nonce.

Without that seed, `signCancel` falls back to `base-fee * 2`, which is below
a hot-broadcast payout after a fee spike. The node rejects the cancel and the
loop replays forever.

---

## 13. Finalize cancelling

`workers/proc.promo.wrk.js:550`

For each CANCELLING row:

- A mined payout-tx (status=1) wins -> the user was paid late -> emit
  `settled` (yes, even though we tried to cancel; on-chain truth wins).
- A mined payout-tx (status=0) -> reverted -> emit `failed`.
- A mined cancel-tx (status=1) -> cancel succeeded -> emit `failed`.
- Cancel dropped from mempool -> rebroadcast with bumped fees, increment
  `cancelRetries`. Past `cancelMaxRetries`, alert and leave in cancelling for
  operator review (nonce must not be abandoned).

---

## 14. Crash-recovery for callbacks

`workers/proc.promo.wrk.js:674`

```js
async _reconcileV2MissingCallbacks () {
  const missingSettled = await payoutsV2.getPayoutsMissingCallback(this.db, {
    statuses: [MINED],
    kind: SETTLED, limit
  })
  // backfill settled callback from canonical txHash

  const missingFailed = await payoutsV2.getPayoutsMissingCallback(this.db, {
    statuses: [FAILED], kind: FAILED, limit
  })
  // backfill failed callback from lastError
}
```

Belt-and-suspenders: if we transitioned a payout to MINED/FAILED but crashed
before `ensureEnqueued` ran, this picks it up next cycle.

---

## 15. Operability: persistent rate-limit alert

`workers/proc.promo.wrk.js:255`

Rate-limit skips are normal and transient. Warn-level log only. But a
**persistent** skip is a real problem (batch > limit, or sustained
congestion) and should page someone.

```js
_maybeAlertRateLimitSkip ({ batchSize, token }) {
  if (this._v2RateLimitSkipSince === null) this._v2RateLimitSkipSince = now
  const persistedForMs = now - this._v2RateLimitSkipSince
  if (persistedForMs < this.rateLimitSkipAlertAfterMsV2) return  // 60s default
  if (now - this._v2RateLimitSkipLastAlertAt < this.rateLimitSkipAlertRepeatMsV2) return  // 10min throttle
  this._v2RateLimitSkipLastAlertAt = now
  this.slackNotification.sendAlert(...)
}
```

`_clearRateLimitSkipState` resets both counters on the next successful cycle.

---

## 16. Config knobs (`config/proc.promo.json.example`)

```jsonc
{
  "v2": {
    "payoutSchedule":            "*/5 * * * * *",    // payout loop tick
    "callbackSchedule":          "*/5 * * * * *",    // callback dispatch tick
    "payoutBatchSize":           20,
    "callbackBatchSize":         20,
    "callbackMaxRetries":        12,                  // outbox dead-letter
    "callbackBackoffBaseMs":     30000,
    "payoutStaleThresholdMs":    300000,              // 5 min stale-row threshold
    "broadcastPendingMaxMs":     1800000,             // 30 min stuck-pending cap
    "payoutMaxRetries":          6,                   // before nonce cancel
    "cancelMaxRetries":          6,                   // before alert + leave for ops
    "hotWalletLowThreshold":     "0",
    "rateLimitSkipAlertAfterMs": 60000,               // skip must persist this long
    "rateLimitSkipAlertRepeatMs": 600000               // throttle between alerts
  }
}
```

---

## Edge cases the design covers

| Scenario | Outcome |
|---|---|
| Process crash between sign and broadcast | Recovery queries chain by persisted hash |
| Process crash between broadcast and DB update | Recovery sees tx via `getTransaction` -> heals to BROADCAST |
| Process crash between `setPayoutMined` and `ensureEnqueued` | `_reconcileV2MissingCallbacks` backfills |
| Tx reverts (status=0) | Observer / recovery sends `failed` |
| Tx dropped from mempool after broadcast | Roll back to PAYING, increment retries, eventually cancel |
| Tx stuck pending forever (underpriced after fee spike subsides) | After `broadcastPendingMaxMs`, cancel nonce -> `failed` |
| Cancel tx underpriced vs stuck payout | `_findHighestFeeKnownTx` seeds `lastTx`; cancel bumps off it |
| Payout lands late while we're cancelling | `_finalizeCancellingV2Payouts` detects payout-tx receipt -> `settled` |
| Crash mid-cancel; cancel hash + payout hashes both present | Receipt classified by `receipt.to`; cancel-leftover -> `failed` |
| Rumble admin endpoint down | Outbox retries with exponential backoff, then dead-letters |
| Rate limit persistently blocking payouts | Throttled Slack alert after 60s |

---

## Things worth pointing out live

- **No callback is enqueued at broadcast time.** This was the big spec
  flip (Andre on 2026-05-20). The observer is now load-bearing for the
  happy path, not just a defensive sweep.
- **`receipt.to` classification is the keystone.** Cancel-tx safety
  depends on it. Three call sites share `_classifyHashes` +
  `_resolveClassifiedReceipt`.
- **`broadcastedAt` resets on every broadcast attempt**, not just the
  first. The pending cap measures the *current* attempt.
- **`rollbackBroadcastToPaying` increments retries.** Without that, an
  accept-then-drop loop never escalates to cancel.
- **`_recoverStuckV2Payouts`'s "provider knows tx" path no longer
  enqueues settled.** It just heals back to BROADCAST. The observer
  drives settled when a receipt is confirmed.
- **All `*-app-node` schema validation lives upstream.** The proc
  worker validates again post-Rumble-accept because `failPostAccept`
  needs to release Rumble budget if anything is off.
