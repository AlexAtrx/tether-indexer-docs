# __truth.md — Tether WDK / Rumble Wallet Indexer System Summary

> Purpose: a single, clear, conversational reference for the whole backend. It is written
> so another LLM can confidently talk about this system in a live meeting: what each service
> does, how the pieces relate, how they talk to each other, what databases they use, and what
> every public API does in plain English. It stays architectural and design-level on purpose.
> It is not the coding-agent source of truth (that is the root `AGENTS.md`); it is the
> "explain the system to a human" companion.

---

## 1. What this system is, in one breath

This is the backend behind **Tether's Wallet Development Kit (WDK)** and the **Rumble Wallet**
built on top of it. WDK is an open-source, modular, multi-chain, self-custodial wallet toolkit:
private keys never leave the user, and the backend's job is to **index blockchain data**
(balances, transfers, transaction history) across many chains and serve it back to wallets and
apps through clean APIs. Rumble Wallet is a consumer product that extends the generic WDK
backend with its own features (device management, MoonPay buy/sell, swaps, push notifications,
promo codes, tip jars).

Think of it as two layers:
- **WDK core backend** — the generic, reusable wallet + indexer engine.
- **Rumble overlay** — product-specific features layered on top of the WDK base, repo by repo.

---

## 2. The mental model (read this first)

The system is a **mesh of small Node.js worker services**. A request flows through layers:

```
                 HTTP (public)                 Internal P2P RPC (HRPC over Hyperswarm)
   user/app  ─────────────────▶  app-node  ──────────▶  ork  ──────────▶  data-shard  ──────────▶  chain indexer  ──▶  blockchain RPC / Mongo
 (wallet,                       (HTTP API,            (router,           (canonical            (per-chain reader,
  Rumble                         the only             no auth,            storage of            talks to the actual
  server)                        HTTP doors)          internal)          wallets/balances/      chain nodes)
                                                                          transfers)
```

Two hard rules that explain almost everything:

1. **Only `*-app-node` repos speak HTTP.** Everything else (`*-ork-wrk`,
   `*-data-shard-wrk`, `*-indexer-wrk-*`, `*-indexer-processor-wrk`) is an **internal service**
   that talks over **HRPC on Hyperswarm**, even though some have public-sounding names. The
   "API boundary" where request shape is validated is the Fastify schema on the app-node layer.
2. **Every service is split into a Proc and an API half.** The **Proc** worker owns writes and
   runs scheduled jobs; it prints a one-time "Proc RPC Key" at boot. The **API** worker answers
   reads and must be handed that key (`--proc-rpc <KEY>`) to authenticate back to its Proc.

A third thing worth knowing: services find each other on Hyperswarm only if they share the same
**handshake secret and crypto key** (`topicConf.capability` + `topicConf.crypto.key`). If those
differ, every service looks healthy but they silently never discover each other. This is the
single most common "everything is up but nothing works" failure.

---

## 3. The services, and what each one does

### HTTP surfaces (the only doors into the system)

| Service | What it is | What it does |
|---|---|---|
| **wdk-app-node** | Authenticated wallet/user HTTP API | The generic WDK wallet API. Connects users, stores encrypted entropy/seed backups, returns balances, balance trends, wallets, and token-transfer history. |
| **rumble-app-node** | Rumble's extension of wdk-app-node | Everything wdk-app-node does, plus Rumble product features: device IDs, push notifications, MoonPay buy/sell, swaps, promo claims, tip jars, passkey auth, admin transfer views, client log ingest. |
| **wdk-indexer-app-node** | Public, API-key indexer HTTP API | A standalone "blockchain data as a service" API. Anyone with an API key can query token transfers and balances for an address on a given chain/token, directly and in batch. Has Swagger docs. |

### Routing / lookup mesh (internal)

| Service | What it is | What it does |
|---|---|---|
| **wdk-ork-wrk** | Gateway / router ("orchestrator") | Resolves a user/wallet/address to the right data shard. Holds the address-to-owner lookup. **Has no authentication** of its own, so it must stay on internal networks only. |
| **rumble-ork-wrk** | Rumble overlay on the ork | Adds in-memory (LRU) idempotency so duplicate `SWAP_STARTED` / `TOPUP_STARTED` / `CASHOUT_STARTED` events do not double-fire. |

### Canonical storage (internal)

