# Next steps for RW-1807 Address Consistency BE vs FE

**Ticket:** https://app.asana.com/1/45238840754660/project/1212521145936484/task/1215170498657541
**BE subtask (Alex's piece, RW-1905):** https://app.asana.com/1/45238840754660/task/1215596633875644

## What we know
- Some RW V1 legacy users and migrated V2 users may have BE wallet addresses that differ from FE locally derived addresses (V1 inconsistent generation; V2 migrations that accidentally created a new seed phrase). Impacted-user count unknown.
- FE will compare BE vs locally derived addresses on startup across all wallets/networks/tip jars and report success/failed (with mismatch details) to Sentry. That part is FE work (parent assigned to Aliaksei Shaltykou).
- BE work is subtask RW-1905 "BE API for Address snapshot" (assigned to Alex, Sprint 4, no description): accept all FE-derived wallet addresses and temporarily persist them for later offline processing/analysis.

## Evidence captured here
- 0 images
- 0 non-image attachments
- 0 comments (system events only, see `comments.md`)

## What's missing (from `missing-context.md`)
- ~~No API contract / storage / retention spec~~ Specced 2026-06-10: new endpoint + dedicated collection, never touches actual addresses, written into the RW-1905 subtask. `/api/v1/user-data` reuse was evaluated and rejected, see `user-data-api-analysis.md`. Exact payload schema and retention still open.
- Whether FE payload format is already agreed with Aliaksei or BE defines it
- Whether the snapshot data must be queryable for an impacted-user count/report

## Before starting work
Ask Alex the missing items above first — chiefly the API contract and where/how long to persist. Likely repos: rumble-app-node (HTTP endpoint, fastify schema.body validation at the API boundary) fanning out to rumble-ork-wrk / rumble-data-shard-wrk for persistence, per the layering in `.claude/CLAUDE.md`.
