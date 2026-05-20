# Status — 2026-05-16

Root cause confirmed. Original fix shape was wrong; pulling the self-heal PR
back to draft and replacing it with a Rumble-side migration per Vigan's
review.

## TL;DR

- `purgeUserData` in `wdk-ork-wrk` is **already correct** on `main`. The
  autobase `delLookupsForUser` cascades `lookups-by-user` → walletIds →
  addresses and removes the matching `@wdk-ork/wallet-id-lookups` rows
  (`workers/lib/db/autobase/lookup.storage.js:50-75`). The Mongo impl does
  the same (`workers/lib/db/mongodb/lookup.storage.js:161-183`).
- The `ERR_ADDRESS_ALREADY_EXISTS` Vigan/Ashot hit on rumble-staging was
  caused by **pre-existing orphans** in `@wdk-ork/wallet-id-lookups` (rows
  whose `walletId` has no parent `(WALLETS, walletId)` row in `@wdk-ork/lookups`,
  so `lookups-by-user` can never reach them).
- Source of those orphans is historical: prior `purgeUserData` bugs (now
  fixed), the migration `rumble-ork-wrk/migrations/autobase/2025-11-26_normalize-wallet-addresses.js`,
  or partial-crash / manual mongo edits.
- **Correct fix:** a one-shot Rumble migration that scans
  `@wdk-ork/wallet-id-lookups` and deletes rows whose `walletId` has no
  parent `(WALLETS, walletId)` row in `@wdk-ork/lookups`.

## Pull request — withdrawn

- `wdk-ork-wrk#135` — https://github.com/tetherto/wdk-ork-wrk/pull/135 —
  added a self-heal branch in `_validateWalletExistence` that cleared
  orphans on every failed `addWallet`. **Converted to draft on 2026-05-16**
  after Vigan pointed out that the cascade is already complete on `main`
  and that self-heal is permanent tech debt scaffolding around a one-time
  data problem. The branch is preserved for the integration test, but the
  self-heal logic itself will be reverted before the migration ships.

## Vigan's review (the call that changed direction)

> "hmm Alex afaik we remove all lookups no? […] I assume the case is in
> rumble due to previous bugs in purgeUserData that are fixed, in that
> case I would suggest we write a migration to clean these orphaned
> lookups rather than adding more tech debt."

He's right. Verified by reading the three files he linked:

- `workers/api.ork.wrk.js:304` — `purgeUserData` calls
  `lookupStorage.delLookupsForUser(req.userId)`.
- `workers/lib/db/mongodb/lookup.storage.js:161-183` — Mongo impl deletes
  user `lookups` rows then deletes `walletLookups` for each collected
  walletId.
- `workers/lib/db/autobase/lookup.storage.js:50-75` — Autobase impl
  streams `lookups-by-user`, deletes from `lookups`, then for each WALLETS
  walletId streams `lookups-address-by-wallet-id` and deletes the matching
  addresses from `wallet-id-lookups`.

The cascade IS complete. My earlier write-up was sloppy — I claimed the
cascade was structurally fragile. It isn't. It just can't reach orphans
that were already present **before** it ran (no parent → no entry in
`lookups-by-user` → unreachable).

## What we thought it was (and isn't)

- **Vigan's original Slack diagnosis** ("if user gets assigned to same
  shard then we don't reset deletedAt to 0") was an accurate observation
  of one of the symptoms on the shard side, but is not the cause of
  `ERR_ADDRESS_ALREADY_EXISTS`. The ork's address dedup (`wallet-id-lookups`)
  has no `deletedAt` column.
- **First theory** (iterator-and-mutate hazard inside `delLookupsForUser`)
  was refuted by `self-heal-repro.js` in this folder.
- **Counter-agent's theory** (`updateLastActiveToToday` preserves
  `deletedAt` on re-onboarding in `wdk-data-shard-wrk`) is a real bug but
  explains a different symptom. Filed as a separate follow-up below.
- **My self-heal PR** addressed the symptom but at the wrong layer —
  papering over orphans on read instead of cleaning them once at the
  source. Withdrawn.

## Actual root cause (confirmed, unchanged)

`@wdk-ork/wallet-id-lookups` is a flat `address -> walletId` map. Rows
that have a `walletId` with no matching `(WALLETS, walletId)` row in
`@wdk-ork/lookups` cannot be reached by `delLookupsForUser` (which is
keyed off `lookups-by-user`). The fix is to remove those orphan rows
once via migration; future creation paths are already consistent.

Empirically pinned via `self-heal-repro.js` in this folder: scenario D
seeds an orphan and confirms validation throws `ERR_ADDRESS_ALREADY_EXISTS`
against the **pre-patch** code (which is what `main` is again now that the
PR is being withdrawn).

## What lands instead

### rumble-ork-wrk (new — not yet written)
- `migrations/autobase/2026-05-16_purge-orphaned-wallet-id-lookups.js`
  (working title) — scan every row in `@wdk-ork/wallet-id-lookups`, look
  up `(WALLETS, walletId)` in `@wdk-ork/lookups`, delete the row if the
  parent is missing. Idempotent, dry-run-first, per-shard counts logged.

### wdk-ork-wrk (revisit on the PR-135 branch)
- Revert the `_validateWalletExistence` self-heal change in
  `workers/api.ork.wrk.js`.
- Keep `tests/validate-wallet-existence.intg.test.js`, but flip the
  "self-heals orphaned mapping" case to assert the orphan **throws**.
  This locks the invariant: "every `wallet-id-lookups` row has a parent
  in `lookups`" — and makes any future drift loud rather than silent.

## Diagnostic artefacts kept in this folder

- `self-heal-repro.js` — standalone node script reproducing the orphan
  state. Will be reused as the migration's pre/post verification harness.
- `attachments/slack-thread.txt` — the originating Slack discussion.
- `images/mongo-shard-w_2_*.png` — Mongo screenshots of the dirty shard state.

## Out of scope — separate follow-ups

These are real correctness bugs that surfaced during the investigation but
do not produce `ERR_ADDRESS_ALREADY_EXISTS`. They should each get their
own ticket / PR.

- `wdk-ork-wrk/workers/lib/data.shard.util.js` — `user-shard:${userId}`
  LRU is not invalidated on `purgeUserData`. After purge, the in-memory
  cache can still route to the previous shard until eviction.
- `wdk-data-shard-wrk/workers/lib/db/hyperdb/repositories/users.js#updateLastActiveToToday`
  — preserves `deletedAt` on save (both the early-return branch and the
  `...user` spread). A purged user who re-onboards on the same shard stays
  `deletedAt > 0`, making them invisible to `getActiveUsers` and downstream
  cron jobs.
- Decide with Vigan/Francesco whether to flip `saveWalletIdLookup` /
  `saveWalletIdLookupBatch` from first-write-wins to upsert. Not needed
  for this fix, but the first-write-wins semantic is what lets a stale
  entry stay sticky once it exists.
