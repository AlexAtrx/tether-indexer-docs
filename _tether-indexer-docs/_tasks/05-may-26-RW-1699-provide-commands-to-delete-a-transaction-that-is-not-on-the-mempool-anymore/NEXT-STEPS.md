# Next steps for RW-1699 — delete a stuck pending tx

**Ticket:** https://app.asana.com/1/45238840754660/project/1210540875949204/task/1214518529430430

## What we know
- Andrei is seeing repeated `ERR_GET_TX_FROM_CHAIN_FAILED` / `[HRPC_ERR]=No such mempool or blockchain transaction` errors for a single BTC tx hash: `86e0c91ed20fccebf415f1fd201ba066549094fde793235818cc7cc335109e4a`.
- The hash is not on mempool.space — Francesco's hypothesis is that it was underpriced and dropped out of the mempool.
- Two asks in this ticket:
  1. **Ops:** a command Andrei can run in prod to safely delete the one pending tx.
  2. **Code fix:** stop polling for a pending tx after N retries / T time, so this can't happen again.
- Francesco assigned this to Alex on 2026-05-04 because he didn't know the delete command off the top of his head.

## Evidence captured here
- 0 images analysed.
- 0 non-image attachments.
- 0 user comments (only system events: project add, assign, project add).
- Description contains the Slack chat verbatim and a log block (the log block is generic worker heartbeat, NOT the failing-tx error log).

## What's missing (from `missing-context.md`)
- Slack permalink and channel for the original thread.
- The actual error log lines for the failing hash (with wallet id / account id / worker name / retry count).
- Confirmation of chain (presumed BTC mainnet) and which wallet/account holds the stuck tx.
- Which repo + DB owns pending-tx state for BTC in Rumble, and which env/box Andrei should run the command from.
- Confirm whether the retry-cap code fix is in scope of RW-1699 or a separate ticket.

## Before starting work
Ask Alex first:
1. Slack thread link.
2. Which env hit this — staging (the log dump is from `tether-wallet-stg-0`) or production (the description says "execute in production")?
3. Which wallet/account is this for — so we know which HyperDB / app-node / shard to inspect.
4. Is RW-1699 scoped to just the ops command, or also the retry-cap fix?

Once answered, the path is:
- Locate the pending-tx record(s) in the BTC indexer / wallet HyperDB by hash.
- Draft a one-shot script (no schema mutation, append a deletion record) that Andrei can run, plus the read-only verification command to confirm the tx is gone.
- Separately scope the retry-cap fix in the BTC tx-watcher (likely in `wallet-pay-btc` or the rumble-side polling loop) — open a follow-up ticket if not already covered.
