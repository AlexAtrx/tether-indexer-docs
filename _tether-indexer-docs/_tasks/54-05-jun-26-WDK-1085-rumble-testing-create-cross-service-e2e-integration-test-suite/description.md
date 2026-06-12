# Description

**BLOCKED**

NOTE: there is a rumble card as well, make sure that if this is picked up we wait until that is finished before starting this — [Public WDK - Testing - Create cross-service E2E integration test suite](https://app.asana.com/1/45238840754660/task/1213242924383371)

Testing — Build a standalone end-to-end test suite that validates the complete transaction flow across all services, from wallet registration through API endpoint calls based verification.

NOTE: this can be a relatively chunky task and also a task that could be reworked in the future so make sure you are ok with this before picking it up.

---

## CURRENT STATE

Each service has isolated unit/integration tests using `brittle` + `sinon`, but all use mocked dependencies. No test exists that:
- Starts real services
- Sends real transactions to a local EVM node
- Verifies data flows through the full pipeline

---

## PROBLEM

Cannot verify that services work together correctly. Regressions in service communication are only caught in staging/production.

---

## DELIVERABLE

New `e2e-tests/` directory at repo root containing:

1. **Docker Compose** for infrastructure (MongoDB, Redis, Anvil)
2. **Test suite** using existing `brittle` framework
3. **GitHub Actions workflow** for CI can be added in a second moment - for this asana task we want to target for a suite that can be ran locally, later please create a card to move this to CI after the team has tried to run it and they're happy with it

**Core test flow to validate:**
Register user → Create wallet → Send ETH on Anvil → Wait for indexing → Query token-transfers API → Verify transfer data

**Services involved:**
Anvil → indexer-evm → processor → data-shard → ork → app-node

---

## NOTES

- Use Docker for infra only (Mongo/Redis/Anvil) — start Node services directly for speed
- Single test should execute in < 30 seconds
- Use existing test patterns from `rumble-app-node/tests/test-lib/`
- Anvil provides deterministic accounts with pre-funded ETH

ANVIL: https://getfoundry.sh/anvil/overview/

---

There is some work on the setup done at public indexer level by Maksym woth to look at before starting this:
https://tether-to.slack.com/archives/C090AUH3V6K/p1773856271731709
