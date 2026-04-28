# Next steps for Fix Mongo Deprecation Warning (Prod DB Password Leak)

**Ticket:** https://app.asana.com/1/45238840754660/project/1210540875949204/task/1213549645575555

## What we know
- Node's `[DEP0170] DeprecationWarning: The URL mongodb://...` was emitted by indexer services at startup and printed the connection string verbatim, embedding the prod DB password (`mongodb://wallet:<password>@...`).
- Root cause: v3 `mongodb` driver's URL parser. The fix is to re-pin `bfx-facs-db-mongo` to branch `feature/mongodb-v6-driver`, which uses `mongodb ^6.21.0`.
- Pin style: **branch name** in `package.json` (not commit hash) — Vigan's preference, overriding the tether-wallet security-review guidance to pin by commit hash. Decision captured in `slack-thread.md`.

## Status of work shipped so far

- `wdk-ork-wrk` PR #115 — merged into **`dev` only** (2026-04-14). Still needs promotion to staging + main.
- `wdk-indexer-wrk-base` PR #104 — merged into **`dev` only** (2026-04-14, merge commit `dc188b7a`). Still needs promotion.
- `wdk-data-shard-wrk` — already on v6 across all branches since 2026-01-08 (commit `e0803bd` by sarge). No action.

## What's still outstanding

Two unshipped categories on top of the promotion work above. See `scope-audit.md` for the full per-branch table; see `execution-plan.md` for the code-ready PR plan.

**Direct dep, still on v3 master across dev/staging/main** (1 repo):
- [ ] `wdk-indexer-processor-wrk` — one-line `package.json` bump on `dev`

**Transitive via `wdk-indexer-wrk-base` pinned to a pre-fix SHA on dev** (6 repos):
- [ ] `wdk-indexer-wrk-btc`
- [ ] `wdk-indexer-wrk-evm`
- [ ] `wdk-indexer-wrk-spark`
- [ ] `wdk-indexer-wrk-solana`
- [ ] `wdk-indexer-wrk-ton`
- [ ] `wdk-indexer-wrk-tron`

After Phases 1 + 2 (the 7 PRs above) land on dev, **everything needs promoting `dev → staging → main`** via the repo's normal promotion-PR convention (sample: base PRs #98, #99, #107, #108).

## Detection caveat
Original ticket Loki queries filter `service_name=~"idx-xaut-arb-api.+"` — that's only the XAUT/Arbitrum service. The other 6 chain indexers + processor would not appear in those queries. Phase 4 in `execution-plan.md` re-runs the query without that filter post-deploy.

## Files in this folder
- `ticket.md` — Asana metadata
- `description.md` — original ticket body
- `comments.md` — Asana comments + system events
- `slack-thread.md` — PR review thread (pin-style decision lives here)
- `pr-diffs.md` — actual diffs of #115 and #104
- `scope-audit.md` — per-branch state of every Mongo-using repo
- `execution-plan.md` — **the code-and-PR plan; this is the file to open when picking the work back up**
- `missing-context.md` — outstanding asks (mostly resolved)
- `_raw/` — original Asana JSON responses
