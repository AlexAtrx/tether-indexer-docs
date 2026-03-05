# Transaction History v2 — Complete Implementation Summary

> **Feature status:** Phase 1 complete, shipped
> **Branch:** `feat/transaction-history-v2` across all 14 repos
> **Dates:** Feb 6–13, 2026
> **Scope:** 14 repositories, ~2,630 lines added (initial), response reduction follow-up across 3 repos

---

## 1. Problem Statement

The existing `token-transfers` endpoints return flat, raw transfer records — one record per on-chain output/event:

| Chain | What the user did | What the app showed |
|-------|-------------------|---------------------|
| **EVM** | Sent 100 USDT to a friend | 2 entries: one USDT transfer, one gas payment |
| **BTC** | Sent 0.5 BTC to a friend | 2 entries: one to recipient (0.5 BTC), one change output back to sender (0.3 BTC) |

The frontend had no reliable way to group these into a single logical transaction. Building custom grouping per chain in the FE is unscalable.

**Goal:** A backend API that returns **one logical transaction per user action**, with all chain-specific details already resolved.

---

## 2. Solution Overview

- **No new service or deployment.** Processing happens in existing indexer and data-shard workers.
- **One new MongoDB collection:** `wdk_data_shard_wallet_transfers_processed` — one document per logical transaction.
- **Two new HTTP endpoints:**
  - `GET /api/v1/wallets/:walletId/transfer-history`
  - `GET /api/v1/users/:userId/transfer-history`
- **No breaking changes.** Existing `/token-transfers` endpoints remain untouched.
- **Write-time architecture:** Grouping happens at ingestion time in indexer workers. The data-shard stores and serves pre-processed data — no chain awareness at read time.
- **Dual-write:** Both `wallet_transfers_v2` (legacy) and `wallet_transfers_processed` (new) are written, ensuring zero disruption to existing consumers.
- **Two-layer design:** Core chain-level logic in `wdk-*` repos, app-specific enrichment (Rumble tips, counterparty resolution) in `rumble-*` repos via a hook-based extension.

---

## 3. Architecture

### Write Path

```
Indexer Workers (per chain: EVM, BTC, Tron, TON, Solana, Spark)
    │
    ├─ existing: per-transfer CSV → Redis stream (unchanged)
    │
    └─ new: grouped JSON → @wdk/grouped-transactions:{chain}:{token}
                │
                ▼
        Processor Worker (wdk-indexer-processor-wrk)
            - Resolves shard assignments for wallet addresses
            - Forwards to per-shard stream
                │
                ▼
    @wdk/grouped-transactions:shard-{shardGroup}
                │
                ▼
        Data Shard Proc Worker (wdk-data-shard-wrk)
            ├─ TransferProcessor.processTransferGroup()
            ├─ _enrichProcessedTransfer() hook → Rumble override
            ├─ dual-write: wallet_transfers_v2 (legacy, unchanged)
            └─ dual-write: wallet_transfers_processed (new, grouped)
```

### Read Path

```
Client
    │
    ▼
App Node (wdk-app-node / rumble-app-node) — HTTP route
    │
    ▼
Ork Worker (wdk-ork-wrk / rumble-ork-wrk) — RPC gateway
    │
    ▼
Data Shard API Worker (wdk-data-shard-wrk)
    ├─ getWalletTransferHistory() — queries wallet_transfers_processed
    ├─ getUserTransferHistory() — queries across all user wallets
    └─ mapProcessedToResponse(doc, userId) — converts stored doc to API shape
    │
    ▼
Client receives flat, minimal JSON response
```

### Two-Layer Design

| | Layer 1: Core (WDK) | Layer 2: Rumble Enrichment |
|---|---|---|
| **Grouping** | `wdk-indexer-wrk-*` at ingestion time | Uses core output |
| **Processing** | `wdk-data-shard-wrk` `processTransferGroup()` | `rumble-data-shard-wrk` enrichment via hook |
| **Storage** | `wallet_transfers_processed` — generic fields | Same collection, Rumble fields added |
| **Serving** | `wdk-app-node` — simple query | `rumble-app-node` — same query + Rumble params |
| **Domain knowledge** | Blockchain only | Rumble-specific (users, channels, tips, rants) |
| **Reusable by** | Any app | Rumble only |

---

