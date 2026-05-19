# Root Cause Analysis: BTC Transactions Logged with Incorrect Amounts

## Executive Summary

The sender-side BTC history is wrong because the backend stores and serves **one transfer per BTC output**, then classifies any row whose `from` address belongs to the wallet as `sent`.

For a normal BTC spend, that means:

- the real payment output is stored as one transfer
- the change output back to the sender is stored as another transfer
- both transfers are returned for the sender wallet
- both are classified as `sent`

The system never computes a single logical BTC "send amount" as:

`sum(inputs) - change - fee`

Instead, it stores raw `vout.value` amounts and loses the extra context needed to reconstruct the real send cleanly later.

## Reproduction Evidence

The screenshots in this task folder line up with the code path:

- `04-comment-receiver-side.png` shows the receiver correctly seeing `0.00001249 BTC`
- `03-comment-sender-side.png` shows the sender seeing `Amount = 0.00012602 BTC` and `Fees = 0.00001249 BTC`
- `05-blockchain-explorer.png` shows the on-chain transaction (`a86e927e07bcc8...`):
  - input value: `0.00014133 BTC`
  - output 1 to receiver: `0.00001249 BTC`
  - output 2 back to sender: `0.00012602 BTC`
  - network fee: `0.00000282 BTC`

So the sender UI is being fed output-level data that does not distinguish payment from change.

## 1. Where the incorrect amount is calculated and stored

### A. BTC parser stores each output as its own transfer

File: `wdk-indexer-wrk-btc/workers/lib/providers/rpc.provider.js:124-193`

`_parseTx()` loops over `tx.vout` and returns one transfer per output:

```js
return tx.vout.map((vout, i) => {
  return {
    transactionHash: tx.txid.toLowerCase(),
    transferIndex: i,
    from,
    to,
    amount: vout.value.toString(),
    ...
  }
})
```

The stored `amount` is not a BTC "sent amount". It is just the value of a single output.

### B. The base indexer persists only flat transfer rows and drops metadata

File: `wdk-indexer-wrk-base/workers/proc.indexer.wrk.js:221-237`

The processing worker persists only these fields:

- `blockchain`, `blockNumber`, `transactionHash`, `transactionIndex`, `transferIndex`
- `logIndex`, `from`, `to`, `token`, `amount`, `timestamp`, `label`

Although `_parseTx()` builds a `metadata.inputs` array (lines 154-166) with each input's address and value, this field is **not included** in the value object written by `proc.indexer.wrk.js`. The metadata is discarded at persistence time, making it impossible to reconstruct fee or net send amount from stored indexer data alone.

### C. The transfer and wallet-transfer schemas have no fee, no change marker, and no input summary

Files:

- `wdk-indexer-wrk-base/workers/lib/db/base/models/transfer.js:3-17`
- `wdk-data-shard-wrk/workers/lib/db/hyperdb/build.js:65-84`
- `wdk-data-shard-wrk/workers/lib/db/base/repositories/wallet.transfers.js:3-20`

The wallet-transfer schema (hyperdb build.js:65-84) stores:

```
walletId, ts, token, transactionHash, blockchain, transferIndex,
blockNumber, amount, transactionIndex, logIndex, from, to,
fiatAmount, fiatCcy, label
```

There is no stored field for: fee amount, total input amount, change amount, `isChange` flag, or input list / metadata. So the incorrect output-level amount becomes the canonical stored amount.

## 2. Why the logic is wrong

BTC is UTXO-based, but the backend models it like an account-based transfer.

For the reproduced transaction:

- total input: `0.00014133 BTC`
- recipient output: `0.00001249 BTC`
- change output: `0.00012602 BTC`
- fee: `0.00000282 BTC`

The backend stores two rows:

| transferIndex | from | to | amount | meaning |
| --- | --- | --- | --- | --- |
| 0 | sender | receiver | `0.00001249` | actual payment |
| 1 | sender | sender's change addr | `0.00012602` | change |

That is the core bug. The code never computes:

- `sentAmount = external outputs only`
- `fee = sum(inputs) - sum(outputs)`

Instead, it copies `vout.value` into `amount` for every output and treats each output as a user-facing transfer.

## 3. Why it only affects the sender view

### A. Shard sync copies every transfer row into wallet history without BTC-aware consolidation

File: `wdk-data-shard-wrk/workers/proc.shard.data.wrk.js:894-949`

The shard sync job fetches transfers per wallet address and saves each returned row as a wallet transfer keyed by `walletId + transactionHash + transferIndex`:

```js
const existingTransfer = await uow.walletTransferRepository.get(wallet.id, tx.transactionHash, transferIndex)
if (!existingTransfer) {
  await uow.walletTransferRepository.save({
    ...tx,
    transferIndex,
    fiatAmount: fiatAmount ? fiatAmount.toString() : null,
    fiatCcy,
    walletId: wallet.id,
    ts
  })
}
```

There is no BTC-specific aggregation or change filtering in this step. Every output-level transfer from the indexer becomes a separate wallet-transfer row.

### B. Address queries return both sides of a transfer

