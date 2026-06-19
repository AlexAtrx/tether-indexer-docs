# WDK-1196 / RW-1683 - channel split execution rollup

Date: 2026-06-19

This is the execution/rollup record for moving Rumble-specific channel-wallet
logic out of the shared `wdk-*` repos into the Rumble `rumble-*` child repos.
It ties together the planning ticket and the three implementation cards, records
every branch and commit produced, and lists what changed in each repo so the
work can be picked up later.

All work is **local only**: nothing pushed, no PRs opened, nothing posted to
Asana. No em dashes in any human-facing output per workspace rules.

## Related tasks

- Umbrella / planning: `52-05-jun-26-WDK-1196-rumble-refactor-wdk-repos-to-remove-rumble-specific-logic-move-to-rumble-child-repo`
  (see its `SPLIT-PROPOSAL.md`, `LOCAL-CODE-AUDIT.md`, `CREATED-ASANA-TICKETS.md`)
- Card 1 (data-shard): `77-17-jun-26-WDK-1196-RW-1683-data-shard-channel-wallet-ownership`
- Card 2 (ork): `78-17-jun-26-WDK-1196-RW-1683-rumble-owned-channel-shard-routing`
- Card 3 (app/API/docs): `76-17-jun-26-WDK-1196-RW-1683-rumble-owned-channel-wallet-api-and-docs`

## What this effort does

`rumble-*` repos extend pinned `wdk-*` packages. Rumble-specific channel-wallet
behavior used to live in the shared WDK layer. The split makes WDK generic and
re-homes the channel/tip-jar/walletTypes surface in Rumble, in three dependency-
ordered cards: data-shard (storage) -> ork (routing) -> app-node (public API).

Each card has two sides: a WDK removal (`refactor/...`) and a Rumble ownership
addition (`feat/...`). All six branches are cut from current `dev` and hold a
single clean commit. See `COMMITS.md` for the exact branch/SHA trace.

## Per-repo summary

### Card 1 - data-shard

**wdk-data-shard-wrk** - `refactor/WDK-1196-remove-channel-wallet-ownership` (`22ed36d`)
- Generified the proc wallet hooks: `_isDuplicateWallet`, `_validateNewWallet`,
  `_buildExtraWalletFields` now have generic defaults; channel-specific logic removed.
- Removed `getActiveChannelWallet` from base/mongo/hyperdb repos and the Mongo
  channel index.
- Removed `walletTypes` filtering from balance/transfer reads and `blockchain.svc.js`.
- HyperDB channel schema/index left in place (append-only); only its use was removed.
- Channel-specific tests removed; fixtures switched off channel type.

**rumble-data-shard-wrk** - `feat/WDK-1196-channel-wallet-ownership` (`4f3164a`)
- Overrode the proc hooks: one-channel-per-`channelId` dup rule, `channelId`
  validation and persistence.
- Re-added `getActiveChannelWallet` (mongo + hyperdb) and the Mongo channel index.
- Re-added `walletTypes` filtering on `getUserBalance` / `getUserTransfersV2`
  plus the `_filterUserWallets` helper.
- Added unit coverage for the hooks and walletTypes filtering.

### Card 2 - ork

**wdk-ork-wrk** - `refactor/WDK-1196-remove-channel-shard-routing` (`c6a544f`)
- Removed `LOOKUP_TYPES.CHANNELS`, `storeChannelShard` / `resolveChannelShard`,
  and the channel-lookup storage in `addWallet`.
- Added a `_createShardUtil()` seam so child repos can supply channel-aware routing.
- Removed the related channel tests/assertions.

**rumble-ork-wrk** - `feat/WDK-1196-channel-shard-routing` (`37543e3`)
- Added `RumbleDataShardUtil` (new `workers/lib/data.shard.util.js`) with the
  `CHANNELS` lookup type and `store` / `resolveChannelShard`.