## 4. Repository Changes (14 repos)

### 4.1 wdk-indexer-wrk-base — PR [#76](https://github.com/tetherto/wdk-indexer-wrk-base/pull/76)

- Added `_publishGroupedTransfers()`: groups transfers by `transactionHash` using a `Map`, publishes each group as JSON to `@wdk/grouped-transactions:{chain}:{token}`
- Added `grouped_transaction` event type constant
- Modified `_storeAndPublishBatch()` to call both `_publishTransfers` (existing CSV) and `_publishGroupedTransfers` (new JSON)
- Added **tx-hash boundary guard** in `syncTxns()`: tracks `currentTxHash`, delays batch flush until txHash changes — prevents mid-transaction splits across batches

**Files:** `workers/proc.indexer.wrk.js`, `workers/lib/constants.js`

### 4.2 wdk-indexer-wrk-btc — PR [#96](https://github.com/tetherto/wdk-indexer-wrk-btc/pull/96)

- Dependency update only. BTC block iterator already processes all vouts per tx together; base class boundary guard handles batch safety.

### 4.3 wdk-indexer-wrk-evm — PR [#92](https://github.com/tetherto/wdk-indexer-wrk-evm/pull/92)

- Dependency update only. EVM event-driven indexer processes all transfers per block together.

### 4.4 wdk-indexer-wrk-tron — PR [#76](https://github.com/tetherto/wdk-indexer-wrk-tron/pull/76)

- Dependency update only.

### 4.5 wdk-indexer-wrk-ton — PR [#82](https://github.com/tetherto/wdk-indexer-wrk-ton/pull/82)

- Replaced `_storeBatch` calls with `_storeAndPublishBatch` in `proc.indexer.jet.wrk.js` so grouped events are published
- Added `currentTxHash` tracking with tx-hash boundary guard

**Files:** `workers/proc.indexer.jet.wrk.js`, `package.json`

### 4.6 wdk-indexer-wrk-solana — PR [#72](https://github.com/tetherto/wdk-indexer-wrk-solana/pull/72)

- Dependency update only.

### 4.7 wdk-indexer-wrk-spark — PR [#71](https://github.com/tetherto/wdk-indexer-wrk-spark/pull/71)

- Replaced `_storeBatch` calls with `_storeAndPublishBatch` (Spark was bypassing Redis publishing entirely)

**Files:** `workers/proc.indexer.spark.wrk.js`, `package.json`

### 4.8 wdk-indexer-processor-wrk — PR [#10](https://github.com/tetherto/wdk-indexer-processor-wrk/pull/10)

- Added consumption of `@wdk/grouped-transactions:{chain}:{token}` Redis stream
- Resolves shard assignments for involved wallet addresses
- Forwards messages to per-shard `@wdk/grouped-transactions:shard-{shardGroup}` streams

**Files:** `workers/indexer.processor.wrk.js`, `workers/lib/constants.js`

### 4.9 wdk-data-shard-wrk — PR [#168](https://github.com/tetherto/wdk-data-shard-wrk/pull/168) — LARGEST CHANGE (~1,471 lines)

#### New MongoDB Collection: `wallet_transfers_processed`
- Repository: `workers/lib/db/mongodb/repositories/wallet.transfers.processed.js`
- Indexes:
  - `{walletId, transactionHash}` — unique primary key
  - `{walletId, ts}` — query index
  - `{walletId, blockchain, token, type, ts}` — filter index
  - `{ts}` — timestamp sort
  - `{walletId, appActivitySubtype, ts}` — Rumble activity filter

#### TransferProcessor (`workers/lib/transfer.processor.js`)

Core class that converts raw transfer arrays into single logical transactions:

1. **Direction computation:** `out`/`in`/`self` based on wallet address matching
2. **Type classification:** `sent`/`received`/`swap_out`/`swap_in` (configurable swap partners via `SWAP_PARTNERS` map)
3. **Underlying transfers:** Maps raw transfers, marks `isChange` flag (outputs returning to wallet on outgoing txs)
4. **Participant resolution:** Primary from/to (non-change for out, wallet-received for in)
5. **Amount summation:**
   - BTC: `parseFloat` (UTXO amounts are decimal strings like `"0.5"`)
   - Other chains: `BigInt` (token amounts are integer strings like `"1000000"`)
   - Excludes change outputs for outgoing transactions