| Service | What it is | What it does |
|---|---|---|
| **wdk-data-shard-wrk** | The system of record | Canonical storage for wallets, balances, user data, and wallet-transfer history. Runs the balance-sync and transfer-sync jobs. Proc owns writes, API serves reads. |
| **rumble-data-shard-wrk** | Rumble overlay on the shard | Adds notifications and tx-webhooks (a Mongo-backed webhook queue drained by a cron every 10s), plus duplicate-transfer dedupe. |

### Chain indexers (internal, one per chain family)

All extend a shared base, **wdk-indexer-wrk-base**, which provides the common scaffold:
Hyperswarm plumbing, HyperDB codecs, a circuit breaker over chain RPC providers, and optional
Prometheus hooks. Each indexer reads a specific blockchain and answers "what are this address's
transfers / balance" over HRPC.

| Service | Chain(s) it covers |
|---|---|
| **wdk-indexer-wrk-evm** | Ethereum, Arbitrum, Polygon, Avalanche, Sepolia, Plasma, plus ERC-20 tokens (e.g. USDT). |
| **wdk-indexer-wrk-btc** | Bitcoin. Balance via bitcoind `scantxoutset`. |
| **wdk-indexer-wrk-solana** | Solana and SPL tokens. |
| **wdk-indexer-wrk-ton** | TON. |
| **wdk-indexer-wrk-tron** | Tron. |
| **wdk-indexer-wrk-spark** | Spark (Bitcoin Lightning infrastructure). |

### Bridge and product workers

| Service | What it does |
|---|---|
| **wdk-indexer-processor-wrk** | Stream bridge. Consumes per-chain transaction streams from the indexers and re-emits them onto per-shard streams the data-shard can consume. |
| **rumble-promo-wrk** | Rumble promo-code worker (campaign claims, claim status). |

### SDK / wallet libraries (not part of the running indexer mesh)

These ship inside client apps, not the server mesh: `wdk` (multi-wallet manager), `wdk-wallet`
(base BIP-32 wallet) and its per-chain variants (`wdk-wallet-btc/-evm/-solana/-spark/-ton/-tron`),
`wdk-react-native-core`, `rumble-wallet-lib-passkey`, and protocol adapters
`wdk-protocol-fiat-moonpay` and `wdk-protocol-swap-velora-evm`. They matter for "how the mobile
app builds and signs," but they are SDK-side and outside the backend request path.

---

## 4. How the services relate and communicate

### Three main request paths

**A. Wallet / user (authenticated):**
```
user → wdk-app-node (HTTP) → wdk-ork-wrk (routing) → wdk-data-shard-wrk (storage/logic)
     → wdk-indexer-wrk-{chain} (per-chain reads) → chain RPC / Mongo
```

**B. Rumble notifications:**
```
rumble-server → rumble-app-node (HTTP /api/v{1,2}/notifications)
              → rumble-ork-wrk (HRPC sendNotification[V2])
              → rumble-data-shard-wrk (HRPC addTxWebhook → Mongo webhook queue → cron every 10s)
              → wdk-indexer-wrk-{chain} (HRPC getTransactionFromChain) → chain RPC
```

**C. Public indexer (API-key):**
```
client → wdk-indexer-app-node (HTTP) → chain indexer topic RPC ({blockchain}:{token})
```

Important nuance for meetings: internal services can call each other **directly over HRPC and
skip the HTTP schema**. For example `rumble-app-node` calls the ork's `sendNotification`
directly in one path, so the Fastify validation does not run there. HTTP-layer validation is
necessary but not sufficient by itself.

### Transfer ingestion has two paths that both run (a known design ambiguity)

- **Path A — polling:** the shard's `syncWalletTransfers` job periodically pulls transfers from
  the indexers.
- **Path B — Redis streams:** indexers push new transactions onto a Redis stream
  (`@wdk/transactions:{chain}:{token}`), the processor consumes and re-emits onto
  `@wdk/transactions:shard-{shardGroup}`, and the data-shard consumes that with a consumer group.

No single path is declared canonical, so "why is this transfer stale" can be hard to attribute.
This is a recurring talking point (see section 8).

---

## 5. Communication protocols

