# Root Cause Analysis: BTC Transaction Change Output Issue

## Problem Statement

BTC "Sent" transactions display incorrect amounts because change outputs are surfaced as separate "Sent" entries. Users see multiple confusing rows and an inflated apparent sent amount instead of one clear transaction showing the actual payment.

---

## Root Cause

**The system lacks change-output awareness at every layer of the data pipeline.**

A typical BTC spend creates two outputs (vouts):
1. Payment to recipient
2. Change returning to sender

The indexer stores both as identical transfer records. The data shard persists both without filtering. The API labels both as "sent" because it only checks if `from` matches a wallet address, ignoring that `to` may also be a wallet address (indicating change).

---

## Data Flow

```
BTC Node
    │
    ▼
┌─────────────────────────────────────────────────────────────────┐
│ BTC RPC Provider (_parseTx)                                     │
│ wdk-indexer-wrk-btc/workers/lib/providers/rpc.provider.js:149   │
│                                                                 │
│ Creates ONE transfer per vout. No label distinguishing          │
│ payment outputs from change outputs.                            │
└─────────────────────────────────────────────────────────────────┘
    │
    ▼
┌─────────────────────────────────────────────────────────────────┐
│ Base Indexer (findByAddressAndTimestamp)                        │
│ wdk-indexer-wrk-base/workers/lib/db/mongodb/models/transfer.js:165 │
│                                                                 │
│ Query: { $or: [{ from: address }, { to: address }] }            │
│ Returns ALL transfers where address is sender OR recipient,     │
│ guaranteeing change outputs reach the shard.                    │
└─────────────────────────────────────────────────────────────────┘
    │
    ▼
┌─────────────────────────────────────────────────────────────────┐
│ Data Shard (wallet sync loop)                                   │
│ wdk-data-shard-wrk/workers/proc.shard.data.wrk.js:896-916       │
│                                                                 │
│ Persists every returned transfer. Only filters duplicates,      │
│ no change-output filter applied.                                │
└─────────────────────────────────────────────────────────────────┘
    │
    ▼
┌─────────────────────────────────────────────────────────────────┐
│ Data Shard API (type classification)                            │
│ wdk-data-shard-wrk/workers/api.shard.data.wrk.js:377, 493       │
│                                                                 │
│ Logic: walletAddress.includes(tx.from) ? 'sent' : 'received'    │
│ Ignores tx.to entirely. Change output (from=self, to=self)      │
│ is labeled "sent" instead of being filtered or labeled "change" │
└─────────────────────────────────────────────────────────────────┘
    │
    ▼
  User sees multiple "Sent" rows with inflated total
```

---

## Concrete Example

User sends **0.5 BTC** to a recipient. Their UTXO is 0.8 BTC, so 0.3 BTC returns as change.

### What gets stored

| vout | from | to | amount |
|------|------|----|--------|
| 0 | user_addr | recipient_addr | 0.5 BTC |
| 1 | user_addr | user_addr | 0.3 BTC |

### What the API returns

| type | amount | reason |
|------|--------|--------|
| sent | 0.5 BTC | `from` matches wallet |
| sent | 0.3 BTC | `from` matches wallet (but `to` also matches - ignored) |

### What user sees

Two "Sent" transactions totaling 0.8 BTC instead of one 0.5 BTC payment.

---

## Code References

### 1. BTC RPC Provider - No change label set

`wdk-indexer-wrk-btc/workers/lib/providers/rpc.provider.js:149-172`

```javascript
return tx.vout.map((vout, i) => {
  return {
    blockchain: this.conf.chain,
    blockNumber: BigInt(blockNumber),
    transactionHash: tx.txid.toLowerCase(),
    from,
    to,
    token: this.conf.token,
    amount: vout.value.toString(),
    timestamp: +timestamp * 1000
    // No label field - change outputs indistinguishable from payments
  }
})
```

### 2. Indexer Query - Returns all matching transfers

`wdk-indexer-wrk-base/workers/lib/db/mongodb/models/transfer.js:165-167`

```javascript
const query = {
  $or: [{ from: address }, { to: address }]
}
```

### 3. Data Shard Sync - No change filter

`wdk-data-shard-wrk/workers/proc.shard.data.wrk.js:896-916`

```javascript
for (const tx of walletTxs) {
  const existingTransfer = await uow.walletTransferRepository.get(...)
  if (!existingTransfer) {
    await uow.walletTransferRepository.save({ ...tx, ... })
    // Saves all transfers - no change output filtering
  }
}
```

### 4. API Type Classification - Ignores `to` field

`wdk-data-shard-wrk/workers/api.shard.data.wrk.js:377`

```javascript
type: walletIdToAddresses[wallet.id].includes(tx.from) ? 'sent' : 'received'
// Does not check if tx.to is also a wallet address
```

---

## Secondary Issue: Multi-Input Transactions

When a BTC transaction has inputs from multiple different addresses, the `from` field is set to `null`:

`wdk-indexer-wrk-btc/workers/lib/providers/rpc.provider.js:123-142`

```javascript
let from = null
if (tx.vin?.length) {
  let allSame = true
  const prev = this._parseVinAddr(tx.vin[0])
  for (const vin of tx.vin) {
    if (parsed !== prev) {
      allSame = false
      break
    }
  }
  if (allSame) {
    from = prev
  }
}
```

**Impact**: When `from = null`, the API logic `walletAddress.includes(null)` returns `false`, labeling the transfer as "received" even when the user initiated the spend. This affects UTXO consolidation transactions and collaborative spends.

---

## Highest True Cause

**The API type classification logic is the most direct cause of the user-facing bug.**

While the indexer could add labels and the shard could filter, the API is where "sent" vs "received" is determined. The single-field check (`from ∈ wallet`) is fundamentally incomplete for BTC's UTXO model where:

1. Change outputs have `from = wallet` AND `to = wallet`
2. Multi-input spends may have `from = null`

The fix must account for the `to` field, not just `from`.

---

## Recommended Fix Locations

| Priority | Location | Fix |
|----------|----------|-----|
| 1 | `api.shard.data.wrk.js:377, 493` | Check both `from` and `to`: if both are wallet addresses, label as "change" or filter out |
| 2 | `rpc.provider.js:160` | Add `label: (from && to && from === to) ? 'change' : 'transaction'` (limited: only catches same-address change) |
| 3 | `proc.shard.data.wrk.js:906` | Filter change outputs before persisting (requires wallet address context) |

**Note**: The RPC-level fix only works when change returns to the exact same address. HD wallets often send change to new addresses, so the Data Shard API fix (Priority 1) is the most reliable solution since it has access to all wallet addresses.
