# Next steps for Fix Mongo Deprecation Warning (Prod DB Password Leak)

**Ticket:** https://app.asana.com/1/45238840754660/project/1210540875949204/task/1213549645575555

## What we know
- Node's `[DEP0170] DeprecationWarning: The URL mongodb://...` was being emitted by indexer services and printed the connection string verbatim, which embedded the prod DB password (`mongodb://wallet:<password>@...`).
- The warning fires on indexer startup, so you only see it after a service restart. Detected via Grafana Loki (prod query on `job="pm2"`, staging query on `env="staging"`).
- Incident impact: prod password was visible to Tether team in logs during a deployment; Rumble rotated the password.
- Suggested remediation: switch to `bfx-facs-db-mongo` branch `feature/mongodb-v6-driver` (Vigan's recommendation), which presumably uses the v6 driver and avoids the deprecated URL parser path that triggers DEP0170.
- Ticket is currently in **PR MERGED + DEPLOYED TO DEV** — fix is in flight on the indexer side. Francesco flagged that the **data shard** also needs the same fix.

## Evidence captured here
- 0 images
- 0 non-image attachments
- 1 substantive comment + 3 system events in `comments.md`

## What's missing (from `missing-context.md`)
- Slack thread (`C0A5DFYRNBB` / ts `1776091206.320369`) where the data-shard requirement was raised
- A real log snippet showing the leak (we have only the Loki query, not a sample line)
- Production incident timestamp and which indexer service emitted the leaked password
- Confirmation that the `bfx-facs-db-mongo` v6 branch is still the agreed target
- PR URL(s) for the merged fix
- Whether the data-shard repo is covered by the merged PR or needs a follow-up

## Before starting work
This ticket is *already* through DEV. If Alex picks it back up, the most likely
asks are: (a) verify the deployed fix in staging/prod by re-running the Loki
queries after a restart, (b) open / track the data-shard follow-up Francesco
asked for. Pull the PR link and the Slack thread before touching code.