6. **Paymaster detection:** `sponsored = transfers.some(t => t.label === 'paymasterTransaction')`
7. **Label resolution:** `label = transfers.find(t => t.label)?.label || 'transaction'`
8. **Metadata enrichment:** Rails, explorer URLs, token symbols/decimals from static config maps
9. **Fiat propagation:** Carries `fiatAmount`/`fiatCcy` from primary transfer

#### Static Config (`workers/lib/transfer.config.js`)

Frozen maps:
- `RAIL_MAP`: blockchain → `{rail, chainId, networkName}` (e.g., `ethereum → {rail: 'EVM', chainId: 1, networkName: 'Ethereum'}`)
- `EXPLORER_MAP`: blockchain → explorer URL base
- `TOKEN_META_MAP`: token → `{symbol, decimals}`
- `ADDRESS_TYPE_MAP`: rail → address type string
- `SWAP_PARTNERS`: empty by default, configured per deployment

#### Proc Worker (`workers/proc.shard.data.wrk.js`)

- `_consumeGroupedLoop()`: continuously reads `@wdk/grouped-transactions:shard-{shardGroup}` stream
- `_processGroupedMessageBatch(messages)`:
  1. Parse JSON → transfers array + walletId
  2. Validate wallet exists, get addresses
  3. Call `transferProcessor.processTransferGroup(transfers, walletAddresses, wallet)`
  4. Call `_enrichProcessedTransfer(processedDoc, ctx)` hook (no-op in base, overridden by Rumble)
  5. Dual-write to `walletTransfersProcessedRepository` and `walletTransferRepository`

#### API Worker (`workers/api.shard.data.wrk.js`)

- `getWalletTransferHistory(req)`: validates userId + walletId ownership, queries processed collection with filters (blockchain, token, type, activitySubtype, timestamp range), pagination (skip/limit), sort
- `getUserTransferHistory(req)`: same across all user wallets (optional `walletTypes` filter)
- `mapProcessedToResponse(doc, userId)`: converts stored document to API response shape (see Section 6)

#### Migration Script (`scripts/migrate-wallet-transfers-processed.js`)

- Reads from `wallet_transfers_v2`, groups by `(walletId, transactionHash)`
- Calls `processTransferGroup()` for each group
- Accepts optional `enricher` callback for Rumble-specific enrichment
- Upserts into `wallet_transfers_processed` in batches of 500 wallets at a time
- Idempotent: uses upsert on `{walletId, transactionHash}` primary key

**New files:** `transfer.processor.js`, `transfer.config.js`, `wallet.transfers.processed.js`, `migrate-wallet-transfers-processed.js`, `transfer.processor.test.js`, `map.processed.to.response.test.js`

### 4.10 wdk-ork-wrk — PR [#80](https://github.com/tetherto/wdk-ork-wrk/pull/80)

- Added `getWalletTransferHistory` and `getUserTransferHistory` RPC action methods

**Files:** `workers/api.ork.wrk.js`

### 4.11 wdk-app-node — PR [#69](https://github.com/tetherto/wdk-app-node/pull/69)

- Added both HTTP routes with Fastify schema validation (params + querystring)
- Added ork service proxy methods
- Added `transferHistoryItemSchema` and `transferHistoryResponseSchema` in response validator
- Auth: Bearer token or `x-secret-token` via `runGuards`

**Files:** `workers/lib/server.js`, `workers/lib/services/ork.js`, `workers/lib/middlewares/response.validator.js`

### 4.12 rumble-data-shard-wrk — PR [#169](https://github.com/tetherto/rumble-data-shard-wrk/pull/169)

#### Transfer Enricher (`workers/lib/transfer.enricher.js`)

`enrichTransferGroup(processed, { db, walletAddresses, cache })`:
1. Queries `txWebhookRepository.findByTransactionHash()` for webhook data
2. Classifies `appActivitySubtype`: `'transfer'` (default), `'tip'`, `'rant'`
3. Populates `appTip`:
   - `tipDirection`: `'sent'`/`'received'` based on whether wallet is sender or receiver
   - `counterparty`: `{displayName, entityType, avatarUrl}` via `resolveAddress()`
   - `appContent`: `{message}` for rants (set from `webhook.payload`), `null` for tips
