# Next steps for WDK-1453 Plan: Promo Worker refactor

**Ticket:** https://app.asana.com/1/45238840754660/project/1210540875949204/task/1214776665413533

## What we know
- Sprint 2, Rumble area, no explicit priority.
- Planning card paired with WDK-1454 (implementation, BLOCKED) and the Rumble Wallet counterpart RW-1691.
- Goal: turn the current Rumble Promo Worker (single-campaign-flavoured) into reusable code, then wire it through the Rumble Backend API so multiple campaigns can be configured.
- Deliverable: a design doc / approach + task breakdown for the implementation card.

## Evidence captured here
- 0 images, 0 attachments
- 0 user comments, 3 system events

## What's missing (from `missing-context.md`)
- Repo links for both the worker and the Backend API
- Google-Doc requirements (lives on RW-1691)
- Whether FE specs are final (RW-1691 is parked on this)

## Before starting work
1. Read the requirements Google Doc linked from RW-1691.
2. Walk the current `rumble-promo-wrk` codebase (see `repos.md`) to map what is campaign-specific today.
3. Draft the design doc: config schema for campaigns, worker entry-points that swap by campaign, and the integration boundary with the Rumble App Node API.
4. Break that into the tasks WDK-1454 needs.
