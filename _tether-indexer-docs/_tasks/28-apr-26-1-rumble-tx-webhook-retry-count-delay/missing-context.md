# Missing context

The ticket itself is short and points entirely at two external references that are NOT included in this folder. Both are required reading before starting the work.

## External links to review

- [x] **GitHub PR #179 + review comment `r2959235681`**: pulled into `github-pr.md` on 2026-04-28. PR is merged (2026-03-30). Comment by Usman on `workers/proc.shard.data.wrk.js:241` — entries without `retryCount` get processed indefinitely; needs to be fixed alongside the status-column work that #179 introduced.

- [x] **Slack thread**: pasted into `slack-thread.md` on 2026-04-28. Confirms per-blockchain config approach; floats `15s × 10` for ETH-class chains and `5m × 10` for BTC. Discard-policy and flat-vs-exponential not fully nailed down — see notes in `slack-thread.md`.

## Implicit gaps

- [ ] **Where does the retry loop live?** Description and Slack thread point at `_processTxWebhook` calling `blockchainSvc.getTransactionFromChain`, which currently returns `{ isCompleted: false, transaction: null }` whenever the indexer returns `[]` (both unconfirmed and non-existent hashes via `getTransactionByHash`). Need to find this in `rumble-data-shard-wrk` and the existing `gaslessMaxRetries` / `gaslessRetryDelay` handling that we'll mirror. PR #179 is the entry point.

- [ ] **Full chain list.** Slack thread only gave examples (ETH-class, BTC). Need the complete list of chains Rumble supports so each gets a concrete `retryCount` / `retryDelay`. Likely derivable from existing per-chain config files in the data-shard worker.

- [ ] **Discard policy.** Once retries are exhausted: mark the webhook stale, delete it, emit a metric, alert? Not explicitly stated — look at how the gasless path drops exhausted entries and mirror.

- [ ] **Flat vs exponential.** Francesco said "ideally exponential" but the concrete numbers floated were flat. Confirm with him before implementing.
