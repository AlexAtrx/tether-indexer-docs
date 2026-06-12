# Next steps for RW-1900 — Receive transactions missing from list

**Ticket:** https://app.asana.com/1/45238840754660/project/1212521145936484/task/1215593887230418

## What we know
- Receive-type transactions stopped showing in the wallet's Transactions list;
  Sent transactions still show. Affects all users and all networks.
- It worked yesterday (2026-06-09); today (2026-06-10) it is broken — a fresh
  regression, almost certainly from a deploy/config change, not a code edge case.
- Ticket is labelled Stack: FE, but the reporter explicitly asks for backend
  investigation too; Alex's note ("yesterday fine, today broken") points the
  same way.
- Test accounts (with seed phrases) are in `description.md` for reproduction.
- Repro is trivial: send between the two test accounts, open Transactions page.

## Evidence captured here
- 0 images
- 0 non-image attachments
- 1 comment in `comments.md` (severity raised to Critical)

## What's missing (from `missing-context.md`)
- Which environment (staging/prod) and what was deployed 09–10 June
- Identity of the two cc'd profiles; any Slack thread
- No tx hash / address / log evidence at all

## Before starting work
Ask Alex for the environment + deploy timeline first. Likely suspects given
"all networks at once": the transfer-listing path in wdk-data-shard-wrk /
ork (incoming-transfer ingestion or the list query), not per-chain indexers.
Compare with hotspots.md (balance/trend, RW-1526/1601) and recent deploys.
