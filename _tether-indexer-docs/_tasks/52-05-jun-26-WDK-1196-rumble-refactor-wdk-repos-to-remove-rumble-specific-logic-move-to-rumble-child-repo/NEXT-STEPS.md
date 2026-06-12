# Next steps for WDK-1196 / RW-1683 — split Rumble-specific logic out of wdk-*

**Ticket:** https://app.asana.com/1/45238840754660/project/1210540875949204/task/1213303070214495

## What we know
- Large refactor/epic to make `wdk-*` repos generic by removing all Rumble-specific logic — channel wallet type, `channelId` and channel–shard lookups, tip jar (user + channel) APIs and error codes, Rumble config/docs.
- That functionality must move into the Rumble child repos: `rumble-app-node`, `rumble-data-shard-wrk`, `rumble-ork-wrk`, with Rumble retaining equivalent behavior and passing tests independently of `wdk-*`.
- Description gives a concrete per-repo removal list (wdk-app-node, wdk-data-shard-wrk, wdk-ork-wrk) plus doc updates and acceptance criteria.
- **The card is explicitly "TO BE SPLIT" and BLOCKED.** Francesco asked Alex in a comment, then reassigned it on 2026-06-05; Alex confirmed on 2026-06-09 that the split itself is the deliverable.
- High priority, Sprint 3, in both WDK Backends (DEV IN PROGRESS) and Rumble Wallet (To Triage).

## Evidence captured here
- 0 images, 0 attachments (none on the ticket)
- 1 real comment in `comments.md` (Francesco: "can you please split this card?") + full event timeline

## What's missing (from `missing-context.md`)
- The actual reason for the BLOCKED flag, and if it still holds
- HyperDB migration semantics for WDK `channelId` and channel indexes

## Before starting work
This is not a "go implement" ticket yet. The first deliverable is the **card split**, not code. When picking this up:
1. Use `LOCAL-CODE-AUDIT.md` as the current ownership map.
2. Use `SPLIT-PROPOSAL.md` as the suggested three-card split: data-shard, ork, app/API/docs.
3. Resolve the HyperDB migration question before filing/starting the data-shard card.
