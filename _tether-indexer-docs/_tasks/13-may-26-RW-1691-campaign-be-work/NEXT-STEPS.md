# Next steps for RW-1691 Campaign BE work

**Ticket:** https://app.asana.com/1/45238840754660/project/1212521145936484/task/1214395948381748

## What we know
- High-priority Sprint 1 task in Rumble Wallet, Rumble Area "Promo Campaign", Stack BE.
- Description is a single Google-Doc link with the requirements; no inline spec.
- Alex's own latest comment (2026-05-12) parks the work: "Decide with the FE team about the interface 1st. Wait until final specs are rolled out."
- This is the Rumble Wallet–side counterpart to WDK-1453 (plan) and WDK-1454 (implement) which refactor the Rumble Promo Worker for multi-campaign reuse.

## Evidence captured here
- 0 images, 0 non-image attachments
- 1 substantive comment + system stories (see `comments.md`)

## What's missing (from `missing-context.md`)
- Access to the Google-Doc requirements
- FE counterpart ticket / point of contact + status of "final specs"
- Confirmation that RW-1691 is downstream of WDK-1453/1454

## Before starting work
The ticket is parked pending FE specs. Before picking it up:
1. Pull the requirements Google Doc and read in full.
2. Confirm with Alex / FE team whether the interface is locked.
3. Cross-reference the design coming out of WDK-1453 (planning card) so the Rumble App Node side matches the Promo Worker refactor.
