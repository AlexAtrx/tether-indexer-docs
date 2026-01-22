# 11 Jan 26 Balance Oscillation Follow-up

## What I changed locally
- Checked out `fix/balance-determinism` in all PR repositories.
- Implemented seeded RPC fallback in `wdk-data-shard-wrk/workers/lib/blockchain.svc.js`:
  - when seeded peer lookup/request fails, fall back to `jTopicRequest` for availability.
- Updated integration tests in `wdk-data-shard-wrk/tests/api.shard.data.wrk.intg.test.js` to force the fallback path by returning empty topic keys, keeping topic stubs intact.
- Tests: `npm test` in `wdk-data-shard-wrk` passed.

## Slack reply (concise)
- I agree with Vigan’s concern: seeded peer selection can hurt availability and skew load.
- I’ve added a fallback in `wdk-data-shard-wrk` #138 so the deterministic peer path falls back to `jTopicRequest` on failure (reduces the 15-min downtime risk while keeping determinism when healthy).
- On Usman’s “different list shapes” point: determinism is per address set, so cross-list calls can still diverge; fixing that needs API/list normalization and is out of scope here, but this is still a strict improvement over random peer selection.
- Advice: merge the already-approved provider-level PRs now; re-review/merge #138 with this fallback (and optionally reduce lookup cache TTL) and decide if list-shape normalization is needed.
