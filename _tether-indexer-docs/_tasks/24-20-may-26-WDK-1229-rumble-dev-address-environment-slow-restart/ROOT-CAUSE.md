# WDK-1229 / RW-1730 — Root cause

Investigated 2026-05-20 on `rumble-dev` (work@rumble-dev, /home/work/wdk).

## TL;DR

A full sequential `pm2 restart` of every wdk process on rumble-dev today
**completes in 52 s**, not 30 min. The visible symptom from Feb 2026 is no
longer reproducible. The 30 min wall time was the compound effect of three
still-present code paths firing together with a per-process 5-minute pm2
`kill_timeout`. Those code paths are latent footguns; fix them so this can't
silently regress.

## What the 30-min restart actually was

- The deploy script does `pm2 jlist | jq ... | xargs pm2 restart` per phase
  (orks, shards, indexers, processors). Each phase passes a list of `pm_id`s
  to pm2, and **pm2 then restarts them serially**, waiting for each app to
  exit and respawn before moving to the next.
- Every wdk pm2 process is started by `wdk-be-deploy ...` with
  `--kill-timeout 300000` baked in
  (`wdk-devops/wdk-be-deploy/lib/common.flags.js`). That means any process
  that fails to honour SIGINT burns **5 minutes** before pm2 escalates to
  SIGKILL.
- Multiple processes hitting kill_timeout during a serial restart of ~50
  processes is exactly how you land at 30 minutes.

Evidence for processes wedging during shutdown:
- Francesco's 2026-03-19 Asana comment shows `idx-xaut-ton-2-api` stuck in
  `status: stopping` (the symptom of kill_timeout firing).
- WDK-1360 (autobase `Router.add` throw on missing `@wdk-ork/...` routes,
  fixed Apr 27) was a concrete worker that crashed during `_start` and
  could leave the SIGINT path unable to exit cleanly.

## The three latent bugs that turn one slow shutdown into 5 minutes

1. **`bfx-svc-boot-js/index.js` SIGINT handler no-ops during boot.**
   ```js
   process.on('SIGINT', () => {
     if (shutdown) return
     shutdown = 1
     if (!hnd.active) { return }      // <-- silently returns, no process.exit
     hnd.stop(() => { process.exit() })
   })
   ```
   If SIGINT lands before `_start` finishes (so `hnd.active === 0`), the
   handler does nothing and the process never exits on its own. pm2 then
   waits the full 5-min kill_timeout before SIGKILL. Also: the module only
   binds SIGINT, not SIGTERM — anything sending TERM (`pm2 kill`,
   `--shutdown-with-message`, init/systemd, container stop) hits the same
   trap with no handler at all.

2. **`bfx-wrk-base.stop` polls `lockProcessing` with no timeout.**
   ```js
   stop (cb) {
     // step 1: wait forever for lockProcessing to clear
     aseries.push(next => {
       const itv = setInterval(() => {
         if (this.lockProcessing) return
         clearInterval(itv); next()
       }, 250)
     })
     ...
   }
   ```
   No worker in this repo currently sets `lockProcessing`, so the poll
   passes through immediately. But if anything ever sets it and dies
   mid-flight, `stop` hangs forever → kill_timeout → 5 min wasted per
   process.

3. **`wdk-be-deploy` hardcodes `--kill-timeout 300000`.**
   Five minutes is fine as an upper bound for graceful shutdown, but it's
   absurd as the default for a restart loop. Combined with (1)/(2) it
   silently buys five minutes per failure mode.

## The deploy-script bug that masked the original failure

From the Feb restart log:
```
++ /home/work/.nvm/versions/node/v22.22.0/bin/pm2 jlist
++ jq -r '.[] | select(.name | startswith("ork-w-")) | .pm_id'
++ xargs pm2 restart
  error: missing required argument `id|name|namespace|all|json|stdin'
```
At that point orks were named `ork-0`/`ork-1`/`ork-2` so the filter
matched 0 ids. `xargs` with empty stdin still invokes `pm2 restart` with no
arg, which errors out and (depending on `set -e`) exits the deploy halfway
through. The orks were renamed to `ork-w-N` later, so the filter matches
today — but the deploy script is still happy to no-op silently if any phase
filter doesn't match. Should `set -o pipefail` and `xargs -r` (or check the
list is non-empty) so we get a real error.

## Why today's restart is fast

- Topology trimmed: from ~75 processes (3 shards × 4, more indexer
  replicas) to 51 wdk processes today (2 shards × 2 api/proc, single
  replica per indexer, 2 orks). Serial × 50 vs serial × 75 alone shaves
  minutes.
- WDK-1360 fixed (Apr 27) — the autobase startup crash is gone, so workers
  reliably reach `hnd.active = 1` and SIGINT exits cleanly.
- Measured today on rumble-dev:
  - Stop → exit per process: 1–3 s across every observed restart in
    `~/.pm2/pm2.log`. Nothing hit kill_timeout.
  - Single `pm2 restart processor-spark-btc-w-0-10`: 1.15 s.
  - Single `pm2 restart ork-w-1`: shutdown 2 s, "Ork ready" 7 s after
    SIGINT.
  - Full sequential `pm2 restart` of all 51 wdk processes: **52 s**.

## Recommended fixes (small + targeted)

In rough priority order:

1. **`bfx-svc-boot-js/index.js`** — in the SIGINT handler, when
   `!hnd.active`, call `process.exit(0)` instead of returning silently.
   Bind the same handler to SIGTERM. Two-line change, eliminates the
   "stuck in stopping" failure mode.

2. **`wdk-devops/wdk-be-deploy/lib/common.flags.js`** — drop
   `['--kill-timeout', 300000]` to `30000`. 30 s is plenty for graceful
   facility shutdown given today's measurements; caps the worst case
   meaningfully.

3. **`bfx-wrk-base/base.js`** `stop()` — bound the `lockProcessing` poll
   with a timeout (10 s feels right) and proceed to `_stop`/`delFac`
   regardless. Worst-case data loss is bounded, and the worker still won't
   exit until facilities are properly closed.

4. **Deploy script (CI repo, not on this VM)** — `set -o pipefail`,
   `xargs -r`, and consider parallelising within phases that have no
   intra-phase dependency (`xargs -P 4 -n 1`). Inside a phase (e.g. all
   `idx-*-api`) restarts are independent — proc dependency is across
   phases, not within.

5. Wire a one-shot smoke check into the deploy after the restart loop
   (e.g. `pm2 jlist | jq` for any process whose `restart_time` is
   `unstable` or whose `pm2_env.status !== 'online'` 30 s after each
   phase) so a kill_timeout regression surfaces immediately instead of
   silently re-padding the deploy.

## Files inspected

- `wdk-devops/wdk-be-deploy/lib/common.flags.js`
- `wdk-devops/wdk-be-deploy/lib/pm2.js`
- `wdk-devops/wdk-be-deploy/bin/commands/ork/index.js`
- `node_modules/@bitfinex/bfx-svc-boot-js/index.js` (boot wrapper)
- `node_modules/@bitfinex/bfx-svc-boot-js/lib/worker.js`
- `node_modules/@bitfinex/bfx-wrk-base/base.js`
- `~/.pm2/pm2.log`, `~/.pm2/logs/*-out*.log` for restart timings
