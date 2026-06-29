# Missing context

The Asana body is high level by design; the detailed guidance lives in the parent
folder. Items to confirm before starting:

- [ ] HyperDB schema/index removal: "HyperDB needs a reviewer decision before anyone
  removes generated schema/index material." — **Need from Alex:** the reviewer
  decision on whether WDK channel fields/indexes can be removed via a versioned
  schema removal, or must stay (append-only rule). **Source:** description.
- [ ] Ticket-ID note: title says `WDK-1196 / RW-1683` (shared epic) but this card is
  `RW-1870` / `WDK-1530`. — **Need from Alex:** confirm canonical ID for tracking.
  **Source:** custom fields vs title.

Design source for the actual move: parent folder
`_tasks/52-05-jun-26-WDK-1196-.../SPLIT-PROPOSAL.md` (card #1) and `LOCAL-CODE-AUDIT.md`.
