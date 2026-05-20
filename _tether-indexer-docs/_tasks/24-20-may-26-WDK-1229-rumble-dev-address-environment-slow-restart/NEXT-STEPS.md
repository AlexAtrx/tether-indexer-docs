# Next steps for "Rumble DEV - Address environment slow restart"

**Ticket:** https://app.asana.com/1/45238840754660/project/1210540875949204/task/1213475123348181
(WDK-1229 / RW-1730, High priority, Sprint 2)

## What we know

- DEV environment restart takes ~30 minutes (`real 31m24.892s` measured in the
  description's log); it's blocking multiple deploys/day for PR smoke testing.
- Francesco's constraint: do NOT scale the DEV hardware. The screenshot shows
  `wdk-dev-0` at 8 vCPU / 31 GB RAM / 193 GB / Ubuntu 24.04.2 and that is the
  budget. Fix must come from the service set or boot sequence.
- The deploy script does a per-PM2-process restart loop over `idx-*`,
  `shard-*`, `processor-*`, `ork-*`. The shards phase completes (all 12
  shard-{0,1,2}-{proc,0..2}-api processes restart). The orks phase fails
  with `error: missing required argument 'id|name|namespace|all|json|stdin'`
  because the `jq` filter looks for `startswith("ork-w-")` but the actual
  process names are `ork-0`/`ork-1`/`ork-2` — `xargs pm2 restart` gets an
  empty stdin (deploy-script bug worth a separate fix).
- The 2026-03-19 follow-up comment from Francesco ("still happening") shows a
  PM2 process (`idx-xaut-ton-2-api`, id 31) stuck in `stopping` state — the
  hot suspect for the 30-min wall time is one or more indexer-worker API
  processes that won't honour SIGTERM/stop quickly, so the sequential
  `pm2 restart` blocks on them.
- Possible related cause **(ruled out)**: cross-referenced task
  "WDK - Bug - Workers fail to start when lookupEngine is autobase" (WDK-1360,
  fetched under `related/WDK-1360-…/`) was a `Router.add()` throw on missing
  `@wdk-ork/save-wallet-id-lookups-batch` / `@wdk-ork/delete-lookup` route
  declarations. Fixed and merged before 2026-04-27 — predates the reassign
  to Alex (2026-05-12), so it cannot account for the ~30-min restart still
  observed. Keep as background context on the autobase boot path only.

## Evidence captured here

- 1 image analysed in `image-analysis.md` (DEV compute-resources screenshot)
- 0 non-image attachments under `attachments/`
- 1 comment + 10 system-event entries in `comments.md`
- Full restart log preserved in `description.md`
- Related ticket fetched locally:
  [`related/WDK-1360-wdk-bug-workers-fail-to-start-when-lookupengine-is-autobase/`](related/WDK-1360-wdk-bug-workers-fail-to-start-when-lookupengine-is-autobase/)
  (autobase worker-startup fix — already shipped, kept here as context)

## What's missing (from `missing-context.md`)

- Full `pm2 info 31` output (comment text cut at ~645 chars; only the
  `status: stopping` header row survives).
- Confirmation / GID of the related autobase-startup ticket.
- Status of the Francesco/Vigan Slack discussion about temporarily removing
  some services from DEV.
- SSH / deploy-script repo access so we can inspect the restart loop and
  reproduce the timing.
- Confirmation that the "no extra DEV hardware" constraint still holds in
  2026-05.

## Before starting work

If Alex re-assigns this ticket for analysis or fix, **ask for the missing
items above first** before digging into the codebase. The single highest-
value ask is the deploy-script path (or the full `wdk-dev-*` deploy repo) —
without that, we are guessing why the `pm2 restart` loop wedges. Second
ask: full `pm2 info` and `pm2 logs` for `idx-xaut-ton-2-api` (id 31) from
the most recent stuck restart.

Once context lands, the first investigation step is: per-process restart
timing. Wrap the deploy script's `xargs pm2 restart` step with `time` per
process so we can identify which process(es) account for the bulk of the
30 min, then look at their stop-handler code.
