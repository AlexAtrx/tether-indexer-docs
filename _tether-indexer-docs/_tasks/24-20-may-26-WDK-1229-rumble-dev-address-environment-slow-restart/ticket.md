# Rumble DEV - Address environment slow restart

- **URL:** https://app.asana.com/1/45238840754660/project/1210540875949204/task/1213475123348181
- **GID:** 1213475123348181
- **Projects:** Rumble Wallet (removed from WDK Backends 2026-06-10)
- **Sections:** Rumble Wallet → In Review
- **Assignee:** Alex Atrash (inbox)
- **Status:** open
- **Created:** 2026-02-28T16:09:40.510Z
- **Modified:** 2026-06-10T11:37:30.697Z
- **Due:** —
- **Tags:** —
- **Custom fields:**
  - WDK: WDK-1229
  - RW: RW-1730
  - Priority: High
  - Area / Project: Rumble
  - Sprint: Sprint 3
  - Rumble Area: API / Backend
  - Task Type: Task

## PR status (checked 2026-06-12)

- [tetherto/wdk-devops#23](https://github.com/tetherto/wdk-devops/pull/23)
  "fix: reduce default PM2 kill timeout" — **MERGED** 2026-05-29.
- [bitfinexcom/bfx-wrk-base#27](https://github.com/bitfinexcom/bfx-wrk-base/pull/27)
  "fix: bound lockProcessing wait during stop" — **CLOSED unmerged**
  2026-06-11 (closed by Alex per team preference, despite approvals from
  kulwindertether and francesco-ubq). The team chose to leave the
  unbounded lockProcessing wait in `bfx-wrk-base.stop()` as is: nothing
  currently sets `lockProcessing`, so the hang is theoretical, and PM2's
  kill_timeout (30 s since wdk-devops#23) is the backstop if it ever
  fires. This is now **accepted risk** — if a worker ever starts setting
  `lockProcessing`, revisit.
- [bitfinexcom/bfx-svc-boot-js#19](https://github.com/bitfinexcom/bfx-svc-boot-js/pull/19)
  "fix: handle shutdown before worker activation" — OPEN, no conflicts
  (MERGEABLE), now has **4 approvals** (kulwindertether 2026-05-27,
  francesco-ubq 2026-06-08, grantfayvor 2026-06-11, acamaragl
  2026-06-12) but still BLOCKED / REVIEW_REQUIRED by branch protection.
  One open review comment from ShekarArun (2026-06-12, on
  `lib/shutdown.js:20`): what if `hnd.stop()` fails during cleanup —
  suggests try/catch + force exit, or a timeout + force exit. Planned
  reply: a sync throw in a signal handler crashes the process so it
  exits anyway; the only callback-never-fires hang path is the
  lockProcessing wait (accepted risk, see #27 above) with PM2
  kill_timeout as backstop; a force-exit timeout in the shared boot
  wrapper would hardcode supervisor policy in a library, which is the
  same call the team made closing #27. Concession on offer: try/catch
  around `hnd.stop()` if he insists.

Francesco edited the Asana description (2026-05-27 and 2026-06-05) to add
"RESOLVE CONFLICTS + MERGE" at the top plus the PRs Slack thread link
(https://tether-to.slack.com/archives/C0A5DFYRNBB/p1779809767540199), and
moved the task to "In Review" on 2026-06-10. Neither PR ever actually had
conflicts; #19 remains blocked only on a qualifying review from a
maintainer with write access on the bitfinexcom repo.

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
