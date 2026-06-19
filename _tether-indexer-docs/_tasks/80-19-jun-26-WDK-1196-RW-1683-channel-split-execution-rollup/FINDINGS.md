# Review findings and fixes - WDK-1196 / RW-1683

Findings raised against the initial channel-split commits, with the fix applied
to each. All fixes were folded into the relevant card commit (amended), except
finding 2 which produced a new split-out branch.

## Finding 1 - channelId not type-gated below HTTP

**Where:** `rumble-data-shard-wrk/workers/proc.shard.data.wrk.js`,
`rumble-ork-wrk/workers/api.ork.wrk.js`.

**Problem:** The `channelId` invariant was enforced only in the app-node JSON
schema. Internal HRPC callers bypass that schema, so `addWallet({ type: 'user',
channelId: 'x' })` could persist a `channelId` on a non-channel wallet, and the
ork would create a channel -> shard lookup for it. Enforcement was at the wrong
trust level.

**Fix:**
- data-shard `_validateNewWallet` now rejects `channelId` on any non-channel
  wallet type (`ERR_CHANNEL_ID_INVALID`). A validation error sets `status: 400`
  and skips persistence; the ork lookup gates on `status === 201`, so this single
  change closes both the persistence and the lookup vector.
- ork `addWallet` gate changed from `wallet?.channelId` to
  `wallet?.type === CHANNEL_WALLET_TYPE` (correct trust level for the ork's own
  decision to create a lookup).
- Tests added: data-shard `_validateNewWallet` rejection case; ork addWallet
  test now includes a non-channel-wallet-carrying-channelId case.

Folded into `4f3164a` (data-shard) and `37543e3` (ork).

## Finding 2 - unrelated balance-timeout policy mixed into the split

**Where:** `rumble-data-shard-wrk/workers/api.shard.data.wrk.js`.

**Problem:** The WDK-1196 commit bundled in `USER_BALANCE_BUDGET_MS` +
`_runWithinBalanceBudget`, wrapping every `getUserBalance` (including the generic
unfiltered path) to degrade to `{ balance: null, tokenBalances: {} }` after 20s.
This is the Rumble counterpart of the WDK-side balance-budget work, not channel
ownership. It was untested and broadened the blast radius of the refactor.

**Fix:** Extracted the budget code out of the WDK-1196 commit (kept only the
walletTypes filtering in `getUserBalance`). Moved the budget to its own branch
`fix/balance-request-timeout-budget` (`e867c8d`) off `dev`, mirroring the WDK
branch of the same name, as a budget-only override of `super.getUserBalance`.

WDK-1196 data-shard commit amended to `4f3164a`.

**Open question for that branch's review:** returning a successful null balance on
timeout can mask a slow/failed chain indexer as "unknown balance"; consider a
distinct degraded signal.

## Finding 3 - Rumble docs stayed generic after re-adding schemas

**Where:** `rumble-app-node/workers/lib/server.js`.

**Problem:** `applyChannelWalletSchemas` re-added schema properties (channelId,
walletTypes, channel type) but not the route descriptions that WDK genericized.
Rumble's generated Swagger under-documented the exact surface this card re-homes.
Also affected the wallet update route's "Channel id cannot be changed" note. The
v2 transfers route never had a description, so nothing to restore there.

**Fix:** Added `CHANNEL_ROUTE_DESCRIPTIONS` and a loop in
`applyChannelWalletSchemas` that restores the Rumble-owned descriptions for the
six routes whose channel/walletTypes schema is re-added (POST/GET/PATCH wallets,
balance, v1 token-transfers, spark token-transfers). Added
`tests/channel-wallet-schemas.unit.test.js` covering both the re-added schemas and
the restored descriptions.

Folded into `9a48eec` (app-node).
