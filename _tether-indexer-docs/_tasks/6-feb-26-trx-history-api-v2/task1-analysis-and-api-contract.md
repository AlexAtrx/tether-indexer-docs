# Transaction History API v2 — Doability Analysis & API Contract

## 1. Doability Assessment

**Verdict: YES, it is doable** — with clearly scoped limitations in Phase 1.

The requirement does NOT need a separate deployment. It fits naturally as a new service module inside **`wdk-app-node`** (the Rumble backend, not `wdk-indexer-app-node` which is the public indexer). The route is defined in `wdk-app-node` and the aggregation logic lives in `wdk-data-shard-wrk` via RPC — the same pattern used by the existing `getWalletTransfers` endpoint.

The core insight: the indexer already stores flat transfer records with `transactionHash`, `from`, `to`, `amount`, `blockchain`, `timestamp`, and `label`. **Grouping transfers by `transactionHash`** is the fundamental operation that solves the product owner's core problem (BTC showing two entries, EVM showing transfer + gas as separate items).

---

## 2. What Is Possible Today vs. What Requires Additional Data

### Fully possible with current indexed data

| Requirement | How |
|---|---|
| **Group related transfers into one logical transaction** | Group by `transactionHash`. One BTC send with recipient + change = 1 logical tx. One EVM send with transfer + gas = 1 logical tx. |
| **Direction (IN / OUT)** | Compare queried address against `from` / `to` in the grouped transfers. |
| **Network / Rail** | `blockchain` field maps directly (ethereum→EVM, bitcoin→BTC, spark→SPARK, etc.). |
| **Amount (principal)** | For IN: sum of amounts where `to` = queried address. For OUT: sum of amounts where `from` = queried address, excluding change (if detectable). |
| **Asset (symbol, decimals)** | Derivable from `token` + `blockchain` fields + static config. |
| **Explorer link** | Constructable from `blockchain` + `transactionHash` via a chain→explorer-url mapping. |
| **Underlying transactions** | The raw transfer records grouped under the logical transaction. |
| **Timestamps** | Available from `timestamp` field. |
| **Sponsored/Gasless detection** | `label === 'paymasterTransaction'` already flags paymaster-sponsored EVM transactions. |
| **Basic transfer type (SENT / RECEIVED)** | Derivable from direction. |

### Partially possible — needs known addresses or config

| Requirement | Gap | Mitigation |
|---|---|---|
| **BTC change detection** | Indexer stores one transfer per UTXO output. To distinguish recipient vs. change, we need to know the user's other addresses. | API caller passes the user's known addresses in the request, OR module has access to an address registry. Without this, we show all outputs and let the caller filter. |
| **SELF direction** | Need to know all addresses belonging to the user. | Same as above — requires address registry or caller-provided list. |
| **Swap detection (SWAP_IN / SWAP_OUT)** | Need to know swap partner addresses. | Configure known swap partner addresses in the module config. If a counterparty matches → mark as swap. |
| **Fee computation** | No fee data is stored in transfer records. BTC fees = sum(inputs) - sum(outputs), but inputs are not stored (only outputs/vouts). EVM gas fees are not stored. | **Phase 1**: For paymaster txs, mark `sponsored: true`. For BTC, approximate fee only if user addresses are known (fee = total_input_value - recipient_amount - change_amount). For EVM, fee field returns `null`. **Phase 2**: Enrich during indexing or via RPC call. |

### Not possible without external data sources

| Requirement | Missing Data Source | Recommendation |
|---|---|---|
| **Pending / Failed status** | Indexer only indexes confirmed blocks. No pending tx tracking exists. | Phase 1: All returned transactions have status `CONFIRMED`. Phase 2: Add a pending tx submission tracking module. |
| **Tip information** (`app_tip`) | Purely app-level data, not on-chain. Needs a tips database/service. | Rumble addon module queries a tips service by txHash or address. Phase 1: return `null`. |
| **Counterparty resolution** (`app_resolved`) | Needs address → user identity mapping. | Rumble addon module queries a user/address registry. Phase 1: return `null`. |
| **USD value at time of tx** (`value_usd_cents`) | Needs a price oracle or historical price service. | Phase 1: return `null`. Can be enriched later if a price feed is available. |
| **`app_context`** (flow, reference_id) | Needs app-level intent tracking (which flow initiated this tx). | Phase 1: return `null`. Requires FE/BE to tag transactions at submission time. |

