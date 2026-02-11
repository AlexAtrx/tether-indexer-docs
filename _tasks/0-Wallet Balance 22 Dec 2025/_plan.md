# Plan: Wallet Balance Oscillation Fix PRs

Assumptions:
- Production runs multiple indexer peers per topic.
- Each chain worker is a separate Git repo; PRs must be per repo.
- Provider selection should be deterministic per address to avoid oscillation.

Ticket 1 - Core deterministic provider selection (common code change)
- Repo: `wdk-indexer-wrk-base`
- Title: Add deterministic RPC provider selection for balance reads
- Goal: Introduce a stable provider selection method (seeded by address) with circuit breaker fallback.
- Scope / Files:
  - `wdk-indexer-wrk-base/workers/lib/rpc.base.manager.js`
  - `wdk-indexer-wrk-base/tests/rpc.base.manager.unit.test.js` (or existing test location)
- Work:
  - Add `getProviderBySeed(seed)` to choose a provider deterministically from `secondaries`.
  - Add `callWithSeed(fn, seed, opts)` to execute with the seeded provider first, then fall back to round-robin on failure.
  - Ensure OPEN circuit providers are avoided; fallback uses existing `secondary`.
  - Keep hashing logic simple and stable (string hash to index).
- Acceptance:
  - Same seed always resolves to the same provider (unless OPEN).
  - On errors, fallback rotates like existing `call`.
  - Unit tests cover stable selection and fallback behavior.
- Tests:
  - Unit tests for deterministic selection and OPEN fallback.
- Dependencies:
  - None (base change required before chain PRs).

Ticket 2 - EVM chain worker updates
- Repo: `wdk-indexer-wrk-evm`
- Title: Use deterministic provider selection for EVM balance reads
- Goal: Route balance reads through `callWithSeed` using a normalized address seed.
- Scope / Files:
  - `wdk-indexer-wrk-evm/workers/lib/chain.evm.client.js`
  - `wdk-indexer-wrk-evm/workers/lib/chain.erc20.client.js`
- Work:
  - Replace `rpcManager.call` in `getBalance` with `rpcManager.callWithSeed`.
  - Use `address.toLowerCase()` as the seed (matches existing normalization).
  - Keep method name `getBalance` for metrics.
- Acceptance:
  - Balance calls use deterministic provider choice per address.
- Tests:
  - Existing tests (if any); otherwise note "manual verification".
- Dependencies:
  - Ticket 1 merged.

Ticket 3 - BTC chain worker updates
- Repo: `wdk-indexer-wrk-btc`
- Title: Use deterministic provider selection for BTC balance reads
- Goal: Route BTC balance reads through `callWithSeed`.
- Scope / Files:
  - `wdk-indexer-wrk-btc/workers/lib/chain.btc.client.js`
- Work:
  - Replace `rpcManager.call` in `getBalance` with `rpcManager.callWithSeed`.
  - Use the address string as the seed (no lowercasing).
  - Keep method name `getBalance` for metrics.
- Acceptance:
  - Balance calls use deterministic provider choice per address.
- Tests:
  - Existing tests (if any); otherwise note "manual verification".
- Dependencies:
  - Ticket 1 merged.

Ticket 4 - Solana chain worker updates
- Repo: `wdk-indexer-wrk-solana`
- Title: Use deterministic provider selection for Solana balance reads
- Goal: Route SOL + SPL balance reads through `callWithSeed`.
- Scope / Files:
  - `wdk-indexer-wrk-solana/workers/lib/chain.solana.client.js`
  - `wdk-indexer-wrk-solana/workers/lib/chain.spl.client.js`
- Work:
  - Replace `rpcManager.call` with `rpcManager.callWithSeed` in `getBalance`.
  - Seed uses the original base58 address string (no case changes).
  - For SPL: ensure both `getTokenAccountsByOwner` and `getTokenAccountBalance` use the same seed to keep provider consistent for the sequence.
  - Keep method name `getBalance` for metrics (add it where missing).
