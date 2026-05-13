# Next steps for Move #192 code to Rumble Data Shard

**Ticket:** https://app.asana.com/1/45238840754660/project/1210540875949204/task/1214430872139370

**Status (2026-05-12):** Ported. PR open on `tetherto/rumble-data-shard-wrk`, waiting on review.

## PR

- [tetherto/rumble-data-shard-wrk#216](https://github.com/tetherto/rumble-data-shard-wrk/pull/216) — `feat: add wallet anomaly report CLI (WDK-1389)`
- Branch: `AlexAtrx:WDK-1389-wallet-anomaly-report-cli` → `tetherto:dev`
- Commit: `89e0499`
- Files changed: 4 (+376/-0)
  - `package.json` — added `wallet-anomaly-report` script entry
  - `scripts/wallet-anomaly-report-cli.js` (new, 170 lines)
  - `workers/lib/wallet.anomaly.report.js` (new, 103 lines)
  - `tests/wallet.anomaly.report.unit.test.js` (new, 102 lines, flat path)
- Local sanity checks: `standard` lint clean, `brittle` unit test 3/3 pass (21/21 asserts), `--help` prints

## Why the port (resolved revert question)

The original PR #192 landed in `wdk-data-shard-wrk` and was reverted by #211 because **WDK repos are the public/general codebase and Rumble-specific code must live in `rumble-*` repos**. Francesco filed `WDK-1389` titled "Move #192 code to Rumble Data Shard" the same day he reverted it, confirming the revert was about repo placement, not a bug in the script. Memory: [project_wdk_vs_rumble_repo_split](../../../.claude/projects/-Users-alexa-Documents-repos-tether--INDEXER/memory/project_wdk_vs_rumble_repo_split.md).

## What's in the port

Read-only CLI that scans active wallets and flags two migration anomalies:
- `type=unrelated` with `accountIndex != 0`
- `type=user` with `accountIndex == 100`

JSON report to stdout, optionally to a file via `--out`. No data is modified.

## Adaptations vs. PR #192

- Test moved from `tests/unit/wallet.anomaly.report.unit.test.js` to `tests/wallet.anomaly.report.unit.test.js` (rumble uses flat `tests/`, suffix `.unit.test.js`). Relative require changed from `../../workers/...` to `../workers/...`.
- No change needed to `workers/lib/db/mongodb/repositories/wallets.js` — rumble's `WalletRepository` extends the wdk base, so `iterateActiveWallets()` is inherited.
- All other files copied verbatim from `_raw/pr192.diff`.

## After merge

- Run the CLI against a non-prod env first, then prod, to see whether any anomalies surfaced on Rumble (rumble adopted the `accountIndex` schema via PR #115 on 2025-12-13 without a data-fix migration, so wallets predating that date can still carry the anomaly classes).
- Close the Asana ticket.
