# Transaction History API v2 — Implementation Summary

## Overview

Implemented a new transaction history pipeline that groups raw on-chain transfers by transaction hash at write time, producing one logical transaction per user action. The new pipeline runs in parallel with the existing per-transfer flow (dual-write) and exposes two new read endpoints. No breaking changes to existing endpoints.

**Branch:** `feat/transaction-history-v2` across all 14 repos
**New endpoints:**
- `GET /api/v1/wallets/:walletId/transfer-history`
- `GET /api/v1/users/:userId/transfer-history`

**New collection:** `wdk_data_shard_wallet_transfers_processed`

---

## Architecture

```
Indexer Workers (per chain)
    │
    ├─ existing: per-transfer CSV → Redis stream (unchanged)
    │
    └─ new: grouped JSON → @wdk/grouped-transactions:{chain}:{token}
                │
                ▼
        Processor Worker
                │
                ▼
    @wdk/grouped-transactions:shard-{shardGroup}
                │
                ▼
        Data Shard Worker
            ├─ dual-write: wallet_transfers_v2 (legacy, unchanged)
            ├─ dual-write: wallet_transfers_processed (new, grouped)
            └─ _enrichProcessedTransfer hook → Rumble override
                │
                ▼
        API → Ork → App Node → Mobile client
```

---

## Repos and Changes (14 total, 20 commits, ~2,630 lines added)

