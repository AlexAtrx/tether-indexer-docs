# Next steps for WDK-1196 / RW-1683 — Rumble-owned channel wallet API and docs

**Ticket:** https://app.asana.com/1/45238840754660/project/1212521145936484/task/1215537079067713

## Position in the split (card #3 of 3 — do LAST)

- **Parent:** "Rumble - Create cards for Refactor of wdk-* Repos" (GID `1213303070214495`)
- **Local parent folder:** `_tasks/52-05-jun-26-WDK-1196-rumble-refactor-wdk-repos-to-remove-rumble-specific-logic-move-to-rumble-child-repo/`
- This is the **app + docs slice** of that parent split. Read the parent's
  `SPLIT-PROPOSAL.md`, `LOCAL-CODE-AUDIT.md`, and `CREATED-ASANA-TICKETS.md` first.
- **Card #1 (data-shard, do first):** `_tasks/77-17-jun-26-WDK-1196-RW-1683-data-shard-channel-wallet-ownership/`
- **Card #2 (ork routing, do second):** `_tasks/78-17-jun-26-WDK-1196-RW-1683-rumble-owned-channel-shard-routing/`
- Dependency order: data-shard → ork routing → **this card last**.

## What we know

- Goal: make public API ownership clear. WDK app-node must stop exposing
  Rumble-specific channel-wallet / tip-jar concepts; Rumble keeps owning them.
- Scope is the **app layer and docs** only (the storage and routing slices are
  separate sibling tickets from the same split).
- Sequencing: do this **last**, after storage and routing are already Rumble-owned.
- Expected end state: WDK app + docs generic again; Rumble app + docs keep the
  channel-wallet / tip-jar surface; Rumble dependency moves to the cleaned WDK
  app-node version.
- High priority, Sprint 3/4, currently In-Progress in Rumble Wallet.

## Evidence captured here

- 0 images analysed
- 0 non-image attachments
- 0 user comments (system stories only, summarised in `comments.md`)

## What's missing (from `missing-context.md`)

- Confirm storage + routing sibling slices are done before starting (sequencing dep).
- Resolve ticket-ID mismatch (title WDK-1196/RW-1683 vs fields RW-1872/WDK-1532).

## Before starting work

Confirm the sibling slices are merged so this can safely be "last". Then use the
parent folder's audit/proposal docs as the design source for which WDK app-node
endpoints and docs to genericise and which to keep on the Rumble side.