4. Resolves `fromAppResolved`/`toAppResolved` via wallet address reverse lookup with LRU caching

#### Proc Worker Override

Overrides `_enrichProcessedTransfer()` hook. Falls back to unenriched doc on failure (graceful degradation).

**New files:** `transfer.enricher.js`, `transfer.enricher.test.js`

### 4.13 rumble-app-node — PR [#146](https://github.com/tetherto/rumble-app-node/pull/146)

- Added both HTTP routes with full Swagger/OpenAPI annotations
- Added ork service proxy methods
- Response schemas include Rumble addon fields (`subType`, `tipDirection`, `message`) — required because Fastify uses response schemas for serialization and strips unlisted fields

**Files:** `workers/lib/server.js`, `workers/lib/services/ork.js`

### 4.14 rumble-ork-wrk — PR [#103](https://github.com/tetherto/rumble-ork-wrk/pull/103)

- Added both RPC action methods

**Files:** `workers/api.ork.wrk.js`

---

## 5. Response Reduction (Feb 12–13 follow-up)

After the initial implementation shipped, the lead developer reviewed the API responses and requested a reduction — fewer fields, flatter structure. The processing pipeline, stored documents, enrichment logic, and migration script are unchanged. Only the API response mapping and validation schemas changed.

### What was dropped

| Dropped field(s) | Reason |
|-------------------|--------|
| `rail`, `chainId`, `networkName` | FE derives from `blockchain` |
| `symbol`, `decimals` | FE derives from `token` |
| `direction` (`in`/`out`/`self`) | Redundant with `type` (`sent`/`received`/`swap_out`/`swap_in`) |
| `explorerUrl` | FE builds from `blockchain` + `transactionHash` |
| `fromMeta`, `toMeta` (nested objects) | Replaced by flat `fromUserId`/`toUserId` (null for now) |
| `fees` (nested object) | Replaced by flat `fee`/`feeToken`/`feeLabel` |
| `label` | Replaced by `feeLabel` |
| `underlyingTransfers[]` | Less duplicate data; detail endpoint can be added later |
| `appActivitySubtype` | Renamed to `subType` in Rumble addon |
| `appContext` | Dropped — webhooks are temporary data |
| `appTip` (nested object) | Replaced by flat `tipDirection` + `message` |

### What was added

| New field | Source |
|-----------|--------|
| `userId` | From request context (wallet owner) |
| `blockNumber` | Promoted from `underlyingTransfers[0].blockNumber` |
| `fromUserId` | `null` for now — future address-to-user mapping |
| `toUserId` | `null` for now — future work |
| `fee` | `null` for now — fee extraction is next priority |
| `feeToken` | `null` for now |
| `feeLabel` | Derived from `doc.sponsored`: `true` → `'paymaster'`, `false` → `'gas'` |
| `subType` (Rumble) | Renamed from `appActivitySubtype` |
| `tipDirection` (Rumble) | From `appTip.tipDirection` |
| `message` (Rumble) | From `appTip.appContent.message` (rants only; tips have `appContent: null` upstream) |

### Files changed in response reduction

| File | Change |
|------|--------|
| `wdk-data-shard-wrk/workers/api.shard.data.wrk.js` | Rewrote `mapProcessedToResponse()` from spread-based to explicit allowlist; added `userId` param; derives `feeLabel` from `doc.sponsored`; conditionally includes Rumble fields; exported as `_mapProcessedToResponse` for testing |
| `wdk-app-node/workers/lib/middlewares/response.validator.js` | Replaced `transferHistoryItemSchema` with reduced field set; `additionalProperties: true` for Rumble passthrough |
| `rumble-app-node/workers/lib/server.js` | Replaced both Swagger response schemas (wallet-level + user-level) with flat shape including Rumble addon fields |

### Bug fix during response reduction

The original plan derived `feeLabel` from `doc.label` (`doc.label === 'paymasterTransaction' ? 'paymaster' : 'gas'`). Code review identified a regression: `doc.label` uses `.find()` (first labeled transfer wins) while `doc.sponsored` uses `.some()` (true if *any* transfer is a paymaster transaction). In a group like `['transaction', 'paymasterTransaction']`, `doc.label` would be `'transaction'` but `doc.sponsored` would be `true`. Fixed to derive from `doc.sponsored` instead, preserving the exact semantics of the old `fees.sponsored` field.

