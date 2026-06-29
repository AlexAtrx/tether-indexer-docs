# Reverted work — WDK-1196 / RW-1683 channel split (data-shard card #1)

Status: **all my code changes were undone on request** (parallel work in the
same files was preserved). This file is the exact reapply guide.

## Context
- Goal was the 3-card split (data-shard #1 / ork #2 / app+docs #3). Only **card #1
  (data-shard)** was partially implemented before the undo. Cards #2 and #3 were
  never started in code.
- A **parallel process** is actively editing the `rumble-*` repos on branch
  `feat/uma-wallet-config-RW-1920` (UMA / RW-1920 work). The `wdk-*` repos are on
  `dev` and had no parallel work.
- Open base decision (deferred): Alex chose "reset rumble-* to dev" for this
  refactor, but then asked to undo first. Branches were left as-is (rumble on
  feat/uma). Decide base before reapplying.

## Design decisions already settled (keep on reapply)
1. HyperDB: **keep** the generated channel schema/index/helper in `wdk` build
   (`channelId` field, `active-wallets-by-channel-id` index, `activeWalletsByChannelIdMap`)
   — append-only. Do NOT remove them. Only stop *using* channel in WDK code; move
   the query method + Mongo channel index + validation to Rumble.
2. Mongo channel index is NOT append-only constrained, so it moves cleanly to Rumble.

## Saved patches (in this folder)
- `wdk-data-shard-wrk.MINE.patch` — clean, 100% my changes. Reapply with:
  `git -C wdk-data-shard-wrk apply <path>` (from workspace root).
- `rumble-data-shard-wrk.MINE.patch` — **CAUTION: contains one parallel hunk**
  (the UMA username index `partialFilterExpression` -> `sparse: true` in
  `mongodb/.../wallets.js`) that is NOT mine. Do not reapply that hunk. Use the
  explicit edits below for the rumble side instead.

---

## My changes by file

### A) wdk-data-shard-wrk (make WDK generic) — branch `dev`
1. `workers/proc.shard.data.wrk.js` — in `addWallet`: dropped `channelId` from the
   per-wallet destructure; replaced the inline channel dup branch with
   `this._isDuplicateWallet(newWallet, w)`; replaced the `ERR_CHANNEL_ID_INVALID`
   block with `this._validateNewWallet(newWallet)`; replaced `...(channelId && { channelId })`
   with `...this._buildExtraWalletFields(newWallet)`. Added three generic hook
   methods before `addWallet`:
   - `_isDuplicateWallet(newWallet, existing)` -> `newWallet.type === 'user' && existing.type === 'user'`
   - `_validateNewWallet(newWallet)` -> `null`
   - `_buildExtraWalletFields(newWallet)` -> `{}`
2. `workers/lib/db/base/repositories/wallets.js` — removed the abstract `getActiveChannelWallet`.
3. `workers/lib/db/mongodb/repositories/wallets.js` — removed the `channelId` index
   in `ready()` and the `getActiveChannelWallet` method.
4. `workers/lib/db/hyperdb/repositories/wallets.js` — removed `this.activeWalletsByChannelId`
   and the `getActiveChannelWallet` method. (build.js / helpers.js / spec untouched.)
5. `workers/api.shard.data.wrk.js` — `getUserBalance(req)` -> `this.blockchainSvc.getUserBalance(userId)`
   (no walletTypes). Added generic hook `_filterUserWallets(wallets, req) { return wallets }`.
   `getUserTransfers` + `getUserSparkBitcoinMainnetTransfers`: dropped `walletTypes`
   from destructure, replaced inline `if (walletTypes ...) continue` with iterating
   `this._filterUserWallets(userWallets, req)`. `getUserTransfersV2`: dropped the
   `walletTypes` branch, kept only the generic `findForUser` path.
6. `workers/lib/blockchain.svc.js` — `getUserBalance(userId)` (dropped `walletTypes`
   param + filter loop).
7. Tests: `tests/unit/proc.shard.data.wrk.unit.test.js` (removed the two channel
   tests: "channelId not provided" and "channel wallet already exists"; switched the
   wallet-limit fixtures from `type:'channel'`+channelId to `type:'unrelated'`),
   `tests/unit/api.shard.data.wrk.unit.test.js` (channel fixture -> unrelated),
   `tests/proc.shard.data.wrk.intg.test.js` and `tests/api.shard.data.wrk.intg.test.js`
   (deleted channelId fixture props, `type:'channel'`->`'unrelated'`, removed
   getActiveChannelWallet assertions in the deletion-cascade test, removed the two
   walletTypes tests in api.intg).
   Unit tests passed (56/56) + lint clean. Intg tests gated on MongoDB (not runnable
   locally), migrated by inspection.

### B) rumble-data-shard-wrk (Rumble owns channel) — was applied on `feat/uma`
> The exact additions to reapply (these are mine; nothing else in these files is):

`workers/proc.shard.data.wrk.js` — add before `async addWallet (req) {`:
```js
  // Channel wallets are Rumble-specific: one channel wallet per channelId.
  _isDuplicateWallet (newWallet, existing) {
    if (newWallet.type === WALLET_TYPES.CHANNEL) {
      return existing.type === WALLET_TYPES.CHANNEL && existing.channelId === newWallet.channelId
    }
    return super._isDuplicateWallet(newWallet, existing)
  }

  _validateNewWallet (newWallet) {
    if (newWallet.type === WALLET_TYPES.CHANNEL && !newWallet.channelId) {
      return 'ERR_CHANNEL_ID_INVALID'
    }
    return super._validateNewWallet(newWallet)
  }

  _buildExtraWalletFields (newWallet) {
    return newWallet.channelId ? { channelId: newWallet.channelId } : {}
  }
```

`workers/api.shard.data.wrk.js` — add before `async getUserTipJar (req) {`:
```js
  // Rumble exposes optional wallet-type filtering (e.g. user vs channel) on the
  // user balance/transfer reads via the request-level `walletTypes` field.
  _filterUserWallets (wallets, req) {
    return req.walletTypes ? wallets.filter(w => req.walletTypes.includes(w.type)) : wallets
  }

  async getUserBalance (req) {
    const { userId, walletTypes } = req
    if (!walletTypes) {
      return super.getUserBalance(req)
    }

    const wallets = (await this.db.walletRepository.getActiveUserWallets(userId).toArray())
      .filter(w => walletTypes.includes(w.type))
    if (wallets.length === 0) {
      return { balance: '0', tokenBalances: {} }
    }

    const { balance, tokenBalances } = await this.blockchainSvc.getAggregatedWalletBalance(wallets)
    return { balance, tokenBalances }
  }

  async getUserTransfersV2 (req) {
    const { walletTypes } = req
    if (!walletTypes) {
      return super.getUserTransfersV2(req)
    }

    const { userId, blockchain, token, type, from, to, limit = 10, skip = 0, sort = 'desc' } = req
    if (!userId) {
      throw new Error('ERR_USER_ID_INVALID')
    }

    const userWallets = await this.db.walletRepository.getActiveUserWallets(userId).toArray()
    if (userWallets.length === 0) {
      throw new Error('ERR_USER_WALLETS_NOT_FOUND')
    }

    const eligibleWallets = userWallets.filter(w => walletTypes.includes(w.type))
    if (eligibleWallets.length === 0) {
      throw new Error('ERR_NO_ELIGIBLE_WALLETS')
    }

    const reverse = sort.toLowerCase() === 'desc'
    const docs = await this.db.walletTransfersProcessedRepository
      .findForWallets(eligibleWallets.map(w => w.id), blockchain, token, type, from, to, reverse, skip, limit)
      .toArray()

    return { transfers: docs.map(doc => this._mapProcessedToResponse(doc)) }
  }
```

`workers/lib/db/hyperdb/repositories/wallets.js` — in the constructor add
`this.activeWalletsByChannelId = '@wdk-data-shard/active-wallets-by-channel-id'`,
and add the method:
```js
  // Channel wallets are Rumble-specific: resolve the active wallet for a channelId.
  getActiveChannelWallet (channelId) {
    return this.dbOrTx.findOne(this.activeWalletsByChannelId, {
      gte: channelId,
      lte: channelId
    })
  }
```

`workers/lib/db/mongodb/repositories/wallets.js` — in `ready()` after the username
index add the channel index, and add the method (DO NOT touch the username index,
that is parallel work):
```js
    await this.collection.createIndex(
      { channelId: 1, enabled: 1, deletedAt: 1 },
      { background: true, name: 'idx_wdk_data_shard_wallets_active_wallets_by_channel_id' }
    )
```
```js
  // Channel wallets are Rumble-specific: resolve the active wallet for a channelId.
  getActiveChannelWallet (channelId) {
    return this.collection.findOne({
      channelId,
      deletedAt: { $lte: 0 }
    }, {
      ...this.sessionOpts,
      readPreference: this.readPreference,
      projection: { _id: 0 },
      maxTimeMS: this.operations.readTimeout ?? 30000
    })
  }
```

Still TODO on the Rumble side when reapplying: add Rumble tests for the channel
hooks (dup, ERR_CHANNEL_ID_INVALID, channelId persistence) and walletTypes filtering
(these were removed from the WDK suite and need a Rumble home).

### C) Integration test note
Local integration tests need a live MongoDB (worker boot fails on auth otherwise),
so the intg edits were inspection-only. Validate them in CI.

### D) Non-source side effects (left in place, not reverted)
- `wdk-data-shard-wrk/config/*.json` were generated by `./setup-config.sh`
  (gitignored test scaffolding): `proc.shard.data.json`, `facs/{redis,net,db-mongo}.config.json`.
  Harmless; remove if a pristine config dir is wanted.
- The `node_modules` WDK overlay in rumble-data-shard-wrk was restored to the pinned
  commit `49e4444b8ff0063d3797cc441085b4df25c3c2f1` (no npm, via `git archive`).

## Cards not started (no code written)
- Card #2 ork: in `wdk-ork-wrk` remove `LOOKUP_TYPES.CHANNELS` + `store/resolveChannelShard`
  + the channelId branch in `api.addWallet`; add a `_createShardUtil()` factory seam.
  In `rumble-ork-wrk` add a `RumbleDataShardUtil` (CHANNELS + store/resolveChannelShard),
  override `_createShardUtil`, and override `addWallet` to store the channel shard.
  Note: user-deletion cascade (`delLookupsForUser`) deletes by `userId` generically,
  so dropping CHANNELS from WDK does not leak channel lookups.
- Card #3 app+docs: in `wdk-app-node` remove `channel` from `walletEnum` + `walletTypes`
  schema, `channelId` from POST /wallets + response validator, `walletTypes` query
  params on balance/transfers/spark/v2 + ork.js forwarding, tip-jar error codes,
  Rumble `staticRootPath` example, and channel/tip-jar docs. Re-home all of that in
  `rumble-app-node`. Each card ends by bumping Rumble's `@tetherto/wdk-*` pin (a
  post-merge step; cannot produce a real pushed SHA in local-only mode).
