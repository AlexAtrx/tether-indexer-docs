# Discussion notes (clarifications from Alex)

Captured 2026-06-05 from a discussion with Alex about scope and implementation. These
override / refine the original ticket description where they conflict (notably the
Docker Compose deliverable).

## Goal
- The original idea is an **EVM end-to-end flow** that proves indexing works end to end.
- Concrete flow: **register an address → execute a transaction on Anvil → call the transaction-history endpoint → verify the transaction is indexed**.
- The suite should run **locally and also on GitHub (CI)**. (This firms up the original ticket's "CI in a second moment" — GitHub execution is in scope, not just deferred.)

## Scope: Rumble vs Tether Wallet
- Alex raised whether to target **Rumble APIs or Tether Wallet**.
- Answer: ideally **something that can run everything**, referencing **Maxime's earlier PR approach** — but the immediate example stays on the **EVM happy path**.

## Orchestration / infra decision (important — refines the deliverable)
- Alex asked whether to rely on **Kubernetes** so workers come up consistently. Clarified: **not for local execution.**
- Locally, **Terraform / online infra is not possible**; the only local infra option would be **Docker Compose**.
- **BUT** the key decision: the target is **NOT to run against a deployed environment**, and **NOT in Docker for the services** — they have **issues with the Holepunch RPC inside Docker**.
- Preferred approach: run the services **on dev without Docker**, **via Node scripts**, essentially **like Maxime did in his PRs**.
- Takeaway: Docker (if used at all) is for infra only (Mongo/Redis/Anvil); the Hyperswarm/Holepunch Node services must run directly, not containerised.

## Repo / packaging
- Expect a **separate repo** that at runtime **clones all required repos if missing, then runs the tests** from there.

## Naming note
- Description credits prior setup work to "Maksym" (Slack C090AUH3V6K / ts 1773856271731709); discussion refers to "Maxime's PRs". Likely the same person / body of work — confirm and look at those PRs before starting.
