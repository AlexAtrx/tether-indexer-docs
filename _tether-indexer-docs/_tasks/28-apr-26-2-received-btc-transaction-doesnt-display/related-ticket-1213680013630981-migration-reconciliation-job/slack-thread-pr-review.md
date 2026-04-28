# Slack thread — PR review for `wdk-data-shard-wrk#192`

Source: Slack channel `C0A5DFYRNBB` (tether-to workspace). This is the thread Alex linked from this Asana ticket on 2026-03-20 as "PR to generate a report as an initial phase to measure impact" (`p1774015635649839`).

## Key facts pulled out

- **PR URL:** https://github.com/tetherto/wdk-data-shard-wrk/pull/192
- **Repo:** `tetherto/wdk-data-shard-wrk` — this is where the reconciliation / migration-check code lives.
- **Author:** Alex
- **Reviewers requested:** @Vigan, @Usman Khan, @Francesco C., @Eddy WM
- **Testing:** tested locally.
- **What the script checks (per Alex's summary at the bottom of the thread):** it is an *analysis step* toward full reconciliation (not the full reconciliation job yet). It looks for two migration-induced anomalies:
  1. **Unrelated wallets with `accountIndex != 0`** — unrelated wallets got a wrong account index during migration.
  2. **User wallets with `accountIndex = 100`** — sentinel/default value that shouldn't exist in production.
- **Where it needs to run:** staging (where the migration took place).
- **Open operational question (from Alex, unanswered in the thread):** *"Who can do this and get us the results?"* — the script is approved/merged-ready but nobody has been nominated to run it on staging and share output.
- **Alternative remediation Alex mentioned:** if the reconciliation script is deemed unnecessary, the fallback plan is to "tell the app team to only display addresses that are registered with the backend" — i.e. have the FE stop serving locally-derived addresses that the BE doesn't know about. This is directly relevant to the parent BTC-tx bug, where the FE is serving `bc1qgm7k56…` but BE `/wallets` doesn't contain it.
- **Review trajectory:** Usman's first review at `https://github.com/tetherto/wdk-data-shard-wrk/pull/192#pullrequestreview-4070935741` prompted Alex to rewrite the script to "a more practical flow". Usman's second pass concluded it's fine as-is, with optional simplifications. Francesco thanked both. No explicit approval/merge event in the thread.

## Thread contents (verbatim as provided)

> **Alex** [3:07 PM]
> PR Review:
> 🔹 Task Name: Migration Reconciliation Job - (Slack ref)
> 🔹 PR Link: https://github.com/tetherto/wdk-data-shard-wrk/pull/192
> 🔹 Testing: tested locally
> 🔹 Assigned To: @Vigan @Usman Khan @Francesco C. @Eddy WM *(edited)*
>
> *17 replies*
>
> **Alex** [2:35 PM]
> @Vigan can you review plz?
>
> **Alex** [8:48 PM]
> Hey @Vigan
> I wrote this PR as a check for migration shortcomings of any:
> https://github.com/tetherto/wdk-data-shard-wrk/pull/192
>
> This for its own ticket, and another ticket that is relevant.
> Please review so that one of us can run it to solve this issue.
> If you think it's unnecessary, with which we will have to tell the app team to only displays addresses that are registered with the backend, let me know.
>
> **Usman Khan** [10:07 PM]
> @Alex just reviewed the PR: https://github.com/tetherto/wdk-data-shard-wrk/pull/192#pullrequestreview-4070935741
>
> **Alex** [12:54 PM]
> hey @Usman Khan thanks for the review!
> I changed the script to a more practical flow.
> Plz check again.
>
> **Alex** [12:19 PM]
> hey @Usman Khan whenever you can re-look, plz do
>
> **Usman Khan** [10:57 AM]
> Hey Alex, reviewed, sorry I missed adding comments for 1 file, I don't think the comments need to be fixed, but would simplify the code further IMO.
>
> **Francesco C.** [11:23 AM]
> thanks both
>
> **Alex** [11:52 AM]
> Thanks @Usman Khan
> This script is an analysis step toward full reconciliation (the ticket).
>
> It checks two things:
> 1- unrelated wallets with accountIndex != 0 (unrelated wallets got a wrong account index)
> 2- user wallets with accountIndex = 100 (sentinel/default value that shouldn't exist in production).
>
> This needs to run where migration took place - staging I believe.
> Question: Who can do this and get us the results?

## Implications for the parent BTC-tx ticket

- This PR is **not** the full FE-vs-BE address-set diff described in the Asana requirements — it's a narrower `accountIndex`-anomaly check. A Missing-in-BE BTC-only address (like `bc1qgm7k56…` for `pagZrxLHnhU`) would **not** be caught by this check unless that user also has a wrong `accountIndex`. Worth verifying Usman's two `/wallets` snapshots: one wallet had `accountIndex 0` (type `unrelated`), the other `accountIndex 1` (type `user`) — neither looks like the patterns this script flags (`unrelated != 0` or `user == 100`).
- So: running this script on staging is still useful population-level diagnostics, but it will almost certainly **not** surface `pagZrxLHnhU` as the source of the BTC-tx bug. The BTC-address mismatch is a separate class of discrepancy that this initial-phase script does not cover.
- Alex's fallback plan — "tell the app team to only display addresses that are registered with the backend" — would directly fix the parent BTC-tx ticket's symptom, because the FE would stop showing `bc1qgm7k56…` as a receive address if the BE doesn't confirm it. That is an independent decision from this PR.
