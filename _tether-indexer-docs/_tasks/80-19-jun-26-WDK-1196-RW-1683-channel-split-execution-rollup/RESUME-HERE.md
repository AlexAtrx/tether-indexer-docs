# RESUME HERE - WDK-1196 / RW-1683 channel split + balance safeguard

Last updated: 2026-06-19. This is the entry point when picking the work back up.
Read this first, then `README.md` (full detail), `COMMITS.md` (SHAs), `FINDINGS.md`
and `LOCAL-PR-REVIEW-FINDINGS.md` (review history).

## TL;DR

All code is written, committed, pushed to the AlexAtrx forks, and open as **draft
PRs** into each `tetherto` repo's `dev`. Nothing is merged. Two independent tracks
are parked, each waiting on an external event:

- **Track A - channel split (6 PRs):** ready to land. Blocked only on the
  pin-bump choreography (each Rumble PR needs its paired WDK PR merged first).
- **Track B - balance timeout safeguard (1 PR, CLOSED):** retired. Will be
  re-done on top of Israel's **WDK-1459** balance-move branch once that lands.

Hard constraints still apply: push only to the AlexAtrx fork (never `tetherto`),
no em dashes, no AI attribution, Rumble depends on WDK by git SHA pin.

## PR status snapshot (2026-06-19)

| Track | Repo | PR | Branch | State |
|---|---|---|---|---|
| A card1 | wdk-data-shard-wrk | [#251](https://github.com/tetherto/wdk-data-shard-wrk/pull/251) | `refactor/WDK-1196-remove-channel-wallet-ownership` | OPEN draft |
| A card1 | rumble-data-shard-wrk | [#251](https://github.com/tetherto/rumble-data-shard-wrk/pull/251) | `feat/WDK-1196-channel-wallet-ownership` | OPEN draft |
| A card2 | wdk-ork-wrk | [#162](https://github.com/tetherto/wdk-ork-wrk/pull/162) | `refactor/WDK-1196-remove-channel-shard-routing` | OPEN draft |
| A card2 | rumble-ork-wrk | [#174](https://github.com/tetherto/rumble-ork-wrk/pull/174) | `feat/WDK-1196-channel-shard-routing` | OPEN draft |
| A card3 | wdk-app-node | [#131](https://github.com/tetherto/wdk-app-node/pull/131) | `refactor/WDK-1196-remove-channel-wallet-api` | OPEN draft |
| A card3 | rumble-app-node | [#255](https://github.com/tetherto/rumble-app-node/pull/255) | `feat/WDK-1196-channel-wallet-api` | OPEN draft |
| B | rumble-data-shard-wrk | [#252](https://github.com/tetherto/rumble-data-shard-wrk/pull/252) | `fix/balance-request-timeout-budget` | **CLOSED** (redo on WDK-1459) |
| (no-go) | wdk-data-shard-wrk | [#250](https://github.com/tetherto/wdk-data-shard-wrk/pull/250) | `fix/balance-request-timeout-budget` (`9e4ae78`) | OPEN, **no-go** - Alex to close |

## Track A - finish the channel split (when ready to merge)

The split is shippable per card; the only gate is that Rumble pins WDK by git SHA
and the pins still point at pre-split commits (cannot bump until the WDK side is
merged on `tetherto`). Land in dependency order, one card fully before the next:

**Order: card1 (data-shard) -> card2 (ork) -> card3 (app-node).**

For each card:
1. Mark the WDK `refactor/...` PR ready for review and merge it into `tetherto` `dev`.
2. Copy the merge commit SHA from `tetherto/<wdk-repo>` `dev` (call it `NEW_SHA`).
3. Bump the matching Rumble pin and regenerate the lockfile, then commit on the
   Rumble `feat/...` branch and push to the AlexAtrx fork:
   ```bash
   # card1
   cd rumble-data-shard-wrk
   npm pkg set 'dependencies.@tetherto/wdk-data-shard-wrk=git+https://github.com/tetherto/wdk-data-shard-wrk.git#<NEW_SHA>'
   npm install && npm run test:unit && npm run lint
   git add package.json package-lock.json && git commit -m "chore: bump wdk-data-shard-wrk to the channel-split removal"
   git push origin feat/WDK-1196-channel-wallet-ownership

   # card2 -> rumble-ork-wrk, pin @tetherto/wdk-ork-wrk, branch feat/WDK-1196-channel-shard-routing
   # card3 -> rumble-app-node, pin @tetherto/wdk-app-node, branch feat/WDK-1196-channel-wallet-api
   ```
4. Mark the Rumble `feat/...` PR ready and merge it.

Why this order: data-shard owns storage, ork owns routing on top of it, app-node
exposes the surface last. See `README.md` "PR-readiness and sequencing".

## Track B - redo the balance safeguard (when WDK-1459 lands)

The balance timeout safeguard is NOT part of the channel split. Team decision: it
lives on the Rumble layer and lands **with** Israel's **WDK-1459 balance-move**
(Asana 1214792055861213). PR #252 was closed; the WDK-side approach (#250) is no-go.

When WDK-1459 balance-move has landed:
1. Branch off the WDK-1459 balance-move branch (the new Rumble base), not `dev`.
2. Re-apply the safeguard: the `_runWithinBalanceBudget` guard on `getUserBalance`
   in `rumble-data-shard-wrk/workers/api.shard.data.wrk.js`, including the fix that
   **throws `ERR_USER_BALANCE_BUDGET_EXCEEDED`** on timeout instead of returning a
   null balance (a null serializes to `""` under the string-only app-node balance
   contract). Source to replicate verbatim: commit **`eaea0fb`** on the closed
   branch `fix/balance-request-timeout-budget` (`git show eaea0fb`), plus its unit
   test in `tests/api.shard.data.wrk.unit.test.js`.
3. Confirm WDK-1459 did not already solve it at a finer granularity (per-currency
   timeout producing a valid string). If it did, the outer-deadline guard may be
   unnecessary - decide then.
4. Open a draft PR into Rumble `dev` (or the integration branch WDK-1459 used).

How to tell WDK-1459 has landed:
```bash
gh pr list --repo tetherto/rumble-data-shard-wrk --search "WDK-1459 OR balance" --state all
gh pr list --repo tetherto/tether-wallet-data-shard-wrk --search "balance" --state all
# Israel is the author; ticket https://app.asana.com/1/45238840754660/project/1210540875949204/task/1214792055861213
```

## Local working state (safety nets)

- Each of the 6 channel-split repos is checked out on its `feat/...` or
  `refactor/...` branch at the SHA in `COMMITS.md`; working trees are clean.
- `rumble-data-shard-wrk` has the retired `fix/balance-request-timeout-budget`
  branch at `eaea0fb` (local + fork), kept as the source for the Track B redo.
- Each repo also has a git stash `WDK-1196-wip-2026-06-19` (the pre-split working
  tree) as a backup; safe to drop once everything is merged.
- Pins are currently the pre-split SHAs (see `COMMITS.md` "Base (dev)"): do NOT
  bump until the paired WDK PR merges.

## Don't repeat these (already decided)

- Pin-not-bumped is the known sequencing item, not a bug. Do not "fix" it before
  the WDK merges.
- The HyperDB `channelId` field stays in `wdk-data-shard-wrk` (append-only; cannot
  drop mid-struct). The Mongo channel index was removed (not append-only).
- WDK base passing channel fields through reads is by design; do not strip them.
- A generic wallet-type allowlist in WDK is out of scope (separate hardening idea).