---

## 3. Architecture: Module Design

Following the existing pattern where `wdk-app-node` defines routes and `wdk-data-shard-wrk` handles data logic via RPC:

```
wdk-app-node/
  workers/
    lib/
      services/
        ork.js                      ← existing (add new RPC proxy methods)
      server.js                     ← existing (add new route definitions)

wdk-data-shard-wrk/
  workers/
    api.shard.data.wrk.js           ← existing (add new RPC handler)
    lib/
      tx-history/
        tx.history.js               ← NEW: Core Transaction History — aggregation logic
        tx.history.enricher.js      ← NEW: Rumble Addons enricher (optional)
        chains.config.js            ← NEW: explorer URLs, chain metadata
```

**`tx.history.js`** (Core — reusable across apps):
- Queries transfers via existing `walletTransferRepository`
- Groups by transactionHash
- Computes direction, type, amount, network, explorer link
- Returns core transaction objects

**`tx.history.enricher.js`** (Rumble Addons — app-specific):
- Takes core transaction objects
- Enriches with counterparty resolution, tip data, fiat value
- This module is swappable per-app

---

## 4. API Contract

> **Field naming convention**: All field names that already exist in the current
> `GET /api/v1/wallets/:walletId/token-transfers` response keep their exact
> same name and format (`transactionHash`, `blockchain`, `token`, `amount`,
> `from`, `to`, `ts`, `type`, `blockNumber`, `transferIndex`, `transactionIndex`,
> `logIndex`, `label`, `fiatAmount`, `fiatCcy`). New fields introduced by this
> API are additions on top.

### 4.1 Endpoint: Get Transaction History

```
GET /api/v1/tx-history/:address
```

**Auth:** `X-API-KEY` header (same as existing endpoints)

**Query Parameters:**

| Param | Type | Required | Default | Description |
|---|---|---|---|---|
| `blockchain` | string | yes | — | Chain filter: `ethereum`, `bitcoin`, `arbitrum`, `polygon`, `tron`, `ton`, `solana`, `spark`, `plasma` |
| `token` | string | yes | — | Token filter: `usdt`, `btc`, `xaut`, `usdt0`, `xaut0` |
| `from` | integer | no | 0 | Start timestamp (ms, epoch) |
| `to` | integer | no | now | End timestamp (ms, epoch) |
| `limit` | integer | no | 25 | Max results (1-100) |
| `skip` | integer | no | 0 | Number of results to skip (offset pagination, matching existing convention) |
| `sort` | string | no | `desc` | `asc` or `desc` (matching existing convention) |
| `known_addresses` | string | no | null | Comma-separated list of the user's other known addresses on this chain. Used for change detection (BTC) and SELF direction. |

> **Design note**: `known_addresses` is the pragmatic bridge between a pure chain-level module and the app layer. The app (Rumble BE or FE) knows which addresses belong to the user and passes them. This avoids the module needing a user registry, keeping it reusable.

**Response:**

