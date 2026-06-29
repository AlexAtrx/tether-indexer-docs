# Handling — WDK-1196 / RW-1683 — split Rumble channel/tip-jar logic out of wdk-*

Covers all three cards of the split, implemented in dependency order
(data-shard → ork → app+docs). This folder is card #3 (app+docs); cards #1/#2
live in `_tasks/77-...` and `_tasks/78-...`.

## Type
refactor (move Rumble-specific channel-wallet + tip-jar + walletTypes surface
out of generic `wdk-*` into the `rumble-*` overlays).

## What was wanted
`wdk-*` must be generic: no `channel` wallet type, `channelId`, channel->shard
lookups, `walletTypes` filter, tip-jar error codes, or Rumble config. Rumble
keeps all of it working via its overlays. Each card ends shippable.

## Design decisions
- HyperDB (data-shard): **keep** the generated channel schema/index/helper in
  the wdk build (append-only); only stop *using* channel in wdk code and move the
  query + Mongo index + validation to Rumble. (Confirmed with Alex.)
- Generic seams added to wdk (overridden by the Rumble overlays), not branches:
  proc `_isDuplicateWallet` / `_validateNewWallet` / `_buildExtraWalletFields`;
  api `_filterUserWallets`; ork `_createShardUtil`.
- Channel->shard lookup cleanup on user delete is generic (deletes by `userId`),
  so dropping `LOOKUP_TYPES.CHANNELS` from wdk does not leak channel lookups.

## Change (by card)

### Card #1 — data-shard
- `wdk-data-shard-wrk` (generic): proc.addWallet uses the 3 hooks (channel logic
  gone); removed `getActiveChannelWallet` from base/mongo/hyperdb repos + the
  Mongo channel index; removed `walletTypes` from api (`getUserBalance`,
  `getUserTransfers`, `getUserSparkBitcoinMainnetTransfers`, `getUserTransfersV2`)
  via `_filterUserWallets`; removed `walletTypes` from `blockchain.svc.getUserBalance`.
  Kept HyperDB build/helpers/spec untouched.
- `rumble-data-shard-wrk` (owns channel): proc overrides the 3 hooks (channel
  dup, `ERR_CHANNEL_ID_INVALID`, channelId persistence); added
  `getActiveChannelWallet` + the Mongo channel index to the Rumble wallet repos;
  api overrides `_filterUserWallets` + `getUserBalance` + `getUserTransfersV2` for
  `walletTypes`.

### Card #2 — ork
- `wdk-ork-wrk` (generic): removed `LOOKUP_TYPES.CHANNELS`, `storeChannelShard`,
  `resolveChannelShard`, the channelId branch in `api.addWallet`; added a
  `_createShardUtil()` factory seam.
- `rumble-ork-wrk` (owns channel): new `lib/data.shard.util.js`
  (`RumbleDataShardUtil` with `CHANNELS` + store/resolveChannelShard); overrides
  `_createShardUtil`; the existing UMA `addWallet` override now also stores the
  channel->shard lookup for created channel wallets (merged, not duplicated).

### Card #3 — app + docs
- `wdk-app-node` (generic): removed `channel` from `walletEnum` + the `walletTypes`
  schema (`schemas/common.js`); removed `channelId` from POST `/api/v1/wallets`
  body + the channel conditional; removed `walletTypes` query param from the user
  balance + 3 transfer routes (+ cache key + `services/ork.getUserBalance`
  forwarding); removed `channelId` from the wallet response schema; removed the
  tip-jar error codes; replaced the Rumble `staticRootPath` in the config example.
- `rumble-app-node` (owns channel/tip-jar): new `applyChannelWalletSchemas(ctx)`
  re-adds, on the inherited routes, the `channel` type + `channelId` (POST
  /wallets) and `walletTypes` (balance + 3 transfer routes), and overrides the
  cached user-balance handler to key on + forward `walletTypes`; added a Rumble
  `service.ork.getUserBalance` walletTypes forwarder; added the tip-jar error
  codes to Rumble's error map; added `channelId` to the Rumble wallet response
  schemas (uma.js). Docs are the Swagger generated from these route schemas, so
  the schema moves are the doc moves (wdk drops channel, Rumble keeps it).

## Repos touched
- wdk-data-shard-wrk, rumble-data-shard-wrk
- wdk-ork-wrk, rumble-ork-wrk
- wdk-app-node, rumble-app-node

## Tests
- wdk-data-shard-wrk: `npm run test:unit` 56/56 pass; lint clean. Channel/walletTypes
  removed from intg tests by inspection (intg needs MongoDB, not runnable locally).
- rumble-data-shard-wrk: `npm run test:unit` 97/99 (the 2 failures are pre-existing
  `rantTransactionInit/Confirm` logger tests, fail with my changes stashed too);
  added a channel-hooks unit test; lint clean.
- wdk-ork-wrk: edited `data.shard.util` unit test + 2 intg cascade tests; files
  syntax-checked. (Repo's `standard` + the `_setShards` unit test are pre-broken in
  this env, shown failing on committed HEAD; unrelated to this change.)
- rumble-ork-wrk: `npm run test:unit` 14/14 pass incl. a new `RumbleDataShardUtil`
  test; lint clean.
- wdk-app-node: unit 71/72 (the 1 failure is a pre-existing `JwtGuard noAuth` test,
  fails with my changes stashed too); lint clean.
- rumble-app-node: unit 43/43 pass; lint clean; the intg `POST /api/v1/wallets
  channel validation` test passes (proves the re-homed channelId schema accepts
  channel wallets). The intg `/wallets/:id/balance` failure is pre-existing
  (`token_balances` vs `tokenBalances`), fails on pinned WDK too.

Cross-repo integration was validated by overlaying the edited wdk-* `workers/`
into each rumble-* `node_modules` (the git-pinned copy) and running the Rumble
suites against it.

## Local-only / open points
- All work is local: no commits, no pushes, no Asana, no PRs.
- **Pin bumps not done** (each card should end with Rumble's `@tetherto/wdk-*`
  pin bumped to the cleaned wdk commit): impossible in local-only mode (needs a
  pushed SHA). The `node_modules` overlay stands in for it locally; restore with
  `npm install` or re-archive the pins (data-shard `49e4444`, ork `b72e608`,
  app `32b3b80`).
- **Base:** all six repos (wdk-* and rumble-*) are now on `dev`, with the changes
  as uncommitted working-tree edits. The rumble side was initially authored on
  `feat/uma-wallet-config-RW-1920` (the active parallel UMA branch), then re-based
  onto `dev` at Alex's request, **decoupling the channel refactor from the
  (unmerged) UMA work**. The UMA-entangled spots were re-authored against the
  UMA-less dev base: the rumble-ork `addWallet` is now a standalone override (dev
  has no UMA `addWallet`), the rumble Mongo wallet repo keeps only the channel
  index/method (no UMA username index), and the `uma.js` response-schema edit was
  dropped (the file does not exist on dev; channelId still flows in responses via
  WDK's `additionalProperties: true`). Backup patches of the feat/uma-based work
  are in `_my-changes-to-reapply/on-feat-uma-backup/`.
- HyperDB: a future versioned removal of the wdk channel field/index is possible
  if a reviewer approves a migration; deferred per the append-only rule.
- Reapply patches/record: `_tasks/77-.../_my-changes-to-reapply/`.

## Assumptions
- `walletTypes` is treated as Rumble-specific across the whole stack (consistent
  with card #1), so it was removed from wdk and re-homed to Rumble end to end.
- `unrelated` stays a generic wdk wallet type; only `channel` is Rumble-specific.
