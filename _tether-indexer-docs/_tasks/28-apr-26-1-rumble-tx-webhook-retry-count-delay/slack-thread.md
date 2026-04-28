# Slack thread — context for retryCount/retryDelay

Channel: `C0A5DFYRNBB` · Thread ts: `1773915817050799`
Link: https://tether-to.slack.com/archives/C0A5DFYRNBB/p1773915817050799
Pasted by Alex on 2026-04-28.

---

**Usman Khan** [11:23 AM]
Problem: The current behavior of processing webhooks in rumble backend results in certain webhooks remaining stuck indefinitely in the `processTxWebhook` job. Details in thread:

> 10 replies

**Usman Khan** [11:52 AM] — Details

This happens when user creates a webhook with `transactionHash` that is invalid or doesn't exist on the blockchain. In the code here, after calling the `blockchainSvc.getTransactionFromChain` function, we always return `{ isCompleted: false, transaction: null }`, which results in the `_processTxWebhook` job never updating the state of this webhook, resulting in this particular webhook remaining stuck. **I noticed 1 webhook that still exists in the staging env from 2 months ago.**

Note that in case user provides a `transactionReceipt`, we don't run into this issue because we define `gaslessMaxRetries` and `gaslessRetryDelay` that define when and how many times the system will try to process this webhook.

**Proposed solution:** Similar to the scenario where users provide `transactionReceipt` / UserOp hash, we should retry only a certain number of times before ignoring this transaction.

**Question:** What should be the `retryDelay` and `maxRetries` values in this scenario? Block processing speed varies based on the blockchain. Should we define separate `retryDelay` and `maxRetries` for each blockchain we use, or can we use 1 value for all different blockchains?

CC: @Francesco C. @Vigan

---

**Francesco C.** [11:54 AM]
What's the failure we get from the blockchain node? Maybe if we get a failure where we are sure that it's a failure we should just delete the entry.

[11:55] Ideally if we go to retry route the retries should be exponential.

[11:55] BTC could take 2h+ for example if gas spikes.

[11:56] But if it's just for processing webhooks maybe we can ignore anything that takes long.

[11:56] If we want to keep the same logic:

> retry delay **15s** — max retries **10** would work for all blockchains including ETH
> for BTC probably retry delay **5m** — max retries **10**

---

**Usman Khan** [11:57 AM]
Indexers simply return an empty array `[]` when:
a) the transaction isn't yet confirmed
b) a non-existent hash is used

The RPC method called from data-shard to indexers is `getTransactionByHash`.

[11:58] So you suggest we define blockchain-specific delay and retry count?

---

**Francesco C.** [12:01 PM]
Probably that's the simplest approach.

---

## Decisions extracted

- **Approach:** mirror the existing `gaslessMaxRetries` / `gaslessRetryDelay` pattern used for `transactionReceipt` / UserOp hashes, but applied to the `transactionHash` path.
- **Per-blockchain config**, not a single global value (Francesco confirmed).
- **Default values floated in thread:**
  - ETH (and similar fast chains): `retryDelay = 15s`, `maxRetries = 10`
  - BTC: `retryDelay = 5m`, `maxRetries = 10`
- **Trigger condition:** indexer returns empty array `[]` from `getTransactionByHash` — both for unconfirmed and non-existent hashes. (Note: this means the retry loop currently can't distinguish "pending" from "garbage hash", so the cap is the only safety net.)
- **Retry shape:** Francesco preferred exponential, but the agreed concrete numbers in the thread are flat (15s × 10 / 5m × 10). Worth confirming whether to implement flat or exponential — the thread doesn't fully resolve this.
- **Discard policy after exhaustion:** still not explicitly nailed down. Implication is "ignore" (drop / mark stale), matching how the gasless path treats exhausted retries. Confirm against the gasless implementation when scaffolding.
