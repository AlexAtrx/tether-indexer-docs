# GitHub PR context

The Asana ticket only links PR #192. Both that and its revert PR matter for the
port. Raw data in `_raw/pr192.{json,diff}` and `_raw/pr211.json`.

## PR #192 — the source change

- Repo: `tetherto/wdk-data-shard-wrk`
- Title: "Add one-off wallet anomaly report CLI for migration account-index checks"
- Author: AlexAtrx (this is Alex's own PR)
- State: MERGED on 2026-04-20T10:17:10Z, merge commit `8c9d72d`
- Base: `dev` ← Head: `migration-wallet-anomaly-report`
- Files: 4 (+376/-0)
  - `package.json` — adds `wallet-anomaly-report` npm script
  - `scripts/wallet-anomaly-report-cli.js` — new (170 lines)
  - `tests/unit/wallet.anomaly.report.unit.test.js` — new (102 lines)
  - `workers/lib/wallet.anomaly.report.js` — new (103 lines)

### What it does

Read-only reporting CLI that scans active wallets in shard storage and flags two
migration anomalies:

- `type = unrelated` with `accountIndex != 0`
- `type = user` with `accountIndex = 100`

Outputs JSON to stdout and optionally to `--out <file>`. Mongo-only after review
(hyperdb support stripped during review).

### Review history (relevant for the port)

- Francesco-ubq suggested a `parseAccountIndex` helper refactor — accepted, applied.
- SargeKhan pushed back on environment flags and hyperdb support, asked to
  inline the small helpers and rely on default config rather than `--env`,
  `--ns`, `--root`, etc. — Alex stripped hyperdb, kept only `--db-name`,
  `--wtype`, `--rack`, `--out`. The merged version is the simplified mongo-only
  shape.

These review comments matter when porting: the merged version is intentionally
narrower than the initial PR, so we should port from merge commit `8c9d72d`
itself, not from intermediate revisions.

## PR #211 — the revert

- Repo: `tetherto/wdk-data-shard-wrk`
- Title: "Revert \"Add one-off wallet anomaly report CLI for migration account-index checks\""
- Branch: `revert-192-migration-wallet-anomaly-report` (auto-generated revert)
- State: MERGED on 2026-04-30T12:47:11Z, merge commit `ebf037b`, base `dev`
- Author / merger: francesco-ubq
- Body: literally just "Reverts tetherto/wdk-data-shard-wrk#192"
- Comments: none

**The revert reason is not documented anywhere.** This is the single biggest
unknown — see `missing-context.md`.

## Repo-shape comparison: source vs. destination

| Path                                                  | wdk-data-shard-wrk | rumble-data-shard-wrk |
|-------------------------------------------------------|--------------------|------------------------|
| `scripts/migration-cli.js`                            | yes                | yes                    |
| `scripts/wallet-anomaly-report-cli.js`                | (was added by #192, now reverted) | absent |
| `workers/lib/wallet.anomaly.report.js`                | (same)             | absent                 |
| `workers/lib/db/mongodb/repositories/wallets.js`      | 6693 bytes         | 1666 bytes             |
| `workers/lib/db/mongodb/repositories/` other files    | address.checkpoint, user.balances, user.data, users, wallet.balances, wallet.transfers | txwebhook, userdata |
| `workers/lib/` extras                                 | async.task.processor, blockchain.svc, constants, price.calculator, traceId.util, utils | (none) |
| `tests/unit/`                                         | yes (`wallet.anomaly.report.unit.test.js` was added) | flat under `tests/` (no `unit/` subdir) |
| `package.json` "name"                                 | `@tetherto/wdk-data-shard-wrk` | `rumble-data-shard-wrk` |

Implication: the port is **not** a clean cherry-pick. The wallets repository in
`rumble-data-shard-wrk` is a quarter the size of the wdk one, and the methods
the CLI calls (`MongoWalletRepository.<scan-active-wallets>`) need to be
verified to exist. The test layout differs (`tests/unit/` vs flat `tests/`),
and `migrations/` exists in rumble but not in wdk — so we should land the
script alongside the existing `migration-cli.js` pattern.

Diff for reference: `_raw/pr192.diff` (405 lines).
