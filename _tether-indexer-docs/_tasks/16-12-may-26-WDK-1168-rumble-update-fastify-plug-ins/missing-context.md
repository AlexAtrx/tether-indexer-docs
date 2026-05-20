# Missing context

- [ ] External ticket: "mentioned this task in another task: Security - Chore - update fastify version" — **Need from Alex:** Status of that parent fastify-v5 effort (sibling ticket `1213145412557891`). Is the v5 upgrade landed in all upstream repos, or is `svc-facs-httpd#8` still the only blocker? **Source:** Nicholas Hrboka system story, 2026-02-11T17:18:13Z.

- [ ] External ticket: "mentioned this task in another task: Rumble - Security - Fix Tron Indexer High Vulnerabilities" — **Need from Alex:** Whether this Tron Indexer vuln ticket (`1213478780310237`) shares the same fastify-plugin scope or is independent. **Source:** Francesco Canessa system story, 2026-03-23T13:58:31Z.

- [ ] GitHub PR state: "svc-facs-httpd PR #8 is still open" and "wdk-indexer-app-node #52 was partially reverted May 1" — **Need from Alex / verify on GitHub:** Current state of `tetherto/svc-facs-httpd#8` (merged? blocked? on whom?), and the exact partial-revert commit on `wdk-indexer-app-node#52` so we know which plugins are still on v6 vs v8. **Source:** Alex's own comment, 2026-05-06T15:40:31Z.

- [ ] Decision / scope: "Plan: land #8, cut a new svc-facs-httpd major, then redo the bumps on the three consumers? Any other repos in scope?" — **Need from Francesco/Alex:** Confirmation that the three named consumers (`wdk-indexer-app-node`, `wdk-app-node`, `rumble-app-node`) are the full scope, plus any rumble-only repos (rumble-data-shard, rumble-* siblings) that also pull fastify plugins. **Source:** Alex's comment, 2026-05-06T15:40:31Z; description says "Check the repos, both internal and rumble, for what needs updating."

- [ ] Blocked? flag: ticket has `Blocked?: BLOCKED` custom field set but no blocker note in the comments beyond Alex's PR-#8 hypothesis — **Need from Alex:** Confirm BLOCKED is purely on `svc-facs-httpd#8`, or whether something else (a Boka revert decision, Usman handoff) is also gating.
