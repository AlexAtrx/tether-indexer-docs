
# Context

## Company

* **Tether** — [https://tether.io](https://tether.io)
* Best known for **USD₮ (USDT)**, the largest and most-traded USD-pegged stablecoin (1:1).

## Product Focus: Wallet Development Kit (WDK)

* **Open-source, developer-first** toolkit for building **secure, multi-chain, self-custodial wallets** for humans, machines, and AI agents.
* **Targets/environments:** Node.js, Bare runtime, React Native, and future embedded; runs on embedded devices, mobile, desktop, and servers.
* **Architecture:** Unified, modular, extensible; avoids vendor lock-in; supports multiple chains with add-on modules.
* **Dev experience:** Strong TypeScript typings, extensive docs, ready-to-use starters.
* **Security:** Stateless self-custody; keys never leave user control.
* **Ecosystem pieces:**

  * Modular **SDK** for wallet/protocol ops
  * **Indexer API** for blockchain data
  * **UI kits** (React Native components)
  * **Examples/starters** for rapid wallet deployment
* **Use cases:** Consumer wallets, DeFi apps, IoT, AI-driven finance.

# Meeting Notes (Indexer + Data Shard)

> May be imperfect; use judgment.

* **Repo layout:** Base **UDK indexer** repo + child repos per chain.

  * Schema changes ⇒ **version bump**.
  * **HyperDB fields must be appended**, not inserted.
* **Workers:** Per-chain indexer workers sync blocks & expose RPC to front-end.

  * Deployed on **GCP (staging/dev)** on shared **EC2** instances.
  * Managed by **Usman & Vegan**.
* **Data Shard:** Core library for business logic, RPC, and encrypted user seeds/entropy (client-side encryption).

  * Stores **public data**.
  * Multiple shard instances partition ~**100M users**.
  * Limited backup; **staging** uses migrations only.
* **Rumble extensions:** Child repo adds notifications, webhooks, etc.

  * Any base-repo change must be mirrored in child repo.
* **Org service (`wdk-org-wrk`):** API gateway routing requests to the correct data shard; **no authentication**.
* **App node (`wdk-app-node`):** Mobile-app routes + proxy endpoints for third-party provider tokens.

  * **No shared TS/OpenAPI spec**; consistency handled manually.
* **Deployment/tooling:** Manual one-by-one deploys; team wants CI/CD (GitHub Actions / K8s).

  * Local dev: MongoDB container, Hyperswarm topic & key validation.
  * **Bruno** used as shared API client (like Postman).

# Additional Artifact

* `diagram.png`: simple, repetitive diagram; **not exhaustive** but provides helpful structure.

---

# Your Task

1. **Understand the repos and the `diagram.png`** (expect base indexer + per-chain workers, data shard, org service, app node, Rumble extensions).
2. **Explain how to run the needed pieces together locally**, assuming I can spin up a **MongoDB** cluster on my machine.
3. **Do not actually run anything** — provide a **step-by-step plan** only.
4. **Scope:** Focus on what’s necessary to run the **indexer**; do **not** include unrelated services unless required by the indexer’s data/RPC paths.

---

# Required Output

Produce a concise technical plan that includes:

* **Components & Repos Map**

  * List each service (base indexer, per-chain worker(s), data shard, org service, app node, Rumble extensions).
  * For each: purpose, dependencies, key env vars, expected ports, local dev commands (e.g., `pnpm/npm/yarn` scripts or `go run`, etc.), and how they interconnect.
* **Local Topology**

  * Diagram-by-words: which services must run for local indexing; which are optional.
  * Any **HyperDB**/Hyperswarm topics and key validation notes.
* **MongoDB Setup**

  * MongoDB (single node or replica set) params, init steps, connection URIs, users/roles, required indexes/migrations.
  * Clarify what data is public vs. encrypted client-side.
* **Schema & Versioning**

  * How to handle schema changes (append-only fields for HyperDB; version bump policy).
* **Boot Order & Health Checks**

  * Startup sequence (e.g., DB → data shard → per-chain worker(s) → org service → app node).
  * Health/readiness checks and smoke tests (e.g., sample RPC calls via Bruno).
* **Chain Configuration**

  * How to enable N chains locally: RPC endpoints, env secrets, rate limits, block range backfill, reorg handling, and pruning.
* **Minimal Run Set**

  * The **smallest set** of processes needed to have a working local indexer (e.g., MongoDB + data shard + one per-chain worker + org service).
* **CI/CD Hints (Optional)**

  * Outline for future GitHub Actions + K8s, without executing anything.
* **Caveats & Gaps**

  * Call out any missing specs (e.g., no shared TS/OpenAPI), and how to keep app node/org service consistent locally.

**Constraints**

* Explain only; no execution.
* Assume repos follow the meeting structure even if names differ slightly.
* If a component is ambiguous, note assumptions explicitly and proceed.

**Deliverable Format**

* Use clear headings, bullet lists, and command/code blocks for commands and env samples.
* Keep it pragmatic and step-by-step so a dev can follow to get a local indexer working.