---

## 6. Final API Response Shape

### WDK Base Layer

```jsonc
{
  "userId": "user-123",
  "walletId": "052d6e5d-...",
  "transactionHash": "0xabc123...",
  "blockNumber": 12345,               // from underlyingTransfers[0], null if empty

  "ts": 1707222200000,                // block timestamp (epoch ms)
  "updatedAt": 1707222200000,         // equals ts in Phase 1

  "blockchain": "ethereum",
  "token": "usdt",

  "type": "sent",                     // "sent" | "received" | "swap_out" | "swap_in"
  "status": "confirmed",              // Phase 1: always "confirmed"

  "amount": "1000000",                // raw chain format (app converts using token decimals)
  "fiatAmount": "100.50",             // nullable
  "fiatCcy": "usd",                   // nullable

  "from": "0xabc...",
  "fromUserId": null,                 // null for now — future work
  "to": "0xdef...",
  "toUserId": null,                   // null for now — future work

  "fee": null,                        // null for now — fee extraction next priority
  "feeToken": null,                   // null for now
  "feeLabel": "gas"                   // "gas" | "paymaster" — derived from doc.sponsored
}
```

### Rumble Addon Fields (conditionally included when `appActivitySubtype` is set on stored doc)

```jsonc
{
  "subType": "rant",                  // "transfer" | "tip" | "rant"
  "tipDirection": "sent",             // "sent" | "received" — nullable
  "message": "Great stream!"          // rant text — nullable, only populated for rants
}
```

### Query Parameters (both endpoints)

| Param | Type | Description |
|-------|------|-------------|
| `token` | string | Filter by token identifier (e.g., `usdt`, `btc`) |
| `blockchain` | string | Filter by blockchain network |
| `type` | enum | `sent`, `received`, `swap_out`, `swap_in` |
| `activitySubtype` | enum | Rumble only: `transfer`, `tip`, `rant` |
| `from` | integer | Start timestamp filter (inclusive, unix ms) |
| `to` | integer | End timestamp filter (inclusive, unix ms) |
| `limit` | integer | Max results (default 10) |
| `skip` | integer | Pagination offset (default 0) |
| `sort` | enum | `asc` or `desc` by timestamp (default `desc`) |
| `walletTypes` | array | User endpoint only: filter by wallet type |

---

## 7. Stored Document Shape

The document in `wallet_transfers_processed` is richer than the API response. The `mapProcessedToResponse()` function selectively extracts fields for the API. Key stored fields not in the response:

- `processedAt` — processing timestamp
- `rail`, `chainId`, `networkName` — network metadata
- `symbol`, `decimals` — token metadata
- `direction` — `in`/`out`/`self`
- `explorerUrl` — block explorer link
- `label` — `'transaction'` or `'paymasterTransaction'`
- `sponsored` — boolean flag for paymaster detection
- `fromMeta`, `toMeta` — address metadata with `addressType`, `isSelf`
- `fromAppResolved`, `toAppResolved` — Rumble-resolved user info
- `underlyingTransfers[]` — raw on-chain transfers with `isChange` flag
- `appActivitySubtype`, `appContext`, `appTip` — Rumble enrichment data

This means future API changes can expose more data without re-processing.

---

## 8. Key Design Decisions

### Write-Time Processing (not Query-Time)

Original v2 spec proposed query-time aggregation in data-shard. Lead developer redirected to write-time processing at indexers. Rationale: blockchain logic stays in indexers, pre-computed results mean faster reads, simpler read path, better scalability.

### Dual-Write for Backward Compatibility

Both `wallet_transfers_v2` (legacy per-transfer) and `wallet_transfers_processed` (new grouped) are written. Existing consumers are unaffected. The two collections can be compared for debugging.

### Hook-Based Extension (not Subclass Inheritance)

Base proc worker defines `_enrichProcessedTransfer(processedDoc, ctx)` as a no-op. Rumble overrides this single method. Less coupled than subclass inheritance — enrichment happens after processing, base class controls call order, Rumble only touches one method.

### Tx-Hash Boundary Guard

For polling-based indexers (BTC, Spark, TON Jetton), batch flushes are delayed when `batch.length >= dbWriteBatchSize` until the txHash changes. Ensures all transfers from the same transaction stay in the same batch for correct grouping.

