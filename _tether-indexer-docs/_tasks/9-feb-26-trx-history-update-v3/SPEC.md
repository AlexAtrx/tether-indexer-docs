# Transaction History API v2 — Definitive Specification (v4 Update)

> **Status:** Approved for Phase 1 implementation
> **Last updated:** 2026-02-11
> **Previous version:** `_docs/_tasks/6-feb-26-trx-history-api-v2/SPEC.md` (2026-02-09)
> **Audience:** All team members (PO, PM, FE, BE)
> **What changed in v4:** **Architectural shift from query-time aggregation to write-time processing.** Based on lead dev feedback, grouping and chain-specific parsing now happen at ingestion time in `wdk-indexer-wrk-*`, not at read time in data-shard. A new `wdk_data_shard_wallet_transfers_processed` collection stores one document per logical transaction. The old `wallet_transfers_v2` collection is preserved unchanged for backward compatibility and debugging. Read endpoints are now simple collection queries. Extension via `super.method()` happens at processing time, not query time. Added Section 6A (Collection Schema for `wallet_transfers_processed`). Rewrote Sections 2, 3, 6, 10, 12, 13 to reflect the new architecture. Backfill via one-time migration script (Rumble only). All API contracts (Section 4) and response schemas (Section 5) remain unchanged.
> **What changed in v3:** Added Section 12 (Implementation Nuances from Codebase Audit), corrected BTC amount example in Section 7, expanded Section 6 with concrete grouping strategy, expanded Section 9 with newly discovered gaps. Added Section 13 (Rumble Enrichment Layer — Complete Specification). Expanded Sections 2, 3, 4, 5, 8, 10, 11 with Rumble enrichment details.

---

## Table of Contents

