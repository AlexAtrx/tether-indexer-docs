# Root cause — WDK-1451

## TL;DR

Four placeholder hashes (`debug-1778082053217`, `…230306`, `…84251656`, `…84846161`) were pushed into the `txWebhook` queue from an external caller in a 46-minute window on **2026-05-06**. Neither the ork nor the shard validates that `transactionHash` is a 0x-hex hash before persisting, and the shard's webhook-processing cron has **no try/catch around the chain RPC call** — so each retry throws past the retry-policy code, `retryAt`/`retryCount` are never updated, and the same 4 records have been re-tried every cron tick for ~7 days. The actual error in Grafana is just the deepest log point of that loop.

## The exact call path of one error

1. Cron tick fires `_processTxWebhooksJob` every 10s on each shard proc (`rumble-data-shard-wrk/workers/proc.shard.data.wrk.js:71`).
2. `getTxWebhooks()` (`…/repositories/txwebhook.js`) yields docs from HyperDB collection `@wdk-data-shard/tx-webhooks` whose `status=PENDING` and `(!retryAt || retryAt <= now)`. All 4 placeholders match.
3. For the first yielded webhook, `_isTxCompleted(hook)` runs (`proc.shard.data.wrk.js:251`).
4. `isTransactionReceipt` is **false** on these records (the placeholder is in `transactionHash` directly, not in `transactionReceiptId`), so the gasless branch is skipped and `blockchainSvc.getTransactionFromChain('polygon', 'usdt', 'debug-…')` runs (`proc.shard.data.wrk.js:365`).
5. `blockchainSvc.getTransactionFromChain` (`wdk-data-shard-wrk/workers/lib/blockchain.svc.js:640`) issues an HRPC call to the USDT-POL indexer-api worker.
6. Indexer-api `getTransactionFromChain` (`wdk-indexer-wrk-base/workers/api.indexer.wrk.js:196`) calls `chainClient.getTransaction(hash)`.
7. `ChainErc20Client.getTransaction(hash)` (`wdk-indexer-wrk-evm/workers/lib/chain.erc20.client.js:94`) calls `_getTransactionReceipt(hash)`.
8. `_getTransactionReceipt` (`chain.erc20.client.js:65`) calls `this.provider.getTransactionReceipt(hash)` straight on the ethers main provider — the only provider used for this method, no `rpcManager.callWithSeed` wrap, no input validation.
9. Ethers POSTs `eth_getTransactionReceipt(["debug-1778082053217"])` to luganodes → RPC returns `-32602 invalid argument 0: json: cannot unmarshal hex string without 0x prefix into Go value of type common.Hash`.
10. Ethers wraps it as `Error: could not coalesce error (…)` → caught at `chain.erc20.client.js:84` → logged as `failed to get transaction receipt, Provider: luganodes` (the line we see in Grafana) → **rethrown**.
11. Error bubbles back through HRPC to the shard proc.
12. In `_isTxCompleted` (line 365), **no try/catch** → throws to `_processTxWebhooksJob` (line 251), which also has **no try/catch around `_isTxCompleted`** → the `for await (txHook of cursor)` aborts → caught by the outer `_runJob` wrapper (`wdk-data-shard-wrk/workers/proc.shard.data.wrk.js:725`) → logged `ERR_JOB_FAILED`, cron flag reset.
13. Next tick (10s later): same 4 records still PENDING, still no `retryAt` → step 2 yields them again. Loop forever.

## Two distinct defects, both required to produce the bug

### Defect A — no input validation when persisting webhooks
- `rumble-ork-wrk/workers/api.ork.wrk.js sendNotification` (line 292) and `sendNotificationV2` (line 420) accept `payload.transactionHash` from the caller verbatim. The only normalisation is line 204/308: `if (payload.transactionReceiptId) payload.transactionHash = payload.transactionReceiptId` — no format check on either field.
- `rumble-data-shard-wrk/workers/proc.shard.data.wrk.js storeTxWebhook` (line 428) checks `type` against `WEBHOOK_TYPES` but does not validate `transactionHash` against any chain-specific format before calling `txWebhookRepository.save(req)`.
- Result: any string the rumble-server sends as `transactionHash` ends up in HyperDB as a webhook record that the indexer will eventually try to fetch on-chain.

### Defect B — chain-RPC errors abort the cron with no retry-policy update
- `proc.shard.data.wrk.js _processTxWebhooksJob` (line 240–344) has try/catch only around the unit-of-work commits (lines 258–279 and 332–339). The outer `await this._isTxCompleted(txHook)` (line 251) and `await this.blockchainSvc.getTransactionFromChain(...)` inside it (line 365) are **uncovered**.
- When the chain RPC throws, the for-await aborts. The retry-policy block (lines 252–281) — which would `retryCount++`, set `retryAt = now + retryDelay`, or mark the record FAILED after `maxRetries` — is never reached. So:
  - `retryAt` stays undefined → `getTxWebhooks` keeps yielding the record every tick.
  - `retryCount` never increments → the FAILED branch never triggers.
  - The record is effectively immortal until a human drains it.