| Protocol | Where it is used | Notes |
|---|---|---|
| **HTTP (Fastify)** | Only on the three `*-app-node` services | The public boundary. Request-shape validation lives in Fastify `schema.body` here. Swagger docs on the indexer app-node. |
| **HRPC over Hyperswarm** | All internal service-to-service calls (app-node → ork → shard → indexer, and lateral calls) | P2P encrypted RPC. Discovery via shared topics; gated by shared capability + crypto key. Topic names you will see: `@wdk/data-shard`, `@wdk/ork`, and `{blockchain}:{token}` for per-chain indexers. An HRPC handler must always return something serializable; a bare `return` makes the caller see a 500. |
| **Redis streams** | Transfer ingestion Path B and the indexer→processor→shard bridge | Payload is CSV `raw`, not JSON. Message type `new_transaction`. |
| **Chain RPC** | Indexers → actual blockchain nodes | Each indexer talks to its chain's node/RPC (e.g. bitcoind `scantxoutset` for BTC balance). A circuit breaker in the base lib guards these calls. |

Authentication summary:
- **External:** wallet/user APIs are authenticated per user; the public indexer API uses API keys.
- **Internal:** there is **no per-service identity or mTLS**. Trust is the shared Hyperswarm
  secret plus the Proc/API key handshake. The ork has no auth at all. Keep the mesh internal.

---

## 6. Databases

| Store | Used by | Role |
|---|---|---|
| **MongoDB (replica set, rs0)** | data-shards, chain indexers, ork lookup, Rumble webhook queue | Primary canonical/document storage in production-style deployments. Requires a 3-node replica set; a single-node Mongo does not work. |
| **HyperDB** | chain indexers and shards (configurable) | Append-only embedded P2P database. Schemas are **append-only**: never insert a field in the middle of an existing schema, only append at the end, or you corrupt the DB. |
| **Autobase** | ork and processor lookup (configurable) | Append-only multi-writer log used for the address/ownership lookup. |
| **Redis** | transfer streams + caching | Stream transport for ingestion Path B and the processor bridge. |

Two configuration knobs to know:
- Chain indexers and shards: `dbEngine: hyperdb | mongodb`.
- Ork and processor lookup: `lookupEngine: autobase | mongodb`.

In practice Rumble deployments lean Mongo, while upstream WDK examples still lean HyperDB. So
"which DB" depends on the service and the deployment, not a single global answer.

---

## 7. The APIs (base URL + plain-English meaning)

There are **three HTTP services**, each with its own base host. Paths below are relative to that
host. (Hosts vary per environment: local is typically `http://localhost:3000`; staging/prod sit
behind Caddy on `:443`.)

### 7.1 wdk-app-node — authenticated wallet/user API

Base: the WDK wallet host, e.g. `https://<wdk-app-node-host>`

| Method + path | What it does |
|---|---|
| `GET /api/v1/health` | Liveness check. |
| `GET /api/v1/ready` | Readiness check (dependencies up). |
| `GET /api/v1/chains` | Lists supported chains. |
| `POST /api/v1/connect` | Connects/authenticates a user session. |
| `POST /api/v1/entropy` / `GET /api/v1/entropy` | Stores / retrieves the user's encrypted wallet entropy backup. |
| `POST /api/v1/seed` / `GET /api/v1/seed` | Stores / retrieves the user's encrypted seed backup. |
| `GET /api/v1/balance` | Aggregate balance for the connected user. |
| `GET /api/v1/balance/trend` | Balance over time (the chart). Known to be flaky for some users; see section 8. |
| `GET /api/v1/balance/:token` | Balance for one token. |
| `GET /api/v1/wallets` / `POST /api/v1/wallets` | List the user's wallets / create a wallet. |
| `GET /api/v1/wallets/:id` / `PATCH /api/v1/wallets/:id` | Get / update a single wallet. |
| `GET /api/v1/wallets/:id/balance` / `.../balance/trend` | Balance and balance-trend for one wallet. |
| `GET /api/v1/wallets/:walletId/balance/:token` | One wallet's balance for one token. |
| `GET /api/v1/wallets/from-address/:address` | Reverse lookup: which wallet owns an address. |
| `GET /api/v1/wallets/balances` | Balances across the user's wallets in one call. |
| `GET /api/v1/users/:userId/balance` | A user's aggregate balance. |
| `GET /api/v1/wallets/:walletId/token-transfers` | Transfer history for a wallet (v1, flat rows). |
| `GET /api/v1/users/:userId/token-transfers` | Transfer history for a user (v1, flat rows). |
| `GET /api/v1/users/:userId/spark/bitcoin/token-transfers` | Spark/Bitcoin-specific transfer history for a user. |
| `GET /api/v2/wallets/:walletId/token-transfers` | Transfer history for a wallet (v2 shape). |
| `GET /api/v2/users/:userId/token-transfers` | Transfer history for a user (v2 shape). |

