# Missing context

- [ ] **External tickets:** "blocked by: CARD ✓ Security - Chore - update fastify version" — **Need from Alex:** confirm whether the blocking card (task 1213145412557891) is actually done. It is shown with a ✓ (completed) in Asana, and "Blocked?" is still set to BLOCKED on this ticket — these contradict each other. Clarify whether this is now unblocked. **Source:** description.

- [ ] **External tickets / PRs:** GitHub PR https://github.com/tetherto/svc-facs-httpd/pull/8 is cited as the example fastify-plugin bump (`@fastify/static` ^6.10.2 → ^8.3.0). PR content not fetched here. **Need from Alex:** nothing blocking — can be read directly via the read-remote-repo skill when work starts. **Source:** description.

- [ ] **Related ticket:** "✓ Security - Fix Tron Indexer High Vulnerabilities" (task 1213478780310237) was cross-linked. May overlap with the fastify/plugin upgrade scope. **Need from Alex:** confirm if relevant to plugin updates. **Source:** system mention, 2026-03-23.

- [ ] **Scope / repo list:** "Check the repos, both internal and rumble, for what needs updating." No explicit list of which repos use fastify plugins. **Need from Alex:** confirm the target repo set (all `*-app-node` repos expose HTTP/fastify — `wdk-app-node`, `rumble-app-node`, `wdk-indexer-app-node`, plus `svc-facs-httpd`). **Source:** description.

- [ ] **Ownership:** "Assigned to Alex but can be passed to Usman if needed." **Need from Alex:** confirm who owns this (Alex or Usman). **Source:** description.
