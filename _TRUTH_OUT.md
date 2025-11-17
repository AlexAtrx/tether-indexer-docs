# WDK Indexer – TRUTH

_Last updated: 2025-11-14. This file is designed to be updated incrementally as the system evolves._

## 1. Key Architecture Decisions

- **Distributed, multi-chain indexer** for self-custodial wallets (WDK – Wallet Development Kit Indexer).
- **Service stack & data flow** (runtime order):
  - `1_wdk-indexer-app-node`: HTTP REST API surface (Fastify-based, port 3000).
  - `2_wdk-ork-wrk`: Org service / API gateway & router.
  - `3_wdk-data-shard-wrk_*`: Business logic & wallet data (per-shard workers).
  - `4_wdk-indexer-wrk-evm_*` (and other chains): Per-chain indexers that speak to blockchain RPC providers and MongoDB.
  - Persistence via **MongoDB replica set** (3-node local dev: `mongo1`, `mongo2`, `mongo3`).
- **Proc/API worker pattern**:
  - Each logical service has two worker types:
    - **Proc worker** (writer): handles mutations, blockchain sync, HyperDB writes, and prints a **Proc RPC key**.
    - **API worker** (reader): serves queries and must be started with the corresponding **`--proc-rpc` key**.
  - This is enforced in data shards and chain indexers (at least EVM; pattern extends to BTC/Solana/TON/Tron/Spark and token indexers like ERC-20 and SPL).
- **P2P RPC via Hyperswarm mesh**:
  - All workers discover and talk to each other over Hyperswarm topics.
  - **Critical invariant**: all services share identical `topicConf.capability` and `topicConf.crypto.key` in `config/common.json`.
  - Topics tie layers together, e.g. `@wdk/ork`, `@wdk/data-shard`, `@wdk/indexer/evm`.
- **Storage model**:
  - Core blockchain state stored in MongoDB databases per domain (e.g., `wdk_indexer_evm`, `wdk_data_shard`).
  - HyperDB is used as an append-only log for blockchain data and schema codecs (via `wdk-indexer-wrk-base`).
- **Monorepo & layering**:
  - Chain workers (`4_wdk-indexer-wrk-evm_*`, `4_wdk-indexer-wrk-btc_*`, `4_wdk-indexer-wrk-solana_*`, etc.) share a common base package `@tetherto/wdk-indexer-wrk-base` for scaffolding, Hyperswarm plumbing, and codecs.
  - `1_wdk-indexer-app-node` is built on `@tetherto/wdk-app-node` (HTTP server + middleware).
  - `3_wdk-data-shard-wrk_*` and `2_wdk-ork-wrk` are standalone workers whose npm packages are extended by `rumble-*` repos for notifications/webhooks.
- **Local dev topology** (from diagram):
  - User → HTTP (`1_*`) → Org API (`2_*`) → Data Shard API → Data Shard Proc → EVM API → EVM Proc → MongoDB + external Ethereum JSON-RPC providers.
  - EVM Proc fans out to multiple public RPCs (Cloudflare, Ankr, PublicNode) with basic weight configuration.

## 2. Key Challenges & Weak Points

- **Hyperswarm secrets coupling**:
  - If `topicConf.capability` or `topicConf.crypto.key` differ between services, workers start but cannot communicate (silent failure). This is a fragile, non-obvious failure mode.
- **Proc/API key dependency**:
  - API workers cannot start without the correct Proc RPC key. This creates operational friction (manual copying from logs) and is a frequent source of misconfiguration.
- **Org service lacks authentication**:
  - `2_wdk-ork-wrk` has no auth layer; it is assumed to be on a trusted internal network. This is a deliberate trade-off but a notable risk if boundaries are misconfigured.
- **MongoDB replica set dependency**:
  - The system assumes a functioning replica set (not a single node). Local dev relies on a dockerized 3-node RS without auth, which can hide production realities.
- **RPC provider observability gaps** (from tickets):
  - Current error logs do not always include the **provider name** when a JSON-RPC call fails, making it hard to identify flaky or misbehaving providers.
  - No alerting yet on critical RPC errors such as `RPCError: TIMEOUT_EXCEEDED: timeout of ...`; monitoring is reactive via log reading.
- **Operational UX for workers**:
  - The process of making workers “runnable for repos” and wiring up all configs/RPC keys is non-trivial; some work has been captured in PR screenshots rather than fully documented.

## 3. Key TODOs (from current docs & tickets)

These are items clearly hinted at or explicitly requested:

- **Logging & observability**
  - Include **RPC provider identifiers** in error logs for failed provider requests to quickly pinpoint problematic endpoints.
  - Configure basic **alerts** for high-frequency RPC timeouts (e.g., logs containing `RPCError: TIMEOUT_EXCEEDED`) as an initial SRE baseline.
