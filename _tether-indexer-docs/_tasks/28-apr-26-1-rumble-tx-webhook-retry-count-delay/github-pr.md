# GitHub PR #179 — context for this ticket

Repo: `tetherto/rumble-data-shard-wrk`
PR URL: https://github.com/tetherto/rumble-data-shard-wrk/pull/179
Title: **save txwebhooks upon completion/instead of deletion**
Author: `SargeKhan` (Usman)
Branch: `feat/save_tx_webhook_status` → `dev`
State: **MERGED** on 2026-03-30 (created 2026-03-03)
Size: +194 / -44 across 11 files
Body: empty

## Why this PR matters for our ticket

PR #179 reworked the tx-webhook lifecycle to **stop deleting** rows on terminal states and instead persist a `status` column (PENDING / FAILED / COMPLETED). It also **removed the `retryAt`-based skip** in the iteration loop. During review, Usman flagged that there are still entries which never get a `retryCount` incremented — so they stay PENDING forever. That gap is what RW-1525 / WDK-1344 has to close.

## The review comment that spawned RW-1525

- Comment: https://github.com/tetherto/rumble-data-shard-wrk/pull/179#discussion_r2959235681
- Author: `SargeKhan` (Usman) — 2026-03-19 10:52 UTC
- File: `workers/proc.shard.data.wrk.js` line 241 (left side, on the deleted block)

> i've noticed that there are some entries that don't have retryCount and result in processing of those transactions indefinitely. We should fix both issues together. More details: https://tether-to.slack.com/archives/C0A5DFYRNBB/p1773915817050799

## Diff hunk the comment is anchored to (`workers/proc.shard.data.wrk.js`)

The PR removed the `retryAt`-gated skip:

```diff
     this.logger.info('processTxWebhooks: starting iteration')
     let processedCount = 0
-    let skippedCount = 0

     for await (const txHook of cursor) {
-      const now = Date.now()
-      if (txHook.retryAt && txHook.retryAt > now) {
-        skippedCount++
-        this.logger.info(`processTxWebhooks: skipping ${txHook.transactionHash}, retryAt=${txHook.retryAt}`)
-        continue
-      }
-
       processedCount++
```

…and replaced terminal `del` calls with status updates:

```diff
       if (retryCount >= this.gaslessMaxRetries) {
-        await uow.txWebhookRepository.del(txHook.transactionHash)
+        await uow.txWebhookRepository.updateStatus(txHook.transactionHash, TX_WEBHOOK_STATUS.FAILED, Date.now())
         this.logger.error(
-          `Max retries exceeded for ${txHook.transactionHash}, marking as deleted`
+          `Max retries exceeded for ${txHook.transactionHash}, marking as failed`
         )
       } else {
-        // schedule retry
         await uow.txWebhookRepository.save({
           ...txHook,
+          status: TX_WEBHOOK_STATUS.PENDING,
           retryCount,
           retryAt
         })
```

…and on the completion path:

```diff
-      await uow.txWebhookRepository.del(txHook.transactionHash)
+      await uow.txWebhookRepository.updateStatus(txHook.transactionHash, TX_WEBHOOK_STATUS.COMPLETED, Date.now())
```

Also adds `req.status = TX_WEBHOOK_STATUS.PENDING` on insert.

## Key files touched (relevant to the follow-up fix)

- `workers/proc.shard.data.wrk.js` (+8 / -14) — the iteration / retry / status-update logic to extend.
- `workers/lib/utils/constants.js` (+8 / -1) — `TX_WEBHOOK_STATUS` enum landed here; this is also where new per-chain `retryCount` / `retryDelay` constants likely belong.
- `workers/lib/db/base/repositories/txwebhook.js`, `workers/lib/db/hyperdb/repositories/txwebhook.js`, `workers/lib/db/mongodb/repositories/txwebhook.js` — gained the `updateStatus` method and a `status`-aware listing.
- HyperDB schema bumps under `workers/lib/db/hyperdb/spec/...` — adding the `status` field. **Reminder per repo conventions: any new HyperDB field must be appended at the end of the schema, never inserted.** If we add anything (e.g. `lastTriedAt`, per-chain config persisted on the row), follow the same rule.

## Implications for RW-1525 / WDK-1344

1. The PR already gives us a place to write `FAILED` to (the status column). The follow-up needs the **tx-hash** code path (the one that today returns `{ isCompleted: false, transaction: null }` from `blockchainSvc.getTransactionFromChain`) to actually increment `retryCount` and respect a per-chain max — mirroring how the gasless path already does it via `gaslessMaxRetries`.
2. Per-chain values likely belong alongside `gaslessMaxRetries` / `gaslessRetryDelay` in `constants.js` (or wherever those are sourced — confirm at implementation time).
3. Once max retries hit, set `status = FAILED` (don't `del`) for parity with PR #179's new contract.
