# Next steps for "Rumble DEV - Address environment slow restart" (WDK-1229 / RW-1730)

**Ticket:** https://app.asana.com/1/45238840754660/project/1210540875949204/task/1213475123348181

## What we know
- Dev env restart historically took ~31m (`real 31m24s` in the captured log) —
  too slow for multiple smoke-test deploys/day.
- Francesco confirmed "still happening" (2026-03-19) with an indexer api process
  (`idx-xaut-ton-2-api`) wedged in `stopping`.
- Alex re-measured 2026-05-20: a sequential restart of all 51 wdk processes now
  finishes in **52s**, not reproducible anymore — but the latent mechanism remains.
- Root mechanism: serial pm2 restart over ~75 processes × a baked-in 5-minute
  `--kill-timeout 300000` per process × processes that fail to self-exit on SIGINT.
- Identified fixes: patch `bfx-svc-boot-js` SIGINT handler (silent return when
  `hnd.active === 0`), lower kill-timeout 300000→30000, bound `bfx-wrk-base.stop()`
  poll with a 10s timeout, harden the restart script (`set -euo pipefail`,
  `xargs -r`, fail on empty phase match — the `ork-w-` selector matched nothing).
- Task is in WDK Backends **"PR OPEN"** → fix PR(s) already exist (linked only via
  a Slack thread). Priority High, Sprint 3.

## Evidence captured here
- 1 image analysed in `image-analysis.md` (partial Compute Resources table; Francesco's "don't scale dev further" point)
- 0 non-image attachments
- 3 comments in `comments.md` (incl. Alex's full root-cause analysis)

## What's missing (from `missing-context.md`)
- Actual PR links (only a Slack thread URL given)
- Related Asana task 1214143657334762 (not fetched)
- Confirmation of which repo holds the dev restart script
- Whether goal is "merge preventive fixes" vs also "trim dev services"

## Before starting work
The analysis is already done by Alex and PR(s) appear to be open. If re-assigned:
first get the **PR links from the Slack thread** and confirm whether this is now a
review/merge-conflict-resolution task ("RESOLVE CONFLICTS + MERGE" per the
description header) rather than fresh investigation. Then verify the four fixes
against the open PR(s).
