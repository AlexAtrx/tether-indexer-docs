# Transaction History API v2 — Definitive Specification

> **Status:** Approved for Phase 1 implementation
> **Last updated:** 2026-02-09
> **Audience:** All team members (PO, PM, FE, BE)

---

## Table of Contents

1. [Problem Statement](#1-problem-statement)
2. [Solution Overview](#2-solution-overview)
3. [Architecture](#3-architecture)
4. [API Contract](#4-api-contract)
5. [Response Schema](#5-response-schema)
6. [Aggregation Logic](#6-aggregation-logic)
7. [Chain-Specific Behavior](#7-chain-specific-behavior)
8. [Phase 1 vs Phase 2 Scope](#8-phase-1-vs-phase-2-scope)
9. [Known Gaps](#9-known-gaps)
10. [Implementation Footprint](#10-implementation-footprint)
11. [Glossary](#11-glossary)

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

- **No new service or deployment.** This is a read-side aggregation module added to the existing backend.
- **No schema migrations.** No changes to the database or indexed data.
- **No breaking changes.** Existing `/token-transfers` endpoints remain untouched.
- **Two new endpoints** that return grouped, enriched transaction objects.
- **Modular design:** Core chain-level logic is reusable across apps (Tether Wallet, etc.). App-specific enrichment (Rumble tips, counterparty resolution) is a separate layer that plugs in on top.

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

### Where it lives

```
Request flow (same as existing endpoints):

  FE/Client
    → wdk-app-node         (HTTP route definition + auth)
    → wdk-ork-wrk          (RPC gateway)
    → wdk-data-shard-wrk   (aggregation logic + data access)
    → MongoDB              (existing wdk_data_shard_wallet_transfers_v2 collection)
```

### Module design

```
wdk-data-shard-wrk/
  workers/
    api.shard.data.wrk.js              ← ADD: getWalletTransferHistory, getUserTransferHistory
    lib/
      transfer.parser.js               ← NEW: parseTransferGroup() + static chain/token config

wdk-app-node/
  workers/
    lib/
      server.js                        ← ADD: 2 route definitions
      services/ork.js                  ← ADD: 2 RPC proxy methods
      middlewares/response.validator.js ← ADD: response schemas for new endpoints

rumble-app-node/  (mirror changes)
rumble-data-shard-wrk/  (mirror changes if rumble-specific enrichment is added)
```

**Core module** (`transfer.parser.js`): Pure chain-level grouping and enrichment. No app-specific logic. Reusable by any app.

**Rumble addons** (Phase 2): A separate enricher that resolves counterparty identities, tip information, and app context. Plugs in after the core parser runs.

---

## 4. API Contract

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

### 4.3 Existing Endpoints (Unchanged)

These continue to work exactly as before. **No breaking changes.**

| Endpoint | Status |
|---|---|
| `GET /api/v1/wallets/:walletId/token-transfers` | Unchanged — returns flat raw transfers |
| `GET /api/v1/users/:userId/token-transfers` | Unchanged — returns flat raw transfers |
| `GET /api/v1/chains` | Unchanged — returns supported blockchains/tokens |

---

## 5. Response Schema

### TransferHistoryObject

Every item in the `transfers` array has this shape. Field naming follows these rules:
- Fields that exist in the current `/token-transfers` response **keep the exact same name and format**.
- New fields are clearly marked as **NEW**.

```jsonc
{
  // ─── IDENTITY ───
  "transactionHash": "0xabc123...",       // same as existing

  // ─── TIMING ───
  "ts": 1707222200000,                    // same as existing — epoch ms
  "updatedAt": 1707222200000,             // NEW — same as ts for confirmed txs;
                                           //        will differ for pending→confirmed (Phase 2)

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
  "amount": "1000000",                    // same as existing — string, smallest unit
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
                                           //   Phase 2: { "displayName", "entityType", "avatarUrl" }
  },
  "toMeta": {                             // NEW — same shape as fromMeta
    "addressType": "EVM_ADDRESS",
    "isSelf": false,
    "appResolved": null
  },

  // ─── FEES ───
  "fees": {                               // NEW
    "sponsored": true,                    //   true when label === "paymasterTransaction"
    "networkFee": null                    //   Phase 1: null
                                           //   Phase 2: { "value", "token", "symbol", "decimals" }
  },

  // ─── LINKS ───
  "explorerUrl": "https://etherscan.io/tx/0x...",  // NEW — null if no explorer for this chain

  // ─── LABEL ───
  "label": "transaction",                // same as existing — "transaction" | "paymasterTransaction"

  // ─── WALLET ─── (only in user-level endpoint)
  "walletId": "052d6e5d-...",            // same as existing — only present in /users/:userId/transfer-history

  // ─── APP-LEVEL (Rumble Addons) ─── all null in Phase 1
  "appActivitySubtype": null,             // NEW — Phase 2: "transfer" | "tip"
  "appContext": null,                     // NEW — Phase 2: { "appFlow", "referenceId" }
  "appTip": null,                        // NEW — Phase 2: { "tipId", "tipDirection", "counterparty", "appContent" }

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

## 6. Aggregation Logic

This is the core of the feature — a pure function that takes raw transfer records sharing the same `transactionHash` and produces one logical transaction object.

### Step-by-step

For a given query `(walletId, blockchain?, token?, timeRange)`:

1. **Stream** raw transfers from `walletTransferRepository.getTransfersForWalletInRange` (same data source as existing endpoint).
2. **Filter** by `blockchain` and `token` if provided.
3. **Group** by `transactionHash`. Each group = one logical transaction.
4. **For each group**, compute:

| Field | Logic |
|---|---|
| **direction** | If any transfer has `from` in wallet addresses → `out`. If any has `to` in wallet addresses (and `from` is external) → `in`. If both `from` and `to` are wallet addresses → `self`. |
| **type** | `out` → `sent`, `in` → `received`, `self` → `sent`. (Extended to `swap_out`/`swap_in` when swap partner addresses are configured.) |
| **isChange** | For each underlying transfer: `true` if direction is `out` AND `to` is one of the wallet's own addresses. |
| **from / to** | For `out`: `from` = wallet address, `to` = the non-change recipient. For `in`: `from` = external sender, `to` = wallet address. |
| **amount** | For `out`: sum of non-change output amounts. For `in`: sum of amounts where `to` = wallet address. |
| **sponsored** | `true` if any transfer in the group has `label === 'paymasterTransaction'`. |
| **fiatAmount** | Carried from the primary transfer (non-change for out, wallet-received for in). |
| **explorerUrl** | Built from `blockchain` + `transactionHash` via static explorer URL map. |

5. **Filter** by `type` if provided.
6. **Sort** by `ts` (ascending or descending).
7. **Paginate** using `skip` + `limit`.

### Why `known_addresses` is NOT needed

The original analysis proposed a `known_addresses` query parameter for the FE to pass the user's addresses. **This is unnecessary** because the wallet-based endpoint already resolves all addresses belonging to the wallet via `wallet.addresses`. The wallet knows its own addresses — no external input is needed.

This is a key simplification over the analysis doc's address-based approach.

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
- `amount`: `"50000000"` (0.5 BTC — the non-change output only)
- `from`: sender address
- `to`: recipient address (the non-change output)
- `underlyingTransfers[0].isChange`: `false`
- `underlyingTransfers[1].isChange`: `true`

Change detection works because the wallet knows all its addresses. If a `to` address belongs to the same wallet and the transaction direction is `out`, it's a change output.

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
| Rumble addon fields | Present in schema as `null` — FE can build layouts |

### Phase 2 — Future work (separate tasks)

| Feature | What's needed |
|---|---|
| **Swap detection** (`swap_out` / `swap_in`) | Configure known swap partner addresses |
| **Fee breakdown** (`fees.networkFee`) | Index fee data during block processing, or call RPC at query time |
| **Pending/Failed status** | Add a `pending_transactions` collection; write on tx submission, update on confirmation/failure |
| **Counterparty resolution** (`appResolved`) | Address → user identity mapping service |
| **Tip information** (`appTip`) | Tips service/database that can be queried by txHash |
| **App context** (`appContext`) | FE/BE tags transactions at submission time with flow + reference ID |
| **USD value at time of tx** | Historical price oracle integration |

---

## 9. Known Gaps

| # | Gap | Impact | Mitigation |
|---|---|---|---|
| 1 | No fee data indexed | `fees.networkFee` is null in Phase 1 | `fees.sponsored` flag is available. Full fee data requires indexing changes (Phase 2). |
| 2 | No pending/failed tx tracking | `status` is always `"confirmed"` | Indexer only processes confirmed blocks. Pending tracking requires a new write path (Phase 2). |
| 3 | BTC inputs not stored | Cannot compute exact BTC network fees | Inputs are not indexed — only outputs/vouts. Accept this gap or index inputs in Phase 2. |
| 4 | No address → user registry in indexer | Cannot resolve counterparty identity | Rumble addon (Phase 2) queries an external user service. |
| 5 | No tip data in indexer | Cannot populate `appTip` | Rumble addon (Phase 2) queries a tips service. |
| 6 | No historical price oracle | `fiatAmount` only available when stored at ingestion time | Already stored for most transfers via `price.calculator.js`. Gaps exist for older data. |
| 7 | Spark / Lightning transfer format | Not fully verified | Verify Spark worker's transfer record format before testing. |

---

## 10. Implementation Footprint

### Files changed

| File | Change |
|---|---|
| `wdk-data-shard-wrk/workers/lib/transfer.parser.js` | **NEW** — `parseTransferGroup()` + static config maps (rail, chainId, networkName, explorerUrl, tokenMeta) |
| `wdk-data-shard-wrk/workers/api.shard.data.wrk.js` | **ADD** — `getWalletTransferHistory()` + `getUserTransferHistory()` methods |
| `wdk-app-node/workers/lib/server.js` | **ADD** — 2 route definitions |
| `wdk-app-node/workers/lib/services/ork.js` | **ADD** — 2 RPC proxy methods |
| `wdk-app-node/workers/lib/middlewares/response.validator.js` | **ADD** — response schemas for new endpoints |

### Files NOT changed

- Existing `getWalletTransfers` / `getUserTransfers` — untouched, backward-compatible
- Transfer storage / ingestion (`proc.shard.data.wrk.js`) — untouched
- Database schema / repositories — untouched
- Price calculator — untouched

### Rumble mirror

Per project convention, changes to `wdk-app-node` and `wdk-data-shard-wrk` must be mirrored in `rumble-app-node` and `rumble-data-shard-wrk` respectively.

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
| **Rumble Addons** | App-specific enrichment layer (tip info, counterparty resolution, app context). Null in Phase 1. Separate from core chain-level logic. |
| **Core module** | The reusable chain-level aggregation logic (`transfer.parser.js`). Contains no app-specific code. Can be used by Tether Wallet, Rumble, or any other app. |

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
