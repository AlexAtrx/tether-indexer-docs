# Next steps for WDK-1315 — Rumble migration to clean orphaned lookups

**Ticket:** https://app.asana.com/1/45238840754660/project/1210540875949204/task/1213882531683489

> Ticket re-scoped on 2026-05-15 by Francesco. Direction confirmed by
> Vigan's review on 2026-05-16: drop the self-heal PR, write a migration.
> See [`STATUS.md`](./STATUS.md) for the full reasoning trail. Original
> triage notes are in
> [`NEXT-STEPS-original-triage.md`](./NEXT-STEPS-original-triage.md).

## What's settled

- The ork's `delLookupsForUser` cascade is already complete in both
  Mongo and autobase implementations (`STATUS.md` cites the exact lines).
  No structural bug.
- The `ERR_ADDRESS_ALREADY_EXISTS` symptom comes from **pre-existing
  orphans** in Rumble autobases left by historical issues (now fixed).
- Self-heal at validation time is the wrong shape — permanent tech debt
  scaffolding around a one-time data problem. Vigan's call to write a
  migration instead is correct.

## Plan

### 1. Withdraw / reshape PR #135

- [x] Convert `wdk-ork-wrk#135` to draft on 2026-05-16.
- [ ] Reply on the PR (or the Slack thread) agreeing with Vigan's framing
      and linking to the upcoming migration PR once opened.
- [ ] Before re-marking ready, revert the self-heal branch in
      `workers/api.ork.wrk.js` `_validateWalletExistence`. Keep the
      orphan-detection lookup (`getLookup(LOOKUP_TYPES.WALLETS, …)`) only
      if we decide we want a loud `ERR_ADDRESS_LOOKUP_ORPHANED` instead
      of silent self-heal — but the simpler decision is to revert
      entirely.
- [ ] Keep `tests/validate-wallet-existence.intg.test.js` from the branch.
      Flip the "self-heals orphaned mapping" assertion: the orphan must
      **throw** (locks the invariant; makes any future regression loud).

### 2. Write the migration in `rumble-ork-wrk`

Path: `migrations/autobase/2026-05-16_purge-orphaned-wallet-id-lookups.js`

Shape (modelled on `2025-11-26_normalize-wallet-addresses.js`):

- Stream every row in `@wdk-ork/wallet-id-lookups`.
- For each `(address, walletId)`, read `(WALLETS, walletId)` from
  `@wdk-ork/lookups`.
- If parent missing, delete the `wallet-id-lookups` row inside the
  migration's transaction.
- Idempotent — safe to re-run; on a clean shard it scans and deletes 0.
- Dry-run flag — first run reports counts (scanned / orphans / would-delete)
  without writing. Second run executes.
- Per-shard counters logged: shard id, total scanned, orphans found,
  orphans deleted.

### 3. Verify pre/post

- Use [`self-heal-repro.js`](./self-heal-repro.js) (scenario D seeds an
  orphan) as the migration's pre/post verification harness in a local
  autobase fixture.
- On rumble-staging, dry-run first; share the count with Vigan; run for
  real once approved.

## Open questions to confirm with Vigan before writing

- [ ] Migration runner: invoke manually per env, or hook into the autobase
      migration runner the way `2025-11-26_normalize-wallet-addresses.js`
      does?
- [ ] Should we also walk `@wdk-ork/lookups-address-by-wallet-id` (the
      inverse index) for orphans there, or is that strictly derived?
- [ ] After cleanup, should we add a startup/health check that fails fast
      if any orphan reappears, instead of (or in addition to) the test
      assertion? Cheap insurance.

## Evidence captured here

- 1 user comment in `comments.md` (Alex pasted the Slack PR-announcement link).
- 2 images analysed in `image-analysis.md` (Mongo screenshots from the
  original bug-report Slack thread).
- 1 non-image attachment under `attachments/` — original
  `slack-thread.txt`. The PR-review Slack thread is still not captured;
  see `missing-context.md`.
- `STATUS.md` documents the shipped-then-withdrawn ork-side fix and the
  decision to migrate instead.
- `self-heal-repro.js` reproduces the orphan condition; will be reused
  to verify the migration.

## Before starting work

1. Pull / paste the PR-review Slack thread (`p1778859257013279` /
   `p1778861994960789` in `C0A5DFYRNBB`) into
   `attachments/pr-review-slack-thread.txt` so Vigan's exact migration
   requirements are on record.
2. Confirm the open questions above with Vigan.
3. Start the migration in `rumble-ork-wrk/migrations/autobase/`.