### Amount Summation Strategy

- **BTC:** `parseFloat()` — UTXO amounts are decimal strings (`"0.5"`)
- **Other chains:** `BigInt()` — token amounts are integer strings (`"1000000"`)
- Change outputs excluded from sum for outgoing transactions

### Swap Detection

Configurable via `SWAP_PARTNERS` address map in `transfer.config.js`. Counterparty address match → `swap_out` (outgoing) or `swap_in` (incoming). Map is frozen at module load, overridable per-instance via constructor for testing.

### feeLabel Derivation

Derived from `doc.sponsored` (boolean, set via `.some()` — true if *any* transfer in group is a paymaster transaction), **not** from `doc.label` (set via `.find()` — first labeled transfer). This prevents misclassification when a non-paymaster transfer appears first in the group.

---

## 9. Test Coverage

### Transfer Processor — 15 tests (`wdk-data-shard-wrk/tests/unit/lib/transfer.processor.test.js`)

- Direction computation (out/in/self)
- Type classification (sent/received/swap_out/swap_in)
- Amount summation (BTC parseFloat vs EVM BigInt)
- Change detection (BTC outputs returning to wallet)
- Paymaster/sponsored detection
- Label normalization
- Static config lookups
- Self-transfers
- Swap detection (outgoing, incoming, no-swap)

### Transfer Enricher — 7 tests (`rumble-data-shard-wrk/tests/unit/lib/transfer.enricher.test.js`)

- Regular transfer classification
- Tip classification and direction
- Rant classification with message payload
- Incoming tip direction
- `appResolved` population via address lookup
- Unknown counterparty handling
- LRU cache behavior

### Response Mapper — 14 tests (`wdk-data-shard-wrk/tests/unit/lib/map.processed.to.response.test.js`)

- Allowlisted fields present, dropped fields absent
- `blockNumber` promotion (populated, empty array, missing `underlyingTransfers`)
- `feeLabel` derivation: `gas` for regular, `paymaster` for sponsored
- Key regression case: `sponsored=true` but `label='transaction'` → correctly outputs `'paymaster'`
- Deferred null fields (`fee`, `feeToken`, `fromUserId`, `toUserId`)
- Nullable fallbacks (`fiatAmount`, `fiatCcy` default to `null`)
- Rumble fields absent when `appActivitySubtype` not set
- Rumble tip: `subType='tip'`, `tipDirection='sent'`, `message=null`
- Rumble rant: `subType='rant'`, `tipDirection='sent'`, `message='Great stream!'`
- Rumble transfer: `subType='transfer'`, no `appTip` object → nulls

**Total: 36 unit tests, all passing.**

---

## 10. Pull Requests

