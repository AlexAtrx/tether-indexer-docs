# Comments — WDK-1229

Chronological (oldest first).

---

## Francesco Canessa — 2026-03-19T19:42:01Z (comment)

still happening

```
[PM2] [idx-xaut-ton-1-api](30) ✓
Use --update-env to update environment variables
[PM2] Applying action restartProcessId on app [31](ids: [ '31' ])
....

------

$ pm2 info 31
 Describing process with id 31 - name idx-xaut-ton-2-api
┌───────────────────┬───────────────────────────────────────────────────────┐
│ status            │ stopping                                               │
│ name              │ idx-xaut-ton-2-ap...                                    │
```

→ Reproduction still seen: an indexer api process (`idx-xaut-ton-2-api`, id 31)
stuck in `stopping` during the restart.

---

## Francesco Canessa — 2026-05-12T12:24:30Z (assigned)

Francesco Canessa assigned the task to Alex.

---

## Alex Atrash — 2026-05-20T13:09:48Z (comment)

https://app.asana.com/1/45238840754660/profile/1212252646225966

**Live measurement:**
- A full sequential pm2 restart of all 51 wdk processes on rumble-dev finishes in
  **52 seconds, not 30 minutes.**
- Every process came back online.
- The Feb 2026 symptom is no longer reproducible. But the underlying mechanism
  that produced it is still in the codebase.

I think what produced the original 30 min wall time is: serial pm2 restart ×
~75 processes × a small subset that wedged in shutdown × a baked-in 5-minute
`kill_timeout` per process.

**Potential bugs:**
- Hardcodes `--kill-timeout 300000` for every wdk process, so any process that
  doesn't exit on SIGINT burns 5 full minutes before pm2 takes over / escalates.
- In `@bitfinex/bfx-svc-boot-js/index.js` the SIGINT handler silently returns when
  `hnd.active === 0` (i.e. SIGINT arrived during start). The process never calls
  `process.exit()` on its own → kill_timeout.
- In `@bitfinex/bfx-svc-boot-js/index.js`, `stop()`'s first step polls
  `lockProcessing` every 250 ms with no timeout.

**Small fixes:**
- Patch bfx-svc-boot-js SIGINT handler.
- Lower `--kill-timeout` from 300000 to 30000.
- Bound the poll in `bfx-wrk-base.stop()` with a 10 s timeout.
- Add `set -euo pipefail`, use `xargs -r`, and explicitly fail on empty required
  phase matches (the restart script's `ork-w-` selector matched nothing and
  silently errored).

---

## Alex Atrash — 2026-05-26T15:46:28Z (comment)

PRs:
https://tether-to.slack.com/archives/C0A5DFYRNBB/p1779809767540199
