# Missing context

> Several items resolved by Alex's discussion on 2026-06-05 — see `discussion-notes.md`.

- [ ] **Blocking dependency:** "make sure that if this is picked up we wait until that is finished before starting this" — **Need from Alex:** status of the blocking card [Public WDK - Testing - Create cross-service E2E integration test suite](https://app.asana.com/1/45238840754660/task/1213242924383371) (GID 1213242924383371). The ticket title still says BLOCKED. Confirm whether the public-WDK card is done before any work starts. **Source:** description. **Still open.**

- [ ] **Maxime's / Maksym's PRs + Slack setup:** the description credits "Maksym" with prior public-indexer setup work (https://tether-to.slack.com/archives/C090AUH3V6K/p1773856271731709, channel C090AUH3V6K, ts 1773856271731709); the discussion references "Maxime's PRs" as the model to follow (Node-script harness, no Docker for services). **Need from Alex:** links to those PRs and/or the Slack thread contents, and confirmation Maksym == Maxime. This is now a primary reference for the approach, not just background. **Source:** description + discussion.

- [x] **Repo / packaging** — RESOLVED: a **separate repo** that at runtime clones all required repos (if missing) and runs the tests from there. Not a directory inside an existing service repo. (The original "`e2e-tests/` at repo root" deliverable is superseded.) **Source:** discussion.

- [x] **Scope (Rumble vs Tether Wallet)** — RESOLVED: ideally a harness that can run everything, but the immediate target is the **EVM happy path** (register address → tx on Anvil → query tx-history endpoint → verify indexed). **Source:** discussion.

- [x] **Infra / Docker** — RESOLVED: do **not** run services in Docker (Holepunch RPC issues in Docker) and do **not** target a deployed env. Run services directly on dev via **Node scripts** like Maxime's PRs; Docker (if any) is infra-only (Mongo/Redis/Anvil). Also must run on **GitHub CI**, not local-only. **Source:** discussion.

- [ ] **Existing test patterns:** "Use existing test patterns from `rumble-app-node/tests/test-lib/`" — referenced but not attached. This is in a local clone; read it directly when work starts. **Source:** description (NOTES). **Still open (read locally).**