- `_runJob`'s catch (line 742) swallows the error so we don't crash, but the silent abort also means **legitimate webhooks queued after a poisoned record** can be held up depending on `@wdk-data-shard/tx-webhook-by-status` iteration order. This is the more dangerous half — confirmation of real rant/tip transfers may be lagging.

## Who produced the placeholders?

Not in this codebase. Grepped all `_INDEXER/*` repos for `'debug-' +`, `` `debug-${ `` , `"debug-`, `Date.now().*transactionHash`, etc. — **zero matches outside node_modules**. The four `debug-<Date.now()>` strings must come from a caller of the rumble-ork HRPC `sendNotification`/`sendNotificationV2` API. The most likely source is the **rumble-server monolith** (outside this repo) — a manual staging test or seed script run on 2026-05-06 ~15:40–16:27 UTC that fired four RANT notifications with `transactionHash` set to `` `debug-${Date.now()}` `` to avoid hash collisions across runs.

The pattern fits cleanly:
- 4 distinct values clustered in <1 hour → batch of 4 test calls
- Identical structural shape (`debug-` + 13-digit ms) → one code path generated all 4
- USDT POL only → the test was scoped to one token
- staging only → not prod

## Backing store, for the drain step

HyperDB collection: `@wdk-data-shard/tx-webhooks` (`rumble-data-shard-wrk/workers/lib/db/hyperdb/repositories/txwebhook.js:13`).
Secondary index: `@wdk-data-shard/tx-webhook-by-status`.
Local store dirs on `walletstg1`: `rumble-data-shard-wrk/store/wrk-data-shard-proc-shard-1/` (collection lives inside the shard proc's HyperDB).
Records are keyed on `transactionHash`, so the 4 stuck records are addressable by the strings above.

## What to change (minimum fix)

1. **Validate `transactionHash` at the boundary.** In `rumble-ork-wrk/workers/api.ork.wrk.js sendNotification`/`sendNotificationV2`, reject `transactionHash` that doesn't match the per-chain format (`/^0x[0-9a-fA-F]{64}$/` for EVM; per-chain regex otherwise) before calling `_addTxWebhook`. Same guard in `rumble-data-shard-wrk/workers/proc.shard.data.wrk.js storeTxWebhook` as a defense-in-depth check (and so direct shard callers can't bypass it).
2. **Wrap `_isTxCompleted` in a try/catch inside `_processTxWebhooksJob`.** On error, treat it like `{ retry: true, retryPhase: TX_HASH }` so the retry-policy block runs, `retryAt` is set, and `retryCount` increments. After `maxRetries`, the existing FAILED branch will permanently dispose of bad records instead of letting them churn for a week.
3. **Drain the 4 stuck records.** With the above guard in place, they can either be marked FAILED via a one-off script that opens HyperDB and calls `txWebhookRepository.updateStatus(hash, FAILED, Date.now())` for each, or simply mass-deleted from `@wdk-data-shard/tx-webhooks` on the staging shard proc. (Rumble-only change → must land in `rumble-data-shard-wrk`, never in a public `wdk-*` repo.)

## What this does NOT explain

- We see 4 hashes cycling rather than just the first one ordered by index. Either index ordering rotates between cron runs, or there are multiple shard procs in the staging cluster each at a different cursor position, or the `_runJob` flag occasionally lets two ticks interleave. Doesn't matter for the fix — all four are stuck by the same mechanism. Worth a 1-line note in the PR description but not a blocker.

## File references

- `rumble-data-shard-wrk/workers/proc.shard.data.wrk.js:240` — `_processTxWebhooksJob` (the abort point)
- `rumble-data-shard-wrk/workers/proc.shard.data.wrk.js:251` — uncovered `_isTxCompleted` call
- `rumble-data-shard-wrk/workers/proc.shard.data.wrk.js:346` — `_isTxCompleted`
- `rumble-data-shard-wrk/workers/proc.shard.data.wrk.js:428` — `storeTxWebhook` (no hash validation)
- `rumble-data-shard-wrk/workers/lib/db/hyperdb/repositories/txwebhook.js:13` — HyperDB collection name
- `rumble-ork-wrk/workers/api.ork.wrk.js:204` / `:308` / `:350` / `:361` / `:442` / `:454` — ork webhook write paths, no hash validation
- `wdk-indexer-wrk-base/workers/api.indexer.wrk.js:196` — indexer-api `getTransactionFromChain`
- `wdk-indexer-wrk-evm/workers/lib/chain.erc20.client.js:65` — `_getTransactionReceipt`, logs the line we see
- `wdk-data-shard-wrk/workers/proc.shard.data.wrk.js:725` — `_runJob` wrapper that catches and resets
