# Next steps for "Sentry Rumble not receiving data"

**Ticket:** https://app.asana.com/1/45238840754660/project/1210540875949204/task/1214842519965679

## What we know
- Sentry project `rumble-wallet-backend` / env `production` shows zero issues in the last 7 days (screenshot 1).
- Expanding to 90 days surfaces 6 issues; the most recent fired ~2 weeks before ticket creation, i.e. ~2026-05-01.
- The last surviving error is a LevelDB lock failure: `while open a file for lock: store/3002/db/LOCK: Permission denied` from `Object.onopen(...)`, marked Unhandled, tagged `RUMBLE-WALLET-BACKEND-2D`.
- Ticket has no comments. WDK-1462, High priority, Sprint 2, Area = Rumble.

## Evidence captured here
- 2 images analysed in `image-analysis.md`
- 0 non-image attachments under `attachments/`
- 0 user comments in `comments.md` (3 system events recorded)

## What's missing (from `missing-context.md`)
- Sentry access / confirmation of the correct project + env to monitor
- Deploy / release diff around 2026-05-01 in the `rumble-wallet-backend` repo
- Health of the production process(es) that own the Sentry init
- Sentry config: where `Sentry.init()` lives, DSN, environment/release tags, inbound filters
- Full Sentry issue page for the LevelDB-lock crash (stack, breadcrumbs, release, server)
- Whether `RUMBLE-WALLET-BACKEND-2D` is a renamed/new Sentry project that's silently catching events instead

## Before starting work
Pull the items above from Alex first — especially Sentry access and the May 1st deploy window. Without those two, debugging is guesswork. Once we have them, the investigation order is roughly:
1. Confirm the process is alive in prod and is the same binary that wires up Sentry.
2. Confirm DSN + environment tag have not drifted (env var rename, secret rotation, project rename like `-2D`).
3. Check whether Sentry inbound filters were tightened.
4. If everything looks correct, generate a controlled error in prod and confirm whether it arrives.
