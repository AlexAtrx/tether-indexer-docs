# Next steps for RW-1862 — completed rant txs not showing in chat

**Ticket:** https://app.asana.com/1/45238840754660/project/1212521145936484/task/1215461909208384

## What we know
- Rants sent through the wallet complete on-chain and the recipient gets the funds, but the rant never appears in chat. Seen on both prod and staging.
- Reported by Mariia in Slack during mobile testing.
- This is framed as an **implementation** ticket, not an investigation: "implement what did with WDK-1515 in `wdk-ork-wrk` and `rumble-ork-wrk`". WDK-1515 was the ERR_WALLET_TRANSFER_RPC_FAIL ("RPC client closed") issue that required data-shard restarts; the same RPC reconnect/recovery fix needs to be ported into the two ork workers.
- Confirmed example txs (nothing displayed in chat):
  - Prod: 0.045 scudos ($0.20) Jun 4 16:04 — eth tx 0x7371...ccaa5
  - Prod: 0.3 USDt ($0.30) Jun 4 16:09 — plasma tx 0xa1c7...4d7fe
  - Staging: 0.227 scudos ($1.00) Jun 5 09:17 — eth tx 0x424b...0b027
- Priority High, Sprint 3 (Francesco: added mid-sprint, likely lands in Sprint 4 but prioritize).

## Evidence captured here
- 0 images
- 0 non-image attachments
- 1 substantive comment in `comments.md` (+ system events)

## What's missing (from `missing-context.md`)
- Slack thread (C094R63HQ64 / p1780603661792139) — Mariia's report.
- The WDK-1515 fix itself — it is the spec for this port.
- Ork-worker logs around the example tx timestamps.

## Before starting work
Pull the WDK-1515 resolution first (that defines what to implement), then the Slack thread. The chat-drop is almost certainly the ork RPC client closing (same root cause as WDK-1515) breaking the notification/chat-write path after the on-chain transfer succeeds. Trace the rant notification path: rumble-app-node → rumble-ork-wrk (sendNotification) → rumble-data-shard-wrk, and the wdk-ork-wrk transfer path, for where a closed RPC client silently drops the post-transfer chat write.