- Acceptance:
  - SOL/SPL balance reads hit a stable provider per address.
- Tests:
  - Existing tests (if any); otherwise note "manual verification".
- Dependencies:
  - Ticket 1 merged.

Ticket 5 - TON chain worker updates
- Repo: `wdk-indexer-wrk-ton`
- Title: Use deterministic provider selection for TON and Jetton balance reads
- Goal: Route TON + Jetton balance reads through `callWithSeed`.
- Scope / Files:
  - `wdk-indexer-wrk-ton/workers/lib/chain.ton.client.js`
  - `wdk-indexer-wrk-ton/workers/lib/chain.jetton.client.js`
- Work:
  - Replace `rpcManager.call` with `rpcManager.callWithSeed` in `getBalance`.
  - Use the original address string as the seed.
  - Keep method name `getBalance` for metrics.
- Acceptance:
  - TON/Jetton balance reads hit a stable provider per address.
- Tests:
  - Existing tests (if any); otherwise note "manual verification".
- Dependencies:
  - Ticket 1 merged.

Ticket 6 - Tron chain worker updates
- Repo: `wdk-indexer-wrk-tron`
- Title: Use deterministic provider selection for TRON/TRC20 balance reads
- Goal: Route TRON + TRC20 balance reads through `callWithSeed`.
- Scope / Files:
  - `wdk-indexer-wrk-tron/workers/lib/chain.tron.client.js`
  - `wdk-indexer-wrk-tron/workers/lib/chain.trc20.client.js`
- Work:
  - Replace `rpcManager.call` with `rpcManager.callWithSeed` in `getBalance`.
  - Use hex address (the one sent to provider) as the seed for TRON.
  - Keep method name `getBalance` for metrics (add where missing).
- Acceptance:
  - TRON/TRC20 balance reads hit a stable provider per address.
- Tests:
  - Existing tests (if any); otherwise note "manual verification".
- Dependencies:
  - Ticket 1 merged.

Ticket 7 - Deterministic indexer peer selection (multi-peer prod)
- Repo: `wdk-data-shard-wrk`
- Title: Choose indexer peers deterministically for balance RPCs
- Goal: Remove randomness in peer selection when multiple indexer peers exist.
- Scope / Files:
  - `wdk-data-shard-wrk/workers/lib/blockchain.svc.js`
- Work:
  - Extend `_rpcCall` to accept an optional `seed` parameter.
  - If `seed` is present:
    - Call `ctx.net_r0.lookupTopicKeyAll(topic, cached)`.
    - Select a peer deterministically using a stable hash of the seed.
    - Call `ctx.net_r0.jRequest` directly to the chosen peer (use `lookup.reqOpts()` plus existing opts).
  - Thread a stable seed into balance paths (e.g., in `fetchBalancesByChain` use `seed = chain + ':' + ccy + ':' + sortedAddresses.join(',')`).
- Acceptance:
  - Repeated balance requests with same seed go to the same peer.
  - When `seed` is not provided, existing random behavior remains for non-balance calls.
- Tests:
  - Add unit test for deterministic key selection if test harness exists; otherwise manual verification.
- Dependencies:
  - None (can be parallel with chain updates, but safe after Ticket 1).

Ticket 8 - Docs and truth updates
- Repo: `rumble-docs` and root docs
- Title: Document cache behavior and correct prior cache assumptions
- Goal: Make API behavior explicit and update internal truth doc.
- Scope / Files:
  - `rumble-docs/api/Wallets and balance/GET -api-v1-wallets--balances.bru`
  - `_docs/___TRUTH.md`
- Work:
  - Document `cache` param: default true, TTL 30s, `cache=false` bypasses read/write.
  - Update `_docs/___TRUTH.md` to remove old "cache poisoning" claim and note shared Redis requirement.
- Acceptance:
  - Docs reflect current behavior and expected caching semantics.
- Tests:
  - None.
- Dependencies:
  - None.
