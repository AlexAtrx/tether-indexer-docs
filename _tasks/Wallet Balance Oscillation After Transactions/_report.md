# Intermittent Wallet Balance Oscillation After Transactions - Findings

## Scope recap
The reported issue is that `/api/v1/wallets/balances` alternates between pre- and post-transaction balances for minutes after a transfer. I reviewed the prior task notes, the slack thread, and the current code paths for balance queries and caching.

## Key code paths (evidence)
- HTTP endpoint and cache param default: `wdk-app-node/workers/lib/server.js:569`
- HTTP cache implementation and TTL: `wdk-app-node/workers/lib/utils/cached.route.js:3`
- Cache skip on `cache=false`: `wdk-app-node/workers/lib/utils/cached.route.js:21`
- Cache only when no nulls: `wdk-app-node/workers/lib/utils/helpers.js:3`
- Balance RPC entry point (data-shard): `wdk-data-shard-wrk/workers/api.shard.data.wrk.js:593`
- Balance aggregation, on-chain fetch: `wdk-data-shard-wrk/workers/lib/blockchain.svc.js:591`
- Per-chain balance fetch via indexer RPC: `wdk-data-shard-wrk/workers/lib/blockchain.svc.js:472`
- RPC to indexer uses HyperDHT lookup and random peer: `tether-wrk-base/node_modules/hp-svc-facs-net/index.js:89` and `tether-wrk-base/node_modules/hp-svc-facs-net/index.js:209`
- DHT peer list cache TTL (5 min default): `tether-wrk-base/node_modules/hp-svc-facs-net/lib/hyperdht.lookup.js:35`
- Indexer RPC provider rotation: `wdk-indexer-wrk-base/workers/lib/rpc.base.manager.js:181`
- Example multiple RPC providers per chain: `wdk-indexer-wrk-evm/config/usdt-pol.json.example:7`
- Redis is required and shared across app-node instances: `wdk-app-node/README.md:29`
- Docs for `/api/v1/wallets/balances` do not mention `cache`: `rumble-docs/api/Wallets and balance/GET -api-v1-wallets--balances.bru:18`

## What is actually happening
1. `/api/v1/wallets/balances` is a live on-chain query (not a DB snapshot). The data-shard calls `blockchainSvc.getMultiWalletsBalances`, which then calls `getBalanceMulti` on indexer workers for each chain/token pair.
2. Provider selection is non-deterministic at two layers:
   - The net layer selects a random indexer peer on each call (`lookupTopicKey` chooses a random key).
   - Each indexer worker rotates across multiple RPC providers via `RpcBaseManager` (round robin with weights).
3. If any provider or peer is lagging behind the latest block (or otherwise inconsistent), repeated requests can return older balances. Because the app-node cache TTL is only 30 seconds, each cache refresh can land on a different peer/provider, producing 10 -> 15 -> 10 -> 15 oscillation even when the transaction is already confirmed.
4. The prior hypothesis that `cache=false` "poisons" the cache is not true in current code. `cachedRoute` explicitly skips both read and write when `cache=false`. However, `cache=false` does not make provider selection consistent; it simply bypasses the 30s response cache, so it can actually expose provider drift more often.
5. If Redis is not shared across app-node instances (misconfig), per-worker caching divergence could reintroduce oscillation. The README explicitly requires a shared Redis, so this is a config check to validate in production.

## Root cause summary
The oscillation is caused by inconsistent upstream data sources (indexer peers and/or RPC providers at different block heights) combined with non-deterministic selection and a short HTTP cache TTL. Mixed client usage of `cache=true` and `cache=false` further exposes this inconsistency.

## Local reproduction ideas
Option A - provider drift (single indexer worker):
1. Configure an EVM chain with two RPCs: one stale fork (anvil/hardhat pinned to block N) and one live RPC.
2. Set `mainRpc` to the stale endpoint and include both in `secondaryRpcs`.
3. Submit a transfer on the live chain.
4. Repeatedly call `/api/v1/wallets/balances?cache=false` and observe alternating pre/post balances due to round robin provider selection.

Option B - multiple indexer workers:
1. Run two indexer API workers for the same chain with different RPC URLs (one lagging).
2. Data-shard `jTopicRequest` randomly selects a peer each call.
3. Repeated balance calls alternate between peers and show oscillation.

Option C - mixed cache usage:
1. Trigger concurrent calls to `/api/v1/wallets/balances` (default cache) and `/api/v1/wallets/balances?cache=false` from different UI flows.
2. Observe cached stale values vs live values alternating in the UI.

## Fix plan (backend)
1. Make provider selection deterministic for balance reads.
   - Fastest: call `rpcManager.call` with `useSecondary: false` for balance reads, only fall back to secondary on errors.
   - Safer: introduce a "sticky provider" per chain for read-only balance calls with a short TTL; rotate only on errors or if the provider is N blocks behind.
   - More robust: sample block heights across providers and choose the highest (or within a threshold).
2. Consider serving `/api/v1/wallets/balances` from DB snapshots (syncBalancesJob) when stability is preferred over real-time, with an optional "refresh" endpoint to update snapshots on demand.
3. Add logging of provider URL / peer id / block height and cache hit or miss for balance endpoints to diagnose in production.
4. Document the `cache` param for `/api/v1/wallets/balances` in rumble-docs and ensure backend behavior is explicit.

## Fix plan (frontend)
1. Standardize cache usage per UX context (example: always use cached for background polling, use `cache=false` only on explicit user refresh).
2. Avoid mixing cached and live requests for the same screen/session within a short interval.

## Test ideas
1. Unit test for `cachedRoute` to assert `cache=false` does not read/write Redis.
2. Unit/integration test for sticky or height-based provider selection to ensure balance responses are stable across repeated calls.
3. Integration test to verify `/api/v1/wallets/balances` returns a consistent value across multiple requests within the TTL.

## Notes
`_docs/___TRUTH.md` currently states that `cache=false` still writes to cache and that shared Redis is not implemented. That is out of date with the current `cachedRoute` implementation and `wdk-app-node/README.md`. The doc should be updated once the fix is validated.
