# Balance Oscillation Recap

## Solution implemented across the PR set

- `wdk-indexer-wrk-base` PR #63: adds deterministic provider selection via `_getSeededIndex`, `getProviderBySeed`, and `callWithSeed`, with circuit-breaker-aware fallback in `wdk-indexer-wrk-base/workers/lib/rpc.base.manager.js`; unit tests added in `wdk-indexer-wrk-base/tests/rpc.base.manager.unit.test.js`.
- `wdk-indexer-wrk-evm` PR #62: routes native and ERC20 balance reads through `callWithSeed` using normalized addresses in `wdk-indexer-wrk-evm/workers/lib/chain.evm.client.js` and `wdk-indexer-wrk-evm/workers/lib/chain.erc20.client.js`.
- `wdk-indexer-wrk-btc` PR #64: routes BTC balance reads through `callWithSeed` in `wdk-indexer-wrk-btc/workers/lib/chain.btc.client.js`.
- `wdk-indexer-wrk-solana` PR #50: uses `callWithSeed` for SOL balance reads and for SPL token account lookup + balance with the same seed in `wdk-indexer-wrk-solana/workers/lib/chain.solana.client.js` and `wdk-indexer-wrk-solana/workers/lib/chain.spl.client.js`.
- `wdk-indexer-wrk-ton` PR #60: routes TON and Jetton balance reads through `callWithSeed` in `wdk-indexer-wrk-ton/workers/lib/chain.ton.client.js` and `wdk-indexer-wrk-ton/workers/lib/chain.jetton.client.js` (plus metrics wiring in provider files).
- `wdk-indexer-wrk-tron` PR #56: routes TRX and TRC20 balance reads through `callWithSeed` using hex addresses in `wdk-indexer-wrk-tron/workers/lib/chain.tron.client.js` and `wdk-indexer-wrk-tron/workers/lib/chain.trc20.client.js`.
- `wdk-data-shard-wrk` PR #138: adds seeded peer selection in `_rpcCall` using `lookupTopicKeyAll` and a stable hash; seeds are built per address and per address list in `wdk-data-shard-wrk/workers/lib/blockchain.svc.js`, and are used for both `getBalance` and `getBalanceMulti` (via `fetchBalancesByChain`).
- `rumble-docs` PR #34: documents the `cache` query parameter for `/api/v1/wallets/balances` in `rumble-docs/api/Wallets and balance/GET -api-v1-wallets--balances.bru` (diff via PR).

## Senior developer objection (quoted)

> We have multiple indexers for chain+ccy. In this set of PRs, we are using address list as seeds to always ensure that we call the same indexer. This has a few drawbacks. If this indexer goes down, then we won't call a different indexer that provides the same functionality. Generating seed from addresses is fine in case we are fetching 1 wallet addresses. But if we fetch different wallets, then we'd still have the balance oscillation behavior. Therefore I am not 100% sure if adding this functionality fulfills the benefits against the added cost.

## Assessment (does the objection make sense?)

- The availability concern is valid. In `wdk-data-shard-wrk/workers/lib/blockchain.svc.js`, the seeded path calls `lookupTopicKeyAll` and then `ctx.net_r0.jRequest` directly. There is no fallback to another peer; retries are done via `retryTask`, but they reuse the same seed and therefore the same key. In contrast, `ctx.net_r0.jTopicRequest` would reselect (randomly) from available peers. So if the chosen peer is down but still in the topic list, the seeded path can keep failing.
- The “different wallets” concern is partially valid. `fetchBalancesByChain` seeds on the full address list (`_buildBalanceListSeed`), so the same list is stable, but a different list (or a single-wallet call) can hash to a different indexer. If the UI mixes list shapes for the same wallet, balances can still diverge across calls.
- The core benefit still stands: deterministic provider selection inside each indexer is implemented in `wdk-indexer-wrk-base/workers/lib/rpc.base.manager.js` with failover behavior, and chain clients consistently use `callWithSeed`. That directly addresses provider-level oscillation.
- Net: the objection makes sense for the data-shard seeded peer selection (availability and cross-list consistency), but it does not invalidate the provider-level fix. Whether the data-shard change is worth it depends on how many peers per topic exist in production and whether the system relies on peer failover.
