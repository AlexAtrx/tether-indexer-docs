# Next steps for WDK-1441 rumble-promo-wrk security upgrades

**Ticket:** https://app.asana.com/1/45238840754660/project/1210540875949204/task/1214716439993136

## What we know
- Sprint 2, High priority, Rumble area.
- 11 open Dependabot high/critical alerts on `tetherto/rumble-promo-wrk` at 2026-05-11.
- Parent ticket for the Tron Indexer security pass was just closed (RW-1682) — this ticket extends the same effort to the Rumble Promo Worker repo.

## Evidence captured here
- 0 images, 0 attachments
- 0 user comments, 3 system events

## What's missing (from `missing-context.md`)
- Current Dependabot alert list (only the count is in the ticket)
- Confirmation that the prior Tron Indexer upgrade notes are reusable
- Target branch + version-bump policy

## Before starting work
1. Pull the live Dependabot list from https://github.com/tetherto/rumble-promo-wrk/security/dependabot.
2. Cross-reference the `08-may-26-RW-1682-rumble-security-fix-tron-indexer-high-vulnerabilities/` folder for upgrade strategy already validated for the Tron indexer.
3. Plan package bumps in batches (low-risk patch / minor first) and run the worker's tests before each batch.
