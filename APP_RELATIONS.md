**Who supports what**
- `wdk-indexer-wrk-evm_proc-type` & `wdk-indexer-wrk-evm_api-type` depend on `@tetherto/wdk-indexer-wrk-base` for the shared worker scaffold, Hyperswarm plumbing, and HyperDB codecs.
- All other chain repos (`wdk-indexer-wrk-btc_*`, `wdk-indexer-wrk-solana_*`, etc.) import that same base package in exactly the same way.
- `wdk-indexer-app-node` is built on `@tetherto/wdk-app-node`, which supplies the HTTP server framework, lifecycle helpers, and middleware used by both the WDK and any Rumble variants.
- `wdk-data-shard-wrk_*` and `wdk-ork-wrk` are stand-alone workers but expose npm packages that the `rumble-*` repos extend (e.g., `rumble-data-shard-wrk` overlays notifications/webhooks on top of `@tetherto/wdk-data-shard-wrk`).

**Basis / layering**
- Runtime stack order matches the diagram: user → `wdk-indexer-app-node` (HTTP) → `wdk-ork-wrk` (routing) → `wdk-data-shard-wrk_*` (business logic) → `wdk-indexer-wrk-evm_*` (per-chain indexers) → MongoDB + external RPC providers.
- Every worker inside the Hyperswarm mesh must share the same `topicConf.capability` and `topicConf.crypto.key`; this basis is what allows service discovery and RPC between Proc/API pairs.
- Proc/API relationships are handshake-based: each Proc prints a `proc-rpc` token that its matching API requires; this is how data-shard and indexer API workers authenticate back to their Proc counterparts.
