# Next steps for WDK-1085 / RW-1729 — cross-service E2E integration test suite

**Ticket:** https://app.asana.com/1/45238840754660/project/1210540875949204/task/1212919215237588

## What we know
- Build a standalone E2E test suite that exercises the full transaction pipeline with REAL services (no mocks): Register user → Create wallet → Send ETH on Anvil → Wait for indexing → Query token-transfers API → Verify transfer data.
- Services in the chain: Anvil → indexer-evm → processor → data-shard → ork → app-node.
- Deliverable is a new `e2e-tests/` dir: Docker Compose for infra only (MongoDB, Redis, Anvil), Node services started directly for speed, suite built on the existing `brittle` framework, reusing patterns from `rumble-app-node/tests/test-lib/`. Single test < 30s.
- CI (GitHub Actions) is explicitly OUT of scope for now — local-runnable suite only; a follow-up card moves it to CI later.
- Priority High, Sprint 3, assigned to Alex.

## Evidence captured here
- 0 images
- 0 non-image attachments
- 0 user comments (only system/metadata stories — see `comments.md`)

## What's missing (from `missing-context.md`)
- Status of the blocking ticket gid 1213242924383371 ("Public WDK - Testing - ..."). This task is gated on it.
- Maksym's public-indexer E2E setup — Slack thread C090AUH3V6K/p1773856271731709 (prior art to reuse).
- Confirm target repo root for `e2e-tests/` (likely `rumble-app-node`).

## Before starting work
This is a chunky task explicitly gated on the blocker ticket finishing. Before any code:
1. Confirm the blocker (1213242924383371) is done.
2. Pull the Slack thread / Maksym's existing setup to avoid duplicating work.
3. Confirm the repo root for the new `e2e-tests/` directory.
Then jump to investigation using the `handle-ticket` skill.