### 7.2 rumble-app-node — Rumble product API (extends wdk-app-node)

Base: the Rumble host, e.g. `https://<rumble-app-node-host>`. It also serves all of the
wdk-app-node routes above, plus:

| Method + path | What it does |
|---|---|
| `GET /api/v1/users/:userId/tip-jar` | Read a user's tip-jar state. |
| `GET /api/v1/channels/:channelId/tip-jar` / `PATCH` same | Read / toggle a channel's tip jar. |
| `POST /api/v1/signature/:provider` | Produce a signature for a third-party provider flow. |
| `POST/GET/DELETE /api/v1/device-ids` (+ `/remove`) | Register, list, and remove a user's push device IDs. |
| `POST /api/v1/notifications` (v1) and `POST /api/v2/notifications` (v2) | Trigger a push notification. v2 is the newer schema; raw float amounts here are a known precision hazard (see section 8). |
| `GET /.well-known/lnurlp/:sparkIdentityPubkey`, `GET /api/lnurl/payreq/:uuid` | LNURL-pay endpoints for Lightning/Spark receive flows. |
| `GET /.well-known/apple-app-site-association`, `GET /.well-known/assetlinks.json` | Mobile deep-link association files (iOS / Android). |
| `POST /passkey/registration/start|finish|start-with-token`, `POST /passkey/authentication/start|finish|start/with-email` | Passkey (WebAuthn) registration and login flows. |
| `POST /moonpay/webhook` | Inbound MoonPay webhook (transaction status callbacks). |
| `POST /api/auth/refresh-token`, `POST /api/auth/authorization-code` | OAuth-style token refresh / code exchange. |
| `POST /api/rpc-key/generate`, `GET /api/rpc-key/validate` | Issue and validate an RPC key for a client. |
| `POST /api/v1/promo/:campaignId/claim`, `GET /api/v1/promo/:campaignId/claim/status` | Claim a promo campaign and check claim status (backed by rumble-promo-wrk). |
| `GET /api/v1/moonpay/currencies`, `.../currencies/:cryptoCurrency/buy_quote`, `.../sell_quote`, `.../transaction/:transactionId` | MoonPay supported currencies, buy/sell quotes, and transaction lookup. |
| `GET /api/v1/swaps/getPaths`, `.../getAction`, `.../getStatus`, `POST /api/v1/swaps/registerTxs` | Swap routing: find paths, get the action to sign, register signed txs, poll status. |
| `GET /api/v1/admin/wallets`, `GET /api/v1/admin/token-transfers` | Admin/back-office views of wallets and transfers (protected). |
| `POST/GET/DELETE /api/v1/user-data` | Store, read, delete arbitrary per-user data blobs. |
| `POST /api/v1/seed-phrases/connect/challenge`, `.../verify` | Challenge/verify flow to connect a seed phrase. |
| `POST /api/v1/logs` | Ingest client-side logs from the mobile app. |

### 7.3 wdk-indexer-app-node — public API-key indexer API

Base: the public indexer host, e.g. `https://<indexer-host>`. Swagger UI at `/docs`.

| Method + path | What it does |
|---|---|
| `GET /register` | Self-serve registration entry point for getting access. |
| `POST /api/v1/request-api-key` | Request an API key (generated plaintext, hashed at rest, emailed to the owner). |
| `GET /api/v1/health` | Liveness check. |
| `GET /api/v1/chains` | Lists chains the public indexer will answer for. |
| `GET /api/v1/keys`, `POST /api/v1/keys`, `DELETE /api/v1/keys/:hashedKey` | Manage API keys (list, create, revoke). |
| `GET /api/v1/:blockchain/:token/:address/token-transfers` | Direct query: transfer history for one address on one chain/token. |
| `GET /api/v1/:blockchain/:token/:address/token-balances` | Direct query: balances for one address on one chain/token. |
| `POST /api/v1/batch/token-transfers` | Batch version: transfers for many addresses in one request. |
| `POST /api/v1/batch/token-balances` | Batch version: balances for many addresses in one request. |

Whitelisted chains the public indexer advertises: `ethereum, sepolia, plasma, avalanche,
arbitrum, polygon, tron, ton, solana, bitcoin, spark`. Note this list is broader than the set
of chain-worker repos actually checked into the workspace, so "advertised" and "running" can
differ.

