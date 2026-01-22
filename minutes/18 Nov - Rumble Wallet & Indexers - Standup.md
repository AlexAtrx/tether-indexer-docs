# Rumble Wallet & Indexers - Standup

## Overview

- BTC proxy endpoints not a blocker now, but need config from Usman/Vegan for future stability
  - Ask them on Slack for server URLs, ports, and node provider details
- Cache layer causing balance flicker and duplicate notifications
  - Verify backend cache‑delay logic (30 s) and front‑end query‑param usage
  - Align front‑end to consistently use or bypass cache, involve George if needed
- Webhook duplication observed: same transaction sent twice with different hashes
  - One payload from notification endpoint, another from indexer; add transactionShiftId flag handling
- Paymaster support now added for Plasma and Sepolia; next step is full integration testing
- Test coverage: BTC tests refactored and ready; other chains (Plasma, Sepolia, EVM variants) still need replicated BTC test structure and CI workflow
- Action items
  - Ping Usman (even if sick) and Vegan for BTC proxy config
  - Investigate and fix cache inconsistency; update docs on query‑param behavior
  - Review and merge PR removing endless‑transaction check
  - Replicate BTC integration test template to remaining repos; set up GitHub Actions for automated runs
  - Track label‑to‑array discussion and ensure paymaster transaction handling is correct in the indexer.


## In details

