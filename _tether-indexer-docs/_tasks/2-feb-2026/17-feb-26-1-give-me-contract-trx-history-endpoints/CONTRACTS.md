# Transaction History API v2 — Endpoint Contracts

> Derived from PRs, implementation code, and agreed response shapes (tasks 11 & 12).
> Branch: `feat/transaction-history-v2` across all repos.

---

## Endpoints

### 1. `GET /api/v1/wallets/:walletId/transfer-history`

Returns transfer history for a single wallet.

**Auth:** Bearer token required (`middleware.auth.guard`).

**Path Parameters:**

| Param | Type | Required | Description |
|-------|------|----------|-------------|
| `walletId` | string | yes | Wallet identifier |

**Query Parameters:**

| Param | Type | Default | Description |
|-------|------|---------|-------------|
| `token` | string | — | Filter by token identifier (e.g. `usdt`, `btc`) |
| `blockchain` | string | — | Filter by blockchain network (e.g. `ethereum`, `bitcoin`) |
| `type` | enum | — | `sent` \| `received` \| `swap_out` \| `swap_in` |
| `activitySubtype` | enum | — | Rumble only: `transfer` \| `tip` \| `rant` |
| `from` | integer | — | Start timestamp filter, inclusive (unix ms) |
| `to` | integer | — | End timestamp filter, inclusive (unix ms) |
| `limit` | integer | `10` | Max results to return |
| `skip` | integer | `0` | Pagination offset |
| `sort` | enum | `desc` | `asc` \| `desc` — sort by `ts` |

> **Rumble note:** The Rumble variant also accepts `userId` as a query parameter (required for ownership validation).

**Errors:**

| Code | Error | When |
|------|-------|------|
| 401 | Unauthorized | Missing or invalid auth token |
| 404 | `ERR_WALLET_NOT_FOUND` | Wallet does not exist or does not belong to the authenticated user |

---

### 2. `GET /api/v1/users/:userId/transfer-history`

Returns transfer history across all wallets belonging to a user.

**Auth:** Bearer token required (`middleware.auth.guard`).

**Path Parameters:**

| Param | Type | Required | Description |
|-------|------|----------|-------------|
| `userId` | string | yes | User identifier (must match authenticated user) |

**Query Parameters:**

Same as the wallet endpoint, plus:

| Param | Type | Default | Description |
|-------|------|---------|-------------|
| `walletTypes` | array | — | Filter by wallet type (only returns transfers from matching wallets) |

**Errors:**

| Code | Error | When |
|------|-------|------|
| 401 | Unauthorized | Missing or invalid auth token |
| 403 | `ERR_USER_ID_INVALID` | Path `userId` does not match authenticated user (WDK layer) |
| 404 | `ERR_USER_WALLETS_NOT_FOUND` | User has no active wallets |
| 404 | `ERR_USER_WALLET_ADDRESSES_NOT_FOUND` | No wallets match requested `walletTypes` |

---

## Response Shape

Both endpoints return the same structure:

```json
{
  "transfers": [ <TransferItem>, ... ]
}
```

### WDK Base — `TransferItem`

```jsonc
{
  // ─── PRIMARY KEY ───
  "userId": "user-123",               // wallet owner's userId
  "walletId": "052d6e5d-...",
  "transactionHash": "0xabc123...",
  "blockNumber": 12345,               // promoted from underlyingTransfers[0]; nullable

  // ─── TIMING ───
  "ts": 1707222200000,                // block timestamp (epoch ms)
  "updatedAt": 1707222200000,         // equals ts in Phase 1; will differ for pending→confirmed in Phase 2

  // ─── CHAIN / NETWORK ───
  "blockchain": "ethereum",

  // ─── ASSET ───
  "token": "usdt",

  // ─── CLASSIFICATION ───
  "type": "sent",                     // "sent" | "received" | "swap_out" | "swap_in"
  "status": "confirmed",              // Phase 1: always "confirmed"

  // ─── AMOUNT ───
  "amount": "1000000",                // raw chain format — app converts using token decimals
  "fiatAmount": "100.50",             // nullable
  "fiatCcy": "usd",                   // nullable

  // ─── PARTICIPANTS ───
  "from": "0xabc...",
  "fromUserId": null,                 // null for now — future work (address→user lookup)
  "to": "0xdef...",
  "toUserId": null,                   // null for now — future work

  // ─── FEES ───
  "fee": null,                        // null for now — fee extraction is next priority
  "feeToken": null,                   // null for now
  "feeLabel": "gas"                   // "gas" | "paymaster" — derived from doc.sponsored boolean
}
```

### Rumble Addon Fields

Added on top of the base `TransferItem` when the transaction has Rumble enrichment data (`appActivitySubtype` is set on the stored document):

