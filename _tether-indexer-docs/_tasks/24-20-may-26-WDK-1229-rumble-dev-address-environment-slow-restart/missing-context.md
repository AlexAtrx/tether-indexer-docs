# Missing / external context

- [x] **External tickets**: "Related asana tasks: …/task/1214143657334762"
  — Confirmed by Alex (2026-05-20) that this is the
  `WDK - Bug - Workers fail to start when lookupEngine is autobase` ticket
  (WDK-1360) Francesco cross-mentioned on 2026-04-20. Fetched locally under
  [`related/WDK-1360-…/`](related/WDK-1360-wdk-bug-workers-fail-to-start-when-lookupengine-is-autobase/).
  It is **completed (2026-04-27)** — fix landed in `wdk-ork-wrk` (commits
  bdb9d43, ba0fe10). It is NOT the active root cause for the remaining
  ~30-min restart; useful as background on autobase boot only.
- [ ] **Slack discussion**: description says "Start discussion to remove them
  from the deployment temporarily (Discussion needed on slack mentioning
  Francesco/Vigan about this)" — **Need from Alex:** has this Slack
  discussion happened? If yes, paste the thread / link. If not, this task
  may still be blocked on that decision before code-side investigation.
  **Source:** description.
- [ ] **People / decisions**: Francesco's note "I don't think we should
  scale the Dev env more than what we already have - see screenshot" sets a
  hard constraint (no extra hardware) — **Need from Alex:** is this still
  the position as of 2026-05-20, or has it changed since the ticket was
  re-routed into Rumble Wallet and reassigned on 2026-05-12? **Source:**
  description; Mohamed Elsabry changed Rumble Area to API/Backend on
  2026-05-12T12:41:58 (latest activity).
- [ ] **Logs**: the description and the 2026-03-19 comment paste a partial
  `pm2 jlist` table and a single `pm2 info 31` block that is truncated
  mid-row (`name | idx-xaut-ton-2-ap…` — the comment text in the API
  response is cut at 645 chars). **Need from Alex:** the full `pm2 info 31`
  output (and ideally the per-process `pm2 logs idx-xaut-ton-2-api` around
  the same window) so we can see *why* a single API process took ~30 min to
  go from `stopping` → restarted. **Source:** comments.md, 2026-03-19
  comment by Francesco Canessa.
- [ ] **Environments / systems**: the failing restart script runs on
  `wdk-dev-*` boxes (Ubuntu 24.04.2 per screenshot). The PM2 output also
  references `node v22.22.0` from `/home/work/.nvm/versions/`. **Need from
  Alex:** SSH access details (or the deploy script repo path) for those
  boxes — the bug only reproduces against the DEV PM2 layout, not local.
  **Source:** description LOG block.
- [ ] **Deployment script bug**: the very last lines of the description
  log show the orks restart step failing with
  `error: missing required argument 'id|name|namespace|all|json|stdin'`
  because `xargs pm2 restart` gets an empty stdin (the `jq` filter
  `select(.name | startswith("ork-w-"))` matched nothing — actual ork
  processes in this layout are named `ork-0`, `ork-1`, `ork-2`, not
  `ork-w-*`). **Need from Alex:** path to the restart script that uses
  `startswith("ork-w-")` — it's likely in the deploy repo, not in any of
  the cloned service repos. Worth flagging separately as a deploy-script
  bug regardless of the slow-restart investigation. **Source:** description
  log tail.
