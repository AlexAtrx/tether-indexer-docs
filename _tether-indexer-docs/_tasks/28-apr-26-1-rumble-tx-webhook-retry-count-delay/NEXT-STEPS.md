# Next steps for Rumble tx-webhook retryCount/retryDelay (RW-1525 / WDK-1344)

**Ticket:** https://app.asana.com/1/45238840754660/project/1210540875949204/task/1213868590256377

## What we know
- Tx webhooks in Rumble have two code paths: one for **`transactionReceipt` / UserOp hash** (already capped via `gaslessMaxRetries` / `gaslessRetryDelay`) and one for **`transactionHash`** (no cap — retries forever, never discarded). One stuck webhook from 2 months ago was already observed in staging.
- Trigger: `_processTxWebhook` calls `blockchainSvc.getTransactionFromChain`, which returns `{ isCompleted: false, transaction: null }` whenever the indexer's `getTransactionByHash` returns `[]`. That happens both for *unconfirmed* and for *non-existent* hashes — so the retry loop can't tell them apart, the cap is the only safety net.
- Fix: mirror the gasless retry pattern for the tx-hash path, **per blockchain** (Francesco confirmed in Slack).
- Concrete values floated in Slack: ETH-class `15s × 10`, BTC `5m × 10`. Francesco said exponential is "ideal" but the agreed numbers are flat — confirm before implementing.
- Gated by `tetherto/rumble-data-shard-wrk` PR **#179**, comment `r2959235681`.
- Currently assigned to Alex (Vigan re-assigned 2026-04-14). Sprint 1, High priority, In Progress on the board.

## Evidence captured here
- 0 images analysed (no attachments)
- 0 non-image attachments
- 1 user comment + 9 system events recorded in `comments.md`
- Slack thread pasted in `slack-thread.md` (Usman / Francesco / Vigan, 2026-03 dated thread)
- GitHub PR #179 metadata, review comment, and the `proc.shard.data.wrk.js` diff hunk in `github-pr.md`

## What's still missing (from `missing-context.md`)
- Full chain list — Slack only named ETH-class and BTC; need every chain Rumble supports
- Discard policy: PR #179 already established `status=FAILED` on max retries, so we likely just write FAILED for parity. Confirm this is the intended terminal state for the tx-hash path.
- Confirmation: flat retries (matching the floated numbers) vs exponential (which Francesco said was "ideal")

## Before starting work
1. ~~Re-read the diff in `github-pr.md` and pull `workers/proc.shard.data.wrk.js` from the merged PR #179 to see the current shape of the iteration / retry block.~~ **Done 2026-04-28** — see "Post-merge state" section in `github-pr.md`. Key finding: the tx-hash path in `_isTxCompleted` (lines 356–373) never returns `retry: true`, so on a missing/unconfirmed tx the loop's retry block doesn't run and the hook stays `PENDING` forever. The loop's retry block currently hard-codes `this.gaslessMaxRetries` / `this.gaslessRetryDelay` for every retry.
2. In `rumble-data-shard-wrk`, locate `_processTxWebhook`, `blockchainSvc.getTransactionFromChain`, and the existing `gaslessMaxRetries` / `gaslessRetryDelay` config — that's the template to mirror.
3. Enumerate the supported chains and propose per-chain `retryCount` / `retryDelay` (likely add to `workers/lib/utils/constants.js` next to `TX_WEBHOOK_STATUS`). Use Slack values as starting points (ETH-class `15s × 10`, BTC `5m × 10`) and ping Francesco to confirm flat-vs-exponential before coding.
4. On max retries, write `TX_WEBHOOK_STATUS.FAILED` via `updateStatus` (don't `del`) — matches PR #179's new contract.
5. If we need a new HyperDB field (e.g. `lastTriedAt`), append at the end of the schema — never insert in the middle.
