# Handling — card #1 (data-shard) of the WDK-1196 / RW-1683 split

Implemented as part of the linked 3-card change set. Full write-up (all cards,
tests, open points) is in the sibling card #3 folder:
`_tasks/76-...-rumble-owned-channel-wallet-api-and-docs/HANDLING.md`.

## This card (data-shard)
- `wdk-data-shard-wrk` made generic: proc.addWallet channel logic moved behind
  `_isDuplicateWallet` / `_validateNewWallet` / `_buildExtraWalletFields` hooks;
  `getActiveChannelWallet` + Mongo channel index removed from the wallet repos;
  `walletTypes` removed from the api reads + `blockchain.svc` via `_filterUserWallets`.
  HyperDB build/helpers/spec kept untouched (append-only).
- `rumble-data-shard-wrk` owns channel: overrides those hooks (channel dup,
  `ERR_CHANNEL_ID_INVALID`, channelId persistence), adds `getActiveChannelWallet`
  + the Mongo channel index to its wallet repos, and re-adds `walletTypes`
  filtering (api `_filterUserWallets` + `getUserBalance` + `getUserTransfersV2`).
- Tests: wdk unit 56/56, rumble unit 97/99 (2 pre-existing rant failures). Lint
  clean. Intg edits by inspection (intg needs MongoDB).

Reapply patches/record: `./_my-changes-to-reapply/`.