```jsonc
{
  "transfers": [
    {
      // === IDENTITY ===
      "transactionHash": "string",           // same name as existing endpoint

      // === TIMING ===
      "ts": 1707222200000,                   // epoch ms — same name & format as existing endpoint
      "updatedAt": 1707222200000,            // same as ts for confirmed txs; will differ for pending→confirmed

      // === CHAIN / NETWORK ===
      "blockchain": "ethereum",              // same name as existing endpoint
      "rail": "EVM",                         // derived: EVM | BTC | SPARK
      "chainId": 1,                          // EVM only, null for non-EVM
      "networkName": "Ethereum",             // human-readable

      // === ASSET ===
      "token": "usdt",                       // same name as existing endpoint
      "symbol": "USDT",                      // display symbol
      "decimals": 6,                         // from static config

      // === CLASSIFICATION ===
      "type": "sent",                        // same name as existing endpoint
                                              // extended values: "sent" | "received" | "swap_out" | "swap_in"
      "direction": "out",                    // "in" | "out" | "self"
      "status": "confirmed",                 // Phase 1: always "confirmed"
                                              // Phase 2: "pending" | "submitted" | "confirmed" | "failed"

      // === AMOUNT ===
      "amount": "1000000",                   // same name & format as existing (string, smallest unit)
      "fiatAmount": null,                    // same name as existing — Phase 1: null
      "fiatCcy": null,                       // same name as existing — Phase 1: null

      // === PARTICIPANTS ===
      "from": "0xabc...",                    // same name as existing — primary sender
      "to": "0xdef...",                      // same name as existing — primary recipient (non-change)
      "fromMeta": {                          // NEW — enrichment on top of flat `from`
        "addressType": "EVM_ADDRESS",        // EVM_ADDRESS | BTC_ADDRESS | SPARK_ACCOUNT | UNKNOWN
        "isSelf": false,                     // true if in known_addresses or is the queried address
        "appResolved": null                  // Phase 1: null
                                              // Phase 2: { "displayName": "alice", "entityType": "INTERNAL_USER_ACC", "avatarUrl": "..." }
      },
      "toMeta": {                            // NEW — enrichment on top of flat `to`
        "addressType": "EVM_ADDRESS",
        "isSelf": false,
        "appResolved": null
      },

      // === FEES ===
      "fees": {
        "sponsored": true,                   // true if label === 'paymasterTransaction'
        "networkFee": null                   // Phase 1: null (no fee data indexed)
                                              // Phase 2: { "value": "21000", "token": "eth", "symbol": "ETH", "decimals": 18 }
      },

      // === LINKS ===
      "explorerUrl": "https://etherscan.io/tx/0x...",

      // === LABEL ===
      "label": "transaction",               // same name as existing — "transaction" | "paymasterTransaction"

      // === APP-LEVEL (Rumble Addons) — all null in Phase 1 ===
      "appActivitySubtype": null,            // Phase 2: "transfer" | "tip"
      "appContext": null,                    // Phase 2: { "appFlow": "send", "referenceId": "..." }
      "appTip": null,                        // Phase 2: { tipId, tipDirection, counterparty, appContent }

      // === UNDERLYING TRANSFERS ===
      // Raw indexed records grouped under this logical transaction.
      // Field names inside each item match the existing token-transfers response.
      "underlyingTransfers": [
        {
          "transactionHash": "0xabc...",
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
          "isChange": false                  // NEW — true if `to` is in known_addresses (BTC change detection)
        },
        {
          "transactionHash": "0xabc...",
          "transferIndex": 1,
          "transactionIndex": 0,
          "logIndex": null,
          "blockNumber": 19000000,
          "from": "0xabc...",
          "to": "0xabc...",                  // change output back to sender
          "token": "usdt",
          "amount": "500000",
          "ts": 1707222200000,
          "label": "transaction",
          "isChange": true
        }
      ]
    }
  ]
}
```

### 4.2 Endpoint: Get Single Transaction Detail

```
GET /api/v1/tx-history/:address/:blockchain/:transactionHash
```

**Auth:** `X-API-KEY` header

**Query Parameters:**

| Param | Type | Required | Description |
|---|---|---|---|
| `known_addresses` | string | no | Comma-separated user addresses for change/self detection |

**Response:** Same shape as a single item from the `transfers` array above (unwrapped, not in an array).

### 4.3 Endpoint: Get Transaction History (Batch / Multi-chain)

```
POST /api/v1/tx-history/batch
```

**Auth:** `X-API-KEY` header

**Request Body:**

```jsonc
{
  "queries": [
    {
      "address": "0xabc...",
      "blockchain": "ethereum",
      "token": "usdt",
      "from": 1707136800000,
      "to": 1707223200000,
      "limit": 10,
      "known_addresses": ["0xdef..."]
    },
    {
      "address": "bc1q...",
      "blockchain": "bitcoin",
      "token": "btc",
      "limit": 10,
      "known_addresses": ["bc1q...", "1ABC..."]
    }
  ],
  "merge": true  // if true, merge results across chains sorted by ts desc
                  // if false, return results grouped by query
}
```

**Response (merge=true):**

```jsonc
{
  "transfers": [ /* same transaction objects, sorted by ts desc across all chains */ ]
}
```

**Response (merge=false):**