---

## 8. Design conventions and meeting talking points

These are the things most likely to come up in an architecture or planning discussion.

**Layering and overlays.** WDK base repos (`wdk-*`) are generic; Rumble repos (`rumble-*`) are
overlays that add product features. The overlay relationships are: `rumble-app-node` extends
`wdk-app-node`; `rumble-ork-wrk` extends `wdk-ork-wrk`; `rumble-data-shard-wrk` extends
`wdk-data-shard-wrk`. **There is no automatic sync.** Any change to a base repo must be manually
mirrored into its Rumble overlay.

**Version-bump discipline.** A change to a shared lib or schema requires bumping the
`package.json` version, updating every dependent repo, reinstalling, and shipping a migration
for breaking changes. `wdk-indexer-wrk-base` changes ripple to every chain indexer.

**HyperDB is append-only.** Schema fields are only ever appended, never inserted in the middle.
This is a frequent source of bugs if ignored.

**Writes flow through a unit of work.** In the data-shard repos, repository write methods only
**stage** an operation; the actual flush happens in `commitWrites()` inside a transaction. Never
write to the store directly from a repo method. "Insert if absent" must stay insert-only (so a
redelivered message does not reset a COMPLETED row back to PENDING).

**Proc/API split and shared secrets.** Covered above, but worth repeating in any ops discussion:
the two most common "silent" failures are (1) Hyperswarm capability/crypto-key mismatch and
(2) an API worker started without its Proc's RPC key.

**Idempotency lives in two places.** On the HTTP path (Fastify schema) and on the internal HRPC
path. Because internal callers can bypass HTTP, idempotency cannot rely on the HTTP layer alone.

**No em dashes in external output.** A house style rule: anything posted to GitHub, Slack, commit
messages, or webhooks avoids em dashes.

### Known weak spots worth naming honestly

- **Dual ingestion ambiguity.** Polling and Redis-stream ingestion both run; neither is declared
  canonical, so freshness bugs need evidence across indexer, processor, shard, and app rather
  than blaming the indexer.
- **`/api/v1/balance/trend` can return empty for real users.** The `syncBalancesJob` has several
  interacting failure modes (skips a whole user's snapshot if any one token RPC fails, drops
  buffered batches on abort, `range=all` falling back to 1970). Empty trend data is often a sync
  bug, not an app bug.
- **Legacy transfer APIs are flat rows.** There is no shipped "transaction history v2" grouped
  pipeline in runtime code; the v2 endpoints exist but return wallet-transfer rows, not one
  logical transaction per on-chain action.
- **BTC history/balance is fragile.** Sender-side rows lack fee/change/input context,
  self-transfer dedupe is weak, and balance reads depend on bitcoind `scantxoutset` which can
  report busy. Spark deposit addresses can pollute BTC history (RW-1526).
- **Notification amounts.** Rumble notification schemas have accepted numeric `amount`, so raw
  IEEE-754 floats can reach users in templates (RW-1601). The safer contract is decimal strings
  plus defensive formatting.
- **Notification/idempotency state is memory-only** in places, so a restart loses it.
- **Solana `sync-tx` is intentionally disabled** at proc startup.
- **MoonPay `SWAP_COMPLETED` is unimplemented**; missing `externalCustomerId` warns and skips.
- **Security posture.** Public-indexer API keys are emailed in plaintext; Rumble Swagger docs
  auth has had unsafe fallback credentials when config is missing; service-to-service trust is
  shared-secret only. None of these are show-stoppers, but they are the honest list.

---

## 9. One-paragraph version (for the very start of a meeting)

WDK is Tether's open-source, self-custodial, multi-chain wallet backend; Rumble Wallet is a
consumer product built on it. The backend is a mesh of small Node.js workers. Only the three
`*-app-node` services expose HTTP (the authenticated wallet API, Rumble's extended product API,
and a public API-key indexer API); everything else talks internally over encrypted P2P RPC
(HRPC on Hyperswarm). A request flows app-node to ork (router) to data-shard (canonical storage)
to per-chain indexers, which read the actual blockchains. Storage is MongoDB, HyperDB, Autobase,
and Redis depending on the service and deployment. The main things that bite us are a dual
transfer-ingestion path that makes freshness hard to attribute, a flaky balance-trend sync job,
flat (not grouped) transfer history, and fragile BTC handling.
