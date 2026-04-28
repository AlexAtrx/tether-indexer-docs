# Execution plan — code & PRs to raise

Pick this up cold: each section below is one PR. Order matters because chain-indexer PRs need a SHA from `wdk-indexer-wrk-base@dev`, so do them after that branch is at the SHA you want to pin.

All target branch = `dev` (unless noted). Promotion to staging/main comes later in Phase 3.

## Phase 0 — figure out the SHA to pin

Before opening the chain-indexer PRs, get the current head of `wdk-indexer-wrk-base@dev`:

```bash
gh api repos/tetherto/wdk-indexer-wrk-base/commits/dev --jq '.sha'
```

As of 2026-04-20 this returned `dc188b7a6e043020147d5af0654b82a2619877f0` (the merge commit of PR #104). If newer commits have landed by the time you start, pin to the latest dev HEAD instead — anything ≥ `dc188b7a` includes the fix. The variable `<BASE_SHA>` below means "that value".

---

## Phase 1 — direct dep, one PR

### PR 1 — `wdk-indexer-processor-wrk`

- Base branch: `dev`
- Single file: `package.json`
- Diff:

```diff
   "dependencies": {
-    "@bitfinex/bfx-facs-db-mongo": "github:bitfinexcom/bfx-facs-db-mongo",
+    "@bitfinex/bfx-facs-db-mongo": "github:bitfinexcom/bfx-facs-db-mongo#feature/mongodb-v6-driver",
```

- Then `rm -rf node_modules package-lock.json && npm install` to regenerate the lock file. Commit both files.
- Suggested title: `fix: upgrade bfx-facs-db-mongo to mongodb v6 driver (WDK-1255)` (matches #115/#104).
- Verify locally: boot the worker once, `[DEP0170]` should not appear in stdout.

---

## Phase 2 — chain indexers, six PRs (same shape)

For each of these six repos, the change is identical: bump the `wdk-indexer-wrk-base` pin to `<BASE_SHA>` (from Phase 0).

| # | Repo | Current dev pin | Target dev pin |
|---|---|---|---|
| 2 | `wdk-indexer-wrk-btc` | `2fd2ed5f95d081ef85d246131711ac3a0edeec7b` | `<BASE_SHA>` |
| 3 | `wdk-indexer-wrk-evm` | `2fd2ed5f95d081ef85d246131711ac3a0edeec7b` | `<BASE_SHA>` |
| 4 | `wdk-indexer-wrk-spark` | `2fd2ed5f95d081ef85d246131711ac3a0edeec7b` | `<BASE_SHA>` |
| 5 | `wdk-indexer-wrk-solana` | `2fd2ed5f95d081ef85d246131711ac3a0edeec7b` | `<BASE_SHA>` |
| 6 | `wdk-indexer-wrk-ton` | `2fd2ed5f95d081ef85d246131711ac3a0edeec7b` | `<BASE_SHA>` |
| 7 | `wdk-indexer-wrk-tron` | `2fd2ed5f95d081ef85d246131711ac3a0edeec7b` | `<BASE_SHA>` |

Note: dev SHAs above are all `2fd2ed5f` even though the main pins differ — every chain indexer's dev branch is pinned to the same older base SHA. Per-chain change is the same one-liner.

For each repo:

- Base branch: `dev`
- Single file: `package.json`
- Diff (using `wdk-indexer-wrk-btc` as the example; replace SHA in others):

```diff
   "dependencies": {
-    "@tetherto/wdk-indexer-wrk-base": "github:tetherto/wdk-indexer-wrk-base#2fd2ed5f95d081ef85d246131711ac3a0edeec7b",
+    "@tetherto/wdk-indexer-wrk-base": "github:tetherto/wdk-indexer-wrk-base#<BASE_SHA>",
```

(The `wdk-indexer-wrk-evm` pin uses `git+https://...#<sha>` form rather than `github:...#<sha>`. Match each repo's existing prefix style — don't refactor it as part of this PR.)

- `rm -rf node_modules package-lock.json && npm install` to regenerate the lock. Commit both files.
- Suggested title (per repo): `chore: bump wdk-indexer-wrk-base to v6 mongo driver (WDK-1255)`.
- Verify locally: boot the worker once, `[DEP0170]` should not appear.

These six are mechanical and could be batched in one sitting. Whether to open six separate PRs or one bulk one depends on per-chain CODEOWNERS and reviewer load — six small ones is the safer default.

---

## Phase 3 — promotion to staging and main

This applies to **every** repo touched in Phases 1 and 2, plus the two repos already done on dev (`wdk-ork-wrk`, `wdk-indexer-wrk-base`).

The repos use explicit promotion PRs. Recent examples to mirror:

- `wdk-indexer-wrk-base` PR #98 "promote dev to staging"
- `wdk-indexer-wrk-base` PR #99 "promote staging to main"
- `wdk-indexer-wrk-base` PR #107 / #108 "Release: v0.1.1 / v0.1.2" (cut from a `release/v0.1.x` branch into main)

For each affected repo:
1. Open `dev → staging` promotion PR.
2. After staging deploy, open `staging → main` promotion PR (or cut a release branch first if that's the repo's convention).
3. Once on main, deploy to prod.

Coordinate with whoever owns staging/prod deploys (Vigan / Francesco) — these promotions usually go in batches and need to be timed with the platform release.

---

## Phase 4 — verification in prod

After the prod deploy + a fresh restart of every indexer/processor:

```
{job="pm2", level!="20"} |= "[DEP0170] DeprecationWarning: The URL mongodb"
```

Note: drop the `service_name=~"idx-xaut-arb-api.+"` filter that the original ticket queries used — that filter only matched the XAUT/Arbitrum service and missed BTC, Solana, TON, Tron, Spark, and the processor.

Expected result: zero hits. Any hit is a service we missed — investigate that `service_name` and trace it back to a repo not in the table above.

---

## Recap — total PRs to raise

- Phase 1: 1 (`wdk-indexer-processor-wrk`)
- Phase 2: 6 (one per chain indexer)
- Phase 3: 2 promotion PRs × 9 affected repos = up to 18, but most can be batched per repo's own release cadence

Code changes are trivial — every PR is a one-line edit in `package.json` plus the `npm install`-regenerated `package-lock.json`. No application code touches.
