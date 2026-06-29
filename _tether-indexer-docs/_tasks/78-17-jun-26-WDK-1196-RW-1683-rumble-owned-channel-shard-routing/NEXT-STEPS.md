# Next steps for WDK-1196 / RW-1683 — Rumble-owned channel shard routing

**Ticket:** https://app.asana.com/1/45238840754660/project/1212521145936484/task/1215537218483628

## Position in the split (card #2 of 3 — do SECOND)

- **Parent:** "Rumble - Create cards for Refactor of wdk-* Repos" (GID `1213303070214495`)
  → `_tasks/52-05-jun-26-WDK-1196-rumble-refactor-wdk-repos-to-remove-rumble-specific-logic-move-to-rumble-child-repo/`
- **Card #1 (data-shard, do first):** `_tasks/77-17-jun-26-WDK-1196-RW-1683-data-shard-channel-wallet-ownership/`
- **Card #3 (app + docs, do last):** `_tasks/76-17-jun-26-WDK-1196-RW-1683-rumble-owned-channel-wallet-api-and-docs/`
- Dependency order: data-shard first, **this card second**, then app/docs.

## What we know

- Ork routing slice. Move channel-to-shard lookup out of `wdk-ork-wrk` into
  `rumble-ork-wrk`: `CHANNELS` lookup type, `storeChannelShard`, `resolveChannelShard`,
  and the `addWallet` behavior that stores a channel lookup when a returned wallet has
  `channelId`.
- In `wdk-ork-wrk`, remove `LOOKUP_TYPES.CHANNELS`, channel lookup helpers, channel
  lookup storage after wallet creation, and related tests.
- Keep Rumble `getChannelTipJar` and `updateChannelWalletName` routing green.
- End state: bump Rumble's `@tetherto/wdk-ork-wrk` pin and keep both suites green.
- Why second: Rumble's channel tip-jar routes depend on channelId -> shard routing.
- High priority, Sprint 3/4, In-Progress in Rumble Wallet.

## Evidence captured here

- 0 images, 0 attachments, 0 user comments (system stories only, in `comments.md`).

## What's missing (from `missing-context.md`)

- Confirm card #1 (data-shard) is done before starting.
- Ticket-ID confirmation (title epic vs RW-1871/WDK-1531).

## Before starting work

Confirm the data-shard slice is merged, then use the parent folder's `SPLIT-PROPOSAL.md`
(card #2) and `LOCAL-CODE-AUDIT.md` as the ownership map.
