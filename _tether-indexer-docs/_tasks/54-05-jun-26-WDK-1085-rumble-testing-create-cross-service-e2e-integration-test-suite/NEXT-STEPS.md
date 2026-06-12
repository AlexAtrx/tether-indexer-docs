# Next steps for WDK-1085 — cross-service E2E integration test suite

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

## What's still missing (from `missing-context.md`)
- Status of the blocking card (Public WDK E2E suite, GID 1213242924383371) — confirm it's done first.
- Links to Maxime's / Maksym's PRs and the Slack thread (C090AUH3V6K / ts 1773856271731709) — now the reference approach for the Node-script harness.
- `rumble-app-node/tests/test-lib/` patterns (read from local clone).

## Before starting work
This is flagged BLOCKED. **First confirm the blocking public-WDK card is finished**, then get Maxime's PRs as the model for the Node-script harness. Scope/approach are now settled (separate repo, no Docker for services, EVM happy path, local + GitHub CI). Still a chunky, possibly-rework-later task.
