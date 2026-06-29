# Next steps for WDK-1085 — cross-service E2E integration test suite

> Single consolidated folder for this ticket. The earlier Jun-1 fetch and the
> Jun-5 re-fetch were merged here on 2026-06-17; the duplicate folder was deleted.
> This is the only folder that represents WDK-1085.

**Ticket:** https://app.asana.com/1/45238840754660/project/1210540875949204/task/1212919215237588

## What we know
- Build a standalone E2E suite that drives the full transaction pipeline with real (not mocked) services against a local EVM node (Anvil).
- Core flow: Register address → Send tx on Anvil → Wait for indexing → Query tx-history / token-transfers API → Verify the tx is indexed.
- Service chain: Anvil → indexer-evm → processor → data-shard → ork → app-node.
- Constraints: single test < 30s; reuse patterns from `rumble-app-node/tests/test-lib/`; Anvil's deterministic pre-funded accounts.
- Marked **BLOCKED / High priority**, Sprint 3. Alex moved it to DEV IN PROGRESS on 2026-06-05.

## Key decisions from Alex's discussion (see `discussion-notes.md`)
- **Packaging:** a **separate repo** that clones all required repos at runtime (if missing) then runs the tests — NOT an `e2e-tests/` dir inside a service repo (supersedes the original deliverable).
- **No Docker for services:** Holepunch RPC has issues in Docker. Run the Node/Hyperswarm services directly on dev via **Node scripts**, like **Maxime's PRs**. Docker (if any) stays infra-only (Mongo/Redis/Anvil). No Kubernetes/Terraform locally.
- **Not against a deployed env:** run on dev, not staging/prod.
- **Scope:** immediate target is the **EVM happy path**; ideal end state is a harness that can run everything.
- **CI:** must run **locally and on GitHub** (firms up the original "CI later" note).

## Evidence captured here
- 0 images
- 0 non-image attachments
- 0 human comments (system stories only, in `comments.md`)

## Blocking dependency — resolved (2026-06-17)
- The blocking card was the Public WDK E2E suite (GID 1213242924383371 / WDK-1176): https://app.asana.com/1/45238840754660/project/1210540875949204/task/1213242924383371
- That card's EVM happy-path suite is built; its PR is approved and merging (section PR OPEN). The "wait until it's finished before starting" gate from the original description no longer applies.
- Follow-up created on 2026-06-17 to extend that suite to the non-EVM indexers (Bitcoin, Solana, TON, Tron, Spark): https://app.asana.com/1/45238840754660/project/1210540875949204/task/1215798572158482

## Still to pull when work starts
- Links to Maxime's / Maksym's PRs and the Slack thread (C090AUH3V6K / ts 1773856271731709) — the reference approach for the Node-script harness.
- `rumble-app-node/tests/test-lib/` patterns (read from local clone).

## Before starting work
No longer blocked. Get Maxime's PRs as the model for the Node-script harness. Scope/approach are settled (separate repo, no Docker for services, EVM happy path, local + GitHub CI). Still a chunky, possibly-rework-later task.
