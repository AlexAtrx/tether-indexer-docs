# Comments & relevant activity


- _[2026-02-28T16:09:40.609Z] system/added_to_project_ — Francesco Canessa: Francesco Canessa added this task to WDK Backends

## [2026-03-19T19:42:01.014Z] Francesco Canessa (comment)

```
still happening 

[PM2] [idx-xaut-ton-1-api](30) ✓
Use --update-env to update environment variables
[PM2] Applying action restartProcessId on app [31](ids: [ '31' ])
.... 

------

$ pm2 info 31
 Describing process with id 31 - name idx-xaut-ton-2-api 
┌───────────────────┬─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│ status            │ stopping                                                                                                                                                │
│ name              │ idx-xaut-ton-2-ap

```


- _[2026-04-20T11:00:22.142Z] system/mentioned_ — Francesco Canessa: Francesco Canessa mentioned this task in another task: ✓ WDK - Bug - Workers fail to start when lookupEngine is autobase

- _[2026-04-24T15:40:41.936Z] system/enum_custom_field_changed_ — Francesco Canessa: Francesco Canessa changed Area / Project to Rumble

- _[2026-04-30T10:40:17.607Z] system/enum_custom_field_changed_ — Francesco Canessa: Francesco Canessa changed Sprint to Sprint 2

- _[2026-05-12T12:23:22.844Z] system/added_to_project_ — Francesco Canessa: Francesco Canessa added this task to Rumble Wallet

- _[2026-05-12T12:23:23.264Z] system/text_custom_field_changed_ — Francesco Canessa: Francesco Canessa changed RW to "RW-1730"

- _[2026-05-12T12:23:24.026Z] system/enum_custom_field_changed_ — —: Asana changed Task Type to Task

- _[2026-05-12T12:24:30.414Z] system/assigned_ — Francesco Canessa: Francesco Canessa assigned to you

- _[2026-05-12T12:41:58.668Z] system/multi_enum_custom_field_changed_ — Mohamed Elsabry: Mohamed Elsabry changed Rumble Area to API / Backend

## [2026-05-20T13:09:48.142Z] Alex Atrash (comment)

```
https://app.asana.com/1/45238840754660/profile/1212252646225966
Live measurement: 
    A full sequential pm2 restart of all 51 wdk processes on rumble-dev finishes in 52 seconds, not 30 minutes. 
    Every process came back online. 
    The Feb 2026 symptom is no longer reproducible. But the underlying mechanism that produced it is still in the codebase.

I think that what produced the original 30 min wall time is:
Serial pm2 restart × ~75 processes × a small subset that wedged in shutdown × a baked-in 5-minute kill_timeout per process.

Potential bugs: 
    Hardcodes --kill-timeout 300000 for every wdk process so any process that doesn't exit on SIGINT burns 5 full minutes before pm2 takes over or escalates.
    In @bitfinex/bfx-svc-boot-js/index.js the SIGINT handler silently returns when hnd.active === 0 (i.e. SIGINT arrived during  start). The process never calls process.exit() on its own → kill_timeout.
    In @bitfinex/bfx-svc-boot-js/index.js , stop()'s first step polls lockProcessing every 250 ms with no timeout.

Small fixes: 
    Patch bfx-svc-boot-js SIGINT handler. 
    Lower --kill-timeout from 300000 to 30000
    Bound the poll in bfx-wrk-base.stop() with a 10 s timeout
    add set -euo pipefail, use xargs -r, and explicitly fail on empty required phase matches.
```

- _[2026-05-20T13:09:53.365Z] system/section_changed_ — Alex Atrash: moved from "TO DO" to "DEV IN PROGRESS" in WDK Backends

## [2026-05-26T15:46:28.057Z] Alex Atrash (comment)

```
PRs: 
https://tether-to.slack.com/archives/C0A5DFYRNBB/p1779809767540199
```

- _[2026-05-26T15:46:32.597Z] system/section_changed_ — Alex Atrash: moved from "DEV IN PROGRESS" to "PR OPEN" in WDK Backends
- _[2026-05-27T08:27:25.457Z] system/notes_changed_ — Francesco Canessa: changed the description
- _[2026-05-27T12:47:13.544Z] system/enum_custom_field_changed_ — Francesco Canessa: changed Sprint from Sprint 2 to Sprint 3
- _[2026-06-05T09:07:23.078Z] system/notes_changed_ — Francesco Canessa: changed the description (added "RESOLVE CONFLICTS + MERGE")
- _[2026-06-10T11:37:28.177Z] system/section_changed_ — Francesco Canessa: moved from "To Triage" to "In Review" in Rumble Wallet
- _[2026-06-10T11:37:30.281Z] system/removed_from_project_ — Francesco Canessa: removed from WDK Backends
