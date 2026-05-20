# Rumble DEV - Address environment slow restart

- **URL:** https://app.asana.com/1/45238840754660/project/1210540875949204/task/1213475123348181
- **GID:** 1213475123348181
- **Projects:** WDK Backends, Rumble Wallet
- **Sections:** WDK Backends → TO DO; Rumble Wallet → To Triage
- **Assignee:** Alex Atrash (inbox)
- **Status:** open
- **Created:** 2026-02-28T16:09:40.510Z
- **Modified:** 2026-05-12T12:41:59.005Z
- **Due:** —
- **Tags:** —
- **Custom fields:**
  - WDK: WDK-1229
  - RW: RW-1730
  - Priority: High
  - Area / Project: Rumble
  - Sprint: Sprint 2
  - Rumble Area: API / Backend
  - Task Type: Task

## Related tickets (fetched locally)

- **WDK-1360 — WDK - Bug - Workers fail to start when lookupEngine is autobase**
  ([Asana](https://app.asana.com/1/45238840754660/project/1210540875949204/task/1214143657334762),
  completed 2026-04-27). Local copy:
  [`related/WDK-1360-wdk-bug-workers-fail-to-start-when-lookupengine-is-autobase/`](related/WDK-1360-wdk-bug-workers-fail-to-start-when-lookupengine-is-autobase/).
  Fixed missing `@wdk-ork/save-wallet-id-lookups-batch` and
  `@wdk-ork/delete-lookup` route declarations in `wdk-ork-wrk/build.js`
  (commits [bdb9d43](https://github.com/tetherto/wdk-ork-wrk/commit/bdb9d43)
  and [ba0fe10](https://github.com/tetherto/wdk-ork-wrk/commit/ba0fe10)).
  Resolved before WDK-1229 was reassigned to Alex (2026-05-12), so not the
  active suspect for the remaining ~30-min restart.
