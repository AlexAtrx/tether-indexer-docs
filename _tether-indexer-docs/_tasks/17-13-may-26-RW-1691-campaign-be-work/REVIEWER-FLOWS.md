# RW-1691 — Flows for a first-time reviewer

Repo `tetherto/rumble-promo-wrk`, branch `feat/rw-1691-campaign-builder-v2`, PR #46.

The payout row is the single source of truth. Every method below mutates it
or reads it. The row walks one of these state paths:

```
HAPPY:        queued -> paying -> broadcast -> mined -> notified
DROPPED:                  ^   <- broadcast (rollback, retries++)
REVERT:                                  broadcast -> failed
STALL:                                   broadcast -> cancelling -> failed
EXHAUST:                  paying -> cancelling -> failed
LATE LAND:                          cancelling -> mined -> notified
CRASH-LEFTOVER:           any non-terminal -> failed  (cancel surfaced)
```

The flows below show **who drives each transition** and **where each happy
step can branch off into a side flow**.

---

## 1. Happy path (the contract is honored end to end)

Single API call from the frontend, async chain work, single callback to
Rumble.

| # | Where | Method | What it does | Branch-out if not happy |
|---|---|---|---|---|
| 1 | api worker | `claimCodeV2(req)` | validate `{code, userId, clientIp, wallet}`, forward to proc via HRPC | input missing → throw `ERR_INVALID_PARAMS` → **Flow J** |
| 2 | proc worker | `claimCodeV2({...})` | resolve user wallet address, call Rumble's redeem, validate the parsed response, insert payout row (status=`queued`), return `{claimId, ..., status:'received'}` | wallet address missing → throw → **Flow J**. Rumble 5xx/0/4xx → throw → **Flow J**. 2xx but bad shape (no amount/token, bad decimals, wrong chain) → throw + enqueue failed callback → **Flow K** |
| 3 | proc worker (every 5s) | `_processV2Payouts()` | per token: rate-limit gate, balance check, atomic `queued -> paying` with assigned nonces, sign + broadcast each in parallel | rate-limited → **Flow I**. Balance check fails → **Flow H1**. Broadcast throws on a single row → row stays in `paying` with retries++ → **Flow A** picks it up |
| 4 | proc worker | `_broadcastPayoutTx({...})` | sign → `appendAttemptHash` (durability) → `walletBotV2.broadcast` → `setPayoutBroadcast` flips row to `broadcast` + stamps `broadcastedAt` | provider rejects → caught by `_processV2Payouts` → **Flow A** |
| 5 | proc worker (every 5s, kicks in 30s after broadcast) | `_observeBroadcastedV2Payouts()` | for each row in `broadcast`: classify the persisted hashes; if conclusive, resolve; else evaluate mempool state | status=0 receipt → **Flow E (revert)**. Cancel-tx surfaces → **Flow F (crash-leftover)**. Provider knows tx but pending past `broadcastPendingMaxMs` → **Flow C (stall → cancel)**. Tx no longer known → **Flow D (dropped → rollback)** |
| 6 | proc worker | `_classifyHashes(hashes)` | walks the row's persisted hashes in insertion order, returns the first conclusive receipt tagged `payout` or `cancel` by `receipt.to` | n/a — classification primitive |
| 7 | proc worker | `_resolveClassifiedReceipt(p, classified, phase)` (happy branch) | `payout` + status=1 → `setPayoutMined` + `_ensureCallback(SETTLED)` | `payout` + status=0 → **Flow E**. `cancel` → **Flow F** |
| 8 | proc worker (every 5s) | `_dispatchV2Callbacks()` | pull due callbacks → `_sendV2Callback` → if 2xx `_markV2CallbackDelivered`; else `_markV2CallbackFailed` | non-2xx → **Flow G (callback retry / dead-letter)** |
| 9 | proc worker | `_markV2CallbackDelivered(cb)` | `callbacksV2.markDelivered`; if cb is `settled` and row is still `mined`, `setPayoutNotified` (terminal happy state) | n/a |

The frontend gets one synchronous `received` response in step 2. The actual
"tokens arrived" message reaches the user via the existing wallet-app
incoming-transaction push channel (the chain indexer surfaces the on-chain
ERC-20 transfer like any other inbound).

---

## A. Recovery flow — stuck `paying` rows

Triggered when `_processV2Payouts` left a row in `paying` after a local
failure (broadcast threw, DB write between sign and flip, process crash, etc).

