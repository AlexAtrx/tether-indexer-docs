# Next steps for RW-1760 — Full balance loads slowly / progressively

**Ticket:** https://app.asana.com/1/45238840754660/project/1212521145936484/task/1214949587112861

## What we know
- After login, the Home/Balance screen takes ~1 minute to fully load.
- Balances arrive piece by piece: main balance stays in a loading state while
  individual asset balances trickle in at different times.
- Reported on iPhone 14 Pro, iOS 26.4.2, app v2.2.0 (596). Priority High, Sprint 2/3.
- Tagged Stack "BE - Backend", Rumble Area "Wallet & Tipjars logic".
- Currently in "To Triage". Francesco asked if it's already fixed; Alex's initial
  read is that it should likely be **postponed until transaction-history V2** ships,
  pending a double-check.
- **Frames from the video (see `image-analysis.md`) confirm and extend this:**
  Total Balance climbs in stages (blank → $0.67 → $2.27 → $4.25) over ~1 min, and
  per-asset values keep *changing* (Bitcoin 0 → 879 → 928 → 2 317 sats), i.e. the
  balance is recomputed/reassembled rather than just revealed late.
- **Possible correctness bug:** final-frame totals don't reconcile — Total $4.25
  vs Local $2.08 + kartofili $2.08 = $4.16. Alex flagged he's "not sure the new
  balance is the right balance." Treat as a separate question from the slowness.

## Evidence captured here
- 4 video frames analysed in `image-analysis.md` (extracted by Alex into `shots/`)
- 1 non-image attachment under `attachments/` — a ~20MB `.MOV` screen recording
  of the slow load (source of the frames; not text-readable)
- 2 comments in `comments.md` (Francesco + Alex)

## What's missing (from `missing-context.md`)
- Manual review of the `.MOV` for any extra signal beyond the description
- Confirmation that "transaction history V2" is the real blocker + a link to that work
- Clarification on BE vs app-side root cause (build is an app build, but Stack=Backend)

## Before starting work
Ask Alex the three items in `missing-context.md` first — especially whether this is
genuinely blocked on trx-history V2 (in which case it's a postpone/triage decision,
not an immediate fix) and which layer (indexer balance aggregation vs app rendering)
to investigate. If V2 is confirmed as the dependency, the action here is to link/park
the ticket rather than dig into code.
