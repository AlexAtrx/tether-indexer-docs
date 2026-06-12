# Missing context

- [ ] **Slack thread:** "Reported by Mariia in Slack during mobile testing" / `tether-to.slack.com/archives/C094R63HQ64/p1780603661792139` — **Need from Alex:** the thread contents (Mariia's report + any follow-up). The handle-ticket skill can pull it via the Chrome browser and save as `slack.txt`. **Source:** description.

- [ ] **Related ticket WDK-1515:** "Implement what did with WDK-1515 in `wdk-ork-wrk` and `rumble-ork-wrk`" (Asana GID 1215216504545662) — **Need from Alex / Asana:** the actual fix that WDK-1515 applied (the ork RPC reconnect / restart handling). This ticket is explicitly a port of that fix into the two ork workers, so the WDK-1515 resolution is the spec. **Source:** description.

- [ ] **Logs:** No log snippets attached. To confirm the failure mode we'll likely need the rumble-ork-wrk / wdk-ork-wrk logs around the example tx timestamps (Jun 4 16:04/16:09 prod, Jun 5 09:17 staging) — **Need from Alex:** access or a log export (dev/staging skills can pull live, but these are historical prod events). **Source:** description.

## Added on re-fetch (12 jun 26)

- [ ] **Slack thread (PRs):** Alex's comment 8 Jun links the PR set: `tether-to.slack.com/archives/C0A5DFYRNBB/p1780920983542869` — **Need from Alex:** PR links/numbers if not already in FIX.md. **Source:** comment, Alex Atrash, 2026-06-08.
- [ ] **QA failing tx (1st round):** polygon tx `0xbce04b188bc7dcb96df0278557fbf5ad65b29a61ddd00054cd00508d161df10c` (iPhone 16, build 2.4.0 (656)) — staging, reported "Not fixed" 10 Jun, but Alex replied the fix was not yet deployed then. **Source:** comment, andrey.gilyov, 2026-06-10.
- [ ] **QA failing tx (2nd round):** "Checked on staging, and the problem is there. Not fixed." — 12 Jun 10:58 UTC, AFTER Alex deployed to staging (09:58 UTC). No tx hash/details given. **Need from Alex/QA:** tx hash, sender/recipient, timestamp of the failing rant. **Source:** comment, andrey.gilyov, 2026-06-12.
