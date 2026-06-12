# Next steps for WDK-1454 — Promo multi-campaign refactor (implementation)

**Ticket:** https://app.asana.com/1/45238840754660/project/1210540875949204/task/1214776932455068

## What we know
- Implementation card to refactor the **Rumble App Node API** and the **Rumble Promo Worker** so they support multiple configurable campaigns from a reusable codebase (today the flow is single-campaign).
- It **depends on a companion planning card** that holds the actual design — that card is not linked here.
- Created and assigned by Francesco Canessa on 2026-05-13; in Sprint 2, section "TO DO".
- The `Blocked?` field is set to **BLOCKED** — do not start coding until the blocker is cleared.

## Evidence captured here
- 0 images
- 0 non-image attachments
- 0 user comments (3 system stories only — add/assign/section move)

## What's missing (from `missing-context.md`)
- The companion planning card URL/number (the real spec).
- The reason the ticket is marked BLOCKED.
- Any acceptance criteria / concrete scope (which endpoints, which worker behaviours change).

## Before starting work
This is **BLOCKED** and the spec lives elsewhere. Before any codebase digging, **ask Alex for the planning card** and confirm the blocker is resolved. The single-campaign baseline this builds on is the existing promo-wrk / rumble-app-node deploy (see staging promo deploy notes). Once the planning card is in hand, map its config schema onto the current `promo-wrk` and `rumble-app-node` promo endpoints.
