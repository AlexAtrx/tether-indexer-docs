# Next steps for Fix `getTransactionFromChain` infinite retries when erroring

**Ticket:** https://app.asana.com/1/45238840754660/project/1210540875949204/task/1214518529430430
**RW:** RW-1699 · **WDK:** WDK-1399 · **Priority:** High · **Sprint 1**

## What we know

- Andrei (production-side, Rumble) is seeing repeated `ERR_GET_TX_FROM_CHAIN_FAILED` log spam for BTC tx `86e0c91ed20fccebf415f1fd201ba066549094fde793235818cc7cc335109e4a`.
- The tx is no longer in the mempool (mempool.space confirms not found). Most likely cause: it was underpriced and got evicted.
- Francesco originally framed this as "give Andrei a command to delete the pending tx record". On 2026-05-08 he renamed/refocused the ticket onto the underlying bug: `getTransactionFromChain` should not retry forever when the chain says the tx is unknown.
- A retry cap already exists at `tetherto/rumble-data-shard-wrk` `workers/proc.shard.data.wrk.js:259` (~50min for BTC), but it only triggers when the chain client returns `{retry:true}` — it isn't firing here because `getTransactionFromChain` throws instead.
- Francesco told Andrei to ignore the errors in the meantime.

## Evidence captured here

- 1 image analysed in `image-analysis.md` — **none, no screenshots on the ticket**
- 0 non-image attachments under `attachments/`
- 1 real comment in `comments.md` (Alex's questions back to Francesco), plus a handful of system events for context (assignment, section move, name change, priority change)

## What's missing (from `missing-context.md`)

- Full Slack thread — only the inline quotes copied by Francesco are here.
- Actual error log block for the failing tx (description has level-30 "finished processing" lines that don't include the error).
- Wallet / user / shard id for `86e0c91e…` (asked Francesco, no reply yet).
- Format decision: one-shot script for Andrei vs. admin RPC on the proc worker.
- Pin the exact file/function where `getTransactionFromChain` throws instead of returning `{retry:true}`.

## Before starting work

When this ticket is re-opened for implementation, **ask Alex / Francesco for the items above before touching code**:

1. Wallet/user/shard id for the failing tx (blocks the delete command).
2. Decision on script vs. admin RPC (changes the shape of the fix).
3. Confirmation that the same retry path is the right place to convert thrown "tx not found" errors into `{retry:true}` so the existing 50-min cap kicks in.

Once those are answered:

- Pin the throw site in `rumble-data-shard-wrk` (or in the wrapping wallet-lib client) via Grep for `getTransactionFromChain` and `ERR_GET_TX_FROM_CHAIN_FAILED`.
- Verify the retry-loop logic at `proc.shard.data.wrk.js:259` and confirm `{retry:true}` is what the surrounding code expects.
- Decide whether "tx not found in mempool/chain" should be retried at all, or short-circuit straight to a terminal `failed` state.
- Write the one-off delete command in parallel with the fix so Andrei is unblocked.
