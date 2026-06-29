# Missing context

The ticket body is self-contained, but it is one slice of a multi-ticket split and
explicitly sequences itself after sibling work. Items to confirm before starting:

- [ ] Sibling tickets / sequencing: "this should be last, after storage and routing
  are already owned by Rumble." — **Need from Alex:** confirm the storage and routing
  slices are merged/deployed before this app+docs slice starts. **Source:** description.
  The sibling tickets are tracked in the parent folder
  `_tasks/52-05-jun-26-WDK-1196-.../CREATED-ASANA-TICKETS.md` and `SPLIT-PROPOSAL.md`.
- [ ] Ticket-ID mismatch: title says `WDK-1196 / RW-1683` but custom fields say
  `RW-1872` / `WDK-1532`. — **Need from Alex:** which ID is canonical for tracking.
  **Source:** task custom fields vs title.

The substantive design context (which WDK app-node endpoints expose channel-wallet /
tip-jar concepts, what to move to Rumble) lives in the parent folder's
`SPLIT-PROPOSAL.md` and `LOCAL-CODE-AUDIT.md` — read those first when handling.