1. [Problem Statement](#1-problem-statement)
2. [Solution Overview](#2-solution-overview)
3. [Architecture](#3-architecture)
4. [API Contract](#4-api-contract)
5. [Response Schema](#5-response-schema)
6. [Write-Time Processing Logic](#6-write-time-processing-logic)
6A. [Collection Schema — `wallet_transfers_processed`](#6a-collection-schema--wallet_transfers_processed)
7. [Chain-Specific Behavior](#7-chain-specific-behavior)
8. [Phase 1 vs Phase 2 Scope](#8-phase-1-vs-phase-2-scope)
9. [Known Gaps](#9-known-gaps)
10. [Implementation Footprint](#10-implementation-footprint)
11. [Glossary](#11-glossary)
12. [Implementation Nuances from Codebase Audit](#12-implementation-nuances-from-codebase-audit)
13. [Rumble Enrichment Layer — Complete Specification](#13-rumble-enrichment-layer--complete-specification)
14. [Migration & Backfill](#14-migration--backfill)

---

## 1. Problem Statement

The current `token-transfers` endpoints return **flat, raw transfer records** — one record per on-chain output/event. This causes two user-facing problems:

| Chain | What the user did | What the app shows |
|---|---|---|
| **EVM** | Sent 100 USDT to a friend | 2 entries: one for the USDT transfer, one for the gas payment |
| **BTC** | Sent 0.5 BTC to a friend | 2 entries: one to the recipient (0.5 BTC), one change output back to the sender (0.3 BTC) |

The frontend currently has no reliable way to group these into a single logical transaction, and building custom grouping logic per chain in the FE is unscalable and fragile.

**Goal:** A backend API that returns **one logical transaction per user action**, with all chain-specific details already resolved, so the frontend renders a clean, consistent history across all chains.

---

## 2. Solution Overview

- **No new service or deployment.** Processing happens in existing indexer and data-shard workers.
- **One new collection** — `wdk_data_shard_wallet_transfers_processed` stores one document per logical transaction. The existing `wallet_transfers_v2` is preserved unchanged for backward compatibility and debugging.
- **No breaking changes.** Existing `/token-transfers` endpoints remain untouched.
- **Two new endpoints** that return pre-grouped, enriched transaction objects by querying the new collection.
- **Write-time architecture:** Chain-specific grouping and parsing happen at ingestion time in `wdk-indexer-wrk-*`, keeping blockchain logic in the indexers where it belongs. The data-shard layer stores and serves pre-processed data — no chain awareness needed at read time.
- **Modular design:** Core chain-level logic is reusable across apps (Tether Wallet, etc.). App-specific enrichment (Rumble tips, counterparty resolution) is a separate layer that extends the base processing class.

### Two-Layer Design Principle

This feature is built as **two separate, complementary layers**:

| | Layer 1: Core | Layer 2: Rumble Enrichment |
|---|---|---|
| **Where grouping happens** | `wdk-indexer-wrk-*` — at ingestion time | — (uses core output) |
| **Where processing happens** | `wdk-data-shard-wrk` — `processTransferGroup()` base method | `rumble-data-shard-wrk` — extends via `super.processTransferGroup()` + Rumble enrichment |
| **Where data is stored** | `wdk_data_shard_wallet_transfers_processed` — generic fields | Same collection — Rumble-specific fields added by extended processing |
| **Where data is served** | `wdk-app-node` — simple collection query | `rumble-app-node` — same query + Rumble-specific query params |
| **Domain knowledge** | Blockchain only — chains, tokens, UTXO model, EVM gas, addresses | Rumble-specific — users, channels, tips, rants, content |
| **Reusable by** | Tether Wallet, Rumble, any future app | Rumble only |
| **Phase** | Phase 1 (this implementation) | Phase 2 (separate task) |

The boundary is enforced at the **repository level**: `wdk-*` repos contain zero app-specific logic. Rumble-specific enrichment lives exclusively in `rumble-*` repos. See Section 3 for the extension mechanism and Section 13 for the full Rumble enrichment specification.

### User Experience by Login Method

The PO requirement states:

> *"Users who login with Rumble credentials should be able to retrieve their transactions with Rumble enriched data. Users who login with Seedphrase can have their transaction history from Core Transaction History without Rumble enriched data if we can't deliver it."*

This is satisfied by the two-layer architecture through **deployment-level routing** — not application logic:

| Login method | Which deployment handles the user | Write path (ingestion) | Read path (query) | What the user sees |
|---|---|---|---|---|
| **Rumble credentials** | Rumble deployment | `rumble-data-shard-wrk` processes events → calls `super.processTransferGroup()` (core) + `enrichTransferGroup()` (Rumble) | `rumble-app-node` serves request → queries `wallet_transfers_processed` (Rumble fields populated) | Full enriched history: counterparty names, tip/rant labels, channel identity, app context |
| **Seedphrase only** | WDK deployment | `wdk-data-shard-wrk` processes events → calls `processTransferGroup()` (core only) | `wdk-app-node` serves request → queries `wallet_transfers_processed` (Rumble fields null) | Core history: grouped transactions, direction, amounts, chain metadata — no Rumble identity or tip data |

**How this works:**

- **Write time:** A user's wallets are managed by the deployment they registered through. Rumble users' wallets exist on the Rumble deployment, so their transfer events are processed by `rumble-data-shard-wrk` (extended class → Rumble fields populated). Seedphrase-only users' wallets exist on the WDK deployment, so their events are processed by `wdk-data-shard-wrk` (base class → Rumble fields null).
- **Read time:** The FE routes API calls through the app-node matching the user's login context. Rumble-credentialed users hit `rumble-app-node` (which exposes `activitySubtype` filter and returns enriched data). Seedphrase users hit `wdk-app-node` (core-only data, no Rumble query params).
- **No branching logic needed:** The API response shape is identical for both (Section 5). The only difference is whether Rumble addon fields are populated or null. The FE renders what's available — if `appTip` is null, it doesn't show tip info. No conditional logic per login method.

**Edge case — seedphrase user who also has Rumble credentials:** If a user has both, the deployment they log into determines the experience. If they log in via Rumble, they get enriched data. If they log in via seedphrase on the WDK deployment, they get core-only data. This matches the PO requirement: Rumble credentials → enriched, seedphrase → core.

### What the FE gets from day one (Phase 1)

- Grouped transactions (BTC change + recipient = 1 entry; EVM transfer + gas = 1 entry)
- Direction: `in` / `out` / `self`
- Type: `sent` / `received`
- Correct amount (excluding change outputs)
- Network metadata (rail, chainId, networkName)
- Token metadata (symbol, decimals)
- Sponsored/gasless flag
- Explorer URL
- Fiat amount (already stored on transfer records)
- Underlying raw transfers with `isChange` flag
- Null placeholders for Phase 2 fields — FE can build layouts now and fill them in later

---

## 3. Architecture

### Design principle: chain logic stays in indexers

A core WDK design principle is that **blockchain-specific logic lives only in `wdk-indexer-wrk-*`** — the data-shard layer is chain-agnostic. This architecture preserves that principle by performing all chain-aware grouping and parsing at ingestion time (in the indexers), not at read time (in data-shard).

### Write path (ingestion) — where grouping happens

```
Blockchain
  → wdk-indexer-wrk-*         (indexes blocks, groups transfers by txHash)
    → publishes GROUPED transfer event (all transfers for one tx in a single event)
  → wdk-data-shard-wrk        (receives grouped event, runs processTransferGroup())
    → stores result in wdk_data_shard_wallet_transfers_processed  (1 doc per logical tx)
    → ALSO stores raw transfers in wdk_data_shard_wallet_transfers_v2 (unchanged)
```

**Indexer changes:** Each `wdk-indexer-wrk-*` (BTC, EVM, TRON, TON, SOL, SPARK) already indexes all transfers for a transaction. The change is to **publish them as a single grouped event** instead of individual transfer events. For event-driven indexers, this is natural (all transfers arrive together). For polling-based indexers, a truncate-to-previous-tx strategy ensures atomicity — polling re-fetches the last tx to guarantee all its transfers are included in the same batch.

### Read path (query) — simple collection query

```
FE/Client
  → wdk-app-node              (HTTP route + auth)
  → wdk-ork-wrk               (RPC gateway)
  → wdk-data-shard-wrk        (queries wdk_data_shard_wallet_transfers_processed)
  → MongoDB                   (pre-processed data — no grouping or chain logic needed)
```

The read endpoints are trivial: query the `wallet_transfers_processed` collection with filters (blockchain, token, type, time range), sort, skip, limit. No buffering, no chain-aware parsing, no streaming. Pagination counts documents directly.

### Module design

```
wdk-indexer-wrk-*/
  workers/
    lib/
      transfer.grouper.js              ← NEW: groups raw transfers by txHash before publishing

wdk-data-shard-wrk/
  workers/
    proc.shard.data.wrk.js             ← MODIFY: receive grouped events, call processTransferGroup()
    api.shard.data.wrk.js              ← ADD: getWalletTransferHistory, getUserTransferHistory
                                          (simple collection queries)
    lib/
      transfer.processor.js            ← NEW: processTransferGroup() — generic parsing
                                          (direction, amount, change detection, metadata)
                                          Extensible via class inheritance (super.method pattern)
      db/mongodb/repositories/
        wallet.transfers.processed.js  ← NEW: repository for the new collection

wdk-app-node/
  workers/
    lib/
      server.js                        ← ADD: 2 route definitions
      services/ork.js                  ← ADD: 2 RPC proxy methods
      middlewares/response.validator.js ← ADD: response schemas for new endpoints
```

### Extension mechanism — how Rumble hooks into the core

The existing codebase already establishes the extension pattern. `rumble-data-shard-wrk` extends WDK via class inheritance:

```javascript
// rumble-data-shard-wrk/workers/proc.shard.data.wrk.js
const WrkBase = require('@tetherto/wdk-data-shard-wrk/workers/proc.shard.data.wrk')

class WrkProcShardData extends WrkBase {
  async processTransferGroup (groupedTransfers, walletAddresses, wallet) {
    // 1. Call the core processing (generic parsing — direction, amount, metadata)
    const processed = await super.processTransferGroup(groupedTransfers, walletAddresses, wallet)

    // 2. Rumble-specific enrichment (counterparty, tips, app context)
    const enriched = await this.enrichTransferGroup(processed)

    return enriched
  }
}
```

This is the same `extends WrkBase` + `super.method()` pattern already used for `storeTxWebhook()`, `_walletTransferDetected()`, and other methods in `rumble-data-shard-wrk/workers/proc.shard.data.wrk.js`.

### Write path with Rumble enrichment (Phase 2)

```
Blockchain
  → wdk-indexer-wrk-*              (groups transfers by txHash)
    → publishes GROUPED transfer event
  → rumble-data-shard-wrk          (extends WDK proc worker)
    → super.processTransferGroup()  (core generic parsing)
    → enrichTransferGroup()         (Rumble: counterparty, tips, app context)
    → stores enriched result in wdk_data_shard_wallet_transfers_processed
```

**Key insight:** Enrichment happens at **write time**, not read time. By the time the FE queries the data, all fields (including Rumble-specific ones) are already populated in the stored document. The read path is identical for core and Rumble — just a collection query.

### Rumble read path (Phase 2)

```
Rumble FE
  → rumble-app-node       (Rumble routes + auth — includes activitySubtype query param)
  → wdk-ork-wrk           (RPC gateway)
  → rumble-data-shard-wrk (queries wallet_transfers_processed — data already enriched)
  → MongoDB               (pre-enriched documents)
```

### Rumble module design (Phase 2 additions)

```
rumble-data-shard-wrk/
  workers/
    proc.shard.data.wrk.js              ← OVERRIDE: processTransferGroup() — calls super + enrichment
    api.shard.data.wrk.js               ← ADD: getWalletTransferHistory, getUserTransferHistory
                                            (same simple query, passes activitySubtype filter)
    lib/
      transfer.enricher.js              ← NEW: enrichTransferGroup() — counterparty, tips, app context

rumble-app-node/
  workers/
    lib/
      server.js                          ← ADD: 2 route definitions (same paths, extra query params)
      services/ork.js                    ← ADD: 2 RPC proxy methods (passes activitySubtype)
```

### Backward compatibility

- **Old collection preserved:** `wdk_data_shard_wallet_transfers_v2` continues to be written to as before. Existing `/token-transfers` endpoints read from it unchanged.
- **Old endpoints untouched:** `GET /api/v1/wallets/:walletId/token-transfers` and `GET /api/v1/users/:userId/token-transfers` remain exactly as they are.
- **Dual-write:** On each grouped transfer event, the data-shard writes to BOTH the old collection (individual transfer records, same as today) and the new collection (one processed document per logical tx).

---

## 4. API Contract

> **Routing by login method:** These endpoints are served by both `wdk-app-node` (seedphrase users) and `rumble-app-node` (Rumble-credentialed users) at the same paths. The response shape is identical — the only difference is whether Rumble addon fields are populated or null. See Section 2 "User Experience by Login Method" for details.

### 4.1 Get Wallet Transfer History

Returns grouped transfer history for a single wallet.

```
GET /api/v1/wallets/:walletId/transfer-history
```

**Auth:** Bearer token or `x-secret-token` header (same as existing endpoints)

**Path Parameters:**

| Param | Type | Description |
|---|---|---|
| `walletId` | string | The wallet ID |

**Query Parameters:**

| Param | Type | Required | Default | Description |
|---|---|---|---|---|
| `userId` | string | no* | — | Required when using secret-token auth |
| `blockchain` | string | no | — | Chain filter: `ethereum`, `bitcoin`, `arbitrum`, `polygon`, `tron`, `ton`, `solana`, `spark`, `plasma`, `sepolia` |
| `token` | string | no | — | Token filter: `usdt`, `btc`, `xaut`, `usdt0`, `xaut0` |
| `type` | string | no | — | Filter: `sent`, `received`, `swap_out`, `swap_in` |
| `from` | integer | no | 0 | Start timestamp (epoch ms) |
| `to` | integer | no | now | End timestamp (epoch ms) |
| `limit` | integer | no | 10 | Max results (1-100) |
| `skip` | integer | no | 0 | Offset pagination |
| `sort` | string | no | `desc` | `asc` or `desc` |

**Response:** `200 OK`

```jsonc
{
  "transfers": [
    { /* TransferHistoryObject — see Section 5 */ }
  ]
}
```

**Errors:**

| Status | Code | When |
|---|---|---|
| 404 | `ERR_WALLET_NOT_FOUND` | Wallet doesn't exist or doesn't belong to the user |

---

### 4.2 Get User Transfer History

Returns grouped transfer history across **all wallets** belonging to a user, merged and sorted.

```
GET /api/v1/users/:userId/transfer-history
```

**Auth:** Bearer token or `x-secret-token` header

**Path Parameters:**

| Param | Type | Description |
|---|---|---|
| `userId` | string | The user ID |

**Query Parameters:**

| Param | Type | Required | Default | Description |
|---|---|---|---|---|
| `blockchain` | string | no | — | Chain filter |
| `token` | string | no | — | Token filter |
| `type` | string | no | — | Type filter: `sent`, `received`, `swap_out`, `swap_in` |
| `from` | integer | no | 0 | Start timestamp (epoch ms) |
| `to` | integer | no | now | End timestamp (epoch ms) |
| `limit` | integer | no | 10 | Max results (1-100) |
| `skip` | integer | no | 0 | Offset pagination |
| `sort` | string | no | `desc` | `asc` or `desc` |
| `walletTypes` | string[] | no | — | Filter by wallet type: `user`, `channel`, `unrelated` |

**Response:** `200 OK`

```jsonc
{
  "transfers": [
    { /* TransferHistoryObject — see Section 5 */ }
  ]
}
```

---

### 4.3 Rumble-Specific Endpoints (Phase 2)

The Rumble app serves the **same endpoints** at the same paths but through `rumble-app-node` instead of `wdk-app-node`. The Rumble variants **inherit all core query parameters** from Sections 4.1 and 4.2, and add the following Rumble-specific parameters:

**Additional query parameters (Rumble only):**

| Param | Type | Required | Default | Description |
|---|---|---|---|---|
| `activitySubtype` | string | no | — | Filter by Rumble activity: `transfer`, `tip`, `rant`. When set, only transactions matching this activity type are returned. Requires the enrichment layer to classify transactions (Phase 2). |

**How it works:**

- When `activitySubtype` is **not provided**, the Rumble endpoint behaves identically to the core endpoint but with enriched response fields populated (counterparty identity, tip metadata, etc.).
- When `activitySubtype=tip`, only transactions identified as tips are returned.
- When `activitySubtype=rant`, only transactions identified as rants (tips with a message/payload) are returned.
- When `activitySubtype=transfer`, only regular transfers (not tips/rants) are returned.

**Rumble response differences:**

The response schema is identical to the core (Section 5), but the Rumble addon fields (`appActivitySubtype`, `appTip`, `appContext`, `fromMeta.appResolved`, `toMeta.appResolved`) are **populated** instead of null. See Section 13 for the full field schemas.

**Phase 1 behavior:** In Phase 1, Rumble mirrors the WDK endpoints exactly (same routes, same core logic, addon fields are null). The `activitySubtype` query parameter is not available until Phase 2.

---

### 4.4 Existing Endpoints (Unchanged)

These continue to work exactly as before. **No breaking changes.**

| Endpoint | Status |
|---|---|
| `GET /api/v1/wallets/:walletId/token-transfers` | Unchanged — returns flat raw transfers |
| `GET /api/v1/users/:userId/token-transfers` | Unchanged — returns flat raw transfers |
| `GET /api/v1/chains` | Unchanged — returns supported blockchains/tokens |

---

## 5. Response Schema

### TransferHistoryObject

> **Note on stored vs. response shape:** This section defines the **API response** shape — what the FE receives. The underlying stored document in `wallet_transfers_processed` (Section 6A) has a slightly different shape: `fromAppResolved`/`toAppResolved` are top-level fields (not nested in `fromMeta`/`toMeta`), and `sponsored` is a top-level boolean (not wrapped in a `fees` object). The read endpoint performs a lightweight mapping. See Section 6A "Response mapping" for details.

Every item in the `transfers` array has this shape. Field naming follows these rules:
- Fields that exist in the current `/token-transfers` response **keep the exact same name and format**.
- New fields are clearly marked as **NEW**.

```jsonc
{
  // ─── IDENTITY ───
  "transactionHash": "0xabc123...",       // same as existing

  // ─── TIMING ───
  "ts": 1707222200000,                    // same as existing — epoch ms
  "updatedAt": 1707222200000,             // NEW — Phase 1: always equals ts (all txs are confirmed)
                                           //        Phase 2: may differ when a pending tx is later confirmed

  // ─── CHAIN / NETWORK ───
  "blockchain": "ethereum",               // same as existing
  "rail": "EVM",                          // NEW — "EVM" | "BTC" | "SPARK" | "TRON" | "TON" | "SOL"
  "chainId": 1,                           // NEW — EVM only; null for non-EVM
  "networkName": "Ethereum",              // NEW — human-readable

  // ─── ASSET ───
  "token": "usdt",                        // same as existing
  "symbol": "USDT",                       // NEW — display symbol (uppercase)
  "decimals": 6,                          // NEW — from static config

  // ─── CLASSIFICATION ───
  "type": "sent",                         // same name as existing
                                           // values: "sent" | "received" | "swap_out" | "swap_in"
  "direction": "out",                     // NEW — "in" | "out" | "self"
  "status": "confirmed",                  // NEW — Phase 1: always "confirmed"
                                           //        Phase 2: "pending" | "submitted" | "confirmed" | "failed"

  // ─── AMOUNT ───
  "amount": "1000000",                    // same as existing — string, PRESERVES STORED FORMAT
                                           //   EVM ERC20: smallest unit (e.g. "1000000" = 1 USDT)
                                           //   BTC: BTC denomination (e.g. "0.5" = 0.5 BTC)
                                           //   See Section 12, Nuance 2 for cross-chain format details
                                           // For OUT: amount sent to external recipient (excluding change)
                                           // For IN: amount received by wallet
  "fiatAmount": "100.50",                 // same as existing — may be null
  "fiatCcy": "usd",                       // same as existing — may be null

  // ─── PARTICIPANTS ───
  "from": "0xabc...",                     // same as existing — primary sender address
  "to": "0xdef...",                       // same as existing — primary recipient address
  "fromMeta": {                           // NEW — enrichment on top of flat `from`
    "addressType": "EVM_ADDRESS",         //   "EVM_ADDRESS" | "BTC_ADDRESS" | "TRON_ADDRESS" |
                                           //   "TON_ADDRESS" | "SOL_ADDRESS" | "SPARK_ACCOUNT" | "UNKNOWN"
    "isSelf": false,                      //   true when this address belongs to the queried wallet
    "appResolved": null                   //   Phase 1: null
                                           //   Phase 2: {
                                           //     "displayName": "string"  — Rumble username or channel name
                                           //     "entityType": "user" | "channel" | "channel_tipjar" | "unknown"
                                           //     "avatarUrl": "string"   — URL to profile/channel avatar
                                           //   }
                                           //   See Section 13 for entityType definitions
  },
  "toMeta": {                             // NEW — same shape as fromMeta
    "addressType": "EVM_ADDRESS",
    "isSelf": false,
    "appResolved": null                   //   Same schema as fromMeta.appResolved
                                           //   Example (tip to channel):
                                           //     { "displayName": "TechChannel", "entityType": "channel_tipjar", "avatarUrl": "https://..." }
  },

  // ─── FEES ───
  "fees": {                               // NEW
    "sponsored": true,                    //   true when label === "paymasterTransaction"
                                           //   NOTE: label field is EVM-only. For BTC/TRON/TON/SOL/SPARK,
                                           //   sponsored is always false (see Section 12, Nuance 3)
    "networkFee": null                    //   Phase 1: null
                                           //   Phase 2: { "value", "token", "symbol", "decimals" }
  },

  // ─── LINKS ───
  "explorerUrl": "https://etherscan.io/tx/0x...",  // NEW — null if no explorer for this chain

  // ─── LABEL ───
  "label": "transaction",                // same as existing — "transaction" | "paymasterTransaction"
                                           // NOTE: may be undefined/null for non-EVM chains
                                           // (see Section 12, Nuance 3)

  // ─── WALLET ─── (only in user-level endpoint)
  "walletId": "052d6e5d-...",            // same as existing — only present in /users/:userId/transfer-history

  // ─── APP-LEVEL (Rumble Addons) ─── all null in Phase 1; populated by Rumble enricher in Phase 2
  //     Full schemas defined in Section 13
  "appActivitySubtype": null,             // NEW — Phase 1: null
                                           //        Phase 2: "transfer" | "tip" | "rant"
                                           //        "transfer" = regular send/receive
                                           //        "tip"      = tip without message (TOKEN_TRANSFER_TIP)
                                           //        "rant"     = tip with message/payload (TOKEN_TRANSFER_RANT)
  "appContext": null,                     // NEW — Phase 1: null
                                           //        Phase 2: {
                                           //          "appFlow": "tip" | "rant" | "transfer" | "withdrawal",
                                           //          "referenceId": "string"  — webhook/internal reference ID
                                           //        }
  "appTip": null,                        // NEW — Phase 1: null
                                           //        Phase 2: {
                                           //          "tipId": "string",
                                           //          "tipType": "tip" | "rant",
                                           //          "tipDirection": "sent" | "received",
                                           //          "counterparty": { "displayName", "entityType", "avatarUrl" },
                                           //          "appContent": { "contentId", "contentType", "message" }
                                           //        }
                                           //        See Section 13 for full schema

  // ─── UNDERLYING TRANSFERS ───
  "underlyingTransfers": [                // NEW — raw indexed records grouped under this logical tx
    {
      "transactionHash": "0xabc123...",
      "transferIndex": 0,
      "transactionIndex": 0,
      "logIndex": 0,
      "blockNumber": 19000000,
      "from": "0xabc...",
      "to": "0xdef...",
      "token": "usdt",
      "amount": "1000000",
      "ts": 1707222200000,
      "label": "transaction",
      "isChange": false                   // NEW — true if this output goes back to the wallet (BTC change)
    }
  ]
}
```

### Field Alignment Reference

| Existing `/token-transfers` field | This API | Notes |
|---|---|---|
| `transactionHash` | `transactionHash` | Same |
| `blockchain` | `blockchain` | Same |
| `blockNumber` | in `underlyingTransfers[]` | Moved to underlying; not needed at logical level |
| `transferIndex` | in `underlyingTransfers[]` | Moved to underlying |
| `transactionIndex` | in `underlyingTransfers[]` | Moved to underlying |
| `logIndex` | in `underlyingTransfers[]` | Moved to underlying |
| `from` | `from` | Same — promoted to primary sender |
| `to` | `to` | Same — promoted to primary recipient |
| `token` | `token` | Same |
| `amount` | `amount` | Same format; value is the **effective** amount (excluding change) |
| `ts` | `ts` | Same |
| `type` | `type` | Same name; extended with `swap_out` / `swap_in` |
| `label` | `label` | Same |
| `fiatAmount` | `fiatAmount` | Same |
| `fiatCcy` | `fiatCcy` | Same |
| `walletId` | `walletId` | Same — only in user-level endpoint |
| — | `updatedAt` | **New** |
| — | `rail`, `chainId`, `networkName` | **New** — network metadata |
| — | `symbol`, `decimals` | **New** — token metadata |
| — | `direction` | **New** — in/out/self |
| — | `status` | **New** — always `confirmed` in Phase 1 |
| — | `fromMeta`, `toMeta` | **New** — participant enrichment |
| — | `fees` | **New** — fee info |
| — | `explorerUrl` | **New** — block explorer link |
| — | `appActivitySubtype`, `appContext`, `appTip` | **New** — Rumble addon fields (null in Phase 1) |
| — | `underlyingTransfers` | **New** — grouped raw transfers |

---

## 6. Write-Time Processing Logic

This is the core of the feature. Unlike the previous approach (v3) which grouped at read time, **all grouping and parsing now happens at write time** — when the indexer publishes transfer events.

### Overview

```
wdk-indexer-wrk-*
  │
  │  Groups all transfers for one txHash into a single event
  │
  ▼
wdk-data-shard-wrk (proc worker)
  │
  │  Receives grouped event
  │  Calls processTransferGroup(transfers, walletAddresses, wallet)
  │  Stores result in wallet_transfers_processed
  │  ALSO stores raw transfers in wallet_transfers_v2 (unchanged)
  │
  ▼
MongoDB: wdk_data_shard_wallet_transfers_processed  (1 doc per logical tx)
MongoDB: wdk_data_shard_wallet_transfers_v2          (unchanged — raw transfers)
```

### Step 1: Indexer groups transfers by txHash

Each `wdk-indexer-wrk-*` already processes all transfers for a transaction. The change is to **emit them as a single grouped event** instead of individual events.

**For event-driven indexers:** All transfers for a tx arrive together naturally — no change needed in grouping logic, only in how the event is published.

**For polling-based indexers:** Use a truncate-to-previous-tx strategy — when starting a new polling cycle, re-fetch the last transaction from the previous cycle to ensure all its transfers are included. This guarantees atomicity: all transfers for a given txHash are always in the same batch.

### Step 2: Data-shard processes the grouped event

The data-shard proc worker receives the grouped event and calls `processTransferGroup()` — a method in `transfer.processor.js` that computes all derived fields:

| Field | Logic |
|---|---|
| **direction** | If any transfer has `from` in wallet addresses → `out`. If any has `to` in wallet addresses (and `from` is external) → `in`. If both `from` and `to` are wallet addresses → `self`. |
| **type** | `out` → `sent`, `in` → `received`, `self` → `sent`. (Extended to `swap_out`/`swap_in` when swap partner addresses are configured.) |
| **isChange** | For each underlying transfer: `true` if direction is `out` AND `to` is one of the wallet's own addresses. |
| **from / to** | For `out`: `from` = wallet address, `to` = the non-change recipient. For `in`: `from` = external sender, `to` = wallet address. |
| **amount** | For `out`: sum of non-change output amounts. For `in`: sum of amounts where `to` = wallet address. **Important:** Amount summing must handle the stored format correctly — BTC amounts are in BTC (e.g., `"0.5"`), while EVM ERC20 amounts are in smallest unit (e.g., `"1000000"`). Sum as floating-point for BTC; sum as BigInt for EVM. See Section 12, Nuance 2. |
| **sponsored** | `true` if any transfer in the group has `label === 'paymasterTransaction'`. Note: `label` is only set by the EVM indexer. For non-EVM chains, `label` may be `undefined` — treat as `false`. See Section 12, Nuance 3. |
| **fiatAmount** | Carried from the primary transfer (non-change for out, wallet-received for in). |
| **explorerUrl** | Built from `blockchain` + `transactionHash` via static explorer URL map. |
| **rail, chainId, networkName** | From static config (see Static Configuration Reference). |
| **symbol, decimals** | From static token config (see Static Configuration Reference). |

**Sponsored detection:** Since processing happens at write time with ALL transfers for the txHash available (no token filter applied), the `sponsored` flag is always correctly computed. The token-filter issue from v3 (Section 7 Option C) is eliminated — the indexer groups all transfers regardless of token, processing sees the full picture, and token filtering only applies at read time.

### Step 3: Store the processed document

The result of `processTransferGroup()` is stored as a single document in `wdk_data_shard_wallet_transfers_processed`. See Section 6A for the full collection schema.

**Dual-write:** The raw individual transfers are ALSO stored in `wallet_transfers_v2` as before, for backward compatibility and debugging.

### Step 4: Read endpoints query the new collection

The v2 read endpoints (`getWalletTransferHistory`, `getUserTransferHistory`) are simple MongoDB queries:

```javascript
// Pseudocode — getWalletTransferHistory
async getWalletTransferHistory (req) {
  const { walletId, blockchain, token, type, from, to, limit, skip, sort } = req

  const query = { walletId }
  if (blockchain) query.blockchain = blockchain
  if (token) query.token = token
  if (type) query.type = type
  if (from || to) query.ts = {}
  if (from) query.ts.$gte = from
  if (to) query.ts.$lte = to

  const docs = await this.db.walletTransfersProcessedRepository
    .find(query)
    .sort({ ts: sort === 'asc' ? 1 : -1 })
    .skip(skip)
    .limit(limit)
    .toArray()

  return { transfers: docs }
}
```

**User-level endpoint:** Queries with `userId` instead of `walletId` (or queries across all walletIds belonging to the user). The merge-sort pattern from the existing `getUserTransfers` can be reused, but since each wallet's data is already processed, the merge is over pre-computed documents — not raw transfers.

### Why `known_addresses` is NOT needed

The original analysis proposed a `known_addresses` query parameter for the FE to pass the user's addresses. **This is unnecessary** because the wallet-based endpoint already resolves all addresses belonging to the wallet via `wallet.addresses`. The wallet knows its own addresses — no external input is needed. Address resolution happens at write time when the data-shard processes the grouped event.

---

## 6A. Collection Schema — `wallet_transfers_processed`

This is the schema for the new MongoDB collection that stores one document per logical transaction. The document shape maps directly to the `TransferHistoryObject` response (Section 5) — the read endpoint returns documents nearly as-is.

### Generic fields (WDK — Phase 1)

These fields are computed by the core `processTransferGroup()` in `wdk-data-shard-wrk` and are chain-agnostic at the storage level (chain-specific parsing already happened in the indexer).

```jsonc
{
  // ─── PRIMARY KEY ───
  "walletId": "052d6e5d-...",            // which wallet this tx belongs to
  "transactionHash": "0xabc123...",       // the grouping key

  // ─── TIMING ───
  "ts": 1707222200000,                    // block timestamp (epoch ms) — same as raw transfers
  "updatedAt": 1707222200000,             // same as ts for confirmed; differs for pending→confirmed (Phase 2)
  "processedAt": 1707222300000,           // when this document was created/last updated

  // ─── CHAIN / NETWORK ───
  "blockchain": "ethereum",               // chain identifier — indexed for filtering
  "rail": "EVM",                          // "EVM" | "BTC" | "SPARK" | "TRON" | "TON" | "SOL"
  "chainId": 1,                           // EVM only; null for non-EVM
  "networkName": "Ethereum",              // human-readable

  // ─── ASSET ───
  "token": "usdt",                        // token identifier — indexed for filtering
  "symbol": "USDT",                       // display symbol
  "decimals": 6,                          // from static config

  // ─── CLASSIFICATION ───
  "type": "sent",                         // "sent" | "received" | "swap_out" | "swap_in" — indexed
  "direction": "out",                     // "in" | "out" | "self"
  "status": "confirmed",                  // Phase 1: always "confirmed"

  // ─── AMOUNT ───
  "amount": "1000000",                    // effective amount (excluding change)
                                           //   EVM: smallest unit (e.g. "1000000" = 1 USDT)
                                           //   BTC: BTC denomination (e.g. "0.5" = 0.5 BTC)
  "fiatAmount": "100.50",                 // may be null
  "fiatCcy": "usd",                       // may be null

  // ─── PARTICIPANTS ───
  "from": "0xabc...",                     // primary sender address
  "to": "0xdef...",                       // primary recipient address
  "fromMeta": {
    "addressType": "EVM_ADDRESS",         // address type enum
    "isSelf": true                        // true when address belongs to this wallet
  },
  "toMeta": {
    "addressType": "EVM_ADDRESS",
    "isSelf": false
  },

  // ─── FEES ───
  "sponsored": true,                      // paymaster detected (EVM only; false for non-EVM)
  "label": "transaction",                 // "transaction" | "paymasterTransaction"
                                           // Normalized at processing time: undefined/null → "transaction"

  // ─── LINKS ───
  "explorerUrl": "https://etherscan.io/tx/0x...",  // null if no explorer

  // ─── UNDERLYING TRANSFERS ───
  "underlyingTransfers": [                // raw indexed records grouped under this logical tx
    {
      "transferIndex": 0,
      "transactionIndex": 0,
      "logIndex": 0,
      "blockNumber": 19000000,
      "from": "0xabc...",
      "to": "0xdef...",
      "token": "usdt",
      "amount": "1000000",
      "ts": 1707222200000,
      "label": "transaction",             // normalized: undefined/null → "transaction"
      "isChange": false                   // true if this is a BTC change output
    }
  ],

  // ─── APP-LEVEL FIELDS (null in Phase 1 — populated by extended processing in Phase 2) ───
  "appActivitySubtype": null,             // Phase 2: "transfer" | "tip" | "rant"
  "appContext": null,                     // Phase 2: { appFlow, referenceId }
  "appTip": null,                        // Phase 2: { tipId, tipType, tipDirection, counterparty, appContent }
  "fromAppResolved": null,               // Phase 2: { displayName, entityType, avatarUrl }
  "toAppResolved": null                  // Phase 2: { displayName, entityType, avatarUrl }
}
```

### Rumble-specific fields (Phase 2)

When Rumble's extended `processTransferGroup()` runs, it populates the app-level fields on the same document:

```jsonc
{
  // ... all generic fields above ...

  "appActivitySubtype": "rant",           // "transfer" | "tip" | "rant"

  "appContext": {
    "appFlow": "rant",                    // "tip" | "rant" | "transfer" | "withdrawal"
    "referenceId": "wh_abc123"            // webhook ID from txWebhookRepository
  },

  "appTip": {
    "tipId": "wh_abc123",                // unique tip identifier
    "tipType": "rant",                   // "tip" | "rant"
    "tipDirection": "sent",              // "sent" | "received" — relative to the wallet
    "counterparty": {
      "displayName": "TechChannel",
      "entityType": "channel_tipjar",    // "user" | "channel" | "channel_tipjar" | "unknown"
      "avatarUrl": "https://..."
    },
    "appContent": {
      "contentId": "v12345",             // Rumble video/stream ID
      "contentType": "livestream",       // "video" | "livestream"
      "message": "Great stream!"         // rant message (null for plain tips)
    }
  },

  "fromAppResolved": {
    "displayName": "JohnDoe",
    "entityType": "user",
    "avatarUrl": "https://..."
  },

  "toAppResolved": {
    "displayName": "TechChannel",
    "entityType": "channel_tipjar",
    "avatarUrl": "https://..."
  }
}
```

### Indexes

| Index name | Key | Unique | Purpose |
|---|---|---|---|
| `idx_wallet_transfers_processed_pkey` | `{ walletId: 1, transactionHash: 1 }` | Yes | Primary key — one processed doc per wallet per tx |
| `idx_wallet_transfers_processed_query` | `{ walletId: 1, ts: -1 }` | No | Primary query index — wallet history sorted by time |
| `idx_wallet_transfers_processed_filters` | `{ walletId: 1, blockchain: 1, token: 1, type: 1, ts: -1 }` | No | Filtered queries (blockchain, token, type) |
| `idx_wallet_transfers_processed_by_ts` | `{ ts: -1 }` | No | Global timestamp queries / migration tooling |
| `idx_wallet_transfers_processed_activity` | `{ walletId: 1, appActivitySubtype: 1, ts: -1 }` | No | Rumble: filter by activity subtype (Phase 2) |

### Response mapping

The read endpoint maps the stored document to the API response (Section 5) as follows:

| Stored field | Response field | Transformation |
|---|---|---|
| Most generic fields | Same names | Pass-through (no transformation): `transactionHash`, `ts`, `updatedAt`, `blockchain`, `rail`, `chainId`, `networkName`, `token`, `symbol`, `decimals`, `type`, `direction`, `status`, `amount`, `fiatAmount`, `fiatCcy`, `from`, `to`, `explorerUrl`, `label`, `walletId`, `appActivitySubtype`, `appContext`, `appTip`, `underlyingTransfers` |
| `fromMeta` + `fromAppResolved` | `fromMeta: { addressType, isSelf, appResolved }` | Nest `fromAppResolved` inside `fromMeta.appResolved` |
| `toMeta` + `toAppResolved` | `toMeta: { addressType, isSelf, appResolved }` | Nest `toAppResolved` inside `toMeta.appResolved` |
| `sponsored` | `fees: { sponsored, networkFee: null }` | Wrap in `fees` object, add `networkFee: null` (Phase 1) |
| `underlyingTransfers[]` | `underlyingTransfers[]` with `transactionHash` added | Add `transactionHash` from parent document to each underlying transfer entry |
| `processedAt` | *(not exposed)* | Backend-only field for debugging/auditing — not included in API response |

This is a lightweight transform — no computation, just shape adjustment. Alternatively, the document can be stored in the exact API response shape to eliminate even this mapping. **Decision for implementer:** choose whichever approach is simpler. If stored in response shape, `fromAppResolved`/`toAppResolved` become nested inside `fromMeta`/`toMeta`, and `sponsored` is stored inside a `fees` object.

---

## 7. Chain-Specific Behavior

### BTC — Multiple outputs (change detection)

A BTC send creates N transfer records (one per vout):

```
Transfer 0: from=sender, to=recipient,          amount=0.5 BTC   → isChange: false
Transfer 1: from=sender, to=sender_change_addr,  amount=0.3 BTC   → isChange: true
```

Grouped result:
- `direction`: `out`
- `amount`: `"0.5"` (the non-change output only — **stored in BTC denomination**, see Section 12, Nuance 2)
- `from`: sender address
- `to`: recipient address (the non-change output)
- `underlyingTransfers[0].isChange`: `false`
- `underlyingTransfers[1].isChange`: `true`

Change detection works because the wallet knows all its addresses. If a `to` address belongs to the same wallet and the transaction direction is `out`, it's a change output.

> **v3 correction:** The previous spec version showed the BTC amount as `"50000000"` (satoshis). This was incorrect. The BTC indexer (`wdk-indexer-wrk-btc`) stores `vout.value.toString()` from Bitcoin Core RPC, which returns values in BTC denomination (e.g., `"0.5"`), not satoshis. The `amount` field preserves the stored format. See Section 12, Nuance 2 for full details.

### EVM — Transfer + Gas (paymaster)

An EVM USDT send may produce:

```
Transfer 0 (ERC20): from=sender, to=recipient, amount=100 USDT, label="transaction"
Transfer 1 (gas):   from=sender, to=paymaster, amount=0 ETH,    label="paymasterTransaction"
```

These have **different token values** (USDT vs ETH). When filtering by `token=usdt`, only Transfer 0 is returned. The gas transfer lives on a different token and doesn't pollute the USDT history.

For the grouped result:
- Typically 1 underlying transfer per group (when filtered by token)
- `fees.sponsored`: `true` (detected from the `paymasterTransaction` label that may exist on the same-hash transfers)

**Sponsored detection is clean in the write-time architecture:** Because processing happens at ingestion time with ALL transfers for the txHash available (no token filter applied), the `sponsored` flag is always correctly computed. The gas/paymaster transfer is present in the grouped event even if it's on a different token. Token filtering only applies at read time (when querying `wallet_transfers_processed`), and by then the `sponsored` field is already stored on the document. This eliminates the token-filter issue that existed in the v3 query-time approach.

### EVM — Self transfers

When both `from` and `to` in a transfer are wallet addresses:
- `direction`: `self`
- `type`: `sent`

### Tron / TON / Solana / Spark

These chains follow the same grouping logic. Each on-chain transaction produces one or more transfer records, grouped by `transactionHash`. The parser treats them identically to EVM (single output per tx in most cases).

---

## 8. Phase 1 vs Phase 2 Scope

### Phase 1 — Shipped with this implementation

| Feature | Details |
|---|---|
| **Indexer grouping** | Each `wdk-indexer-wrk-*` publishes grouped transfer events (all transfers for one txHash in one event) |
| **New collection** | `wdk_data_shard_wallet_transfers_processed` — one doc per logical tx |
| **Write-time processing** | `processTransferGroup()` computes all derived fields at ingestion time |
| Transaction grouping | Group raw transfers by `transactionHash` |
| Direction | `in` / `out` / `self` |
| Type | `sent` / `received` |
| Correct amount | Excludes change outputs |
| Change detection (BTC) | Via wallet's own address list |
| Network metadata | `rail`, `chainId`, `networkName` |
| Token metadata | `symbol`, `decimals` |
| Explorer URLs | All supported chains except Spark and Plasma |
| Sponsored flag | From existing `paymasterTransaction` label |
| Fiat amount | Carried from existing stored data |
| Underlying transfers | Full raw records with `isChange` flag |
| Status | Always `"confirmed"` (indexer only indexes confirmed blocks) |
| **Dual-write** | Raw transfers still written to `wallet_transfers_v2` (backward compat) |
| **New read endpoints** | Simple collection queries — no chain logic at read time |
| Rumble addon fields | Present in schema as `null` — FE can build layouts |
| **Backfill** | One-time migration script for Rumble (see Section 14) |

### Phase 2 — Future work (separate tasks)

| Feature | What's needed |
|---|---|
| **Rumble enrichment layer** | Extend `processTransferGroup()` in `rumble-data-shard-wrk` via `super.method()` + `enrichTransferGroup()`. Add `activitySubtype` query param in `rumble-app-node`. Full specification in Section 13. |
| **Tether Wallet enrichment** | Extend `processTransferGroup()` in `tether-data-shard-wrk` for Tether-specific use cases. Same `super.method()` pattern. |
| **Swap detection** (`swap_out` / `swap_in`) | Configure known swap partner addresses in the processing step |
| **Fee breakdown** (`fees.networkFee`) | Index fee data during block processing — stored on the processed document |
| **Pending/Failed status** | Write pending tx to `wallet_transfers_processed` with `status: "pending"`, update on confirmation/failure |
| **Counterparty resolution** (`appResolved`) | Address → user identity mapping service, resolved at write time by extended processing |
| **Tip information** (`appTip`) | Resolved at write time from `txWebhookRepository` by Rumble enricher |
| **App context** (`appContext`) | Resolved at write time from webhook data by Rumble enricher |
| **USD value at time of tx** | Historical price oracle integration |
| **Amount format normalization** | Normalize all chains to smallest-unit format at processing time (see Section 12, Nuance 2) |

---

## 9. Known Gaps

| # | Gap | Impact | Mitigation |
|---|---|---|---|
| 1 | No fee data indexed | `fees.networkFee` is null in Phase 1 | `fees.sponsored` flag is available. Full fee data can be added to the indexer grouping step in Phase 2. |
| 2 | No pending/failed tx tracking | `status` is always `"confirmed"` | Indexer only processes confirmed blocks. Pending tracking: write pending txs to `wallet_transfers_processed` with `status: "pending"`, update on confirmation (Phase 2). |
| 3 | BTC inputs not stored | Cannot compute exact BTC network fees | Inputs are not indexed — only outputs/vouts. Accept this gap or index inputs in Phase 2. |
| 4 | No address → user registry in indexer | Cannot resolve counterparty identity | Rumble enrichment (Phase 2) resolves at write time via extended processing. |
| 5 | No tip data in indexer | Cannot populate `appTip` | Rumble enrichment (Phase 2) resolves at write time from `txWebhookRepository`. |
| 6 | No historical price oracle | `fiatAmount` only available when stored at ingestion time | Already stored for most transfers via `price.calculator.js`. Gaps exist for older data. |
| 7 | Spark / Lightning transfer format | Not fully verified | Verify Spark worker's transfer record format before testing. |
| 8 | BTC amounts stored in BTC, not satoshis | Cross-chain `amount` format is inconsistent. EVM stores smallest unit; BTC stores BTC denomination. | Processor passes through as-is (matches existing `/token-transfers` behavior). FE already handles this. Normalization deferred to Phase 2. See Section 12, Nuance 2. |
| 9 | ~~MongoDB stream sorting~~ | **RESOLVED by v4 architecture.** Grouping now happens at write time in the indexer — no read-time cursor buffering needed. | N/A — indexers group all transfers for a txHash before publishing. |
| 10 | `label` field is EVM-only | BTC, TRON, TON, SOL, SPARK transfers do not have a `label` field. | Processor must treat `undefined`/`null` label as `"transaction"`. `sponsored` is `false` for non-EVM. See Section 12, Nuance 3. |
| 11 | ~~`sponsored` detection with token filter~~ | **RESOLVED by v4 architecture.** Processing sees all transfers for a txHash at write time (no token filter). `sponsored` is always correctly computed before storage. | N/A. |
| 12 | **[NEW]** Backfill for existing data | Historical transfers in `wallet_transfers_v2` need to be processed into the new collection. | One-time migration script for Rumble only. See Section 14. |
| 13 | **[NEW]** Indexer event format change | Indexers must publish grouped events instead of individual transfer events. | Must be coordinated across all `wdk-indexer-wrk-*` repos. Polling indexers use truncate-to-previous-tx for atomicity. |

---

## 10. Implementation Footprint

### Phase 1 — Files changed

**Indexers (`wdk-indexer-wrk-*`):**

| File | Change |
|---|---|
| `wdk-indexer-wrk-btc/workers/lib/providers/rpc.provider.js` (and equivalent in each indexer) | **MODIFY** — Group all transfers for a txHash into a single event before publishing. BTC: all vouts for one tx. EVM: all ERC20 events + gas for one tx. Etc. |
| `wdk-indexer-wrk-*/workers/lib/transfer.grouper.js` | **NEW** (optional) — Shared utility for grouping raw transfers by `transactionHash` before event publish. Can be inline in each indexer if the logic is trivial. |

**Data-shard (`wdk-data-shard-wrk`):**

| File | Change |
|---|---|
| `wdk-data-shard-wrk/workers/proc.shard.data.wrk.js` | **MODIFY** — Receive grouped transfer events. Call `processTransferGroup()` to compute derived fields. Store result in `wallet_transfers_processed`. Continue storing raw transfers in `wallet_transfers_v2` (dual-write). |
| `wdk-data-shard-wrk/workers/lib/transfer.processor.js` | **NEW** — `processTransferGroup(transfers, walletAddresses, wallet)` — computes direction, type, amount, change detection, metadata, sponsored flag. Pure function with static config. **Extensible:** designed to be overridden via `super.processTransferGroup()` in subclasses (Rumble, Tether). |
| `wdk-data-shard-wrk/workers/lib/db/mongodb/repositories/wallet.transfers.processed.js` | **NEW** — Repository for `wdk_data_shard_wallet_transfers_processed` collection. CRUD operations + query methods with filters. |
| `wdk-data-shard-wrk/workers/api.shard.data.wrk.js` | **ADD** — `getWalletTransferHistory()` + `getUserTransferHistory()` methods. Simple collection queries with filters, sort, skip, limit. Register both in the `rpcActions` array (currently at line ~643). |

**App node (`wdk-app-node`):**

| File | Change |
|---|---|
| `wdk-app-node/workers/lib/server.js` | **ADD** — 2 route definitions following the existing Fastify pattern. |
| `wdk-app-node/workers/lib/services/ork.js` | **ADD** — 2 RPC proxy methods following the existing `getWalletTransfers` / `getUserTransfers` pattern. |
| `wdk-app-node/workers/lib/middlewares/response.validator.js` | **ADD** — response schemas for new endpoints. Key format: `'GET:/api/v1/wallets/:walletId/transfer-history'` and `'GET:/api/v1/users/:userId/transfer-history'`. |

**Migration:**

| File | Change |
|---|---|
| `scripts/migrate-wallet-transfers-processed.js` (or similar) | **NEW** — One-time backfill script. See Section 14. |

### Files NOT changed

- Existing `getWalletTransfers` / `getUserTransfers` — untouched, backward-compatible
- Existing `/token-transfers` endpoints — untouched
- `wdk_data_shard_wallet_transfers_v2` collection and its repository — untouched (still written to via dual-write)
- Price calculator — untouched
- Database indexes on `wallet_transfers_v2` — untouched

### Rumble mirror

Per project convention, changes to `wdk-app-node` and `wdk-data-shard-wrk` must be mirrored in `rumble-app-node` and `rumble-data-shard-wrk` respectively.

**Phase 1 Rumble mirror:** The Rumble data-shard inherits from WDK. It gets `processTransferGroup()` from the base class automatically. No Rumble-specific override needed in Phase 1 — addon fields are `null`. Rumble app-node mirrors the 2 route definitions and 2 RPC proxy methods.

### Phase 2 — Rumble-specific files

| File | Change |
|---|---|
| `rumble-data-shard-wrk/workers/proc.shard.data.wrk.js` | **OVERRIDE** — `processTransferGroup()` to call `super.processTransferGroup()` + `enrichTransferGroup()` |
| `rumble-data-shard-wrk/workers/lib/transfer.enricher.js` | **NEW** — `enrichTransferGroup()` — resolves counterparty identity, activity subtype, tip metadata, app context at write time |
| `rumble-data-shard-wrk/workers/api.shard.data.wrk.js` | **ADD/OVERRIDE** — `getWalletTransferHistory()`, `getUserTransferHistory()` to support `activitySubtype` filter |
| `rumble-app-node/workers/lib/server.js` | **ADD** — 2 route definitions with extra `activitySubtype` query param |
| `rumble-app-node/workers/lib/services/ork.js` | **ADD** — 2 RPC proxy methods that pass `activitySubtype` |
| `rumble-data-shard-wrk/workers/lib/db/` | **POSSIBLY MODIFY** — add address-to-wallet reverse lookup for counterparty resolution |

### Phase 2 — Tether Wallet-specific files

| File | Change |
|---|---|
| `tether-data-shard-wrk/workers/proc.shard.data.wrk.js` | **OVERRIDE** — `processTransferGroup()` to call `super.processTransferGroup()` + Tether-specific enrichment |

See Section 13 for the full Rumble enrichment specification.

---

## 11. Glossary

| Term | Definition |
|---|---|
| **Logical transaction** | A single user-facing transaction, derived by grouping raw transfers that share the same `transactionHash`. |
| **Raw transfer** | A single indexed record from the blockchain — one per on-chain output/event. Stored in `wdk_data_shard_wallet_transfers_v2`. |
| **Change output** | A BTC transaction output that sends remaining funds back to the sender's own address. Not part of the intended transfer amount. |
| **Direction** | Whether funds flow into the wallet (`in`), out of the wallet (`out`), or between the wallet's own addresses (`self`). |
| **Rail** | The blockchain protocol family: `EVM`, `BTC`, `SPARK`, `TRON`, `TON`, `SOL`. |
| **Sponsored** | A gasless transaction where fees were paid by a paymaster (detected via `paymasterTransaction` label). |
| **Rumble enrichment layer** | App-specific enrichment layer (tip info, counterparty resolution, app context) implemented in `rumble-*` repos. Null in Phase 1. Separate from core chain-level logic. See Section 13. |
| **Core module** | The reusable chain-level processing logic (`transfer.processor.js` → `processTransferGroup()`). Contains no app-specific code. Can be used by Tether Wallet, Rumble, or any other app. |
| **Enrichment** | The process of augmenting a core grouped transaction with app-specific data (counterparty identity, activity type, tip metadata). Runs after the core parser. |
| **Tip jar** | A wallet designated for receiving tips on Rumble. Can be a user tip jar (`type: 'user'`) or a channel tip jar (`type: 'channel'`). Retrieved via existing `getUserTipJar()` / `getChannelTipJar()` methods. |
| **Rant** | A Rumble tip that includes a message/payload (similar to a "superchat"). Distinguished from a plain tip by the `TOKEN_TRANSFER_RANT` webhook type. |
| **Activity subtype** | A Rumble-level classification of what a transaction represents: `transfer` (regular send/receive), `tip` (tip without message), or `rant` (tip with message). |
| **Entity type** | A Rumble-level classification of what an address represents: `user`, `channel`, `channel_tipjar`, or `unknown`. Used in `appResolved.entityType`. |

---

## Static Configuration Reference

### Rail mapping

| `blockchain` value | `rail` | `chainId` |
|---|---|---|
| `ethereum` | `EVM` | `1` |
| `sepolia` | `EVM` | `11155111` |
| `plasma` | `EVM` | `null` |
| `arbitrum` | `EVM` | `42161` |
| `polygon` | `EVM` | `137` |
| `tron` | `TRON` | `null` |
| `ton` | `TON` | `null` |
| `solana` | `SOL` | `null` |
| `bitcoin` | `BTC` | `null` |
| `spark` | `SPARK` | `null` |

### Explorer URLs

| `blockchain` | Explorer base URL |
|---|---|
| `ethereum` | `https://etherscan.io/tx/` |
| `sepolia` | `https://sepolia.etherscan.io/tx/` |
| `arbitrum` | `https://arbiscan.io/tx/` |
| `polygon` | `https://polygonscan.com/tx/` |
| `tron` | `https://tronscan.org/#/transaction/` |
| `ton` | `https://tonviewer.com/transaction/` |
| `solana` | `https://solscan.io/tx/` |
| `bitcoin` | `https://mempool.space/tx/` |
| `spark` | `null` (no public explorer) |
| `plasma` | `null` (no public explorer) |

### Token metadata

| `token` | `symbol` | `decimals` |
|---|---|---|
| `usdt` | `USDT` | `6` |
| `usdt0` | `USDT0` | `6` |
| `xaut` | `XAUT` | `6` |
| `xaut0` | `XAUT0` | `6` |
| `btc` | `BTC` | `8` |

### Address type mapping

| `rail` | `addressType` |
|---|---|
| `EVM` | `EVM_ADDRESS` |
| `BTC` | `BTC_ADDRESS` |
| `TRON` | `TRON_ADDRESS` |
| `TON` | `TON_ADDRESS` |
| `SOL` | `SOL_ADDRESS` |
| `SPARK` | `SPARK_ACCOUNT` |
| *(other)* | `UNKNOWN` |

---

## 12. Implementation Nuances from Codebase Audit

> **Context:** This section was added after a thorough audit of the actual codebase on 2026-02-10. It documents behaviors in the existing code that the implementer MUST account for. None of these are blockers — the spec is fully feasible — but ignoring any of them will lead to bugs.

---

### Nuance 1: ~~Grouping by `transactionHash` — records are NOT adjacent in the stream~~

> **RESOLVED in v4.** This nuance applied to the v3 query-time aggregation approach where the read path streamed from `wallet_transfers_v2` (sorted by `ts` only). In the v4 architecture, grouping happens at **write time in the indexer** — the indexer already has all transfers for a txHash before publishing the event. The data-shard receives a pre-grouped event and processes it directly. No cursor buffering needed.
>
> **For the migration script** (Section 14), the same concern applies when reading historical data from `wallet_transfers_v2`. The migration script must group by `transactionHash` across the flat records. Use a `Map<txHash, transfer[]>` approach when iterating historical data.

---

### Nuance 2: BTC amount format — BTC denomination, NOT satoshis

**What the spec previously said (Section 7, BTC example):**

> `amount`: `"50000000"` (0.5 BTC — the non-change output only)

**What the BTC indexer actually stores:**

```javascript
// wdk-indexer-wrk-btc/workers/lib/providers/rpc.provider.js
return {
  // ...
  amount: vout.value.toString(),  // Bitcoin Core RPC returns vout.value in BTC (e.g., 0.5)
  // ...
}
```

Bitcoin Core's `getrawtransaction` (verbose) returns `vout[].value` in **BTC denomination** (a decimal number), not satoshis. So 0.5 BTC is stored as `"0.5"`, not `"50000000"`.

**Cross-chain inconsistency in stored data:**

| Chain | Amount format stored | Example for "100 units" |
|---|---|---|
| EVM (ERC20, e.g. USDT) | Smallest unit (from contract event) | `"100000000"` (100 USDT with 6 decimals) |
| BTC | BTC denomination (from RPC vout.value) | `"0.001"` (0.001 BTC) |
| TRON / TON / SOL | Smallest unit (from respective indexers) | Varies by token |

**Decision for Phase 1:** The `amount` field in the grouped response **preserves the stored format** — same as the existing `/token-transfers` endpoint. The FE already handles this inconsistency. The `decimals` field in the response tells the FE how to interpret the amount.

**Impact on amount summing in `parseTransferGroup()`:** When computing the effective amount (sum of non-change outputs for `out`, sum of received amounts for `in`), the parser must use string-based arithmetic that handles decimal BTC values correctly. **Do not parse BTC amounts as integers** — `"0.5"` is not an integer.

```javascript
// For BTC: use parseFloat or a decimal library
// For EVM: use BigInt (amounts are already integers in smallest unit)
const sumAmounts = (amounts, blockchain) => {
  if (blockchain === 'bitcoin') {
    return amounts.reduce((sum, a) => sum + parseFloat(a), 0).toString()
  }
  return amounts.reduce((sum, a) => sum + BigInt(a), 0n).toString()
}
```

**Phase 2 consideration:** A future normalization pass could convert all amounts to smallest unit at query time, making the format consistent across chains. This is explicitly deferred.

---

### Nuance 3: `label` field is EVM-only — non-EVM chains have no label

**What the spec says:**

> `fees.sponsored`: `true` when `label === 'paymasterTransaction'`

**What the codebase shows:**

The `label` field is set exclusively by the EVM indexer:

```javascript
// wdk-indexer-wrk-evm/workers/utils/index.js
const parseLabel = (tx, paymasters) => {
  if (isPaymaster(tx.to, paymasters) || isPaymaster(tx.from, paymasters)) {
    return 'paymasterTransaction'
  }
  return 'transaction'
}
```

This function is imported only in `wdk-indexer-wrk-evm`. The BTC, TRON, TON, SOL, and SPARK indexers do **not** set a `label` field on their transfer records. The field will be `undefined` (or absent from the MongoDB document) for non-EVM transfers.

**What the parser must do:**

```javascript
// In parseTransferGroup():
const sponsored = transfers.some(t => t.label === 'paymasterTransaction')
// This correctly returns false when label is undefined (non-EVM)

// For the logical-level label field in the response:
const label = transfers.find(t => t.label)?.label || 'transaction'
// Default to 'transaction' when no label exists
```

**For `underlyingTransfers[]`:** The `label` field in each underlying transfer should be the stored value (which may be `undefined` for non-EVM). The parser should normalize it to `"transaction"` for consistency with the response schema.

---

### Nuance 4: ~~Pagination counts grouped transactions, NOT raw records~~

> **RESOLVED in v4.** In the v4 architecture, `wallet_transfers_processed` stores one document per logical transaction. Each document IS a grouped transaction. Standard MongoDB `skip` + `limit` on this collection directly paginates grouped transactions. No over-fetching, no buffer counting — just a normal query with `.skip(skip).limit(limit)`.
>
> The existing `getWalletTransfers` (old endpoint) continues to count raw records as before — no change.

---

### Nuance 5: Existing code patterns the implementer should follow

To maintain consistency with the codebase, the new code should follow these established patterns:

**Route definition pattern (`wdk-app-node/workers/lib/server.js`):**

```javascript
{
  method: 'GET',
  url: '/api/v1/wallets/:walletId/transfer-history',
  schema: {
    params: {
      type: 'object',
      properties: {
        walletId: { type: 'string' }
      },
      required: ['walletId']
    },
    querystring: {
      type: 'object',
      properties: {
        userId: { type: 'string' },
        blockchain: { type: 'string' },
        token: { type: 'string' },
        type: { type: 'string' },
        from: { type: 'integer' },
        to: { type: 'integer' },
        limit: { type: 'integer', minimum: 1, maximum: 100, default: 10 },
        skip: { type: 'integer', minimum: 0, default: 0 },
        sort: { type: 'string', enum: ['asc', 'desc'], default: 'desc' }
      }
    }
  },
  preHandler: async (req, rep) => {
    await runGuards([/* auth guards */], ctx, req)
  },
  handler: async (req, rep) => {
    const res = await service.ork.getWalletTransferHistory(ctx, req, rep)
    return rep.status(200).send(res)
  }
}
```

**RPC proxy pattern (`wdk-app-node/workers/lib/services/ork.js`):**

```javascript
const getWalletTransferHistory = async (ctx, req, rep) => {
  try {
    const payload = {
      walletId: req.params.walletId,
      ...req.query
    }
    const res = await rpcCall(ctx, req, 'getWalletTransferHistory', payload)
    return rep.status(200).send(res)
  } catch (err) {
    if (err.message.includes('ERR_WALLET_NOT_FOUND')) {
      throw ctx.httpd_h0.server.httpErrors.notFound('ERR_WALLET_NOT_FOUND')
    }
    throw ctx.httpd_h0.server.httpErrors.internalServerError(err.message)
  }
}
```

**RPC registration (`wdk-data-shard-wrk/workers/api.shard.data.wrk.js`):**

Add `'getWalletTransferHistory'` and `'getUserTransferHistory'` to the `rpcActions` array (around line 643).

**Response schema registration (`wdk-app-node/workers/lib/middlewares/response.validator.js`):**

```javascript
const transferHistoryResponseSchema = {
  type: 'object',
  properties: {
    transfers: {
      type: 'array',
      items: { /* TransferHistoryObject schema */ }
    }
  },
  required: ['transfers'],
  additionalProperties: false
}

// Add to wdkResponseSchemas:
'GET:/api/v1/wallets/:walletId/transfer-history': { 200: transferHistoryResponseSchema },
'GET:/api/v1/users/:userId/transfer-history': { 200: transferHistoryResponseSchema },
```

**Processing extension pattern (`rumble-data-shard-wrk/workers/proc.shard.data.wrk.js`):**

```javascript
// Existing established pattern — Rumble extends WDK proc worker
const WrkBase = require('@tetherto/wdk-data-shard-wrk/workers/proc.shard.data.wrk')

class WrkProcShardData extends WrkBase {
  // Override the base processing method
  async processTransferGroup (transfers, walletAddresses, wallet) {
    // Call core generic processing
    const processed = await super.processTransferGroup(transfers, walletAddresses, wallet)

    // Add Rumble-specific enrichment
    const enriched = await this.enrichTransferGroup(processed)
    return enriched
  }
}
```

This follows the same `extends WrkBase` + `super.method()` pattern already used for `storeTxWebhook()`, `_walletTransferDetected()`, and other methods in the Rumble proc worker.

---

### Nuance 6: Wallet addresses structure

**How `wallet.addresses` works:**

```javascript
// Wallet entity — addresses is an Object.<string, string> mapping chain → address
// Example: { ethereum: "0xabc...", bitcoin: "bc1q...", tron: "T..." }

const wallet = await this.db.walletRepository.getActiveWallet(walletId)
const walletAddresses = Object.values(wallet.addresses || {})
// Result: ["0xabc...", "bc1q...", "T..."]
```

The existing code converts this to a flat array via `Object.values()` and uses `walletAddresses.includes(address)` to check ownership. The v2 should do the same.

**For the user-level endpoint:**

```javascript
const userWallets = await this.db.walletRepository.getActiveUserWallets(userId).toArray()
const walletIdToAddresses = {}
for (const wallet of userWallets) {
  walletIdToAddresses[wallet.id] = Object.values(wallet.addresses || {})
}
```

This per-wallet address mapping is needed because the user-level endpoint must determine direction/change relative to each wallet individually.

---

### Nuance 7: MongoDB collection and index details

**Collection:** `wdk_data_shard_wallet_transfers_v2`

**Indexes:**

| Index name | Key | Unique | Purpose |
|---|---|---|---|
| `idx_wdk_data_shard_wallet_transfers_pkey` | `{ walletId: 1, transactionHash: 1, transferIndex: 1 }` | Yes | Primary key — prevents duplicate records |
| `idx_wdk_data_shard_wallet_transfers_by_walletid_ts` | `{ walletId: 1, ts: 1 }` | No | Used by `getTransfersForWalletInRange()` |
| `idx_wdk_data_shard_wallet_transfers_by_ts` | `{ ts: 1 }` | No | Used for global timestamp queries |

**Key takeaway:** There is no index on `transactionHash` alone, and the query index sorts by `(walletId, ts)`. This means:
- Grouping by `transactionHash` happens in application code, not in MongoDB.
- The `ts`-based buffer flushing strategy (Nuance 1) is the correct approach.
- Adding a new index (e.g., `{ walletId: 1, ts: 1, transactionHash: 1 }`) is NOT required for Phase 1 but could be considered for optimization if performance testing reveals issues.

---

### Summary: Implementation Checklist

The implementer should address these items, in addition to the main spec:

**Indexer changes:**
- [ ] Modify each `wdk-indexer-wrk-*` to publish grouped transfer events (all transfers for one txHash in one event)
- [ ] For polling-based indexers, implement truncate-to-previous-tx to guarantee atomicity

**Data-shard write path:**
- [ ] Implement `processTransferGroup()` in `transfer.processor.js` — direction, type, amount, change detection, metadata, sponsored
- [ ] Handle BTC amounts as decimal strings (`"0.5"` not `"50000000"`) — use `parseFloat` for BTC summation, `BigInt` for EVM (Nuance 2)
- [ ] Default `label` to `"transaction"` when undefined/null for non-EVM chains (Nuance 3)
- [ ] `sponsored` detection sees all transfers for a txHash at write time — no token-filter issue (v4 resolves this)
- [ ] Normalize `label` in `underlyingTransfers[]` to `"transaction"` when absent (Nuance 3)
- [ ] Access wallet addresses via `Object.values(wallet.addresses || {})` (Nuance 6)
- [ ] Create `wallet_transfers_processed` collection with indexes (Section 6A)
- [ ] Implement dual-write: store to both `wallet_transfers_processed` and `wallet_transfers_v2`

**Data-shard read path:**
- [ ] Implement `getWalletTransferHistory()` — simple collection query with filters, sort, skip, limit
- [ ] Implement `getUserTransferHistory()` — query across all user's wallets, merge-sort
- [ ] Pagination is standard MongoDB skip/limit (one doc = one grouped tx)

**App node:**
- [ ] Follow established patterns for routes, RPC proxy, RPC registration, and response schemas (Nuance 5)

**Migration:**
- [ ] Write one-time backfill script for Rumble (Section 14)

**Testing:**
- [ ] Add unit tests for `processTransferGroup()` covering: BTC change detection, EVM paymaster, self-transfer, single-transfer group, multi-output BTC
- [ ] Integration test: verify dual-write produces consistent data in both collections
- [ ] Integration test: verify read endpoint returns correctly shaped response from `wallet_transfers_processed`

---

## 13. Rumble Enrichment Layer — Complete Specification

> **Phase:** Phase 2 (separate task from core implementation)
> **Purpose:** This section fully defines the Rumble-specific enrichment layer — the second of the two layers described in Section 2. It exists so that any developer picking up the Phase 2 work has everything they need without referencing other documents.

---

### 13.1 Design Principle

The system consists of two separate pieces complementing each other:

1. **Core (Layer 1):** Lives in `wdk-*` repos. Its domain knowledge is **blockchain only** — chains, tokens, UTXO model, EVM gas, addresses, grouping, change detection. It knows nothing about Rumble users, channels, tips, or rants. It is reusable by any wallet app. Processing happens at **write time** via `processTransferGroup()`.

2. **Rumble Enrichment (Layer 2):** Lives in `rumble-*` repos. Its domain knowledge is **Rumble-specific** — users, channels, tip jars, tips, rants, content. It extends the core's `processTransferGroup()` via `super.method()` — calling the core first, then enriching with Rumble-specific data. **Both layers run at write time** — by the time data is stored, all fields are populated.

**The layers are decoupled.** The core module never imports or references Rumble code. The Rumble enricher depends on the core's processing output shape. If the core's output shape changes, the enricher adapts — but not the other way around. The read path is identical for both layers — a simple collection query.

---

### 13.2 What Each Layer Produces (at write time)

| Stored field | Populated by Core `processTransferGroup()` (Phase 1) | Populated by Rumble `enrichTransferGroup()` (Phase 2) |
|---|---|---|
| `transactionHash` | Yes | — |
| `ts`, `updatedAt` | Yes | — |
| `blockchain`, `rail`, `chainId`, `networkName` | Yes | — |
| `token`, `symbol`, `decimals` | Yes | — |
| `type`, `direction`, `status` | Yes | — |
| `amount`, `fiatAmount`, `fiatCcy` | Yes | — |
| `from`, `to` | Yes | — |
| `fromMeta.addressType` | Yes | — |
| `fromMeta.isSelf` | Yes | — |
| `fromMeta.appResolved` | null | **Yes** — resolves address to Rumble user/channel |
| `toMeta.addressType` | Yes | — |
| `toMeta.isSelf` | Yes | — |
| `toMeta.appResolved` | null | **Yes** — resolves address to Rumble user/channel |
| `fees` | Yes | — |
| `explorerUrl` | Yes | — |
| `label` | Yes | — |
| `walletId` | Yes | — |
| `appActivitySubtype` | null | **Yes** — `"transfer"` / `"tip"` / `"rant"` |
| `appContext` | null | **Yes** — app flow and reference ID |
| `appTip` | null | **Yes** — full tip/rant metadata |
| `underlyingTransfers` | Yes | — |

---

### 13.3 Extension Mechanism

Rumble extends the core via the established class inheritance pattern **at write time** — in the proc worker, not the API worker:

```javascript
// rumble-data-shard-wrk/workers/proc.shard.data.wrk.js
const WrkBase = require('@tetherto/wdk-data-shard-wrk/workers/proc.shard.data.wrk')
const { enrichTransferGroup } = require('./lib/transfer.enricher')

class WrkProcShardData extends WrkBase {

  async processTransferGroup (transfers, walletAddresses, wallet) {
    // 1. Call the core processing (generic: direction, amount, change, metadata)
    const processed = await super.processTransferGroup(transfers, walletAddresses, wallet)

    // 2. Enrich with Rumble-specific data (counterparty, tips, app context)
    const enriched = await enrichTransferGroup(processed, {
      db: this._getDbCtx(),           // access to txWebhookRepository, wallet lookups
      walletAddresses
    })

    return enriched
  }
}
```

**Key difference from v3:** Enrichment happens at **write time** (when the grouped event is received from the indexer), not at read time (when the FE queries). By the time the document is stored in `wallet_transfers_processed`, all Rumble-specific fields are already populated. The read path is a simple collection query with no enrichment step.

This mirrors the existing pattern used for `storeTxWebhook()`, `_walletTransferDetected()`, and other overridden methods in `rumble-data-shard-wrk/workers/proc.shard.data.wrk.js`.

---

### 13.4 Rumble-Specific API Contract

The Rumble app serves the same endpoint paths but with additional query parameters:

**Wallet-level:**
```
GET /api/v1/wallets/:walletId/transfer-history
```

**User-level:**
```
GET /api/v1/users/:userId/transfer-history
```

**Additional query parameters (Rumble only):**

| Param | Type | Required | Default | Description |
|---|---|---|---|---|
| `activitySubtype` | string | no | — | `transfer`, `tip`, or `rant`. Filters results by Rumble activity classification. |

All other query parameters are inherited from the core (Section 4.1 / 4.2).

**Filtering behavior:**

Since enrichment happens at **write time**, the `appActivitySubtype` field is already stored on each document. The `activitySubtype` query param is a simple MongoDB filter — no over-fetching or post-enrichment filtering needed:

```javascript
// In getWalletTransferHistory query builder:
if (activitySubtype) query.appActivitySubtype = activitySubtype
```

This is a straightforward indexed query (see Section 6A, index `idx_wallet_transfers_processed_activity`).

---

### 13.5 Rumble Response Field Schemas

#### `appResolved` (inside `fromMeta` and `toMeta`)

Resolves a blockchain address to a Rumble entity.

```jsonc
{
  "displayName": "TechChannel",         // Rumble username or channel name
  "entityType": "channel_tipjar",        // what this address represents in Rumble
  "avatarUrl": "https://rumble.com/..."  // URL to profile/channel avatar (may be null)
}
```

**`entityType` vocabulary:**

| Value | Meaning | How it's detected |
|---|---|---|
| `user` | A Rumble user's personal wallet | Address matches a wallet with `type: 'user'` linked to a Rumble userId |
| `channel` | A Rumble channel's wallet | Address matches a wallet with `type: 'channel'` |
| `channel_tipjar` | The tip jar address of a Rumble channel | Address matches the wallet returned by `getChannelTipJar(channelId)` |
| `unknown` | Address not found in Rumble's registry | Default when no match is found |

**Data source:** The enricher queries `walletRepository` to look up wallets by address, then resolves the associated Rumble user/channel identity via existing RPC or database lookups. The exact lookup mechanism depends on what's available in the Rumble DB context (potentially a new address-to-entity index or an RPC call to the Rumble server).

#### `appActivitySubtype`

Classifies the transaction's purpose within Rumble.

| Value | Meaning | How it's detected |
|---|---|---|
| `transfer` | Regular token transfer (not a tip or rant) | No matching webhook record in `txWebhookRepository`, or webhook type is neither `tip` nor `rant` |
| `tip` | A tip to a creator/channel without a message | Matching webhook record with `type: 'tip'` (maps to `TOKEN_TRANSFER_TIP` notification type) |
| `rant` | A tip to a creator/channel with a message/payload | Matching webhook record with `type: 'rant'` (maps to `TOKEN_TRANSFER_RANT` notification type) |

**Data source:** `txWebhookRepository` — the existing Rumble-specific repository that stores webhook records for tip/rant transactions. The enricher looks up the `transactionHash` in this collection.

#### `appContext`

Links the transaction back to the originating action in Rumble.

```jsonc
{
  "appFlow": "tip",                      // "tip" | "rant" | "transfer" | "withdrawal"
  "referenceId": "wh_abc123..."          // webhook ID or internal reference from txWebhookRepository
}
```

| Field | Type | Description |
|---|---|---|
| `appFlow` | string | The Rumble action flow that initiated this transaction. Values: `"tip"`, `"rant"`, `"transfer"`, `"withdrawal"`. |
| `referenceId` | string | The ID of the record in `txWebhookRepository` (or other Rumble-internal reference). Used for cross-referencing with Rumble server logs and debugging. |

#### `appTip`

Full tip/rant metadata. Only populated when `appActivitySubtype` is `"tip"` or `"rant"`. Null for regular transfers.

```jsonc
{
  "tipId": "wh_abc123...",               // unique tip identifier (webhook ID)
  "tipType": "rant",                     // "tip" | "rant"
  "tipDirection": "sent",                // "sent" | "received" — relative to the queried wallet
  "counterparty": {                      // the other party in the tip
    "displayName": "TechChannel",
    "entityType": "channel_tipjar",
    "avatarUrl": "https://rumble.com/..."
  },
  "appContent": {                        // what was tipped on (may be null if not available)
    "contentId": "v12345",               // Rumble video/stream ID
    "contentType": "video",              // "video" | "livestream"
    "message": "Great stream!"           // rant message (null for plain tips)
  }
}
```

| Field | Type | Description |
|---|---|---|
| `tipId` | string | Unique identifier for this tip action. Matches the webhook record ID. |
| `tipType` | string | `"tip"` (no message) or `"rant"` (with message). Mirrors `appActivitySubtype` but scoped to the tip object. |
| `tipDirection` | string | `"sent"` if the queried wallet sent the tip, `"received"` if it received it. Derived from the core `direction` field. |
| `counterparty` | object | The other party. For a sent tip: the channel/user that received it. For a received tip: the user who sent it. Same schema as `appResolved`. |
| `appContent` | object or null | The content being tipped on. Populated from webhook payload data. Null if the content reference is not available. |
| `appContent.contentId` | string | Rumble video or livestream ID. |
| `appContent.contentType` | string | `"video"` or `"livestream"`. |
| `appContent.message` | string or null | The rant message. Null for plain tips. |

---

### 13.6 Enrichment Data Sources

The enricher needs data from these existing Rumble components:

| Data needed | Source | Already exists? | Notes |
|---|---|---|---|
| Webhook type (tip/rant) | `txWebhookRepository` | **Yes** — Rumble-specific repository in `rumble-data-shard-wrk` | Query by `transactionHash`. Collection stores `type: 'rant' \| 'tip'` and payload. |
| Webhook payload (message, content) | `txWebhookRepository` | **Yes** | Stored in the webhook record's `payload` field for rants. |
| User/channel identity from address | Wallet → userId/channelId mapping | **Partial** | Wallets store `userId` and `type` (`user`/`channel`). Reverse lookup (address → wallet → userId) needs an index or query. |
| User display name / avatar | Rumble user service | **No** — external service | Requires an RPC call to Rumble server or a cached identity mapping. This is the main new dependency. |
| Channel display name / avatar | Rumble channel service | **No** — external service | Same as above for channels. |
| Tip jar identification | `getChannelTipJar()` / `getUserTipJar()` | **Yes** | Already implemented in `rumble-data-shard-wrk`. |

**New dependencies for Phase 2:**
- An address → entity identity resolver. Options: (a) add an address index to walletRepository, (b) batch-resolve via RPC to Rumble server, (c) maintain a cached mapping. Decision deferred to Phase 2 implementation.

---

### 13.7 Rumble Enrichment Implementation Footprint

| File | Change | Phase |
|---|---|---|
| `rumble-data-shard-wrk/workers/proc.shard.data.wrk.js` | **OVERRIDE** `processTransferGroup()` — call `super()` + `enrichTransferGroup()` at **write time** | Phase 2 |
| `rumble-data-shard-wrk/workers/lib/transfer.enricher.js` | **NEW** — `enrichTransferGroup()` function. Queries `txWebhookRepository`, resolves counterparty, classifies activity subtype, populates `appTip`, `appContext`, `appResolved`. All at write time. | Phase 2 |
| `rumble-data-shard-wrk/workers/api.shard.data.wrk.js` | **ADD/OVERRIDE** — `getWalletTransferHistory()`, `getUserTransferHistory()` to support `activitySubtype` filter (simple query param → MongoDB filter) | Phase 2 |
| `rumble-app-node/workers/lib/server.js` | **ADD** 2 route definitions with `activitySubtype` query param | Phase 2 |
| `rumble-app-node/workers/lib/services/ork.js` | **ADD** 2 RPC proxy methods that forward `activitySubtype` | Phase 2 |
| `rumble-data-shard-wrk/workers/lib/db/` | **POSSIBLY MODIFY** — add address-to-wallet reverse lookup index or query method | Phase 2 |

---

### 13.8 Worked Examples

#### Example 1: User sends a rant (tip with message) to a channel

**Stored document — Phase 1 (core processing only, Rumble fields null):**
```jsonc
{
  "transactionHash": "0xabc...",
  "type": "sent",
  "direction": "out",
  "amount": "5000000",
  "token": "usdt",
  "from": "0x_user_addr",
  "to": "0x_channel_tipjar_addr",
  "fromMeta": { "addressType": "EVM_ADDRESS", "isSelf": true, "appResolved": null },
  "toMeta": { "addressType": "EVM_ADDRESS", "isSelf": false, "appResolved": null },
  "appActivitySubtype": null,
  "appContext": null,
  "appTip": null
}
```

**Stored document — Phase 2 (core + Rumble enrichment, all at write time):**
```jsonc
{
  "transactionHash": "0xabc...",
  "type": "sent",
  "direction": "out",
  "amount": "5000000",
  "token": "usdt",
  "from": "0x_user_addr",
  "to": "0x_channel_tipjar_addr",
  "fromMeta": { "addressType": "EVM_ADDRESS", "isSelf": true },
  "toMeta": { "addressType": "EVM_ADDRESS", "isSelf": false },
  "fromAppResolved": { "displayName": "JohnDoe", "entityType": "user", "avatarUrl": "https://..." },
  "toAppResolved": { "displayName": "TechChannel", "entityType": "channel_tipjar", "avatarUrl": "https://..." },
  "appActivitySubtype": "rant",
  "appContext": { "appFlow": "rant", "referenceId": "wh_abc123" },
  "appTip": {
    "tipId": "wh_abc123",
    "tipType": "rant",
    "tipDirection": "sent",
    "counterparty": { "displayName": "TechChannel", "entityType": "channel_tipjar", "avatarUrl": "https://..." },
    "appContent": { "contentId": "v12345", "contentType": "livestream", "message": "Great stream!" }
  }
}
```

#### Example 2: Channel receives a plain tip

**Stored document — Phase 2 — from the channel's perspective:**
```jsonc
{
  "transactionHash": "0xdef...",
  "type": "received",
  "direction": "in",
  "amount": "1000000",
  "token": "usdt",
  "from": "0x_tipper_addr",
  "to": "0x_channel_tipjar_addr",
  "fromMeta": { "addressType": "EVM_ADDRESS", "isSelf": false },
  "toMeta": { "addressType": "EVM_ADDRESS", "isSelf": true },
  "fromAppResolved": { "displayName": "GenViewer42", "entityType": "user", "avatarUrl": "https://..." },
  "toAppResolved": { "displayName": "TechChannel", "entityType": "channel_tipjar", "avatarUrl": "https://..." },
  "appActivitySubtype": "tip",
  "appContext": { "appFlow": "tip", "referenceId": "wh_def456" },
  "appTip": {
    "tipId": "wh_def456",
    "tipType": "tip",
    "tipDirection": "received",
    "counterparty": { "displayName": "GenViewer42", "entityType": "user", "avatarUrl": "https://..." },
    "appContent": { "contentId": "v67890", "contentType": "video", "message": null }
  }
}
```

#### Example 3: Regular transfer (not a tip)

**Stored document — Phase 2:**
```jsonc
{
  "transactionHash": "0xghi...",
  "type": "sent",
  "direction": "out",
  "amount": "50000000",
  "token": "usdt",
  "from": "0x_sender",
  "to": "0x_recipient",
  "fromMeta": { "addressType": "EVM_ADDRESS", "isSelf": true },
  "toMeta": { "addressType": "EVM_ADDRESS", "isSelf": false },
  "fromAppResolved": { "displayName": "JohnDoe", "entityType": "user", "avatarUrl": "https://..." },
  "toAppResolved": { "displayName": "JaneSmith", "entityType": "user", "avatarUrl": "https://..." },
  "appActivitySubtype": "transfer",
  "appContext": null,
  "appTip": null
}
```

For regular transfers, `appContext` and `appTip` remain null. Only `appActivitySubtype` is set to `"transfer"` and `fromAppResolved`/`toAppResolved` are populated (if the counterparty is a known Rumble entity).

---

## 14. Migration & Backfill

### Scope

Historical transfers already stored in `wdk_data_shard_wallet_transfers_v2` need to be processed into the new `wdk_data_shard_wallet_transfers_processed` collection. Per lead dev decision, this is a **one-time migration for Rumble only** — no need to re-run indexers.

### Approach

A migration script reads from `wallet_transfers_v2`, groups by `transactionHash`, runs `processTransferGroup()` for each group, and writes to `wallet_transfers_processed`.

```
Migration script
  → Read from wdk_data_shard_wallet_transfers_v2 (sorted by walletId, ts)
  → Group by (walletId, transactionHash) — use Map<txHash, transfer[]> approach
  → For each group:
      → Look up wallet from walletRepository (need addresses for direction/change detection)
      → Call processTransferGroup(transfers, walletAddresses, wallet)
      → If Rumble: call enrichTransferGroup() (counterparty, tips, app context)
      → Upsert into wallet_transfers_processed
  → Log progress and errors
```

### Key considerations

- **Grouping from flat records:** Since `wallet_transfers_v2` is sorted by `(walletId, ts)`, same-hash records are NOT guaranteed adjacent. The migration script must buffer by `transactionHash` (same concern as v3 Nuance 1, but only relevant for this one-time script).
- **Wallet address lookup:** Each group needs the wallet's address list. Batch-load wallets to avoid per-group DB lookups.
- **Rumble enrichment:** The migration should run with Rumble's extended `processTransferGroup()` so that Rumble-specific fields are populated from historical webhook data.
- **Idempotency:** Use upsert (on `walletId + transactionHash`) so the script can be re-run safely.
- **Performance:** Process in batches (e.g., 1000 wallets at a time). The `wallet_transfers_v2` collection may be large, but each wallet's data is small.
- **Validation:** After migration, spot-check a sample of documents in `wallet_transfers_processed` against the raw data in `wallet_transfers_v2` to verify correctness.
