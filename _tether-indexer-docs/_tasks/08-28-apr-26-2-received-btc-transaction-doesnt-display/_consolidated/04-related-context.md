# Related context — RW-1428

## RW-1409 — [Backend] Migration Reconciliation Job

**Ticket:** https://app.asana.com/1/45238840754660/project/1212521145936484/task/1213680013630981
**GID:** 1213680013630981
**Status:** In-Progress · Priority High · Stack BE - Backend · Fix Version (FE) RW 2.0.4
**Why linked:** Alex linked this on 2026-04-09 as the working theory for RW-1428. The hypothesis: during old-app → new-version migration, the FE recreated the user's wallet and produced a set of addresses different from what the BE already had, and the BE did not overwrite. RW-1409 is the mechanism for detecting that class of discrepancy across all migrated users.

### Scope per Asana requirements

A BE job that diffs the wallet addresses the FE recreated during migration against the addresses the BE has stored. Output should contain `UserId, WalletID, Wallet Name, Wallet type, Account index, Backend address, Frontend address, Reconciliation status` plus aggregate metrics. Mismatch policy: users with zero balance are zero-risk; users with a BE-side balance are at-risk.

### What's actually built (PR #192)

PR `tetherto/wdk-data-shard-wrk#192` is an *initial-phase* script narrower than the requirements. It only checks two `accountIndex` anomalies:

1. `unrelated` wallets with `accountIndex != 0`
2. `user` wallets with `accountIndex = 100` (sentinel/default that shouldn't be in prod)

It does **not** compare addresses. Reviewers: Vigan, Usman Khan, Francesco C., Eddy WM. Usman reviewed twice; Alex rewrote to "a more practical flow" between passes. No merge event captured. Designed to run on staging (where the migration took place).

### Why PR #192 won't flag this user

For `pagZrxLHnhU`, Usman's `/wallets` snapshot shows two wallets with `accountIndex` 0 (`unrelated`) and 1 (`user`). Neither condition matches the PR's anomaly checks. Running it on staging today would leave this user off the flagged list even though the BTC-address mismatch is real.

**Implication:** the reconciliation job as currently scoped does **not** resolve RW-1428. Either a future phase adds an address-level diff, or Alex's fallback plan ("FE only displays BE-registered addresses") is what actually closes the parent ticket.

### Alex's stated fallback (in Slack)

If full reconciliation is deemed too heavy, the alternative is to have the app team only display addresses that are registered with the backend. That would symptomatically fix RW-1428 without requiring reconciliation output, and it's the cleanest way to prevent repeat reports while reconciliation catches up.

### Open items on RW-1409 (from `related-ticket-…/missing-context.md`)

1. Who runs the script on staging — nobody nominated yet.
2. Merge + run status of `wdk-data-shard-wrk#192`.
3. Location of the output store (DB table / log index / dashboard).
4. Migration rollout dates and affected-user count.
5. Contents of the 2026-03-17 analysis Slack thread (`C0A5DFYRNBB p1773779479524349`).
6. Coverage for BTC-address-only mismatches — not in current PR.
7. Remediation policy for "Mismatch + BE-has-balance" users.
8. Decision: reconciliation path vs. FE-constraint fallback.

## Slack threads referenced

| Date | URL | Owner | Captured? |
|---|---|---|---|
| 2026-03-17 21:00 | `https://tether-to.slack.com/archives/C0A5DFYRNBB/p1773779479524349` | Alex | analysis + fix from RW-1409 — not captured |
| 2026-03-20 14:11 | `https://tether-to.slack.com/archives/C0A5DFYRNBB/p1774015635649839` | Alex | initial-phase report PR — not captured |
| 2026-04-02 14:27 | `https://tether-to.slack.com/archives/C0A5DFYRNBB/p1775069742706779` | Alex | analysis specifically for RW-1428 — not captured |

## Second related ticket (still unnamed)

On 2026-04-09 11:15 Alex told Eddy "two other tickets" are in progress. Only RW-1409 was named. The second URL is still missing.
