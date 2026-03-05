# Fee Extraction & `totalAmount` — Implementation Plan

> **Date:** 17 Feb 2026
> **Context:** The `totalAmount` field has been added to the transaction history response and schemas. It currently equals `amount` because `fee` is `null`. This document describes what it takes to populate `fee`, `feeToken`, and make `totalAmount` reflect the actual net balance impact.

---

## Current state

| Field | Current value | Target value |
|---|---|---|
| `fee` | `null` | Actual network fee as a string (raw chain format) |
| `feeToken` | `null` | Native token of the chain (e.g. `eth`, `btc`, `trx`) |
| `feeLabel` | `"gas"` or `"paymaster"` | No change needed |
| `totalAmount` | Same as `amount` | Outgoing: `amount + fee`. Incoming: `amount` |

---

## Why fee data is missing

The raw transfer records published by the indexer workers carry **no fee fields**. Each transfer has only: `blockchain`, `blockNumber`, `transactionHash`, `from`, `to`, `token`, `amount`, `timestamp`, `label`.

Fee extraction must happen **at the indexer level** (per chain), before the data reaches the processor/data-shard. The transfer processor in `wdk-data-shard-wrk` then picks up the fee from the transfer records and writes it to the processed document.

---

## Per-chain breakdown

### EVM (Ethereum, Polygon, etc.) — Low effort

The EVM indexer (`wdk-indexer-wrk-evm`) already fetches transaction receipts via `provider.getTransactionReceipt()`. The fee data is available but not extracted.

**What to extract:**
```
fee = receipt.gasUsed * receipt.effectiveGasPrice
```

**Where:**
- `wdk-indexer-wrk-evm/workers/lib/chain.erc20.client.js` — when building transfer records from receipts
- Fee needs to be attached to **one** transfer in the group (e.g. the first), not duplicated across all

**Fee token:** The chain's native token (`eth`, `matic`, etc. — derivable from `blockchain`)

**Paymaster note:** For sponsored transactions (`label: 'paymasterTransaction'`), the user doesn't pay the fee. The fee amount still exists on-chain (paymaster paid it). Decision needed: report the actual fee the paymaster paid, or `"0"` since the user didn't pay?

---

### TON — Low effort

The TON indexer (`wdk-indexer-wrk-ton`) fetches full transaction objects. The `total_fees` field is already present in the fetched data but not extracted.

**What to extract:**
```
fee = tx.total_fees
```

**Where:**
- `wdk-indexer-wrk-ton/workers/lib/chain.ton.client.js` — in the transaction parsing logic

**Fee token:** `ton`

---

### Tron — Medium effort

The Tron indexer (`wdk-indexer-wrk-tron`) fetches transaction details but does not call the endpoint that returns fee info.

**What to extract:**
```
fee = txInfo.fee   // in SUN (1 TRX = 1e6 SUN)
```

**Where:**
- `wdk-indexer-wrk-tron/workers/lib/chain.tron.client.js`
- Requires an additional `getTransactionInfo(hash)` call per transaction

**Fee token:** `trx`

**Trade-off:** One extra RPC call per transaction. Could be batched or cached if throughput is a concern.

---

### Solana — Medium effort

The Solana indexer (`wdk-indexer-wrk-solana`) currently uses the Bitquery API, which may not provide fee data.

**What to extract:**
```
fee = txDetails.meta.fee   // in lamports (1 SOL = 1e9 lamports)
```

**Where:**
- `wdk-indexer-wrk-solana/workers/lib/chain.solana.client.js`
- May require a direct RPC `getTransaction()` call alongside or instead of Bitquery

**Fee token:** `sol`

---

### Bitcoin — High effort

BTC fees are implicit: `fee = sum(input values) - sum(output values)`. The BTC indexer (`wdk-indexer-wrk-btc`) currently parses outputs (`tx.vout`) and extracts sender from inputs (`tx.vin`), but does **not** fetch input values.

**What to extract:**
```
For each vin:
  fetch previous tx → get vout[vin.vout].value
fee = sum(all input values) - sum(all output values)
```

**Where:**
- `wdk-indexer-wrk-btc/workers/lib/providers/rpc.provider.js` — in `_parseTx()`
- `wdk-indexer-wrk-btc/workers/lib/chain.btc.client.js`

**Fee token:** `btc`

**Trade-off:** Each input requires fetching its parent transaction to get the input value. For a typical 2-input tx, that's 2 extra RPC calls. This adds significant overhead to BTC indexing. Options:
1. Fetch input values during indexing (adds latency)
2. Use a UTXO cache / index to avoid repeated lookups
3. Skip BTC fee extraction for now and handle it separately

---

### Spark — Unknown effort

The Spark indexer (`wdk-indexer-wrk-spark`) uses a Spark-specific API. Need to check the API response structure to determine if fee data is available.

**Action:** Inspect the Spark API response for a fee field.

---

## Changes to the transfer processor

Once indexer workers attach fee data to transfer records, the transfer processor (`wdk-data-shard-wrk/workers/lib/transfer.processor.js`) needs to:

1. **Extract `fee` and `feeToken`** from the transfer group (fee should be on one transfer in the group, not duplicated)
2. **Compute `totalAmount`** based on direction:
   - Outgoing (`out`/`self`): `amount + fee` (same numeric type — `nBN` for BTC, `BigInt` for others)
   - Incoming (`in`): `amount` (unchanged)
3. **Handle mixed-token fees:** On EVM, the transfer token might be `usdt` but the fee token is `eth`. `totalAmount` should only sum same-token values. If `feeToken !== token`, `totalAmount` = `amount` (fee is in a different denomination).

---

## Repos touched

| Repo | Change | Effort |
|---|---|---|
| `wdk-indexer-wrk-evm` | Extract fee from receipt | Low |
| `wdk-indexer-wrk-ton` | Extract `total_fees` | Low |
| `wdk-indexer-wrk-tron` | Add `getTransactionInfo` call, extract fee | Medium |
| `wdk-indexer-wrk-solana` | Add RPC call or find Bitquery fee field | Medium |
| `wdk-indexer-wrk-btc` | Fetch input values, compute fee | High |
| `wdk-indexer-wrk-spark` | TBD — check API | Unknown |
| `wdk-indexer-wrk-base` | Pass fee fields through `_publishGroupedTransfers` | Low |
| `wdk-data-shard-wrk` | Update `TransferProcessor` to extract fee and compute `totalAmount` with fee | Low |

No changes needed in app-node, ork-wrk, or rumble repos — `fee`, `feeToken`, and `totalAmount` are already in all schemas.

---

## Suggested rollout order

1. **EVM + TON** — lowest effort, covers the most common chains
2. **Tron + Solana** — medium effort, one extra RPC call each
3. **Bitcoin** — highest effort, needs design decision on input value fetching
4. **Spark** — pending API investigation

Each chain can be shipped independently. The transfer processor handles `fee: null` gracefully — chains without fee extraction continue to work as before.

---

## Open questions for the team

1. **Paymaster fees:** When a paymaster sponsors the tx, should `fee` reflect what the paymaster paid, or `"0"` since the user paid nothing?
2. **Cross-token totalAmount:** For EVM, fee is in ETH but amount is in USDT. Should `totalAmount` only include fee when `feeToken === token`, or always include it regardless of denomination?
3. **BTC input fetching:** Is the RPC overhead acceptable, or should we explore a UTXO cache?
4. **Backfill:** Should we re-run the migration script after fee extraction ships, to populate `fee` on historical transactions? Or only apply to new transactions going forward?
