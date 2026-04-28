# Slack thread — PR review

Channel: `C0A5DFYRNBB` · thread_ts `1776091206.320369`
Source: pasted by Alex on 2026-04-20.

---

**Alex** — 4:40 PM
PR Review:
- Task Name: Rumble - Bug - Security - Fix Mongo Deprecation Warning - Prod DB Password in Logs
- PR Links:
  - https://github.com/tetherto/wdk-ork-wrk/pull/115
  - https://github.com/tetherto/wdk-indexer-wrk-base/pull/104
- Testing: tested locally
- Assigned To: @Usman Khan @Francesco C. @Vigan

**Francesco C.** — 4:43 PM
> can we put the commit hash directly in package.json instead of branch names? this change was requested by the security review of tether-wallet to maximize security (so that we don't inadvertently push a new version via npm install)

**Vigan** — 5:22 PM
> I would prefer branch tbh as it's cleaner

**Vigan** — 5:22 PM
> you never know which commit hash to where it points

**Francesco C.** — 5:24 PM
> ah, so we push back on the tether wallet security doc?

**Francesco C.** — 5:24 PM
> ok for me

**Alex** — 5:40 PM
> "I would prefer branch tbh as it's cleaner"
> Ok

**Alex** — 10:47 AM (next day)
> @Vigan @Francesco C. can you review/merge?

**Vigan** — 1:24 PM
> checking

**Vigan** — 1:25 PM
> merged

**Vigan** — 1:25 PM
> we need data shard as well

---

## Decisions captured

- **Pin style:** branch name (not commit hash) in `package.json`. Vigan's preference for readability overrode the tether-wallet security-review guidance to pin by commit hash. Francesco accepted ("ok for me"). If a future reviewer challenges this, the pushback was knowingly accepted.
- **Merge status:** Vigan merged both PRs.
- **Open follow-up:** data shard repo still needs the same fix — raised by Vigan in the same thread, then re-pinged into the Asana ticket.
