# Rumble Wallet & Indexers - Standup

## Proposal for push based system

- Current pull‑based sync causes lag at \~5 K users; workers poll all wallets even when no txs arrive.
- Goal: indexers push new transaction notifications to data‑shard workers for immediate wallet updates.
- Two design options discussed:
  1. **Router service** – indexers → router → shard (router holds address→wallet→shard lookups).
  2. **Broadcast** – indexers push every tx to all shards; each shard filters locally.
- Router promises network efficiency and targeted delivery; adds a new service layer and state‑management complexity.
- Broadcast is simple, no new service, but sends \~99.9 % irrelevant txs; CPU cost of in‑memory filtering is minimal.
- Both approaches would send lightweight envelopes (chain, txHash, from/to addresses) rather than full transactions.

## Meeting points about the push based system

- **Time to production**: broadcast POC ≈ 2 weeks vs router 8‑12 weeks; faster fix for the urgent sync‑lag issue.
- **Operational risk**: router introduces 5+ new failure modes (change‑stream lag, cache drift, resume token loss, partition failures, etc.).
- **Latency**: broadcast = 2 hops (indexer → shard); router = 3 hops (indexer → router → shard → fetch).
- **Testing plan**:
  - Week 1: implement broadcast POC on one chain, measure latency, CPU, bandwidth.
  - Week 2: load‑test at realistic peak (≈ 5 K tx/s); define success criteria (≤ 100 ms p99, ≤ 10 % CPU, ≤ 100 MB/s network).
  - Decision point: ship broadcast if metrics pass; otherwise invest in router.
- **Resource trade‑offs**: broadcast uses \~50 MB/s at peak (well within 1 Gbps links); router saves \~500 KB/s but adds complexity.

## Detailed findings about the push based system

- **Router analysis**:
  - Requires read‑replica or change‑stream cache of address→wallet→shard mappings; risk of stale data causing missed transactions.
  - Adds an extra hop (shard must fetch full tx from indexer), increasing latency without clear network benefit.
  - Becomes a single point of failure; requires robust health‑checks, persistent queues, and failover.
- **Broadcast analysis**:
  - Simple, leverages existing Hyperswarm topics; shards already hold wallet state, so filtering is O(1) hash lookup.
  - Even at extreme 5 000 tx/s, bandwidth ≈ 50 MB/s and CPU overhead ≈ 8 % per shard – well within capacity.
  - No new state to synchronize; zero risk of missed transactions.
- **Recommendation**: start with broadcast‑first, validate with load tests, then only consider router if metrics fail.
- **Refinements for broadcast**: lightweight envelope, optional per‑chain topics, batching (1‑2 s windows), optional Bloom filter in shards, monitoring of latency and discard ratios.

## Opinion supporting the push based system

- **Preferred design**: router‑based push **only if** it is built stateless with an in‑memory cache fed by MongoDB change streams (or a dedicated HyperDB mirror).
- **Event schema**: chainId, txHash, blockNumber, from, to; optional token contract list; shards fetch full tx from internal indexer when needed.
- **Reliability features**: at‑least‑once delivery, idempotency key (chainId:txHash\[:address\]), back‑pressure handling, HMAC/JWT signing for RPC calls.
- **Rollout plan**:
  1. Feature‑flagged pilot on a single chain with one router instance.
  2. Horizontal scaling via consistent hashing; add Bloom‑filter push‑down to indexers if volume grows.
  3. Harden with alerts (latency P95, dedup ratio, router memory) and failure drills (router kill/restart).
- **Operational benefits**: keeps data‑shard write path unchanged, isolates trigger logic, avoids flooding shards with irrelevant traffic, and provides clear metrics for debugging.
- **Open questions**: owner of address→wallet→shard mapping (data‑shard vs ork), confirmation policy (mempool vs N confirmations), expected peak event rate for sizing router cache.

----

## Footnotes:

Yeah, I can add a bit. From what I’ve seen, this looks like a state divergence between the org-level index and the shard-level data. If Autobase replication lagged or a writer conflict wasn’t resolved cleanly, the org view could miss wallet references even though the shard data exists. We might want to log the replication heads for that org and compare them across nodes to confirm if it’s a sync inconsistency.

That alternating error pattern strongly suggests inconsistent reads between replicas or conflicting heads in Autobase. If one node resolves the org index differently, it could intermittently return “wallet not found” versus “user not found.” We should capture the Autobase heads and metadata for both responses and compare them. Also, enabling debug-level logging for the replication layer temporarily could help confirm if these errors correlate with pending merges or unmerged writes.

Exactly, that’s what it sounds like. They’re using `getWallets` as a pre-check before registration, which isn’t ideal because it triggers a 500 when the user isn’t yet provisioned. We should probably have the backend return a clean 404 or a structured “user not found” response instead, so the app can handle it gracefully without polluting error logs. That way, we separate genuine backend issues from expected pre-registration checks.
