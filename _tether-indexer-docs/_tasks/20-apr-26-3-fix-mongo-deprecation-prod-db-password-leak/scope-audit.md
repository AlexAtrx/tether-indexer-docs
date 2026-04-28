# Scope audit — which repos still emit the leak?

Performed 2026-04-20. Sweep of every plausible Mongo-using repo under `tetherto/*` for how it pins `@bitfinex/bfx-facs-db-mongo` on `dev`, `staging`, and `main`.

## TL;DR

The merged PRs (`wdk-ork-wrk` #115, `wdk-indexer-wrk-base` #104) **only landed on `dev`**. They are not yet on staging, main, or prod. So even for the two repos that are "done" on the ticket, the prod leak is still live until the dev → staging → main promotion completes.

On top of that, **7 more repos have not been touched at all** and are still on the v3 driver — they will leak as soon as they restart.

## Per-repo state table

| Repo | dev | staging | main | Action needed |
|---|---|---|---|---|
| `wdk-ork-wrk` | ✅ v6 (PR #115) | ❌ v3 | ❌ v3 | Promote dev → staging → main |
| `wdk-indexer-wrk-base` | ✅ v6 (PR #104, SHA `dc188b7a`) | ❌ v3 | ❌ v3 | Promote dev → staging → main |
| `wdk-data-shard-wrk` | ✅ v6 | ✅ v6 | ✅ v6 | None — already shipped Jan 2026 |
| `wdk-indexer-processor-wrk` | ❌ v3 | ❌ v3 | ❌ v3 | New PR on `dev`, same one-liner |
| `wdk-indexer-wrk-btc` | ❌ pins base@`2fd2ed5f` | ❌ pins base@`84d33de7` | ❌ pins base@`92442163` | Bump base pin on `dev` to a SHA on/after `dc188b7a` |
| `wdk-indexer-wrk-evm` | ❌ pins base@`2fd2ed5f` | ❌ pins base@`84d33de7` | ❌ pins base@`92442163` | Same |
| `wdk-indexer-wrk-spark` | ❌ pins base@`2fd2ed5f` | ❌ pins base@`84d33de7` | ❌ pins base@`92442163` | Same |
| `wdk-indexer-wrk-solana` | ❌ pins base@`2fd2ed5f` | ❌ pins base@`84d33de7` | ❌ pins base@`10fc1e50` | Same |
| `wdk-indexer-wrk-ton` | ❌ pins base@`2fd2ed5f` | ❌ pins base@`84d33de7` | ❌ pins base@`10fc1e50` | Same |
| `wdk-indexer-wrk-tron` | ❌ pins base@`2fd2ed5f` | ❌ pins base@`84d33de7` | ❌ pins base@`10fc1e50` | Same |
| `rumble-ork-wrk` | n/a | n/a | n/a | None — no Mongo dep |
| `rumble-data-shard-wrk` | n/a | n/a | n/a | None — no Mongo dep |
| `wdk-app-node` | n/a | n/a | n/a | None — no Mongo dep |
| `rumble-app-node` | n/a | n/a | n/a | None — no Mongo dep |
| `wdk-indexer-app-node` | n/a | n/a | n/a | None — no Mongo dep |
| `rumble-promo-wrk` | n/a | n/a | n/a | None — no Mongo dep |

`92442163` is from 2026-04-13 — one day before the fix merged. `10fc1e50` is from 2026-03-02. Neither contains the v6 pin. Verified directly by `gh api .../contents/package.json?ref=<sha>`.

## How the branching flow works in these repos

`wdk-ork-wrk`, `wdk-indexer-wrk-base`, `wdk-indexer-processor-wrk`, and every `wdk-indexer-wrk-<chain>` use **`dev → staging → main`** with explicit promotion PRs (e.g. base PR #98 "promote dev to staging", #99 "promote staging to main") and release branches (`release/v0.1.x`) cut from staging into main. PRs land on `dev`. So both #115 and #104 sit on dev, awaiting promotion.

This explains the ticket section "PR MERGED + DEPLOYED TO DEV" exactly. The next stop is staging, then main / release, then deploy.

## Why the original Loki queries didn't surface this

The queries in `description.md` filter on `service_name=~"idx-xaut-arb-api.+"`, which only matches the XAUT/Arbitrum API (powered by `wdk-indexer-wrk-evm`). BTC, Solana, TON, Tron, Spark, and the indexer processor wouldn't appear in those query results, so they never showed up as needing the fix. Re-running the query without that filter post-restart will confirm coverage.

## Vigan's "we need data shard as well"

Stale. `wdk-data-shard-wrk` was migrated to v6 on 2026-01-08 (commit `e0803bd` by sarge, "use bitfinex branch"), three months before his comment. The pin is live on `dev`, `staging`, and `main`. `rumble-data-shard-wrk` doesn't depend on `bfx-facs-db-mongo` at all. Real outstanding work is the processor + six chain indexers + the promotion of #115 / #104.
