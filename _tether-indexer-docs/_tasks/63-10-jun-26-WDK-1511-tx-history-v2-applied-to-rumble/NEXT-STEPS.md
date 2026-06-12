# Next steps for TX history V2 applied to Rumble (WDK-1511)

**Ticket:** https://app.asana.com/1/45238840754660/project/1210540875949204/task/1215173997871250

## What we know
- Epic/planning card: roll out TX history V2 (WDK) to Rumble, starting on Dev.
- Scope is being split: one card for "just rumble id" (TX history V2 + rumble label support), a second card for Moonpay swaps support.
- This card needs to (a) deploy/support TX history V2 WDK on Dev and (b) make sure rumble labels are supported.
- Moonpay swaps support may be moved to a separate card.
- Currently marked High priority, Sprint 3, BLOCKED (set 2026-06-05). Assigned to Alex on 2026-06-09.
- Status note: "waiting for testing finalized in tether wallet staging; update is being merged."

## Evidence captured here
- 0 images analysed
- 0 non-image attachments
- 0 user comments (only system events in `comments.md`)

## What's missing (from `missing-context.md`)
- Which TX history V2 PR(s) are being merged / tested on wallet staging
- Whether Moonpay swaps is in scope here or in the separate card
- What is blocking the ticket (and whether it is now unblocked)
- Exact meaning/location of "rumble labels" in the TX history V2 path

## Before starting work
This is a high-level epic card with no spec or comments. **Ask Alex the missing
items above first** — especially the scope split (rumble id vs Moonpay) and what
TX history V2 concretely changes — before digging into the WDK indexer / rumble
codebase.
