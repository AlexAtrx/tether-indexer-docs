# Missing context (for this related ticket)

The Asana ticket is mostly a requirements document — the concrete work landed in PR `tetherto/wdk-data-shard-wrk#192` (see `slack-thread-pr-review.md` for the review thread). The list below is the **still-missing** context needed before this ticket can be picked up or cross-referenced with the parent BTC-tx ticket.

## Resolved

- [x] **Repo / code location** — `tetherto/wdk-data-shard-wrk`, PR #192. That PR is the initial-phase migration-check script (not the full reconciliation job).
- [x] **Scope of the first-phase check** — script flags two migration-produced anomalies: (1) `unrelated` wallets with `accountIndex != 0`, (2) `user` wallets with `accountIndex = 100` (sentinel default). It is **not** a full FE-vs-BE address-set diff.
- [x] **Report-PR Slack thread (`p1774015635649839`)** — captured in `slack-thread-pr-review.md`.

## Still missing (priority order)

### 1. Operational: who runs the script on staging?

- [ ] The PR ended with Alex's unanswered question *"Who can do this and get us the results?"* The check needs to run where the migration happened (staging), and no one volunteered in-thread. **Need from Alex:** has anyone since been nominated / has the script been run? If yes, where's the output; if no, who to ask.

### 2. Merge + run status of `wdk-data-shard-wrk#192`

- [ ] Usman's second review was "looks fine, optional simplifications" — but the thread never shows an approval/merge event. **Need:** is PR #192 merged? If merged, has it actually been executed on staging, and what did it find? (Can be answered straight from GitHub + the output store, once the output store location is known.)

### 3. Output store for the results

- [ ] Whether the "dedicated table or log store" specified in the Asana requirements has been provisioned for the initial-phase script's output, or whether the script just prints to stdout and relies on the operator to capture it. **Need:** the target location (DB table / log index / dashboard URL) and whether `userId=pagZrxLHnhU` (klemensqwerty — the user in the parent BTC ticket) appears in any produced output. *(Expectation: klemensqwerty will likely NOT appear in this first-phase output because Usman's `/wallets` snapshot shows `accountIndex` 0 and 1 — neither the `unrelated != 0` nor `user == 100` condition matches. See the cross-link note in `slack-thread-pr-review.md`.)*

### 4. Migration scope

- [ ] When the FE migration ran (date window) and how many users were affected. Without this we can't tell whether the parent BTC-tx class of bug is one-off or systemic. **Need from Alex.**

### 5. Full-reconciliation Slack thread (`p1773779479524349`)

- [ ] The 2026-03-17 analysis thread Alex linked from this Asana ticket (separate from the PR-review thread). The PR-review thread hints at the root cause being an `accountIndex` bug, but the full analysis is in `p1773779479524349` and would confirm the mechanism + name any other anomaly classes beyond the two the initial-phase script covers. **Need:** full thread contents.

### 6. Coverage gap: BTC-address-only mismatches

- [ ] The Asana requirements are contradictory (EVM-first comparison vs. "EVMs and BTC" under mismatch), and the initial-phase PR only checks `accountIndex` — not addresses at all. **Need:** confirmation of which future phase catches the "FE serves BTC address X, BE stores BTC address Y" case — because that is exactly the parent BTC-tx ticket's shape, and nothing fetched so far catches it. Alex's fallback idea ("tell the app team to only display addresses that are registered with the backend") would bypass this gap at the FE layer instead.

### 7. Remediation policy

- [ ] Once a Mismatch + BE-has-balance row is produced, what happens? Sweep funds to the FE address? Force the FE to stop using the offending address? Manual case-by-case? **Need:** the agreed policy — it determines how the parent BTC-tx ticket gets closed for `klemensqwerty` once the root cause is confirmed.

### 8. Decision: reconciliation vs. FE-constraint fallback

- [ ] In the Slack thread Alex explicitly posed an either-or: either we do the reconciliation properly, **or** "we will have to tell the app team to only display addresses that are registered with the backend". **Need:** which path the team has chosen. The FE-constraint path would close the parent BTC-tx ticket symptomatically without needing the reconciliation output; the reconciliation path needs items 1–4 above to make progress.
