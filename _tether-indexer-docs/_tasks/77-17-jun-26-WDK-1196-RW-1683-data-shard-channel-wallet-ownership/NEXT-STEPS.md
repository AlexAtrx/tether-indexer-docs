# Next steps for WDK-1196 / RW-1683 — data-shard channel wallet ownership

**Ticket:** https://app.asana.com/1/45238840754660/project/1212521145936484/task/1215537119353708

## Position in the split (card #1 of 3 — do FIRST)

- **Parent:** "Rumble - Create cards for Refactor of wdk-* Repos" (GID `1213303070214495`)
  → `_tasks/52-05-jun-26-WDK-1196-rumble-refactor-wdk-repos-to-remove-rumble-specific-logic-move-to-rumble-child-repo/`
- **Card #2 (ork routing):** `_tasks/78-17-jun-26-WDK-1196-RW-1683-rumble-owned-channel-shard-routing/`
- **Card #3 (app + docs):** `_tasks/76-17-jun-26-WDK-1196-RW-1683-rumble-owned-channel-wallet-api-and-docs/`
- Dependency order: **this card first**, then ork routing, then app/docs.

## What we know

- Storage slice. Move Rumble-specific channel wallet storage/query semantics out of
  `wdk-data-shard-wrk` into `rumble-data-shard-wrk`: channel wallet creation rules,
  `channelId` validation, duplicate checks, `getActiveChannelWallet`, wallet repo
  channel indexes/specs, `walletTypes` filtering for balance/transfers.
- In `wdk-data-shard-wrk`, remove channel wallet behavior from proc/API/service code
  and tests. For HyperDB, do NOT remove channel fields/indexes without a reviewer
  decision (append-only rule).
- End state: bump Rumble's `@tetherto/wdk-data-shard-wrk` pin and keep both suites green.
- High priority, Sprint 3/4, In-Progress in Rumble Wallet.

## Evidence captured here

- 0 images, 0 attachments, 0 user comments (system stories only, in `comments.md`).

## What's missing (from `missing-context.md`)

- HyperDB schema/index removal reviewer decision.
- Ticket-ID confirmation (title epic vs RW-1870/WDK-1530).

## Before starting work

This is the riskiest layer. Resolve the HyperDB decision first, then use the parent
folder's `SPLIT-PROPOSAL.md` (card #1) and `LOCAL-CODE-AUDIT.md` as the ownership map.