### 1. wdk-indexer-wrk-base
**PR:** [tetherto/wdk-indexer-wrk-base#76](https://github.com/tetherto/wdk-indexer-wrk-base/pull/76)

- Added `_publishGroupedTransfers()` method that groups transfers by `transactionHash` using a `Map` and publishes each group as a single JSON message to a dedicated Redis stream (`@wdk/grouped-transactions:{chain}:{token}`)
- Added `grouped_transaction` event type constant
- Modified `_storeAndPublishBatch()` to call both `_publishTransfers` (existing CSV) and `_publishGroupedTransfers` (new JSON) for backward compatibility
- Added tx-hash boundary guard in `syncTxns()`: tracks `currentTxHash` and delays batch flush until the current transaction's transfers are complete, preventing mid-transaction splits across batches
- Resolved the grouped stream pattern in `_start()` using chain/token config

**Files:** `workers/proc.indexer.wrk.js`, `workers/lib/constants.js`

### 2. wdk-indexer-wrk-btc
**PR:** [tetherto/wdk-indexer-wrk-btc#96](https://github.com/tetherto/wdk-indexer-wrk-btc/pull/96)

- Updated `@tetherto/wdk-indexer-wrk-base` dependency to `feat/transaction-history-v2` branch
- No code changes needed — BTC block iterator already processes all vouts for a tx together, and the base class boundary guard handles batch safety

**Files:** `package.json`, `package-lock.json`

### 3. wdk-indexer-wrk-evm
**PR:** [tetherto/wdk-indexer-wrk-evm#92](https://github.com/tetherto/wdk-indexer-wrk-evm/pull/92)

- Updated `@tetherto/wdk-indexer-wrk-base` dependency to `feat/transaction-history-v2` branch
- No code changes needed — EVM event-driven indexer processes all transfers per block together

**Files:** `package.json`, `package-lock.json`

### 4. wdk-indexer-wrk-tron
**PR:** [tetherto/wdk-indexer-wrk-tron#76](https://github.com/tetherto/wdk-indexer-wrk-tron/pull/76)

- Updated `@tetherto/wdk-indexer-wrk-base` dependency to `feat/transaction-history-v2` branch
- No code changes needed — TRON event-driven indexer processes all transfers per block together

**Files:** `package.json`, `package-lock.json`

### 5. wdk-indexer-wrk-ton
**PR:** [tetherto/wdk-indexer-wrk-ton#82](https://github.com/tetherto/wdk-indexer-wrk-ton/pull/82)

- Replaced all three `_storeBatch` calls in `proc.indexer.jet.wrk.js` with `_storeAndPublishBatch` so grouped transaction events are published to Redis
- Added `currentTxHash` tracking with tx-hash boundary guard (same pattern as base) to prevent mid-transaction batch splits
- Updated base dependency to `feat/transaction-history-v2` branch

**Files:** `workers/proc.indexer.jet.wrk.js`, `package.json`, `package-lock.json`

### 6. wdk-indexer-wrk-solana
**PR:** [tetherto/wdk-indexer-wrk-solana#72](https://github.com/tetherto/wdk-indexer-wrk-solana/pull/72)

- Updated `@tetherto/wdk-indexer-wrk-base` dependency to `feat/transaction-history-v2` branch
- No code changes needed — Solana event-driven indexer processes all transfers per block together

**Files:** `package.json`, `package-lock.json`

### 7. wdk-indexer-wrk-spark
**PR:** [tetherto/wdk-indexer-wrk-spark#71](https://github.com/tetherto/wdk-indexer-wrk-spark/pull/71)

- Replaced `_storeBatch` calls in `proc.indexer.spark.wrk.js` with `_storeAndPublishBatch` so grouped events are published (Spark was bypassing Redis publishing entirely)
- Updated base dependency to `feat/transaction-history-v2` branch

**Files:** `workers/proc.indexer.spark.wrk.js`, `package.json`, `package-lock.json`

### 8. wdk-indexer-processor-wrk
**PR:** [tetherto/wdk-indexer-processor-wrk#10](https://github.com/tetherto/wdk-indexer-processor-wrk/pull/10)

- Added consumption of the `@wdk/grouped-transactions:{chain}:{token}` Redis stream
- For each grouped message, resolves shard assignments for involved wallet addresses (from/to)
- Forwards enriched messages to per-shard `@wdk/grouped-transactions:shard-{shardGroup}` streams with walletId added
- Existing per-transfer stream processing remains unchanged

**Files:** `workers/indexer.processor.wrk.js`, `workers/lib/constants.js`

### 9. wdk-data-shard-wrk (largest change — 1,471 lines)
**PR:** [tetherto/wdk-data-shard-wrk#168](https://github.com/tetherto/wdk-data-shard-wrk/pull/168)

#### New Collection
- `wallet_transfers_processed` MongoDB collection with repository (`wallet.transfers.processed.js`)
- Indexes: unique pkey on `{walletId, transactionHash}`, query index on `{walletId, ts}`, filter index on `{walletId, blockchain, token, type, ts}`, activity index on `{walletId, appActivitySubtype, ts}`
- Registered in `context.js` and `unit.of.work.js`

#### TransferProcessor (`workers/lib/transfer.processor.js`)
Core processing class that converts raw transfer arrays into single logical transactions:
- **Direction computation:** `out`/`in`/`self` based on wallet address matching
- **Type classification:** `sent`/`received`/`swap_out`/`swap_in` with configurable swap partner detection via `SWAP_PARTNERS` map
- **Amount summation:** `parseFloat` for BTC (UTXO), `BigInt` for EVM/others
- **Change detection:** Flags transfers where `direction=out` AND `to` is in wallet addresses
- **Paymaster detection:** `sponsored=true` if any transfer has `label=paymasterTransaction`
- **Static config maps:** `RAIL_MAP`, `EXPLORER_MAP`, `TOKEN_META_MAP`, `ADDRESS_TYPE_MAP`, `SWAP_PARTNERS` in `transfer.config.js`
- Accepts `opts.swapPartners` in constructor for testability (frozen global can't be mutated)

#### Proc Worker (`workers/proc.shard.data.wrk.js`)
- Added `_consumeGroupedLoop()` for consuming `@wdk/grouped-transactions:shard-{shardGroup}` stream
- Added `_processGroupedMessageBatch()` that:
  1. Parses JSON message → gets transfers array + walletId
  2. Looks up wallet and addresses
  3. Calls `transferProcessor.processTransferGroup()`
  4. Calls `_enrichProcessedTransfer()` hook (no-op in base, overridable by Rumble)
  5. Dual-writes to both `walletTransfersProcessedRepository` and `walletTransferRepository`
- **Extension hook:** `_enrichProcessedTransfer(processedDoc, ctx)` — returns doc unchanged in base class

#### API Worker (`workers/api.shard.data.wrk.js`)
- `getWalletTransferHistory(req)` — queries processed collection with filtering by blockchain, token, type, activitySubtype, timestamp range; pagination via skip/limit; sort by ts
- `getUserTransferHistory(req)` — same but across all user wallets (walletId $in)
- Response mapping via `mapProcessedToResponse()`: nests `fromAppResolved`/`toAppResolved` into `fromMeta.appResolved`/`toMeta.appResolved`, wraps `sponsored` into `fees: { sponsored, networkFee: null }`, adds `transactionHash` to each underlying transfer

#### Migration Script (`scripts/migrate-wallet-transfers-processed.js`)
- Reads from `wallet_transfers_v2`, groups by `(walletId, transactionHash)`
- Calls `processTransferGroup()` for each group, upserts into `wallet_transfers_processed`
- Idempotent (upsert on walletId + transactionHash), processes in batches of 1000 wallets
- Accepts optional `enricher` callback for Rumble-specific enrichment during migration

#### Tests (`tests/unit/lib/transfer.processor.test.js`)
- 15 unit tests covering: direction computation, type classification, amount summation (BTC parseFloat vs EVM BigInt), change detection, paymaster/sponsored detection, label normalization, static config lookups, self-transfers, swap detection (outgoing, incoming, no swap)

**Files:** 10 files changed, 5 new files created

### 10. wdk-ork-wrk
**PR:** [tetherto/wdk-ork-wrk#80](https://github.com/tetherto/wdk-ork-wrk/pull/80)

- Added `getWalletTransferHistory` and `getUserTransferHistory` methods delegating to `_rpcRequest`
- Registered both in `rpcActions` array

**Files:** `workers/api.ork.wrk.js`

### 11. wdk-app-node
**PR:** [tetherto/wdk-app-node#69](https://github.com/tetherto/wdk-app-node/pull/69)

- Added `GET /api/v1/wallets/:walletId/transfer-history` route with query params: userId, token, blockchain, type, activitySubtype, from, to, limit, skip, sort
- Added `GET /api/v1/users/:userId/transfer-history` route with same query params (minus walletId)
- Added ork service proxy methods
- Added response schema definitions with `swap_out`/`swap_in` type enum and `activitySubtype` enum
- Existing `/token-transfers` endpoints remain unchanged

**Files:** `workers/lib/server.js`, `workers/lib/services/ork.js`, `workers/lib/middlewares/response.validator.js`

### 12. rumble-data-shard-wrk
**PR:** [tetherto/rumble-data-shard-wrk#169](https://github.com/tetherto/rumble-data-shard-wrk/pull/169)

#### Transfer Enricher (`workers/lib/transfer.enricher.js`)
- `enrichTransferGroup()` function that:
  - Queries `txWebhookRepository.findByTransactionHash()` to look up webhook data
  - Classifies `appActivitySubtype`: `transfer` (default), `tip`, or `rant` based on webhook type
  - Populates `appContext` with `appFlow` and `referenceId`
  - Populates `appTip` with `tipDirection`, `counterpartyUsername`, `counterpartyDisplayName`, `appContent`
  - Resolves `fromAppResolved` and `toAppResolved` via `resolveAddress()` helper (wallet address reverse lookup with LRU caching)

#### Proc Worker Override
- Overrides `_enrichProcessedTransfer()` hook to call `enrichTransferGroup()` with error handling (falls back to unenriched doc on failure)

#### Repository Layer
- Added `findByTransactionHash()` to txwebhook repositories (base, MongoDB, HyperDB)

#### API Worker
- Registered `getWalletTransferHistory` and `getUserTransferHistory` in rpcActions

#### Tests (`tests/unit/lib/transfer.enricher.test.js`)
- 7 unit tests covering: regular transfer, tip classification, rant classification, incoming tip direction, appResolved population, unknown counterparty handling, LRU cache behavior

**Files:** 7 files changed, 2 new files created

### 13. rumble-app-node
**PR:** [tetherto/rumble-app-node#146](https://github.com/tetherto/rumble-app-node/pull/146)

- Added both transfer-history routes with full Fastify schema validation
- Added ork service proxy methods
- Added comprehensive Swagger/OpenAPI annotations for both endpoints:
  - `description`, `summary`, `tags: ['Transfer History']`, `security: [{ bearerAuth: [] }]`
  - Full query parameter descriptions
  - Complete 200 response schema documenting every field including: core fields, classification, network metadata, address metadata with appResolved, fees, Rumble enrichment (appActivitySubtype, appContext, appTip), and underlying transfers array
  - 401 response schema

**Files:** `workers/lib/server.js`, `workers/lib/services/ork.js`

### 14. rumble-ork-wrk
**PR:** [tetherto/rumble-ork-wrk#103](https://github.com/tetherto/rumble-ork-wrk/pull/103)

- Added `getWalletTransferHistory` and `getUserTransferHistory` to rpcActions array

**Files:** `workers/api.ork.wrk.js`

---

## Pull Requests

| # | Repo | PR | Type |
|---|------|----|------|
| 1 | wdk-indexer-wrk-base | [#76](https://github.com/tetherto/wdk-indexer-wrk-base/pull/76) | Grouped publishing + boundary guard |
| 2 | wdk-indexer-wrk-btc | [#96](https://github.com/tetherto/wdk-indexer-wrk-btc/pull/96) | Dependency update |
| 3 | wdk-indexer-wrk-evm | [#92](https://github.com/tetherto/wdk-indexer-wrk-evm/pull/92) | Dependency update |
| 4 | wdk-indexer-wrk-tron | [#76](https://github.com/tetherto/wdk-indexer-wrk-tron/pull/76) | Dependency update |
| 5 | wdk-indexer-wrk-ton | [#82](https://github.com/tetherto/wdk-indexer-wrk-ton/pull/82) | Jetton batch fix + boundary guard |
| 6 | wdk-indexer-wrk-solana | [#72](https://github.com/tetherto/wdk-indexer-wrk-solana/pull/72) | Dependency update |
| 7 | wdk-indexer-wrk-spark | [#71](https://github.com/tetherto/wdk-indexer-wrk-spark/pull/71) | Spark batch fix |
| 8 | wdk-indexer-processor-wrk | [#10](https://github.com/tetherto/wdk-indexer-processor-wrk/pull/10) | Grouped stream routing |
| 9 | wdk-data-shard-wrk | [#168](https://github.com/tetherto/wdk-data-shard-wrk/pull/168) | Core: collection, processor, endpoints, migration, tests |
| 10 | wdk-ork-wrk | [#80](https://github.com/tetherto/wdk-ork-wrk/pull/80) | RPC action registration |
| 11 | wdk-app-node | [#69](https://github.com/tetherto/wdk-app-node/pull/69) | HTTP routes + response schemas |
| 12 | rumble-data-shard-wrk | [#169](https://github.com/tetherto/rumble-data-shard-wrk/pull/169) | Enrichment: tip/rant, counterparty resolution |
| 13 | rumble-app-node | [#146](https://github.com/tetherto/rumble-app-node/pull/146) | HTTP routes + Swagger docs |
| 14 | rumble-ork-wrk | [#103](https://github.com/tetherto/rumble-ork-wrk/pull/103) | RPC action registration |

---

## Key Design Decisions

### Dual-Write for Backward Compatibility
Both `_publishTransfers` (existing CSV per-transfer) and `_publishGroupedTransfers` (new JSON grouped) are called from `_storeAndPublishBatch`. The processor handles both stream types independently. The data shard writes to both `wallet_transfers_v2` (legacy) and `wallet_transfers_processed` (new). This ensures zero disruption to existing consumers.

### Hook-Based Extension (not Subclass)
Instead of `RumbleTransferProcessor extends TransferProcessor` with `super.processTransferGroup()`, we use a `_enrichProcessedTransfer(processedDoc, ctx)` hook in the proc worker. The base class defines a no-op, Rumble overrides it. This is less coupled — the enrichment happens after processing, the base class controls call order, and Rumble only needs to override one method.

### Tx-Hash Boundary Guard
For polling-based indexers (BTC, Spark, TON Jetton), batch flushes are delayed when `batch.length >= dbWriteBatchSize` until the txHash changes. This ensures all transfers from the same transaction stay in the same batch and get grouped correctly by `_publishGroupedTransfers`.

### Amount Summation Strategy
BTC uses `parseFloat` summation (UTXO amounts are decimal strings). All other chains use `BigInt` summation (token amounts are integer strings in base units). Change outputs are excluded from the sum for outgoing transactions.

### Swap Detection
Configurable via `SWAP_PARTNERS` address map in `transfer.config.js`. If the counterparty address matches a known swap partner, the type is `swap_out` (outgoing) or `swap_in` (incoming). The map is frozen at module load but can be overridden per-instance via the `TransferProcessor` constructor for testing.

---

## New Files Created

| File | Repo | Purpose |
|------|------|---------|
| `workers/lib/transfer.processor.js` | wdk-data-shard-wrk | Core transfer grouping logic |
| `workers/lib/transfer.config.js` | wdk-data-shard-wrk | Static config maps (rails, explorers, tokens, swap partners) |
| `workers/lib/db/mongodb/repositories/wallet.transfers.processed.js` | wdk-data-shard-wrk | MongoDB repository for processed collection |
| `scripts/migrate-wallet-transfers-processed.js` | wdk-data-shard-wrk | Backfill migration from wallet_transfers_v2 |
| `tests/unit/lib/transfer.processor.test.js` | wdk-data-shard-wrk | 15 unit tests for transfer processor |
| `workers/lib/transfer.enricher.js` | rumble-data-shard-wrk | Rumble tip/rant enrichment + counterparty resolution |
| `tests/unit/lib/transfer.enricher.test.js` | rumble-data-shard-wrk | 7 unit tests for enricher |

---

## Test Coverage

- **22 unit tests total** (15 transfer processor + 7 enricher), all passing
- Transfer processor tests cover: direction, type, amounts, change detection, swap detection, paymaster, label normalization, static config
- Enricher tests cover: transfer/tip/rant classification, counterparty resolution, cache behavior, error handling

---

## What Is NOT Included (Phase 2+)

- Pending/failed transaction status tracking
- Network fee extraction and population (`fees.networkFee` is null)
- Rumble swap enrichment (swap provider name, swap details)
- `tether-data-shard-wrk` extension (repo does not exist in workspace)
- Package-lock.json resolution for cross-repo git dependencies (requires pushing base repos to GitHub first, then re-running `npm install` in consumers)
