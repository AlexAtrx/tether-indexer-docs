# RW-1526: Balance vs Transaction History Discrepancy - Investigation Report

**Date**: 2026-04-15
**Ticket**: [RW-1526](https://app.asana.com/1/45238840754660/project/1212521145936484/task/1213878209840670)
**Severity**: Critical (Bug)
**Area**: Buy / On-ramp (Backend)

---

## Summary

The backend's `token-transfers` endpoint returns **9 transactions** for this user, but the mempool only shows **7 transactions totaling 78,668 sats** for the user's BTC address. Two "phantom" transactions (31,000 + 30,000 = 61,000 sats) appear in the backend history but are **not** on the Bitcoin blockchain for the user's main BTC address. The WDK balance correctly reflects the on-chain total of 78,668 sats (~$58.79).

**Root cause**: BTC on-chain transactions sent to the `sparkDepositAddress` (a separate Bitcoin address used for Spark deposits) are being stored in the same wallet transfer history as regular BTC transactions. The balance only reflects the main BTC address, creating the mismatch.

This is **not** a case of the backend "marking failed transactions as successful." The transactions are real Bitcoin transactions that *did* succeed - they just went to a different Bitcoin address (the Spark deposit address) that belongs to the same wallet, and the balance display doesn't account for that address.

---

## Evidence

### On-chain data (mempool.space)

**Address**: `bc1quy9rm9zztcqy9fwgfs6hdkjux4lt3vwq4rl9f2`

| # | TxID (short) | Amount (sats) | Block | Date |
|---|-------------|---------------|-------|------|
| 1 | `17ee378e...` | 311 | 942922 | 2026-03-30 |
| 2 | `ae54f98b...` | 7,371 | 942937 | 2026-03-30 |
| 3 | `188c0b80...` | 1,473 | 942937 | 2026-03-30 |
| 4 | `f928dd3c...` | 1,624 | 942939 | 2026-03-30 |
| 5 | `1ff57615...` | 19,889 | 943202 | 2026-04-01 |
| 6 | `cc04eebe...` | 23,000 | 943219 | 2026-04-01 |
| 7 | `b7f98868...` | 25,000 | 944890 | 2026-04-13 |
| | **Total** | **78,668** | | |

- Confirmed UTXOs: 7
- Confirmed balance: 78,668 sats (0.00078668 BTC, ~$58.48)
- Spent: 0

### Backend transaction history

From the `/api/v1/users/{userId}/token-transfers` endpoint (Juan's spreadsheet):

| # | Date | Amount (sats) | Fiat | On-chain? |
|---|------|---------------|------|-----------|
| 1 | 2026-03-26 12:57 | 31,000 | $20.48 | **NO** - phantom |
| 2 | 2026-03-29 10:09 | 311 | $0.21 | YES |
| 3 | 2026-03-29 11:17 | 30,000 | $20.37 | **NO** - phantom |
| 4 | 2026-03-29 11:45 | 1,473 | $1.00 | YES |
| 5 | 2026-03-29 11:45 | 7,371 | $4.99 | YES |
| 6 | 2026-03-29 12:05 | 1,624 | $1.10 | YES |
| 7 | 2026-03-31 08:25 | 19,889 | $13.62 | YES |
| 8 | 2026-03-31 10:22 | 23,000 | $15.68 | YES |
| 9 | 2026-04-12 09:21 | 25,000 | $17.71 | YES |
| | **Total** | **139,668** | | |

**Phantom total**: 61,000 sats ($40.85)
**Real on-chain total**: 78,668 sats ($58.48) - matches mempool

### Phantom transaction verification

**Transaction 1** (`fa9e67d70eed4bddabe24489384e5186f59c067b60c52d50d027db150c08f2d7`):
- Valid Bitcoin transaction, confirmed at block 942481
- 22 outputs - **NONE** go to `bc1quy9rm9zztcqy9fwgfs6hdkjux4lt3vwq4rl9f2`
- Has an output of exactly **31,000 sats** to a Taproot address (likely the `sparkDepositAddress`)
- This is a MoonPay batch payout transaction

**Transaction 2** (`bebe13f3d83ac55efa51e6626ae8062eb036162c3ca424a53b82dfe2fc0ec9ed`):
- Valid Bitcoin transaction, confirmed at block 942932
- 14 outputs - **NONE** go to `bc1quy9rm9zztcqy9fwgfs6hdkjux4lt3vwq4rl9f2`
- Has an output of exactly **30,000 sats** to a Taproot address (likely the `sparkDepositAddress`)
- This is the "BTC Spark buy transaction" Soso originally reported

---

## Root Cause Analysis

### The `sparkDepositAddress` registration

When a wallet is created or updated, the ork worker registers ALL addresses in the lookup storage, **including the `sparkDepositAddress`**:

**File**: `wdk-ork-wrk/workers/api.ork.wrk.js:440-444`
```javascript
const addressLookups = Object.values(wallet.addresses)
if (wallet.meta?.spark?.sparkDepositAddress && wallet.meta?.spark?.sparkIdentityKey) {
    addressLookups.push(wallet.meta?.spark?.sparkDepositAddress)
    // ^ patch for doing btc static address lookups for shard
}
await this.lookupStorage.saveWalletIdLookupBatch(addressLookups, wallet.id)
```

This means the `sparkDepositAddress` (a Bitcoin Taproot address used for Spark deposits) is registered as belonging to this wallet in the global lookup.

### How phantom transactions get stored

1. MoonPay sends BTC to the user's `sparkDepositAddress` (a Taproot address for Spark)
2. The **BTC indexer** (`wdk-indexer-wrk-btc`) processes the block and creates a transfer record for each output
3. The **processor** (`wdk-indexer-processor-wrk`) checks the `to` address against the lookup:
   ```javascript
   // indexer.processor.wrk.js:327-351
   async _handleNewTransfer (transfer) {
       const addresses = [transfer.from, transfer.to]
       for (const address of addresses) {
           const shardInfo = await this.resolveWalletShardByAddress(address)
           // sparkDepositAddress IS in the lookup → finds the wallet
       }
   }
   ```
4. The transfer is forwarded to the user's data shard and stored under the wallet ID with `blockchain: 'bitcoin'`
5. The Spark network independently processes the deposit and credits the user's Spark balance

### Why the balance doesn't match

- **Balance source** (WDK/`useBalancesForWallets`): Reads only the main BTC on-chain address (`bc1quy9rm9zztcqy9fwgfs6hdkjux4lt3vwq4rl9f2`) → **78,668 sats**
- **Transaction history source** (`/api/v1/users/{userId}/token-transfers`): Returns ALL transfers stored under the wallet ID, which includes both:
  - Transfers to the main BTC address (78,668 sats)
  - Transfers to the `sparkDepositAddress` (61,000 sats)
  - Both have `blockchain: 'bitcoin'`, `token: 'btc'`

### Why the frontend shows the mismatch

The API call made by the app (from Juan's investigation):
```
GET /api/v1/users/jYrl0hDlZC8/token-transfers?limit=100&sort=desc&walletTypes=user&walletTypes=unrelated
```

**No `blockchain` filter is applied.** The endpoint returns all transfers for the wallet regardless of which Bitcoin address received them.

The `getUserTransfers` method (`api.shard.data.wrk.js:312-437`) reads ALL wallet transfers and doesn't distinguish between the main BTC address and the `sparkDepositAddress`.

---

## Impact Assessment

### Is this an outlier?

**No, this affects ALL users who have purchased BTC via MoonPay for Spark deposits.** Any user whose wallet has a `sparkDepositAddress` will see these "phantom" transactions in their BTC transaction history, while the balance only reflects the main BTC address.

### Is there a financial loss?

**No.** The 61,000 sats (31,000 + 30,000) were successfully sent to the user's Spark deposit address. The funds went into the Spark protocol. The BTC was not lost - it's just reflected in the Spark balance, not the on-chain BTC balance. The user's total across both chains should be:
- BTC on-chain: 78,668 sats
- Spark: includes the 61,000 sats (plus any Spark-native transfers)

### Staging vs Production

This bug exists in the **core architecture** (address registration + unfiltered transfer queries). It affects:
- **Staging**: Confirmed (this is where it was found)
- **Production**: Any user with a `sparkDepositAddress` in their wallet metadata is affected. The severity depends on how many users have done MoonPay → Spark purchases.

---

## Recommended Fixes

### Short-term (Frontend)

The app should filter the token-transfers request by the specific address or use the `blockchain` parameter when showing BTC balance context:
```
GET /api/v1/users/{userId}/token-transfers?token=btc&walletTypes=user&...
```
And exclude transactions where the `to` address is the `sparkDepositAddress`, OR add a UI distinction for "Spark deposit" vs "BTC received".

### Medium-term (Backend)

1. **Add a `label` or `depositType` field** to transfers stored via the `sparkDepositAddress` path so they can be distinguished from regular BTC receives
2. **The `getUserSparkBitcoinMainnetTransfers` endpoint** already exists at `/api/v1/users/:userId/spark/bitcoin/token-transfers` - this could be leveraged to separate these transfers

### Long-term (Architecture)

1. **Balance should be multi-chain aware**: The balance display should aggregate both BTC on-chain balance AND Spark balance when the wallet has Spark enabled
2. **Transaction history should be chain-aware**: Clearly separate "BTC on-chain" from "Spark deposit" transactions in the response, or allow filtering by destination address type

---

## Key Files

| File | Lines | Purpose |
|------|-------|---------|
| `wdk-ork-wrk/workers/api.ork.wrk.js` | 440-444 | Registers `sparkDepositAddress` in lookup |
| `wdk-indexer-processor-wrk/workers/indexer.processor.wrk.js` | 327-351 | Routes transfers to shards by address lookup |
| `wdk-data-shard-wrk/workers/api.shard.data.wrk.js` | 312-437 | `getUserTransfers` - returns all wallet transfers |
| `wdk-data-shard-wrk/workers/api.shard.data.wrk.js` | 514-612 | `getUserSparkBitcoinMainnetTransfers` - separate Spark BTC endpoint |
| `wdk-data-shard-wrk/workers/proc.shard.data.wrk.js` | 829-961 | Wallet transfer sync job |
| `wdk-data-shard-wrk/workers/lib/blockchain.svc.js` | 432-509 | Fetches transfers per address+chain |
| `wdk-indexer-wrk-spark/workers/lib/chain.spark.client.js` | 99-114 | Spark transaction formatting |
| `wdk-indexer-wrk-btc/workers/lib/providers/rpc.provider.js` | 124-194 | BTC transaction parsing |

---

## Account Details (for reproduction)

- Username: `sosorumble`
- User ID: `jYrl0hDlZC8`
- BTC address: `bc1quy9rm9zztcqy9fwgfs6hdkjux4lt3vwq4rl9f2`
- Environment: Staging (`wallet-8s4anfsr6it9.rmbl.ws`)
- Spark deposit address: Unknown (stored in `wallet.meta.spark.sparkDepositAddress` - needs DB query)

### To verify the `sparkDepositAddress`
```bash
# Query the data shard for the wallet details:
curl -sS -X GET 'https://wallet-8s4anfsr6it9.rmbl.ws/api/v1/users/jYrl0hDlZC8/wallets' \
  -H 'Authorization: Bearer <ACCESS_TOKEN>'
```
Check `wallet.meta.spark.sparkDepositAddress` in the response. It should be one of the Taproot output addresses from the phantom transactions.
