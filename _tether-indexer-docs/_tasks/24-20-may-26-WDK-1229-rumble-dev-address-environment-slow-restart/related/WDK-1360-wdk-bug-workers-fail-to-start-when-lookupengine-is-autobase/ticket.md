# WDK - Bug - Workers fail to start when lookupEngine is autobase

- **URL:** https://app.asana.com/1/45238840754660/project/1210540875949204/task/1214143657334762
- **GID:** 1214143657334762
- **Project / Section:** WDK Backends → PR MERGED + TESTED ON DEV
- **Assignee:** Usman Khan (inbox)
- **Status:** completed (marked complete 2026-04-27 by Francesco Canessa)
- **Created:** 2026-04-20T03:38:46.988Z
- **Modified:** 2026-05-11T13:40:56.859Z
- **Due:** 2026-04-20
- **Tags:** —
- **Custom fields:**
  - WDK: WDK-1360

## Why this is filed under WDK-1229

Cross-linked by Francesco on 2026-04-20 (comment on this ticket says
"related to" the parent slow-restart task, and the system "mentioned" event
references it back). This was a worker-startup failure under
`lookupEngine=autobase` — a candidate root cause for slow restarts on DEV.
It has been **resolved on the ork side** (fix merged 2026-04-20, marked
complete 2026-04-27), so it cannot explain restarts that still measure
~30 min after 2026-04-27. Useful as background on the autobase boot path
but not the active suspect for WDK-1229 going forward.
