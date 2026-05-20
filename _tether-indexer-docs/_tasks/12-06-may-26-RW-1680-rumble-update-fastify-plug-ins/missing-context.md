# Missing context

- [ ] **External tickets:** Description references the example PR https://github.com/tetherto/svc-facs-httpd/pull/8 — **Need from Alex:** confirm whether the PR is merged and whether the same diff (i.e. `@fastify/static` 6.x → 8.x and any other plugin bumps in that PR) is the canonical pattern to apply across other repos. **Source:** description.

- [ ] **External tickets:** System story references *"Security - Chore - update fastify version"* (mentioned 2026-02-11) and *"Rumble - Security - Fix Tron Indexer High Vulnerabilities"* (mentioned 2026-03-23). **Need from Alex:** Asana links to those tickets so we know what scope is already covered vs. left for this ticket. **Source:** system stories.

- [ ] **Blocker reason:** Custom field `Blocked?` was set to **BLOCKED** on 2026-04-30 with no comment explaining why. **Need from Alex:** what is blocking this — waiting on the fastify v5 upgrade itself to land in shared repos? Waiting on a specific plugin's release? **Source:** custom field change 2026-04-30T10:38:32Z.

- [ ] **Repo scope:** Description says "Check the repos, both internal and rumble, for what needs updating." **Need from Alex:** confirm the target repo list — at minimum the Rumble-side indexer/ork/shard/app-node + wallet libs in this workspace (`repos.md`), but also any internal `svc-facs-*` / `wrk-*` repos that pull fastify. **Source:** description.

- [ ] **Owner handoff:** Description ends with "Assigned to Alex but can be passed to Usman if needed". **Need from Alex:** decide whether this stays with Alex or goes to Usman before starting work. **Source:** description.