```jsonc
{
  "results": [
    {
      "query": { "address": "0xabc...", "blockchain": "ethereum", "token": "usdt" },
      "transfers": [ /* transactions */ ]
    },
    {
      "query": { "address": "bc1q...", "blockchain": "bitcoin", "token": "btc" },
      "transfers": [ /* transactions */ ]
    }
  ]
}
```

### 4.4 Endpoint: Supported Chains (existing, no change needed)

```
GET /api/v1/chains
```

Already returns the list of supported blockchains and tokens.

### 4.5 Field Name Alignment Reference

| Existing (`/wallets/:id/token-transfers`) | This API (`/tx-history`) | Notes |
|---|---|---|
| `transactionHash` | `transactionHash` | Same |
| `blockchain` | `blockchain` | Same |
| `blockNumber` | (in `underlyingTransfers[]`) | Promoted to logical tx level not needed; lives in underlying |
| `transferIndex` | (in `underlyingTransfers[]`) | Same — per-output detail |
| `transactionIndex` | (in `underlyingTransfers[]`) | Same |
| `logIndex` | (in `underlyingTransfers[]`) | Same |
| `from` | `from` | Same — primary sender |
| `to` | `to` | Same — primary recipient |
| `token` | `token` | Same |
| `amount` | `amount` | Same format (string, smallest unit) |
| `ts` | `ts` | Same (epoch ms integer) |
| `type` (`"sent"` / `"received"`) | `type` | Same name, extended with `"swap_out"` / `"swap_in"` |
| `label` | `label` | Same |
| `fiatAmount` | `fiatAmount` | Same name (null until enriched) |
| `fiatCcy` | `fiatCcy` | Same name (null until enriched) |
| `walletId` | — | Not included; this endpoint is address-based, not wallet-based |
| — | `updatedAt` | **New** — for future pending→confirmed transitions |
| — | `rail` | **New** — EVM / BTC / SPARK |
| — | `chainId` | **New** — EVM chain ID |
| — | `networkName` | **New** — human-readable chain name |
| — | `symbol` | **New** — display symbol (uppercase) |
| — | `decimals` | **New** — token decimals |
| — | `direction` | **New** — in / out / self |
| — | `status` | **New** — confirmed (Phase 1 only) |
| — | `fromMeta` / `toMeta` | **New** — enrichment layer over flat from/to |
| — | `fees` | **New** — fee breakdown (null in Phase 1) |
| — | `explorerUrl` | **New** — block explorer link |
| — | `appActivitySubtype` | **New** — Rumble addon (null Phase 1) |
| — | `appContext` | **New** — Rumble addon (null Phase 1) |
| — | `appTip` | **New** — Rumble addon (null Phase 1) |
| — | `underlyingTransfers` | **New** — grouped raw transfers with `isChange` flag |

---

## 5. Core Aggregation Logic (How grouping works)

For a given `(address, blockchain, token, timeRange)`:

1. **Query** raw transfers via `walletTransferRepository.getTransfersForWalletInRange` (same as existing `getWalletTransfers`).
2. **Group** transfers by `transactionHash`. Each group = one logical transaction.
3. **For each group**, compute:
   - **direction**: If any transfer has `from === address` → OUT. If any has `to === address` → IN. If both → SELF (or needs known_addresses to confirm).
   - **transfer_type**: Default SENT/RECEIVED from direction. If counterparty matches configured swap addresses → SWAP_OUT/SWAP_IN.
   - **amount**: For OUT direction, the primary amount is the transfer where `to` is NOT the queried address and NOT in `known_addresses` (i.e., the actual recipient, not change). For IN, it's the transfer where `to === address`.
   - **participants.from / .to**: The external counterparty (not the user). For OUT, `to` of the non-change transfer. For IN, `from` of the transfer.
   - **is_change**: For each underlying transfer, mark `is_change = true` if `to` is in `known_addresses` or is the queried address AND direction is OUT.
   - **sponsored**: `true` if any transfer in the group has `label === 'paymasterTransaction'`.
   - **explorer_url**: Construct from chain config.
4. **Sort** by `ts` descending (or ascending if `sort=asc`).
5. **Paginate** using `skip` + `limit` (matching existing convention).