File: `wdk-indexer-wrk-base/workers/api.indexer.wrk.js:183-193`

`queryTransfersByAddress()` fetches transfers by address. In MongoDB the query is `{ $or: [{ from: address }, { to: address }] }`. In HyperDB, the address index is built from both `from` and `to`.

So for the sender address, the indexer returns both:

- the payment output (`from = sender`)
- the change output (`from = sender`, `to = sender's change address`)

For the receiver address, it returns only the payment output (`to = receiver`).

### C. Sender/receiver direction is derived only from `tx.from`

File: `wdk-data-shard-wrk/workers/api.shard.data.wrk.js:380, 499`

The API classifies direction like this:

```js
type: walletAddresses.includes(tx.from) ? 'sent' : 'received'
```

This ignores whether `tx.to` is also one of the wallet's addresses. For the change row:

- `from` belongs to the sender wallet -> classified as `sent`
- `to` also belongs to the sender wallet -> ignored

The receiver sees the correct amount because only the payment output matches their address. The sender sees multiple `sent` rows with wrong amounts because both the payment and change outputs have `from = sender`.

## 4. How UTXO handling breaks down

The breakdown happens in four stages:

1. **`rpc.provider.js`** flattens BTC outputs into separate transfer rows, discarding input metadata at persistence
2. **`proc.indexer.wrk.js`** persists only flat fields (`from`, `to`, `amount`) and drops the `metadata.inputs` array
3. **`proc.shard.data.wrk.js`** copies every row into wallet history without BTC-aware consolidation
4. **`api.shard.data.wrk.js`** marks rows as `sent` based only on ownership of `from`

That pipeline works for account-model chains (ETH, SOL), but it breaks for BTC because one logical spend often has:

- one or more inputs
- one recipient output
- one change output
- an implicit fee (inputs - outputs)

The current model has no durable notion of "external payment output", "change output", "transaction fee", or "logical send amount".

## 5. Stored data is insufficient for fee reconstruction

`_parseTx()` does build `metadata.inputs` with input addresses and amounts, but that data is not persisted by the base indexer (`proc.indexer.wrk.js:221-237` explicitly picks only flat fields).

This means a pure read-time fix using existing stored wallet-transfer rows cannot accurately compute:

- total input value
- exact fee

unless the system is changed to persist extra BTC-specific context or re-fetch raw chain transaction details at query time.

## 6. Related edge case: multi-input transactions

File: `wdk-indexer-wrk-btc/workers/lib/providers/rpc.provider.js:128-152`

The BTC parser only sets `from` when **all** inputs resolve to the same address:

```js
let allSame = true
const prev = this._parseVinAddr(tx.vin[0])
for (const vin of tx.vin) {
  if (vin.coinbase) { allSame = false; break }
  const parsed = this._parseVinAddr(vin)
  if (parsed !== prev) { allSame = false; break }
}
if (allSame) { from = prev }
```

If a wallet spends multiple UTXOs from different wallet-owned addresses (common with HD wallets), `_parseTx()` leaves `from = null`. The shard API direction logic (`walletAddresses.includes(tx.from)`) then fails to classify the outbound spend as `sent`, because `null` won't match any wallet address.

This is not the bug shown in the screenshots, but it stems from the same root problem: BTC is being squeezed into a single `from/to/amount` transfer model.

## 7. Suggested direction for the fix

### Recommended direction

Fixing this in the wallet-aware history layer (data-shard) is the most practical direction, but reliable BTC change detection requires either full wallet-owned address context or extra BTC transaction metadata persisted during indexing.

Today, the shard layer only has visibility into the wallet's currently stored chain addresses (`wallet.addresses`), not a full HD BTC address set. That means change detection based solely on `wallet.addresses` will work when the change output goes to a known address, but will miss change outputs sent to derived addresses not yet tracked by the wallet model.

### Practical approach

1. **Group BTC wallet-transfer rows by `transactionHash`** for sender-side history
2. **Treat outputs whose `to` matches a known wallet address as change** -- this covers the common case but is not exhaustive for HD wallets
3. **For outbound BTC transactions, display the amount as the sum of non-wallet-owned outputs** (the actual payment)
4. **Do not expose wallet-owned change outputs as separate `sent` transfers**
5. **For reliable fee display and complete change detection**, persist extra BTC context during indexing or shard sync:
   - total input amount, or
   - explicit fee amount, or
   - the `metadata.inputs` array that `_parseTx()` already builds but currently drops
   - alternatively, expand wallet address tracking to include the full HD derivation set

### Optional improvement at the indexer level

The BTC indexer can add a preliminary label for obvious self-change where `from === to`, but this is only a partial heuristic. It will miss HD-wallet change outputs that go to a different wallet-owned address not currently stored in the wallet model.

## Conclusion

The root cause is not a bad numeric formula in one line. It is a pipeline mismatch:

- BTC outputs are stored as if each output were a user-facing transfer
- Change outputs are not identified
- Fee is not stored
- Input metadata is dropped at persistence
- Sender/receiver direction uses only `from`

As a result, the sender history shows change as a separate `sent` amount, while the receiver history remains correct because it only matches the actual payment output.