| # | Method | What it does | Branch-out |
|---|---|---|---|
| A1 | `_recoverStuckV2Payouts()` (every 5s) | pull `paying` rows older than `payingStuckThresholdMs` (30 s default) | n/a |
| A2 | `_classifyHashes(hashes)` | look for any final receipt across all persisted hashes | conclusive → **A3**; none → **A4** |
| A3 | `_resolveClassifiedReceipt(...)` | payout+1 → **Happy step 7**. payout+0 → **Flow E**. cancel → **Flow F** | leaves the recovery flow |
| A4 | `_getKnownTransactions(hashes)` | ask provider if any persisted hash is still in the mempool | known → **A5**; none → **A6** |
| A5 | `setPayoutBroadcast(...)` | heal row back to `broadcast`; observer (Happy step 5) will drive the rest | re-enters **Happy step 5** |
| A6 | retries check | `retries >= payoutMaxRetriesV2`? | yes → **Flow C (cancel)**; no → **A7** |
| A7 | `_resubmitPayout(p, hashes)` | re-broadcast at same nonce; gas seeded as `max(estimate, 1.5 × highest-fee live tx)` via `_findHighestFeeKnownTx` | success → row goes back to `broadcast` → **Happy step 5**. Broadcast throws → `recordPayoutAttempt` (retries++), stays in `paying` → next A1 cycle |

---

## C. Stall / exhaust → cancel flow

Triggered by either:
- recovery (A6) when retries are exhausted on a paying row, OR
- observer (Happy step 5) when a broadcast tx stays pending past
  `broadcastPendingMaxMs` (30 min default).

| # | Method | What it does | Branch-out |
|---|---|---|---|
| C1 | `_cancelExhaustedPayout(p, hashes)` | first re-classify in case a receipt landed in the meantime | classified → **A3**, leaves cancel flow |
| C2 | `_findHighestFeeKnownTx(hashes)` | pick the highest-fee live tx as `lastTx` to seed the cancel's replacement-underpriced bump | n/a |
| C3 | `_broadcastCancelTx({...})` | sign 0-value self-transfer at same nonce → `appendAttemptHash` → broadcast | throws → Slack alert; row stays in incoming status; next cycle retries via A1 or Happy step 5 |
| C4 | `setPayoutCancelling(...)` | flip row to `cancelling` | next loop owner is `_finalizeCancellingV2Payouts` |
| C5 | `_finalizeCancellingV2Payouts()` (every 5s, kicks in 30s after `cancelling`) | per row: classify, then check live-tx state | conclusive → **A3**. Pending past `cancelPendingMaxMs` (5 min) → **C6**. Pending within window → wait. Dropped → **C6** |
| C6 | rebroadcast cancel with bumped fees via `_findHighestFeeKnownTx`; `recordCancelAttempt` (cancelRetries++) | past `cancelMaxRetriesV2` → Slack alert + leave in `cancelling` for ops; nonce intentionally not abandoned | n/a |

Outcomes from this flow:
- payout-tx landed late → row goes to `mined` → re-enters **Happy step 8**.
- cancel-tx mined → **Flow E/F**-style failed callback enqueued by `_resolveClassifiedReceipt`.

---

## D. Dropped flow

Triggered by observer (Happy step 5) when no persisted hash is known to the
provider anymore.

| # | Method | What it does | Branch-out |
|---|---|---|---|
| D1 | `rollbackBroadcastToPaying({...})` | flip row `broadcast -> paying` and `retries = retries + 1` | n/a |
| D2 | Slack alert | reports the dropped-mempool event | n/a |
| D3 | next cycle | **Flow A** picks up the paying row | exits this flow into recovery |

The retries bump ensures repeated accept-then-drop loops converge to **Flow C**
instead of looping forever.

---

## E. Revert flow

Triggered when `_classifyHashes` finds a `payout` receipt with `status === 0`.

| # | Method | What it does | Branch-out |
|---|---|---|---|
| E1 | `_resolveClassifiedReceipt` failure branch | `setPayoutFailed` (row terminal), `_ensureCallback(FAILED)`, Slack alert tagged by `phase` | exits to **Flow G** for callback delivery |

---

## F. Crash-leftover flow (cancel tx surfaced on a paying / broadcast row)

Triggered when `_classifyHashes` finds a `cancel`-kind receipt under a row
that was never officially `cancelling` (a crash partially completed
`_cancelExhaustedPayout` previously).

| # | Method | What it does | Branch-out |
|---|---|---|---|
| F1 | `_resolveClassifiedReceipt` cancel branch | `setPayoutFailed`, `_ensureCallback(FAILED)`, Slack alert with crash-leftover detail | exits to **Flow G** |

---

## G. Callback delivery failure flow

Triggered inside `_dispatchV2Callbacks` when Rumble's admin endpoint returns
non-2xx, or the HTTP call throws.

