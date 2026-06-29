# Missing context

> Several items resolved by Alex's discussion on 2026-06-05 — see `discussion-notes.md`.
> Single consolidated folder for this ticket (Jun-1 and Jun-5 fetches merged on 2026-06-17; duplicate deleted).

- [x] **Blocking dependency** — RESOLVED (2026-06-17): the blocking card was the [Public WDK E2E suite](https://app.asana.com/1/45238840754660/task/1213242924383371) (GID 1213242924383371 / WDK-1176). Its EVM happy-path suite is built and the PR is approved and merging (section PR OPEN), so the "wait until finished" gate no longer applies. A follow-up to extend that suite to the non-EVM indexers (Bitcoin, Solana, TON, Tron, Spark) was created: https://app.asana.com/1/45238840754660/project/1210540875949204/task/1215798572158482. **Source:** description + Alex (2026-06-17).

- [ ] **Maxime's / Maksym's PRs + Slack setup:** the description credits "Maksym" with prior public-indexer setup work (https://tether-to.slack.com/archives/C090AUH3V6K/p1773856271731709, channel C090AUH3V6K, ts 1773856271731709); the discussion references "Maxime's PRs" as the model to follow (Node-script harness, no Docker for services). **Need from Alex:** links to those PRs and/or the Slack thread contents, and confirmation Maksym == Maxime. This is now a primary reference for the approach, not just background. **Source:** description + discussion.

- [x] **Repo / packaging** — RESOLVED: a **separate repo** that at runtime clones all required repos (if missing) and runs the tests from there. Not a directory inside an existing service repo. (The original "`e2e-tests/` at repo root" deliverable is superseded.) **Source:** discussion.

- [x] **Scope (Rumble vs Tether Wallet)** — RESOLVED: ideally a harness that can run everything, but the immediate target is the **EVM happy path** (register address → tx on Anvil → query tx-history endpoint → verify indexed). **Source:** discussion.

- [x] **Infra / Docker** — RESOLVED: do **not** run services in Docker (Holepunch RPC issues in Docker) and do **not** target a deployed env. Run services directly on dev via **Node scripts** like Maxime's PRs; Docker (if any) is infra-only (Mongo/Redis/Anvil). Also must run on **GitHub CI**, not local-only. **Source:** discussion.

- [ ] **Existing test patterns:** "Use existing test patterns from `rumble-app-node/tests/test-lib/`" — referenced but not attached. This is in a local clone; read it directly when work starts. **Source:** description (NOTES). **Still open (read locally).**
