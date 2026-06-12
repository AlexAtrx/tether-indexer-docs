# WDK-1196 / RW-1683 - simplest split

Parent: https://app.asana.com/1/45238840754660/project/1210540875949204/task/1213303070214495
Baseline: local code audit on 2026-06-09.

## What this ticket is

`rumble-*` repos extend pinned `wdk-*` packages. Rumble currently inherits a few
Rumble-specific wallet/channel behaviors from WDK:

- `wdk-app-node`: channel wallet schemas, `channelId`, `walletTypes`, response
  `channelId`, tip-jar error codes, and a Rumble UI `staticRootPath` example.
- `wdk-data-shard-wrk`: channel wallet creation/duplicate validation,
  `channelId` persistence, `getActiveChannelWallet`, Mongo/HyperDB channel
  indexes, and `walletTypes` filtering in balance/transfer reads.
- `wdk-ork-wrk`: channel-to-shard lookup type and `store/resolveChannelShard`,
  plus storing the channel lookup after wallet creation.

Rumble already owns some of the target behavior:

- `rumble-app-node`: user/channel tip-jar HTTP routes and channel ownership
  pre-handler, but wallet creation/balance/transfer schemas are still inherited.
- `rumble-data-shard-wrk`: user/channel tip-jar reads, channel wallet rename,
  jar-sync hooks, and rant/tip webhook handling, but core channel wallet storage
  and `walletTypes` semantics are still inherited from WDK.
- `rumble-ork-wrk`: user/channel tip-jar RPC and notification/rant/tip webhook
  orchestration, but channel shard lookup helpers are still inherited from WDK.

Rants are already Rumble-only in the local code. They need regression coverage
while touching notifications/webhooks, but they do not justify a separate WDK
removal card.

## Three cards

### 1. Data-shard ownership: move channel wallet storage/query semantics to Rumble

Scope:
- In `rumble-data-shard-wrk`, own channel wallet creation rules, `channelId`
  validation, duplicate checks, `getActiveChannelWallet`, wallet repository
  channel indexes/specs, and `walletTypes` filtering for balance/transfers.
- In `wdk-data-shard-wrk`, remove channel wallet behavior from proc/API/service
  code and tests. For HyperDB, stop using channel fields/indexes unless a
  reviewer explicitly approves a versioned schema removal.
- Keep existing Rumble tip-jar, channel rename, jar-sync, and rant/tip webhook
  behavior green.
- Bump Rumble's `@tetherto/wdk-data-shard-wrk` pin and run both test suites.

Why first: this is the persistence/source-of-truth layer and the riskiest piece.

### 2. Ork ownership: move channel shard lookup to Rumble

Scope:
- In `rumble-ork-wrk`, own `CHANNELS` lookup type, `storeChannelShard`,
  `resolveChannelShard`, and the `addWallet` behavior that stores a channel
  lookup when a returned wallet has `channelId`.
- In `wdk-ork-wrk`, remove `LOOKUP_TYPES.CHANNELS`, channel lookup helpers,
  channel lookup storage after wallet creation, and related tests.
- Keep Rumble `getChannelTipJar` and `updateChannelWalletName` routing green.
- Bump Rumble's `@tetherto/wdk-ork-wrk` pin and run both test suites.

Why second: Rumble's channel tip-jar routes depend on channelId -> shard routing.

### 3. App/API/docs ownership: move public channel/tip-jar surface to Rumble

Scope:
- In `rumble-app-node`, own the HTTP schemas and response schemas for channel
  wallets: `channel` wallet type, `channelId` on `POST /api/v1/wallets`,
  `walletTypes` on user balance/transfers, and Rumble-local tip-jar error codes.
- In `wdk-app-node`, remove channel wallet schema pieces, `walletTypes`,
  response `channelId`, tip-jar error codes, and Rumble-specific
  `staticRootPath` examples.
- Update docs: WDK docs/schema should no longer advertise channel wallets,
  `channelId`, `walletTypes`, or tip jar; Rumble docs should keep/own them.
- Bump Rumble's `@tetherto/wdk-app-node` pin and run both test suites.

Why last: once storage and routing are native to Rumble, the public API can stop
inheriting the WDK definitions without breaking Rumble.

## Dependency order

1. Data-shard
2. Ork
3. App/API/docs

Do not split this into "remove from WDK" cards and a later "add to Rumble" card.
Each card should end with the Rumble repo bumped to the cleaned WDK dependency so
the stack remains shippable at every step.