### BTC specific behavior

A BTC send transaction creates N transfer records (one per vout). Example:
- Transfer 0: from=sender, to=recipient, amount=0.5 BTC
- Transfer 1: from=sender, to=sender_change_addr, amount=0.3 BTC

Grouped into one logical transaction:
- direction: OUT
- amount: 0.5 BTC (the non-change output)
- underlying_transfers[0].is_change = false
- underlying_transfers[1].is_change = true (if sender_change_addr is in known_addresses)

If `known_addresses` is NOT provided, both outputs appear with `is_change: false` and the FE can decide how to display them. This is a graceful degradation — the API still works, just with less intelligence.

### EVM specific behavior

An EVM USDT send may produce:
- Transfer 0 (ERC20): from=sender, to=recipient, amount=100 USDT, label=transaction
- Transfer 1 (native): from=sender, to=paymaster, amount=0.001 ETH, label=paymasterTransaction

These have different `token` values, so they'd be queried separately (USDT vs ETH). However, the ERC20 transfer + gas are on the same txHash. If we query USDT transfers, we get only Transfer 0. The gas payment is on a different token and won't appear in a USDT-filtered query.

This means for EVM: the grouping by txHash within a single token query typically yields 1 transfer per group. The fee/gas is a separate concern, which aligns with Phase 1 returning `fees.network_fee: null`.

---

## 6. Bottlenecks & Considerations

### Performance
- **Query cost**: Same as existing `getWalletTransfers` — streams from `walletTransferRepository.getTransfersForWalletInRange`. Grouping is done in-memory and is O(n) where n = number of raw transfers returned.
- **Pagination**: Cursor-based on timestamp ensures consistent performance regardless of dataset size.
- **Batch endpoint**: Runs queries in parallel per chain. Merging is a simple sorted merge of pre-sorted arrays — O(n log k) where k = number of chains.

### Data integrity
- **No new writes required for Phase 1**. This is purely a read-side aggregation layer over existing indexed data.
- **No schema migration** needed. The transfer entity stays the same.

### Rate limiting
- New endpoints need rate limit config entries (following existing pattern in `common.json`).
- Suggested: same limits as `tokenTransfers` for the single endpoint, same as `tokenTransfersBatch` for batch.

### Backward compatibility
- Existing `/api/v1/wallets/:walletId/token-transfers` stays untouched.
- New endpoints are additive — no breaking changes.

---

## 7. Gaps to Fill (for BE team)

| # | Gap | Impact | Suggestion |
|---|---|---|---|
| 1 | **No fee data indexed** | Cannot show fee breakdown in Phase 1 | Add fee storage during indexing in Phase 2, or call RPC at query time (slower) |
| 2 | **No pending/failed tx tracking** | Status is always CONFIRMED | Phase 2: add a `pending_transactions` collection, write on tx submission, update on confirmation/failure |
| 3 | **BTC inputs not stored** | Cannot compute exact BTC fees from indexed data alone | For BTC fee: fee = total_input - total_output. Inputs aren't indexed. Either index them or accept the gap. |
| 4 | **No address → user registry** in indexer | Cannot resolve counterparty identities | Rumble addon module needs to call an external user service, or a new collection mapping addresses to user profiles needs to exist |
| 5 | **No tip data** in indexer | Cannot populate `app_tip` | Rumble addon module needs a tips service/API to query |
| 6 | **No price oracle** | Cannot populate `value_usd_cents` | Integrate a price feed or skip in Phase 1 |
| 7 | **Spark/Lightning transfers** | Not fully explored — need to verify transfer record format matches the grouping logic | Verify Spark worker's transfer output format before implementation |

---

## 8. Summary

The transaction history API is **doable as a module within the existing backend**. Phase 1 delivers the core value — consolidated transaction history with proper grouping, direction, amount, network, explorer links, and underlying transaction references. The `known_addresses` parameter is the key enabler for BTC change detection and SELF direction without requiring an address registry in the indexer.

The Rumble addon fields (`app_resolved`, `app_tip`, `app_context`) return `null` in Phase 1 and are populated when external services (user registry, tips service) become available. The API contract is designed so FE can start building immediately against the Phase 1 shape and progressively enhance as Phase 2 fields get populated.
