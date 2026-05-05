# Next steps for Move #192 code to Rumble Data Shard

**Ticket:** https://app.asana.com/1/45238840754660/project/1210540875949204/task/1214430872139370

## What we know

- PR [tetherto/wdk-data-shard-wrk#192](https://github.com/tetherto/wdk-data-shard-wrk/pull/192)
  ("Add one-off wallet anomaly report CLI for migration account-index checks")
  was merged 2026-04-20 by AlexAtrx and reverted by [PR #211](https://github.com/tetherto/wdk-data-shard-wrk/pull/211)
  on 2026-04-30 by francesco-ubq, with no documented reason.
- The ticket asks the same change to be applied on `tetherto/rumble-data-shard-wrk`
  instead.
- Diff is 4 files (+376/-0): `package.json` script entry, the CLI, a unit
  test, and the report builder lib. Full diff at `_raw/pr192.diff`.
- The two repos diverge at `workers/lib/db/mongodb/repositories/`: rumble has
  a much smaller `wallets.js` (1666B vs 6693B) and a different file set, so
  the port is not a clean cherry-pick. See `pr-context.md` for the comparison
  table.
- Priority: High. Sprint 1. Not blocked.

## Evidence captured here

- 0 images analysed in `image-analysis.md`
- 0 non-image attachments under `attachments/`
- 0 user comments on the Asana ticket; full GitHub PR context in `pr-context.md`
- Source diff in `_raw/pr192.diff`, PR JSON in `_raw/pr19{2,1}.json`

## What's missing (from `missing-context.md`)

- **Why was #192 reverted?** Single biggest unknown. Determines whether to
  port verbatim, port-with-fix, or skip.
- Target branch on `rumble-data-shard-wrk` and intended runtime environment.
- Whether `rumble-data-shard-wrk/workers/lib/db/mongodb/repositories/wallets.js`
  exposes a scan method that returns `type` + `accountIndex`, or whether the
  port also has to add that capability.
- Test directory convention (`tests/unit/` vs flat `tests/`).
- Whether the migration this script reports on has already run on Rumble (in
  which case this task may be obsolete).

## Before starting work

Ask Francesco the revert reason **first**. If the answer is "the script was
fine, we just realized it had to live in rumble-data-shard-wrk instead", the
port is straightforward. If it's "the script had a bug" or "the migration
already happened on Rumble too", scope changes significantly.

Once the revert reason is in hand:

1. Clone `tetherto/rumble-data-shard-wrk` (use `read-remote-repo` skill or
   `gh repo clone`), check out `dev` (or whatever target Alex confirms).
2. Inspect `workers/lib/db/mongodb/repositories/wallets.js` and confirm it
   exposes a scan method usable by the report. If not, scope-add it.
3. Apply the four-file diff from `_raw/pr192.diff`, adapting:
   - test path (`tests/unit/` vs `tests/`)
   - `package.json` "name" stays as `rumble-data-shard-wrk`, just add the
     `wallet-anomaly-report` script entry
   - any import paths that reference wdk-only modules
4. Run `npm test` and the script against a non-prod env before opening the PR.
5. Open the PR against `dev` of `rumble-data-shard-wrk`. In the description,
   link both PR #192 and PR #211 and call out the revert-reason resolution.
