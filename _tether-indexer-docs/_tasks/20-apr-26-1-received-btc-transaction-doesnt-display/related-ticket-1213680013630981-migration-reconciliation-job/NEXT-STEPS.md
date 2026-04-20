# Next steps for "[Backend] Migration Reconciliation Job" (RW-1409)

**Ticket:** https://app.asana.com/1/45238840754660/project/1212521145936484/task/1213680013630981

## What we know
- **Scope (Asana requirements):** BE job that diffs the wallet addresses the FE recreated during old-app → new-version migration against the addresses the BE has stored. The BE never overwrites stored addresses, so whenever the FE's re-derived address differs from the stored one, the two sides silently diverge. Report should contain `UserId, WalletID, Wallet Name, Wallet type, Account index, Backend address, Frontend address, Reconciliation status` plus aggregate metrics.
- **What's actually built so far:** PR [`tetherto/wdk-data-shard-wrk#192`](https://github.com/tetherto/wdk-data-shard-wrk/pull/192) — an *initial-phase* script, narrower than the Asana requirements. It checks only two `accountIndex` anomalies:
  1. `unrelated` wallets with `accountIndex != 0` (unrelated wallets that got a wrong account index during migration).
  2. `user` wallets with `accountIndex = 100` (sentinel/default value that shouldn't exist in production).
  This is **not** a full FE-vs-BE address diff. It does not compare addresses at all.
- **Review trajectory:** Reviewers requested — Vigan, Usman Khan, Francesco C., Eddy WM. Usman Khan reviewed twice; Alex rewrote to "a more practical flow" between passes; Usman's final comment was "reviewed, I don't think the comments need to be fixed, but would simplify the code further IMO". No explicit merge event captured.
- **Deployment:** script is designed to run on staging (where the migration took place). Alex's open question in Slack — *"Who can do this and get us the results?"* — is unanswered.
- **Mismatch policy (requirements, not implementation yet):** users with zero balance are zero-risk; users with a balance on the BE address are at-risk.
- **Alex's alternative plan (stated in Slack):** if the reconciliation effort is deemed unnecessary, the fallback is to have the app team only display addresses that are registered with the backend — which would symptomatically fix the parent BTC-tx ticket without requiring reconciliation output.
- Status: "In-Progress" in Asana since 2026-03-23. Fix Version (FE) RW 2.0.4 (bumped from 2.0.2 on 2026-04-01).

## Why this is relevant to the parent BTC-tx ticket
- Working theory of the parent ticket: the FE serves `bc1qgm7k56yqdzzn30vzzxrjnle6nkdn2wgt0m9ph2` as `pagZrxLHnhU`'s BTC receive address (proved by 2026-04-06 video Frame 6), but BE `/wallets` returns a different BTC address set for the same user.
- **However, PR #192 won't catch this specific user.** Usman's `/wallets` snapshot shows two wallets for `pagZrxLHnhU` with `accountIndex` 0 (`unrelated`) and 1 (`user`). Neither condition (`unrelated != 0`, `user == 100`) matches — so running the initial-phase script on staging would leave this user off the flagged list even though the BTC-address mismatch is real.
- That means:
  - The reconciliation-job effort as currently scoped/implemented **does not solve the parent BTC-tx ticket**.
  - Either a future phase adds an address-level diff, or Alex's fallback plan ("FE only displays BE-registered addresses") is what actually closes the parent ticket.

## What's missing (see `missing-context.md`)
1. Who runs the script on staging — nobody nominated yet.
2. Merge + run status of `wdk-data-shard-wrk#192`.
3. Location of the output store (DB table / log index / dashboard).
4. Migration rollout dates and affected-user count.
5. Contents of the 2026-03-17 analysis Slack thread (`C0A5DFYRNBB p1773779479524349`) — the full root-cause write-up.
6. Coverage for BTC-address-only mismatches (none in current PR).
7. Remediation policy for "Mismatch + BE-has-balance" users.
8. Decision: reconciliation path vs. FE-constraint fallback — both options still open per Alex's Slack ask.

## Before starting work
Priority asks of Alex:
1. Has PR #192 been merged and has anyone run it on staging? If yes, where's the output?
2. Which path is the team taking — full reconciliation, or the FE-constraint fallback?
3. The contents of the 2026-03-17 analysis thread (root-cause write-up) so we can confirm whether address-level divergence is a known second anomaly class beyond the two `accountIndex` cases this PR covers.
