**Who supports what**
- `4_wdk-indexer-wrk-evm_proc-type` & `4_wdk-indexer-wrk-evm_api-type` depend on `@tetherto/wdk-indexer-wrk-base` for the shared worker scaffold, Hyperswarm plumbing, and HyperDB codecs.
- All other chain repos (`4_wdk-indexer-wrk-btc_*`, `4_wdk-indexer-wrk-solana_*`, etc.) import that same base package in exactly the same way.
- `1_wdk-indexer-app-node` is built on `@tetherto/wdk-app-node`, which supplies the HTTP server framework, lifecycle helpers, and middleware used by both the WDK and any Rumble variants.
- `3_wdk-data-shard-wrk_*` and `2_wdk-ork-wrk` are stand-alone workers but expose npm packages that the `rumble-*` repos extend (e.g., `rumble-data-shard-wrk` overlays notifications/webhooks on top of `@tetherto/wdk-data-shard-wrk`).

**Basis / layering**
- Runtime stack order matches the diagram: user → `1_wdk-indexer-app-node` (HTTP) → `2_wdk-ork-wrk` (routing) → `3_wdk-data-shard-wrk_*` (business logic) → `4_wdk-indexer-wrk-evm_*` (per-chain indexers) → MongoDB + external RPC providers.
- Every worker inside the Hyperswarm mesh must share the same `topicConf.capability` and `topicConf.crypto.key`; this basis is what allows service discovery and RPC between Proc/API pairs.
- Proc/API relationships are handshake-based: each Proc prints a `proc-rpc` token that its matching API requires; this is how `3_*` and `4_*` API workers authenticate back to their Proc counterparts.
