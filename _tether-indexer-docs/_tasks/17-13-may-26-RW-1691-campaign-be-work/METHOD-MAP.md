# RW-1691 — file + method map

Quick reference for a live review. One line per method.

Repo: `tetherto/rumble-promo-wrk`, branch `feat/rw-1691-campaign-builder-v2` (PR #46).

## workers/api.promo.wrk.js
- `claimCodeV2(req)` — validate `{code, userId, clientIp, wallet}`, forward to proc via HRPC, return what proc returns

## workers/proc.promo.wrk.js
- `claimCodeV2({...})` — resolve wallet address, call Rumble's redeem, validate the response, insert the payout row, return `{claimId, ..., status: 'received'}`
- `_processV2Payouts()` — every 5s per token: rate-limit gate, balance check, atomic queued→paying with assigned nonces, sign + broadcast in parallel
- `_recoverStuckV2Payouts()` — stale `paying` rows: receipt → mined/failed, mempool-hit → broadcast, retries exhausted → cancel, else resubmit
- `_observeBroadcastedV2Payouts()` — stale `broadcast` rows: receipt → settled/failed, dropped → rollback to paying with retries++, pending past cap → cancel
- `_finalizeCancellingV2Payouts()` — stale `cancelling` rows: payout-tx mined → settled, cancel-tx mined → failed, else rebroadcast cancel with bumped fees
- `_classifyHashes(hashes)` — return the first conclusive receipt across the row's hashes, tagged `payout` or `cancel` by `receipt.to`
- `_resolveClassifiedReceipt(p, classified, phase)` — apply mined+settled / failed / failed-on-cancel based on the classifier output
- `_broadcastPayoutTx({...})` — sign → persist hash → broadcast (the durability invariant)
- `_broadcastCancelTx({...})` — same shape for a 0-value self-transfer cancel
- `_resubmitPayout(p, hashes)` — re-broadcast at the same nonce with bumped fees (max of fresh estimate vs 1.5× last)
- `_cancelExhaustedPayout(p, hashes)` — broadcast a same-nonce cancel seeded by highest-fee live tx, flip row to `cancelling`
- `_findHighestFeeKnownTx(hashes)` — pick the live tx with highest fee to seed `lastTx` so the cancel beats replacement-underpriced
- `_ensureCallback(params)` — enqueue a settled/failed callback; convert opposite-kind conflict into a Slack alert
- `_ensureV2Balance({token, payouts})` — verify native + token balance before signing; throws if low/insufficient
- `_reconcileV2MissingCallbacks()` — backfill missing settled callbacks from MINED rows and failed callbacks from FAILED rows
- `_dispatchV2Callbacks()` — pull due callbacks, POST to Rumble; mark delivered + payout → notified, else reschedule with exponential backoff, else dead-letter
- `_maybeAlertRateLimitSkip` / `_clearRateLimitSkipState` — throttled Slack alert for persistent rate-limit skips
- `_collectV2Metrics()` — periodic log with wallet balances and per-status counts

## workers/lib/wallet.bot.evm.v2.js
- `loadSeedPhrase()` — read seed from Hyperbee key `seedPhraseV2`; generate fresh if absent
- `initialize()` — derive EVM account from seed via WDK
- `signTransfer({token, to, amount, nonce}, gas)` — local ERC-20 transfer signing, returns `{signed, hash}`
- `signCancel({nonce, lastTx})` — local 0-value self-transfer; bumps fees off `lastTx` for replacement-underpriced
- `broadcast(signed)` — provider `broadcastTransaction`
- `getTransaction(hash)` — provider knows tx (pending or mined)
- `getTransactionReceipt(hash)` — final status (1 success / 0 revert) after mining
- `getBalance()` / `getTokenBalance(token)` — wallet balances

## workers/lib/queries/payouts.v2.js
- `insertPayout` — INSERT OR IGNORE on claimId; idempotent
- `getQueuedPayouts` / `getStuckPayingPayouts` / `getStaleBroadcastedPayouts` / `getStuckCancellingPayouts` — selectors per state, with stale threshold
- `batchUpdatePayoutsToPaying` — atomic queued→paying with assigned nonces
- `appendAttemptHash` — push a hash into the row's JSON array (called before broadcast)
- `setPayoutBroadcast` — paying→broadcast + stamp `broadcastedAt`
- `setPayoutMined` — broadcast→mined (status=1 receipt observed)
- `setPayoutNotified` — mined→notified (settled callback delivered)
- `setPayoutCancelling` — paying/broadcast→cancelling
- `setPayoutFailed` — terminal failure
- `rollbackBroadcastToPaying` — broadcast→paying + retries++ (dropped from mempool)
- `recordPayoutAttempt` / `recordCancelAttempt` — retry counters + lastError
- `parseTxHashes` — JSON array helper for the `txHash` column
- `getMaxPayoutNonce` — boot-time nonce recovery
- `getPayoutsMissingCallback` — used by the reconciler

## workers/lib/queries/payout_callbacks.v2.js
- `ensureEnqueued` — INSERT OR IGNORE on `UNIQUE(claimId, kind)`; throws `ERR_CALLBACK_CONFLICT` if opposite kind already exists
- `getDue` — pending callbacks past `nextAttemptAt`
- `markDelivered` / `markDead` / `reschedule` — outbox lifecycle
- `gatherMetrics` — counts grouped by kind/status for the metrics tick

## workers/lib/rumble.admin.client.js
- `_sign(payload)` — HMAC-SHA256(secret, timestamp + payload)
- `_post(path, body)` — add `x-signature` / `x-signed-on` headers; normalize errors to `{status, body}`
- `redeem({code, userId, clientIp})` — POST to Rumble's claim endpoint (called from `claimCodeV2`)
- `settled({claimId, txHash, walletAddress})` — success callback (sent after mined receipt)
- `failed({claimId, reason, walletAddress})` — failure callback (sent for revert / dropped / pre-broadcast / pending-too-long)

## workers/lib/schema.js
- `SCHEMA_SQL` — CREATE TABLE for `promo_payouts_v2` (status, nonce, txHash JSON array, `broadcastedAt`, retries) and `promo_payout_callbacks_v2` (UNIQUE(claimId, kind))

## workers/lib/constants.js
- `PAYOUT_STATUSES_V2` — queued / paying / broadcast / mined / notified / cancelling / failed
- `CALLBACK_KINDS_V2` — settled / failed
- `CALLBACK_STATUSES_V2` — pending / delivered / dead