| # | Repo | PR | Summary |
|---|------|----|---------|
| 1 | wdk-indexer-wrk-base | [#76](https://github.com/tetherto/wdk-indexer-wrk-base/pull/76) | Grouped publishing + boundary guard |
| 2 | wdk-indexer-wrk-btc | [#96](https://github.com/tetherto/wdk-indexer-wrk-btc/pull/96) | Dependency update |
| 3 | wdk-indexer-wrk-evm | [#92](https://github.com/tetherto/wdk-indexer-wrk-evm/pull/92) | Dependency update |
| 4 | wdk-indexer-wrk-tron | [#76](https://github.com/tetherto/wdk-indexer-wrk-tron/pull/76) | Dependency update |
| 5 | wdk-indexer-wrk-ton | [#82](https://github.com/tetherto/wdk-indexer-wrk-ton/pull/82) | Jetton batch fix + boundary guard |
| 6 | wdk-indexer-wrk-solana | [#72](https://github.com/tetherto/wdk-indexer-wrk-solana/pull/72) | Dependency update |
| 7 | wdk-indexer-wrk-spark | [#71](https://github.com/tetherto/wdk-indexer-wrk-spark/pull/71) | Spark batch fix |
| 8 | wdk-indexer-processor-wrk | [#10](https://github.com/tetherto/wdk-indexer-processor-wrk/pull/10) | Grouped stream routing |
| 9 | wdk-data-shard-wrk | [#168](https://github.com/tetherto/wdk-data-shard-wrk/pull/168) | Core: collection, processor, API endpoints, migration, tests |
| 10 | wdk-ork-wrk | [#80](https://github.com/tetherto/wdk-ork-wrk/pull/80) | RPC action registration |
| 11 | wdk-app-node | [#69](https://github.com/tetherto/wdk-app-node/pull/69) | HTTP routes + response validation schemas |
| 12 | rumble-data-shard-wrk | [#169](https://github.com/tetherto/rumble-data-shard-wrk/pull/169) | Enrichment: tip/rant classification, counterparty resolution |
| 13 | rumble-app-node | [#146](https://github.com/tetherto/rumble-app-node/pull/146) | HTTP routes + Swagger docs |
| 14 | rumble-ork-wrk | [#103](https://github.com/tetherto/rumble-ork-wrk/pull/103) | RPC action registration |

---

## 11. New Files Created

| File | Repo | Purpose |
|------|------|---------|
| `workers/lib/transfer.processor.js` | wdk-data-shard-wrk | Core transfer grouping logic |
| `workers/lib/transfer.config.js` | wdk-data-shard-wrk | Static config maps (rails, explorers, tokens, swap partners) |
| `workers/lib/db/mongodb/repositories/wallet.transfers.processed.js` | wdk-data-shard-wrk | MongoDB repository for processed collection |
| `scripts/migrate-wallet-transfers-processed.js` | wdk-data-shard-wrk | Backfill migration from `wallet_transfers_v2` |
| `tests/unit/lib/transfer.processor.test.js` | wdk-data-shard-wrk | 15 unit tests for transfer processor |
| `tests/unit/lib/map.processed.to.response.test.js` | wdk-data-shard-wrk | 14 unit tests for response mapper |
| `workers/lib/transfer.enricher.js` | rumble-data-shard-wrk | Rumble tip/rant enrichment + counterparty resolution |
| `tests/unit/lib/transfer.enricher.test.js` | rumble-data-shard-wrk | 7 unit tests for enricher |

---

## 12. What Is NOT Included (Phase 2+)

| Feature | Status | Notes |
|---------|--------|-------|
| Fee extraction (`fee`, `feeToken`) | Null for now | Next priority after this ships. Paymaster fees easier to detect. |
| `fromUserId` / `toUserId` resolution | Null for now | Requires address-to-user mapping service |
| Human-friendly `amount` | Deferred | App handles conversion using token decimals |
| Pending/failed transaction status | Deferred | Indexer only processes confirmed blocks |
| Swap provider names | Deferred | Needs swap provider config |
| Historical price oracle | Deferred | `fiatAmount` only at ingestion time |
| `underlyingTransfers` detail endpoint | Deferred | Can be added if FE needs transfer-level detail |
| MongoDB query projection | Not needed | Response mapper handles field selection; stored doc intentionally richer for future use |

---

## 13. Deployment & Migration

### Boot Order

Standard WDK boot order applies. No new services to deploy — changes are within existing workers.

### Migration

Run backfill script per environment:

```bash
MONGO_URI="mongodb://..." MONGO_DB="wdk_data_shard" \
  node scripts/migrate-wallet-transfers-processed.js
```

For Rumble environments, pass the enricher callback:

```javascript
const enricher = async (doc, { walletAddresses, wallet }) => {
  return await enrichTransferGroup(doc, { db: mongoDb, walletAddresses })
}
await migrate({ enricher })
```

The script is idempotent and can be re-run safely.

### Dependency Chain

All chain indexers depend on `wdk-indexer-wrk-base`. After merging the base, run `npm install` in each dependent repo to pick up the branch reference. The processor depends on the new Redis stream key pattern. Data shard is self-contained (new collection auto-created on first write).

---

## 14. Task History

| Task Directory | Date | Focus |
|----------------|------|-------|
| `0-trx history api` | Early | Initial concept exploration |
| `6-feb-26-trx-history-api-v2` | Feb 6–9 | Comprehensive v2 spec and doability analysis |
| `9-feb-26-trx-history-update-v3` | Feb 9 | v3 spec updates: nuances, Rumble enrichment layer |
| `11-feb-26-execute-plan-trx-history` | Feb 11 | v4 architectural shift to write-time processing; implementation across 14 repos |
| `12-feb-26-update-trx-history-res-data` | Feb 12–13 | Response field reduction based on lead developer review; bug fix; response mapper tests |