- **Dev ergonomics / worker UX**
  - Finish/solidify the work to make workers easily runnable **per repo**, ideally with:
    - Clear `README` or `Makefile`/`npm` scripts that encapsulate boot sequences.
    - Minimal manual copying of Proc RPC keys (e.g., helper scripts or env-file injection).
- **Documentation consolidation**
  - Keep `_TRUTH_OUT.md` in sync as new minutes, tickets, or architecture changes land.
  - Gradually move implicit knowledge from screenshots/PR comments into textual docs where possible.

_(More TODOs should be appended here as new tickets/minutes are added.)_

## 4. Key Security Threats / Risks

- **Un-authenticated internal RPC**:
  - Org worker (`2_wdk-ork-wrk`) has no auth; compromise or misconfiguration of the internal network boundary could expose powerful internal RPCs.
- **Shared secret mismanagement**:
  - All workers share the same `topicConf.capability` and `crypto.key`; leakage of these values would allow a malicious process to join the mesh and impersonate services.
- **MongoDB in dev with no auth**:
  - Local replica set runs without auth; if exposed beyond localhost/docker network, it could leak or allow tampering with blockchain/indexer data.
- **Reliance on public RPC endpoints**:
  - Public providers (Infura/Alchemy equivalents, Cloudflare, Ankr, PublicNode) can rate-limit, censor, or provide inconsistent data; without robust validation, this can corrupt indexing.

_(As more security-focused minutes/tickets are added, expand this section with concrete threat models and mitigations.)_

## 5. Key Features Offered by the Indexer (as part of WDK)

- **Multi-chain blockchain indexing**:
  - Core support for EVM chains (Ethereum, Arbitrum, Polygon) and extension points for BTC, Solana (native + SPL), TON, Tron, Spark.
- **Wallet-centric data shard**:
  - `3_wdk-data-shard-wrk_*` aggregates indexed blockchain data into wallet/business views, exposed via API workers.
- **HTTP API surface for SDKs & apps**:
  - `1_wdk-indexer-app-node` exposes REST/HTTP endpoints and Swagger docs on port 3000 for use by wallets or other WDK consumers.
- **Rumble extensions**:
  - `rumble-*` repos extend the base WDK workers with notifications/webhooks for downstream applications.
- **Append-only historical ledger via HyperDB**:
  - Chain indexers write to HyperDB using schema codecs, preserving an append-only history aligned with blockchain data.

## 6. Key Features Needed for Top Industry Standard

These are gaps or enhancements implied by the current design and common industry expectations:

- **First-class observability**:
  - Structured logs including provider IDs, chain, shard, and correlation IDs.
  - Metrics (latency, error rate, timeout rate per provider and per chain) and dashboards.
  - Alerting on RPC failures, sync lag, and Mongo replication issues.
- **Hardened security & isolation**:
  - Authentication and authorization for internal RPC (e.g., mTLS or signed tokens between workers).
  - Secret management for `topicConf` values and RPC keys (vault or KMS) instead of static config files.
  - Optional MongoDB auth with role-based access in non-local environments.
- **Resilient provider strategy**:
  - Smarter load-balancing and failover across RPC providers (health checks, backoff, provider scoring).
  - Data validation / cross-checking between providers to detect inconsistent or censored responses.
- **Scalability & multi-tenant support**:
  - Clear sharding strategies for data shards (by org, by user cohort, by chain).
  - Horizontal scaling patterns and autoscaling hooks for Proc/API workers.
- **DX & automation**:
  - One-command local bootstrap (Mongo + workers + sample config).
  - CI pipelines for schema validation, migrations, and backward compatibility checks.

_(As more product/architecture discussions happen, append new “standard” criteria here.)_

## 7. Nice-to-Have / Add-On Features

- **Fine-grained notification & webhook framework** (building on `rumble-*`).
- **Historical reindexing tools** for backfilling or recovering from corruption.
- **Pluggable chain modules** with a stable interface so new chains/tokens can be added with minimal friction.
- **Local simulation/sandbox mode** for testing wallet flows without hitting public RPCs.

## 8. Other Notes, Concerns, Suggestions

- **Operational clarity is critical**: The system’s correctness depends heavily on precise config (shared secrets, RPC URLs, Mongo URIs, Proc RPC keys). Small misconfigurations produce subtle failures, so investing in validation and tooling will pay off.
- **_TRUTH_OUT.md is the living summary**: Re-run the `_TRUTH.md` process periodically (e.g., monthly) and append/update sections rather than rewriting from scratch.
- **When new minutes or tickets are added**: categorize them under architecture decisions, challenges, TODOs, threats, or features, and update the corresponding sections here.
