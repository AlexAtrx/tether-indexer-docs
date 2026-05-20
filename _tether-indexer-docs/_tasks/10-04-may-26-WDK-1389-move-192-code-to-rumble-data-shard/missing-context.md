# Missing context

Updated 2026-05-12. Originally captured open questions before the port. All resolved.

## Resolved

- [x] **Why was #192 reverted?** Confirmed (without needing Francesco's reply): the revert was about repo placement, not a bug. WDK repos are public/general; Rumble-specific code lives in `rumble-*` repos. Francesco filed `WDK-1389` titled "Move #192 code to Rumble Data Shard" the same day he opened revert PR #211, which is consistent with this reading. Saved as memory `project-wdk-vs-rumble-repo-split`.
- [x] **Repo-shape mismatch / scan capability** — `rumble-data-shard-wrk` wallets.js extends the wdk base class via `require('@tetherto/wdk-data-shard-wrk/workers/lib/db/mongodb/repositories/wallets.js')`, so `iterateActiveWallets()` is inherited. No scope-add needed.
- [x] **Test directory convention** — rumble uses flat `tests/` with the `.unit.test.js` suffix. Port test landed at `tests/wallet.anomaly.report.unit.test.js` with require fixed to `../workers/lib/wallet.anomaly.report`.
- [x] **Target branch** — `dev`. PR opened against `tetherto/rumble-data-shard-wrk:dev`.
- [x] **Migration relevance on Rumble** — rumble adopted the `accountIndex` schema via PR #115 on 2025-12-13 without a data-fix migration. The same anomaly classes the CLI flags are possible on rumble's data. Report is useful unless Francesco confirms a separate manual cleanup already ran.
- [x] **PR review history of #192** — captured inline in `pr-context.md`. Merged-form (mongo-only, simplified) is what was ported.
