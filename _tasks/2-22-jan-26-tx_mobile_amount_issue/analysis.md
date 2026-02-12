# BTC Transaction Amount Display Bug - Analysis

## The Problem

When a user sends BTC, the mobile app shows **multiple "Sent" transactions** with incorrect amounts that don't match the actual send. This is because the backend returns **change outputs** as separate "sent" transactions.

## Screenshots Confirmation

- **gohar1.png (Sender)**: Shows "SENT" 0.00012602 BTC
- **gohar2.png (Receiver)**: Shows "RECEIVED" 0.00001249 BTC

The amounts don't match because the sender sees inflated values from change outputs being included.

## Root Cause: Two-Part Issue

### 1. BTC Indexer Creates One Transfer Per Output

**File:** `wdk-indexer-wrk-btc/workers/lib/providers/rpc.provider.js:148-173`

```javascript
return tx.vout.map((vout, i) => {
  // Creates a separate transfer for EVERY output
  return {
    from,  // Same 'from' for ALL outputs
    to,    // Different 'to' for each output (including change address)
    amount: vout.value.toString(),
    ...
  }
})
```

In Bitcoin's UTXO model, a transaction has:
- **Inputs**: UTXOs being spent
- **Outputs**:
  - Payment to recipient
  - **Change** back to sender's own address

The indexer creates a separate transfer record for each output without distinguishing the change output.

### 2. Type Determination Doesn't Handle Self-Sends

**File:** `wdk-data-shard-wrk/workers/api.shard.data.wrk.js:493`

```javascript
type: walletAddress.includes(tx.from) ? 'sent' : 'received',
```

This logic labels a transfer as "sent" if `tx.from` matches the wallet. For change outputs:
- `from` = sender's address (wallet match → "sent")
- `to` = sender's address (it's change going back!)

**Result**: Change is labeled as a separate "sent" transaction.

## Example from Slack

Same transaction hash `8fcd36eac73ddd0231d589052abf0486c667b032b1722b7210960a49500a1231`:

| Transfer | Amount | To Address | Type | Actual Purpose |
|----------|--------|------------|------|----------------|
| 0 | 0.00001571 | bc1q25yys... | sent | **Real payment** |
| 1 | 0.00008501 | bc1q4ykyew... (same as FROM) | sent | **Change** (incorrectly labeled) |

The user sees two "sent" entries when they should only see one with the actual payment amount.

## Missing Logic

There is **no code** anywhere that:
1. Detects change outputs (where `to` == `from` or `to` is in user's wallet addresses)
2. Skips or consolidates change outputs
3. Distinguishes "actual payment" from "change returning to sender"

## Proposed Solution Direction (from proposal.txt)

The team proposed adding `feeAmount` and `feeCcy` fields to the transfer structure. However, this doesn't fully address the core issue of change outputs being displayed as separate transactions.

A complete fix would need to either:
1. **At indexing time**: Mark change outputs with a special label (e.g., `label: 'change'`)
2. **At query time**: Filter out transfers where `to` is also in the user's wallet addresses for "sent" transactions
3. **Consolidate**: Combine outputs per transaction hash, showing only the net amount sent to external addresses

## Culprit Code Locations

| File | Lines | Issue |
|------|-------|-------|
| `wdk-indexer-wrk-btc/workers/lib/providers/rpc.provider.js` | 148-173 | Creates separate transfer per output, no change detection |
| `wdk-data-shard-wrk/workers/api.shard.data.wrk.js` | 493 | Labels transfers as "sent" based only on `from`, ignoring if `to` is also wallet's address |
