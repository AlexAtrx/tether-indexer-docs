Module-free summary (repo-level): Across `wdk-indexer-wrk-base`, `wdk-indexer-wrk-evm`, `wdk-indexer-wrk-btc`, `wdk-indexer-wrk-solana`, `wdk-indexer-wrk-ton`, `wdk-indexer-wrk-tron`, `wdk-data-shard-wrk`, and `rumble-docs`, the work implements deterministic balance reads per address, wires balance calls to use that deterministic path, updates tests to match the new behavior, adds metrics wiring where needed, and documents the cache parameter so behavior is explicit.

Detailed breakdown (repos, modules, tech approach)

wdk-indexer-wrk-base (PR #63)
- Adds deterministic provider selection in `workers/lib/rpc.base.manager.js` via `_getSeededIndex`, `getProviderBySeed`, and `callWithSeed`. The seed is hashed to a provider index; if the seeded provider is OPEN, it falls back to a local round-robin cursor that does not mutate the global index.
- The fallback path preserves circuit-breaker behavior and records RPC errors per seeded provider name.
- Adds tests in `tests/rpc.base.manager.unit.test.js` for seed stability, failover, "all providers open" behavior, and metrics recording.
- Updates `workers/lib/metrics.manager.js` to register metrics via `registers: [this.registry]` and uses `interval_0.del('push-metrics')` during close.

wdk-indexer-wrk-evm (PR #62)
- Routes native and ERC20 balance reads through `rpcManager.callWithSeed` in `workers/lib/chain.evm.client.js` and `workers/lib/chain.erc20.client.js`.
- Uses normalized lowercase addresses as the seed and tags the method as `getBalance` for metrics.
- Updates unit tests to stub `callWithSeed` instead of `call`.

wdk-indexer-wrk-btc (PR #64)
- Routes BTC balance reads through `rpcManager.callWithSeed` in `workers/lib/chain.btc.client.js`, using the address as the seed.
- Refactors unit tests to mock the base manager (`@tetherto/wdk-indexer-wrk-base/workers/lib/rpc.base.manager`) and focus on `ChainBtcClient` behaviors; removes provider and provider-manager unit tests that were tied to the old provider setup.

wdk-indexer-wrk-solana (PR #50)
- Uses `rpcManager.callWithSeed` for SOL balance reads in `workers/lib/chain.solana.client.js`.
- Uses `callWithSeed` twice in `workers/lib/chain.spl.client.js` (token account lookup and account balance) with the same address seed to keep both calls pinned to the same provider.
- Updates tests to stub `callWithSeed` and adjusts test config to use `mainRpc`.

wdk-indexer-wrk-ton (PR #60)
- Routes TON and Jetton balance reads through `rpcManager.callWithSeed` in `workers/lib/chain.ton.client.js` and `workers/lib/chain.jetton.client.js`.
- Passes `metricsManager` into `RpcBaseManager` and provider constructors; providers record `ERR_HTTP_REQUEST` when response bodies are missing in `workers/lib/providers/*.ton.provider.js`.
- Adds metrics config example in `config/common.json.example`.

wdk-indexer-wrk-tron (PR #56)
- Routes TRX and TRC20 balance reads through `rpcManager.callWithSeed` in `workers/lib/chain.tron.client.js` and `workers/lib/chain.trc20.client.js`.
- Uses hex-encoded address as the seed, tags method as `getBalance` for metrics.
- Updates tests, adds `tests/utils/mockGasfreeModule.js`, and adjusts fixtures around gasfree receipts and block numbering.

wdk-data-shard-wrk (PR #138)
- Adds seeded peer selection to `_rpcCall` in `workers/lib/blockchain.svc.js`: when a seed is provided, it uses `lookupTopicKeyAll`, sorts keys, and picks a deterministic peer by hashing the seed, then calls `jRequest` directly.
- Adds `_buildBalanceSeed` and `_buildBalanceListSeed` (chain/ccy/address based) and threads seeds into `getBalance` and `getBalanceMulti` flows (notably `fetchBalancesByChain` and wallet balance aggregation). This pins balance requests to a stable indexer peer.
- Updates unit tests to stub `_rpcCall` directly to avoid brittle net-layer stubs.

rumble-docs (PR #34)
- Documents the `cache` query parameter for `/api/v1/wallets/balances` in `api/Wallets and balance/GET -api-v1-wallets--balances.bru` (default true, false bypasses cache read/write and fetches live).

Review notes (from PR reviews)
- `wdk-indexer-wrk-base` PR #63 has "changes requested" due to code-duplication concerns around provider selection helpers; a reviewer also questioned rate-limiting impact, and the author replied that the intent is balance determinism rather than rate limiting. Other listed PRs are awaiting review and have no review comments yet.

Overall effect
- The core fix makes balance reads deterministic at two layers: data-shard selects a stable indexer peer per address/token, and each indexer worker selects a stable RPC provider per address. This reduces oscillation when upstream providers or peers are at different block heights while keeping circuit-breaker failover in place.