| # | Method | What it does | Branch-out |
|---|---|---|---|
| G1 | `_markV2CallbackFailed(cb, lastError)` | branches on `cb.retries` vs `callbackMaxRetriesV2` | exhausted → **G2**; else → **G3** |
| G2 | `callbacksV2.markDead({...})` + Slack alert | callback dies in `dead` status; no further retries | terminal |
| G3 | `callbacksV2.reschedule({...})` | exponential backoff `callbackBackoffBaseMs × 2^retries` | re-enters **Happy step 8** on the next due timestamp |

---

## H. Crash-window callback backfill

Belt-and-suspenders for the case where the row reached `MINED` or `FAILED`
but the process crashed before `_ensureCallback` ran.

| # | Method | What it does | Branch-out |
|---|---|---|---|
| H0 | `_reconcileV2MissingCallbacks()` (every 5s, before dispatcher) | find `MINED` rows with no `settled` callback, `FAILED` rows with no `failed` callback | each missing row → **H1** |
| H1 | `_ensureCallback({...})` | enqueue the missing callback row | exits to **Happy step 8** |

### H1 sub-flow: insufficient funds

When `_processV2Payouts` calls `_ensureV2Balance`:

| # | Method | What it does | Branch-out |
|---|---|---|---|
| H1a | `_ensureV2Balance` | check token + native balance + low-threshold | low / insufficient → `sendLowBalanceAlert` (Slack) + throw |
| H1b | `_processV2Payouts` catch | log error, `continue` the loop without progressing the batch | rows stay in `queued`; next cycle retries from **Happy step 3** |

This is the only flow that silently parks claims: queued rows persist
indefinitely until funded. It does fire Slack on every cycle, so the
condition is visible. Rumble's accounting still considers those claimIds
in-flight until either a settled or failed callback eventually fires.

---

## I. Rate-limit-skip flow

| # | Method | What it does | Branch-out |
|---|---|---|---|
| I1 | `_processV2Payouts` rate-limit branch | warn-log + `_maybeAlertRateLimitSkip({...})`; the cycle for that token is skipped | row stays in `queued` |
| I2 | `_maybeAlertRateLimitSkip(...)` | start timer on first skip; if skipped continuously past `rateLimitSkipAlertAfterMs` (60 s) → Slack alert; subsequent alerts throttled by `rateLimitSkipAlertRepeatMs` (10 min) | n/a |
| I3 | `_clearRateLimitSkipState()` | called on the next successful (non-skipped) cycle | resets the skip timer + last alert |

---

## J. Pre-accept failure (no row, no callback)

Triggered inside `claimCodeV2` before Rumble's redeem call commits state, or
when Rumble itself refuses.

| # | Trigger | Result | Next step |
|---|---|---|---|
| J1 | missing input | throw `ERR_INVALID_PARAMS` | client sees error, no row, no callback, no Rumble state |
| J2 | wallet address missing for chain | throw `ERR_USER_WALLET_NOT_FOUND` | same |
| J3 | Rumble 5xx / network / 0 | throw `ERR_PROMO_SERVICE_UNAVAILABLE` | client should retry |
| J4 | Rumble 4xx with `errorCode` | throw `<rumble-errorCode>` | client surfaces it (e.g. ALREADY_CLAIMED) |
| J5 | Rumble 2xx with no `claimId` | Slack alert (operator review), throw `ERR_PROMO_SERVICE_UNAVAILABLE` | mock/bug; no automatic action |

Nothing is persisted in the worker until Rumble returns a valid `claimId`.

---

## K. Post-accept failure (failed callback only, no broadcast)

Triggered inside `claimCodeV2` after Rumble returned a `claimId` but
something in the parsed response is wrong (bad amount format, unsupported
token, exceeds decimals, unsupported chain) or `insertPayout` throws.

| # | Method | What it does | Branch-out |
|---|---|---|---|
| K1 | `failPostAccept(reason)` | `_ensureCallback({kind: FAILED, ...})` + Slack alert | enqueues a failed callback so Rumble releases budget |
| K2 | throw `ERR_PROMO_SERVICE_UNAVAILABLE` | client sees a generic error | n/a |
| K3 | next cycle | **Happy step 8** dispatches the failed callback to Rumble | exits to **Flow G** if Rumble rejects it |

The row is never inserted (or the failed insert is the trigger itself), so
no on-chain activity happens for this claimId.

---

## Mental model in one line

> Two API surfaces (api worker + Rumble admin client). One persistent row
> per claim. Four loops own the four non-terminal states. Two
> sources-of-truth: the chain (`receipt.to` + `status`) and the row
> (`status` + `txHash` JSON + `broadcastedAt`). Every non-happy branch
> either re-enters the happy path or terminates the row with a single
> callback to Rumble — never both, never zero.