- Wired it via `_createShardUtil()`; `addWallet` override stores the channel
  lookup for created channel wallets.
- Added unit coverage (new `tests/unit/data.shard.util.unit.test.js` + addWallet test).

### Card 3 - app / API / docs

**wdk-app-node** - `refactor/WDK-1196-remove-channel-wallet-api` (`26054bf`)
- Dropped the `channel` wallet type and `channelId` from the wallet schemas,
  `walletTypes` from balance/transfer routes, response `channelId`, and the
  tip-jar error codes.
- Genericized the affected route descriptions (Swagger no longer advertises
  channel / channelId / walletTypes).
- Replaced the Rumble-specific `staticRootPath` example with a generic one.

**rumble-app-node** - `feat/WDK-1196-channel-wallet-api` (`9a48eec`)
- `applyChannelWalletSchemas` re-adds the `channel` wallet type, `channelId` on
  POST /api/v1/wallets, `walletTypes` on the four balance/transfer reads, the
  response `channelId`, and the tip-jar error codes at the HTTP boundary.
- Restores the Rumble-owned route descriptions so Swagger documents the channel
  and walletTypes surface again (`CHANNEL_ROUTE_DESCRIPTIONS`).
- Added `tests/channel-wallet-schemas.unit.test.js` covering both the re-added
  schemas and the restored descriptions.

## Review findings fixed during execution

Three findings were raised against the initial commits and fixed in place
(commits amended). See `FINDINGS.md` for detail.

1. **channelId not type-gated below HTTP** (data-shard + ork). Internal HRPC
   callers bypass the app-node schema, so a `channelId` could be persisted on a
   non-channel wallet. Fixed: `_validateNewWallet` now rejects `channelId` on
   non-channel types (authoritative, blocks persistence and the ork lookup); the
   ork `addWallet` gate now keys on wallet `type === channel` rather than the
   `channelId` value. Tests added on both sides.
2. **Unrelated balance-timeout policy mixed into the split** (data-shard).
   `USER_BALANCE_BUDGET_MS` / `_runWithinBalanceBudget` wrapping every
   `getUserBalance` was extracted out of the WDK-1196 commit and moved to its own
   branch `fix/balance-request-timeout-budget` (`e867c8d`), the Rumble counterpart
   of the WDK-side balance-budget work.
3. **Rumble docs stayed generic after re-adding schemas** (app-node). Fixed by
   restoring the route descriptions (finding 3 above), plus the wallet update
   route's "Channel id cannot be changed" note.

## PR-readiness and sequencing (read before opening PRs)

- **Pin chain blocker.** Rumble consumes WDK by git SHA
  (`git+https://github.com/tetherto/wdk-*.git#<sha>`). The rumble `package.json`
  pins are NOT bumped and cannot be until the WDK removals are merged on
  `tetherto` and produce a real SHA. Order per card: merge the WDK `refactor/...`
  PR -> get the merge SHA -> bump the matching rumble pin (a follow-up commit on
  the `feat/...` branch) -> merge the rumble PR. Card order: data-shard -> ork ->
  app-node.
- **Branches are local only.** Cut from current `dev`, single commit each. The
  original pre-split working tree is preserved in each repo as a git stash
  labeled `WDK-1196-wip-2026-06-19` (safety net, can be dropped once happy).
- **balance-budget reconciliation.** `feat/WDK-1196-channel-wallet-ownership` and
  `fix/balance-request-timeout-budget` both override `getUserBalance`. Whichever
  merges second needs a one-method reconcile (final form = budget wrapping the
  walletTypes-aware body).
- **Open design question (balance-budget branch).** Returning a successful
  `{ balance: null }` on timeout can mask a slow/failed chain indexer as an
  unknown balance. Decide during that PR's review whether to surface a distinct
  degraded signal.

## Verification

All changed repos: targeted unit tests pass and `standard` lint is clean on the
touched files. The stack was not booted (not required for these changes).