```jsonc
{
  "subType": "transfer",              // "transfer" | "tip" | "rant"
  "tipDirection": "sent",             // "sent" | "received" — nullable, only for tips/rants
  "message": "Great stream!"          // rant text — nullable, only populated for rants
}
```

When no Rumble enrichment exists, these three fields are absent from the response.

---

## Field Reference

### Type values

| Value | Meaning |
|-------|---------|
| `sent` | Outgoing transfer to another address |
| `received` | Incoming transfer from another address |
| `swap_out` | Outgoing transfer to a known swap partner address |
| `swap_in` | Incoming transfer from a known swap partner address |

### feeLabel values

| Value | Meaning | Derivation |
|-------|---------|------------|
| `gas` | Standard gas fee | Default when `doc.sponsored` is `false` or undefined |
| `paymaster` | Paymaster-sponsored transaction | When `doc.sponsored` is `true` (any transfer in group is paymaster) |

### Rumble subType values

| Value | Meaning |
|-------|---------|
| `transfer` | Regular token transfer |
| `tip` | Tip to a content creator |
| `rant` | Rant (paid message) — may include `message` text |

---

## Null/Deferred Fields (Phase 1)

These fields are present in the response but always `null` in Phase 1. They are placeholders for future work:

| Field | Future source | Priority |
|-------|--------------|----------|
| `fee` | Fee extraction logic per chain | Next priority after Phase 1 ships |
| `feeToken` | Derived alongside `fee` | Same as above |
| `fromUserId` | Address→user reverse lookup service | Future work |
| `toUserId` | Address→user reverse lookup service | Future work |

---

## Data Pipeline (for context)

```
Request flow:

  Client
    → App Node (wdk-app-node / rumble-app-node)     — HTTP route + auth
    → Ork Worker (wdk-ork-wrk / rumble-ork-wrk)     — RPC proxy
    → Data Shard API (wdk-data-shard-wrk)            — query + response mapping
    → MongoDB: wdk_data_shard_wallet_transfers_processed
```

The stored document is richer than the API response. The `mapProcessedToResponse()` function selectively extracts the allowlisted fields shown above. Stored-but-not-exposed fields include: `rail`, `chainId`, `networkName`, `symbol`, `decimals`, `direction`, `explorerUrl`, `label`, `sponsored`, `fromMeta`, `toMeta`, `underlyingTransfers[]`, `appActivitySubtype`, `appContext`, `appTip`, `processedAt`.

---

## Existing Endpoints (unchanged)

The legacy `/token-transfers` endpoints remain untouched and continue to serve per-transfer flat records from the `wallet_transfers_v2` collection. The new `/transfer-history` endpoints are additive.

---

## Pull Requests

| Repo | PR | Role |
|------|----|------|
| wdk-indexer-wrk-base | [#76](https://github.com/tetherto/wdk-indexer-wrk-base/pull/76) | Grouped publishing + batch boundary guard |
| wdk-indexer-wrk-btc | [#96](https://github.com/tetherto/wdk-indexer-wrk-btc/pull/96) | Dependency update |
| wdk-indexer-wrk-evm | [#92](https://github.com/tetherto/wdk-indexer-wrk-evm/pull/92) | Dependency update |
| wdk-indexer-wrk-tron | [#76](https://github.com/tetherto/wdk-indexer-wrk-tron/pull/76) | Dependency update |
| wdk-indexer-wrk-ton | [#82](https://github.com/tetherto/wdk-indexer-wrk-ton/pull/82) | Jetton batch fix + boundary guard |
| wdk-indexer-wrk-solana | [#72](https://github.com/tetherto/wdk-indexer-wrk-solana/pull/72) | Dependency update |
| wdk-indexer-wrk-spark | [#71](https://github.com/tetherto/wdk-indexer-wrk-spark/pull/71) | Spark batch fix |
| wdk-indexer-processor-wrk | [#10](https://github.com/tetherto/wdk-indexer-processor-wrk/pull/10) | Grouped stream routing |
| wdk-data-shard-wrk | [#168](https://github.com/tetherto/wdk-data-shard-wrk/pull/168) | Core: collection, processor, mapper, endpoints, migration, tests |
| wdk-ork-wrk | [#80](https://github.com/tetherto/wdk-ork-wrk/pull/80) | RPC action registration |
| wdk-app-node | [#69](https://github.com/tetherto/wdk-app-node/pull/69) | HTTP routes + response validation schemas |
| rumble-data-shard-wrk | [#169](https://github.com/tetherto/rumble-data-shard-wrk/pull/169) | Enrichment: tip/rant classification, counterparty resolution |
| rumble-app-node | [#146](https://github.com/tetherto/rumble-app-node/pull/146) | HTTP routes + Swagger docs |
| rumble-ork-wrk | [#103](https://github.com/tetherto/rumble-ork-wrk/pull/103) | RPC action registration |
