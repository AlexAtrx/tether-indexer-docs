# Missing context — WDK-1229

- [ ] **Slack thread (PRs):** "PRs: https://tether-to.slack.com/archives/C0A5DFYRNBB/p1779809767540199"
  — **Need from Alex:** the actual PR links from this Slack thread (which repos /
  branches the fixes landed in). The same Slack link appears twice (description
  "UPDATE" and the 2026-05-26 comment) and is the only pointer to the PRs. The
  task sits in the **"PR OPEN"** section of WDK Backends, so PR(s) exist but are
  not linked here. **Source:** description + Alex comment 2026-05-26.

- [ ] **Related Asana task:** https://app.asana.com/1/45238840754660/project/1210540875949204/task/1214143657334762
  — **Need from Alex:** what this related ticket covers (fetch it too if it's
  part of the same change set). **Source:** description "Related asana tasks".

- [ ] **Asana profile link:** https://app.asana.com/1/45238840754660/profile/1212252646225966
  — pasted at the top of Alex's 2026-05-20 analysis comment with no context.
  **Need from Alex:** whether this points at a person to loop in (Francesco /
  Vigan were named for the scale-down discussion). **Source:** Alex comment
  2026-05-20.

- [ ] **Source code to confirm fixes:** Alex's analysis names exact files to patch
  — `@bitfinex/bfx-svc-boot-js/index.js` (SIGINT handler + `stop()` poll) and the
  per-process `--kill-timeout 300000` in the pm2/ecosystem config, plus the dev
  restart shell script (the `ork-w-` selector bug). **Need from Alex:** confirm
  these are the files the open PR(s) actually touch, and which repo holds the
  restart script (likely a deploy/ops repo, not a cloned app repo). **Source:**
  Alex comment 2026-05-20.

- [ ] **Partial screenshot:** the "Compute Resources" table is cut off after the
  `wdk-dev-0` row. **Need from Alex (optional):** full table if the other boxes'
  specs matter. **Source:** description screenshot.

- [ ] **Decision pending:** Francesco's "still happening" (2026-03-19) vs Alex's
  "no longer reproducible, 52s now" (2026-05-20). **Need from Alex:** is the goal
  now (a) merge the preventive fixes for the latent mechanism, or (b) also trim
  services from dev? **Source:** comments.
