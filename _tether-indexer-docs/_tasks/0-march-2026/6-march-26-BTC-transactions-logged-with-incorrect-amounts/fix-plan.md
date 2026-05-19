# Fix Plan: BTC Transactions Logged with Incorrect Amounts

Based on the root cause analysis in `analysis.md`.

## Overview

The fix spans three repos and is split into two phases:

1. **Phase 1 -- Persist BTC transaction context end-to-end** (`wdk-indexer-wrk-btc`, `wdk-indexer-wrk-base`, `wdk-data-shard-wrk`)
2. **Phase 2 -- Consume and aggregate BTC transfers at the wallet layer** (`wdk-data-shard-wrk`)

Phase 1 is a prerequisite for accurate fee display but does not change user-visible behavior. Phase 2 is the user-facing fix.

---

## Phase 1: Persist BTC transaction context

### Goal

Each BTC transfer row should carry enough context end-to-end, from chain parsing through shard wallet-transfer storage, to reconstruct fees when knowable, identify the transaction's total input value, and detect multi-input senders without re-fetching from chain.

### 1.1 Compute and attach `fee`, `inputTotal`, and `inputAddresses` in `_parseTx()`

**File:** `wdk-indexer-wrk-btc/workers/lib/providers/rpc.provider.js`

`_parseTx()` already builds `metadata.inputs` (lines 154-166) with each input's value. Use it to compute three new fields:

```js
const hasIncompleteInputs = inputs.some(inp => inp.coinbase || inp.amount == null)

let inputTotal = null
let fee = null
if (!hasIncompleteInputs && inputs.length > 0) {
  inputTotal = inputs.reduce((sum, inp) => {
    return nBN(sum).plus(inp.amount).toString()
  }, '0')

  const outputTotal = tx.vout.reduce((sum, vout) => {
    return nBN(sum).plus(vout.value).toString()
  }, '0')

  fee = nBN(inputTotal).minus(outputTotal).toString()
}

const inputAddresses = [...new Set(
  inputs
    .filter(inp => !inp.coinbase && inp.address)
    .map(inp => inp.address)
)]
```

Attach all three to each returned transfer object (alongside the existing fields). These are transaction-level properties, so they are safe to duplicate across rows:

```js
return {
  // ...existing fields...
  fee,           // new: string|null, total fee for this transaction when knowable
  inputTotal,    // new: string|null, sum of all input values when knowable
  inputAddresses // new: string[], all unique sender addresses seen in vin.prevout
}
```

If any input is coinbase or missing `prevout.value`, both `inputTotal` and `fee` should be `null`. Unknown is safer than wrong. `inputAddresses` should still be populated from whatever input addresses are available.

### 1.2 Persist the new fields in `proc.indexer.wrk.js`

**File:** `wdk-indexer-wrk-base/workers/proc.indexer.wrk.js`

In `syncTxns()` (lines 221-239), add the new fields to the persisted value:

```js
value: {
  // ...existing fields...
  fee: entry.value.fee || null,
  inputTotal: entry.value.inputTotal || null,
  inputAddresses: entry.value.inputAddresses || null
}
```

Using `|| null` keeps the fields absent for non-BTC chains that don't produce them, maintaining backward compatibility.

### 1.3 Update the transfer schema

The new fields must be added as optional in both storage engines.

**MongoDB** (`wdk-indexer-wrk-base/workers/lib/db/mongodb/models/transfer.js`):
No schema change needed -- MongoDB is schemaless. The fields will be stored automatically via the existing `$set: doc` upsert (line 80).

**HyperDB** (`wdk-indexer-wrk-base/workers/lib/db/hyperdb/build.js`):
New fields must be **appended at the end** of the existing schema registration (per WARP.md: HyperDB schemas are append-only, inserting fields in the middle breaks the spec). Add:

```js
{ name: 'fee', type: 'string', required: false },
{ name: 'inputTotal', type: 'string', required: false },
{ name: 'inputAddresses', type: 'json', required: false }
```

After updating the schema:
1. Re-run the HyperDB spec builder to regenerate `spec/hyperdb/` and `spec/hyperschema/`
2. Bump the version in `wdk-indexer-wrk-base/package.json`
3. Update `wdk-indexer-wrk-btc/package.json` to reference the new base version
4. Run `npm install` in `wdk-indexer-wrk-btc`

**Base type definition** (`wdk-indexer-wrk-base/workers/lib/db/base/models/transfer.js`):
Update the `TransferEntity` typedef to include the new optional fields:

```js
 * @property {string} [fee]
 * @property {string} [inputTotal]
 * @property {string[]} [inputAddresses]
```

### 1.4 Update the Redis stream format and shard persistence

The current stream format is a comma-separated string parsed via `raw.split(',')` in `_parseRawTransfer()`. The new `inputAddresses` field is an array, which cannot be safely appended to a CSV format without breaking field positions on split.

**Solution: switch the stream payload to JSON.**

**Publisher** (`wdk-indexer-wrk-base/workers/proc.indexer.wrk.js:358-359`):

Replace the CSV serialization with JSON:

```js
for (const tx of batch) {
  const raw = JSON.stringify({
    transactionHash: tx.transactionHash,
    transferIndex: tx.transferIndex,
    blockNumber: tx.blockNumber,
    from: tx.from,
    to: tx.to,
    amount: tx.amount,
    timestamp: tx.timestamp,
    blockchain: tx.blockchain,
    token: tx.token,
    transactionIndex: tx.transactionIndex,
    logIndex: tx.logIndex || 0,
    label: tx.label,
    fee: tx.fee || null,
    inputTotal: tx.inputTotal || null,
    inputAddresses: tx.inputAddresses || null
  })

  pipe.xadd(
    this._transactionStream,
    '*',
    'type', TRANSACTION_MSG_TYPES.NEW_TRANSACTION,
    'raw', raw
  )
}
```

**Consumer** (`wdk-data-shard-wrk/workers/proc.shard.data.wrk.js:1017-1033`):

Update `_parseRawTransfer()` to handle both JSON (new) and CSV (old in-flight messages during rollover):

```js
_parseRawTransfer (raw) {
  // JSON format (new): starts with '{'
  if (raw.charAt(0) === '{') {
    const parsed = JSON.parse(raw)
    return {
      transactionHash: parsed.transactionHash,
      transferIndex: parsed.transferIndex,
      blockNumber: parsed.blockNumber,
      from: parsed.from,
      to: parsed.to,
      amount: parsed.amount,
      ts: parsed.timestamp,
      blockchain: parsed.blockchain,
      token: parsed.token,
      transactionIndex: parsed.transactionIndex,
      logIndex: parsed.logIndex || 0,
      label: parsed.label,
      walletId: parsed.walletId,
      fee: parsed.fee || null,
      inputTotal: parsed.inputTotal || null,
      inputAddresses: parsed.inputAddresses || null
    }
  }

  // CSV format (legacy): backward compatible fallback
  const parts = raw.split(',')
  return {
    transactionHash: parts[0],
    transferIndex: parseInt(parts[1]),
    blockNumber: parseInt(parts[2]),
    from: parts[3],
    to: parts[4],
    amount: parts[5],
    ts: parseInt(parts[6]),
    blockchain: parts[7],
    token: parts[8],
    transactionIndex: parseInt(parts[9]),
    logIndex: parseInt(parts[10]),
    label: parts[11],
    walletId: parts[12],
    fee: null,
    inputTotal: null,
    inputAddresses: null
  }
}
```

The `charAt(0) === '{'` check provides a zero-cost backward-compatible transition. Old CSV messages still in the stream (up to the trim window, default 6 hours) are parsed correctly. Once all old messages age out, the CSV fallback path becomes dead code and can optionally be removed later.

The save at line 1079 (`...transfer` spread) will then automatically include the new fields for stream-ingested transfers, matching the batch sync path.

Because Phase 1 now persists BTC context end-to-end, the shard wallet-transfer storage also needs to accept the same optional fields.

**Shard HyperDB** (`wdk-data-shard-wrk/workers/lib/db/hyperdb/build.js:65-85`):
Append the same three optional fields at the end of the `wallet-transfers` schema:

```js
{ name: 'fee', type: 'string', required: false },
{ name: 'inputTotal', type: 'string', required: false },
{ name: 'inputAddresses', type: 'json', required: false }
```

After updating the shard schema:
1. Re-run the HyperDB spec builder to regenerate `spec/hyperdb/` and `spec/hyperschema/`
2. Bump the version in `wdk-data-shard-wrk/package.json`
3. Update `rumble-data-shard-wrk/package.json` if it depends on `wdk-data-shard-wrk`
4. Run `npm install` in dependent repos

MongoDB needs no schema change.

**Stream routing dependency:** The indexer publishes to `@wdk/transactions:{chain}:{token}` (e.g. `@wdk/transactions:bitcoin:btc`) while the shard consumes from `@wdk/transactions:shard-{shardGroup}`. These are different Redis streams. There is a router/bridge component (not present in this workspace) that reads from the per-chain indexer streams and writes into the per-shard streams. That router also needs to be updated to forward the new JSON payload format. If the router currently copies the `raw` field verbatim, no change is needed. If it re-serializes or transforms the payload, it must be updated to preserve the new fields. **This dependency must be verified before deployment.**

**Note on `walletId`:** The current CSV format includes `walletId` at position 12 but the publisher in `proc.indexer.wrk.js` does not include it -- this field is added downstream (likely by the stream router or the ork notification path). The JSON format should follow the same convention: only include the fields the publisher knows about. Consumers that need `walletId` should continue to get it from the downstream path that adds it.

### 1.5 Tests

- **Unit test** `_parseTx()` with a multi-output BTC transaction fixture. Verify `fee`, `inputTotal`, and `inputAddresses` are correct on each returned transfer.
- **Unit test** `_parseTx()` with a coinbase transaction. Verify `fee` and `inputTotal` are `null`, `inputAddresses` is empty.
- **Unit test** `_parseTx()` with a transaction where one input is missing `prevout.value`. Verify `fee` and `inputTotal` are `null` rather than partially computed.
- **Unit test** `_parseRawTransfer()` with:
  - Old CSV format (13 fields) -- verify backward compat, new fields default to null
  - New JSON format -- verify all fields including `inputAddresses` are parsed correctly
- **Existing tests** in `wdk-indexer-wrk-btc/tests/` should continue to pass since the new fields are additive.

---

## Phase 2: Aggregate BTC transfers at the wallet layer

### Goal

For BTC, use the persisted Phase 1 context to collapse per-output transfer rows into a single logical transaction for the sender's history. Show the correct sent amount and fee when available.

### 2.1 Use the persisted Phase 1 fields in wallet-transfer rows

Once Phase 1 lands, wallet-transfer rows already carry `fee`, `inputTotal`, and `inputAddresses` via both paths:
- **Batch sync path** (`getTransfersForWalletsBatch` -> `walletTransferRepository.save`): the fields come from the indexer RPC response, which includes the new fields from `_parseTx()`.
- **Stream path** (`_parseRawTransfer` -> `walletTransferRepository.save`): the fields come from the updated JSON stream parser (section 1.4).

Phase 2 does not add new persistence work. It consumes those fields for wallet-history behavior:
- `fee`: display when present
- `inputTotal`: retained as transaction context, even though output aggregation does not require it directly
- `inputAddresses`: used for direction detection when `from` is `null`

Older rows may still have these fields as `null`/absent. Phase 2 must degrade gracefully on historical data.

### 2.2 Add BTC transfer aggregation logic

Create a utility function (e.g., in `wdk-data-shard-wrk/workers/lib/btc.utils.js`):

```js
/**
 * Groups BTC wallet-transfer rows by transactionHash and collapses them
 * into a single logical transfer for the sender's view.
 *
 * @param {Array} transfers - raw wallet-transfer rows for a single txHash
 * @param {string[]} walletAddresses - addresses owned by THIS WALLET (not user-wide)
 * @returns {object} - single logical transfer
 */
function aggregateBtcSendTransfers (transfers, walletAddresses) {
  // All rows share the same transactionHash, fee, inputTotal, from, timestamp
  const first = transfers[0]

  // Separate outputs into payment (external) and change (wallet-owned)
  let paymentAmount = nBN('0')
  let changeAmount = nBN('0')
  let recipientAddress = null

  for (const tx of transfers) {
    if (walletAddresses.includes(tx.to)) {
      changeAmount = changeAmount.plus(tx.amount)
    } else {
      paymentAmount = paymentAmount.plus(tx.amount)
      // Use the first external output as the display recipient
      if (!recipientAddress) recipientAddress = tx.to
    }
  }

  return {
    ...first,
    type: 'sent',
    to: recipientAddress,
    amount: paymentAmount.toString(),
    fee: first.fee || null,
    // Preserve the original transferIndex=0 for the collapsed row
    transferIndex: 0
  }
}
```

**Key behavior:**
- `amount` = sum of outputs NOT owned by the wallet (the actual payment)
- Change outputs are excluded from the displayed amount
- `fee` comes from the persisted field (Phase 1)
- `to` = the first external recipient address

**Critical: per-wallet addresses, not user-wide.** The `walletAddresses` parameter must be the addresses for the specific wallet being queried, not the union of all user wallet addresses. If user-wide addresses were used, a transfer from wallet A to wallet B (same user) would be incorrectly collapsed as "change". In `getUserTransfers`, this means using `walletIdToAddresses[wallet.id]` (line 348), not the global `walletAddresses` array (line 337).

**Limitation:** Change detection relies on `wallet.addresses` which may not include all HD-derived addresses. This handles the common case. For full accuracy, wallet address tracking would need to be expanded separately (out of scope for this fix).

### 2.3 Apply aggregation inside the per-wallet iterator (not post-processing)

**File:** `wdk-data-shard-wrk/workers/api.shard.data.wrk.js`

Aggregation must happen **inside** each wallet's iterator, before the merge-sort and before skip/limit are applied. This is critical because:

- The current merge-sort iterator (`getUserTransfers` lines 404-429, `getWalletTransfers` lines 494-510) applies `skip`/`limit` as it yields individual rows
- If aggregation is done post-page (after skip/limit), multiple raw rows from one BTC tx may span a page boundary, causing short pages, duplicates, or skipped logical transactions
- BTC outputs within the same transaction share the same timestamp, so a same-txHash buffer within the per-wallet iterator is safe and won't break sort order

Modify `createWalletIterator` in `getUserTransfers` (line 369) and the equivalent loop in `getWalletTransfers` (line 494):

First, extract a helper for the `isSent` check that accounts for `inputAddresses`:

```js
/**
 * Checks if a transfer was sent by this wallet.
 * Handles both single-from and multi-input BTC transactions.
 */
function isSentByWallet (tx, walletAddrs) {
  if (walletAddrs.includes(tx.from)) return true
  if (tx.inputAddresses && tx.inputAddresses.some(addr => walletAddrs.includes(addr))) return true
  return false
}
```

Then update the `matcher` functions in both `getUserTransfers` (line 360) and `getWalletTransfers` (line 480) to use it. Currently:

```js
// getUserTransfers matcher (line 364)
if (type && type.toLowerCase() === 'sent' && !walletAddresses.includes(tx.from)) return false

// getWalletTransfers matcher (line 484)
if (type && type.toLowerCase() === 'sent' && !walletAddress.includes(tx.from)) return false
```

Must become:

```js
// getUserTransfers matcher
if (type && type.toLowerCase() === 'sent' && !isSentByWallet(tx, walletAddresses)) return false

// getWalletTransfers matcher
if (type && type.toLowerCase() === 'sent' && !isSentByWallet(tx, walletAddress)) return false
```

Note: the `matcher` functions use the broader address set (user-wide in `getUserTransfers`, wallet-wide in `getWalletTransfers`) because their purpose is filtering which rows to include in the response. This is correct -- the matcher answers "should this row appear in the results at all?" while the per-wallet `isSentByWallet` inside the iterator answers "is this a send from this specific wallet?" The distinction matters for `getUserTransfers` where the filter is user-scoped but the direction classification is wallet-scoped.

Now the iterator:

```js
const createWalletIterator = async (wallet) => {
  const walletAddrs = walletIdToAddresses[wallet.id] // per-wallet, NOT user-wide
  const stream = this.db.walletTransferRepository.getTransfersForWalletInRange(
    wallet.id, fromTs, toTs, reverse
  )

  const iterator = (async function * () {
    let btcBuffer = null // { txHash, rows: [] }

    for await (const tx of stream) {
      const isSent = isSentByWallet(tx, walletAddrs)
      const isBtc = tx.blockchain === 'bitcoin'

      // For BTC sends, buffer rows sharing the same transactionHash
      if (isSent && isBtc) {
        if (btcBuffer && btcBuffer.txHash !== tx.transactionHash) {
          // Flush previous txHash group
          yield aggregateBtcSendTransfers(btcBuffer.rows, walletAddrs)
          btcBuffer = null
        }
        if (!btcBuffer) btcBuffer = { txHash: tx.transactionHash, rows: [] }
        btcBuffer.rows.push(tx)
        continue
      }

      // Flush any pending BTC buffer before yielding a non-BTC-send row
      if (btcBuffer) {
        yield aggregateBtcSendTransfers(btcBuffer.rows, walletAddrs)
        btcBuffer = null
      }

      // For BTC: skip change outputs that appear as "received"
      // A change output has tx.to owned by this wallet AND the transaction
      // was sent by this wallet (tx.from or inputAddresses match).
      // Since isSent is false here (we passed the isSent && isBtc check above),
      // this wallet does NOT own tx.from/inputAddresses. But the tx.to might
      // still be this wallet's address -- that's a genuine receive, not change.
      // The only case to skip is when the aggregated BTC send already accounts
      // for this output as change. That happens when isSent is true, which is
      // handled by the buffer above. So no skip is needed here -- genuine
      // receives pass through normally.

      const txWithCalculatedFields = {
        type: isSent ? 'sent' : 'received',
        ...tx
      }

      if (matcher(txWithCalculatedFields)) {
        yield txWithCalculatedFields
      }
    }

    // Flush final BTC buffer
    if (btcBuffer) {
      yield aggregateBtcSendTransfers(btcBuffer.rows, walletAddrs)
    }
  })()

  const { value, done } = await iterator.next()
  return { iterator, current: done ? null : value, done }
}
```

This works because:
- Rows from the same BTC transaction share the same timestamp and are stored adjacently
- The buffer only holds rows for one txHash at a time, so memory overhead is minimal (typically 2-3 rows)
- The iterator still yields in timestamp order, so the outer merge-sort and skip/limit remain correct
- Non-BTC chains pass through unchanged

### 2.4 Apply aggregation in `getWalletTransfers`

**File:** `wdk-data-shard-wrk/workers/api.shard.data.wrk.js:490-512`

Same buffering pattern as 2.3 but simpler -- there's only one wallet, no merge-sort. Apply the same btcBuffer logic inside the `for await` loop at line 495, using `walletAddress` (the per-wallet array built at line 467).

### 2.5 Handle the `from = null` edge case (multi-input transactions)

**File:** `wdk-indexer-wrk-btc/workers/lib/providers/rpc.provider.js:128-152`

Currently, `from` is set to `null` when inputs come from multiple addresses. This causes the shard layer to misclassify the spend as `received`.

Simply setting `from` to the first input address (as previously proposed) is not a safe fix. It causes the other input addresses to be lost from the query index -- the transaction would stop matching those addresses in `findByAddressAndTimestamp`, turning one lossy encoding into another.

**Recommended approach: persist `inputAddresses` as an additional field.**

In `_parseTx()`, collect all unique input addresses and include them on each transfer row:

```js
const inputAddresses = [...new Set(
  inputs
    .filter(inp => !inp.coinbase && inp.address)
    .map(inp => inp.address)
)]
```

Add to each returned transfer:

```js
return {
  // ...existing fields...
  fee,
  inputTotal,
  inputAddresses  // new: string[], all unique sender addresses
}
```

Keep the existing `from` logic unchanged (set to the single address when all inputs match, `null` otherwise). This preserves backward compatibility for all existing query paths.

In the shard layer, direction detection uses the `isSentByWallet()` helper introduced in section 2.3, which already checks both `tx.from` and `tx.inputAddresses`:

```js
function isSentByWallet (tx, walletAddrs) {
  if (walletAddrs.includes(tx.from)) return true
  if (tx.inputAddresses && tx.inputAddresses.some(addr => walletAddrs.includes(addr))) return true
  return false
}
```

**Schema impact:** `inputAddresses` is an array. For MongoDB, no issue. For HyperDB, this needs a `json` type field appended to the schema. Storage cost is low -- typically 1-2 addresses per transfer.

This field is introduced in Phase 1 and consumed in Phase 2 for direction detection.

### 2.6 `getUserTransfers`: internal transfers between a user's own wallets

`getUserTransfers` iterates across all wallets for a user. When wallet A sends BTC to wallet B (same user), two things happen:

- Wallet A's iterator sees outputs where `from` = wallet A address (sent)
- Wallet B's iterator sees the same transaction where `to` = wallet B address (received)

With per-wallet change detection (2.2), wallet A will NOT treat the output to wallet B as change (wallet B's address is not in wallet A's `walletAddresses`). This is correct -- it should show as a sent transfer on wallet A.

Wallet B will see it as a received transfer. This is also correct.

No special handling is needed for internal transfers, as long as change detection uses per-wallet addresses (not user-wide).

### 2.7 Tests

- **Unit test** `aggregateBtcSendTransfers()` with:
  - Standard 2-output transaction (1 payment + 1 change)
  - Transaction where change address is NOT in `walletAddresses` (should treat all outputs as payment -- graceful degradation)
  - Transaction with multiple payment outputs (batch send)
  - Single-output transaction (no change -- send-all)
- **Unit test** the iterator buffering logic: verify that a stream of [btc-out-0, btc-out-1, eth-tx, btc-out-0, btc-out-1] yields [aggregated-btc, eth-tx, aggregated-btc] in order
- **Unit test** pagination: verify that skip/limit counts aggregated rows, not raw rows
- **Unit test** `isSentByWallet()` with: single-from match, `from=null` with `inputAddresses` match, no match
- **Unit test** `matcher()` with `type=sent` filter for multi-input BTC tx where `from=null` but `inputAddresses` matches
- **Integration test** the full flow: index a BTC block, sync to shard via both batch and stream paths, query via `getWalletTransfers`, verify correct aggregated amount
- **Regression test** that ETH/SOL transfers are unaffected by the BTC-specific logic
- **Edge case test**: wallet A sends to wallet B (same user) -- verify both wallets show the correct amount and direction

---

## Rollout considerations

### HyperDB schema updates

Both `wdk-indexer-wrk-base` and `wdk-data-shard-wrk` require HyperDB schema changes. For each:

1. Append new fields at the **end** of the schema registration (never insert in the middle)
2. Re-run the spec builder (`node workers/lib/db/hyperdb/build.js`) to regenerate `spec/hyperdb/` and `spec/hyperschema/`
3. Commit the regenerated spec files
4. Bump the package version in `package.json`

Dependent repos must then update their dependency versions and run `npm install`:
- `wdk-indexer-wrk-base` change -> update `wdk-indexer-wrk-btc`
- `wdk-data-shard-wrk` change -> update `rumble-data-shard-wrk`

### Data migration

- **New transfers** will carry `fee`, `inputTotal`, and `inputAddresses` after Phase 1 deploys.
- **Existing transfers** in the database will have these fields as `null`/absent. The aggregation logic in Phase 2 must handle this gracefully:
  - If `fee` is null, omit fee from the response (or display "fee unavailable").
  - Amount aggregation (sum of non-wallet outputs) works regardless of whether `fee` is present.
  - If `inputAddresses` is absent, fall back to checking only `tx.from` for direction (current behavior).

### Deployment order

1. **Verify the stream router** (not in this workspace) that bridges `@wdk/transactions:{chain}:{token}` -> `@wdk/transactions:shard-{shardGroup}`. Confirm whether it passes the `raw` field through verbatim or re-serializes it. Update if needed.
2. Deploy Phase 1 (`wdk-indexer-wrk-btc` + `wdk-indexer-wrk-base` + the Phase 1 parser/schema changes in `wdk-data-shard-wrk`) first. This is additive and non-breaking. If the stream router needs changes, deploy those at the same time.
3. Wait for enough new blocks to be indexed with the new fields.
4. Deploy the rest of Phase 2 (`wdk-data-shard-wrk` aggregation logic). The aggregation will immediately fix the sender-side display for new transactions and for existing transactions (using output-based aggregation even without fee data).

### Backward compatibility

- Phase 1 adds optional fields. No consumer breaks.
- Phase 2 changes the shape of BTC transfer responses. The app must handle:
  - A single aggregated `sent` row instead of multiple rows per transaction
  - `fee` field present on BTC transfers
  - If the app currently sums multiple rows per txHash on its own, that logic should be reviewed.

---

## Summary of file changes

| Phase | Repo | File | Change |
|-------|------|------|--------|
| 1 | `wdk-indexer-wrk-btc` | `workers/lib/providers/rpc.provider.js` | Compute `fee` / `inputTotal` when all input values are known, else leave them `null`. Collect `inputAddresses` in `_parseTx()`. |
| 1 | `wdk-indexer-wrk-base` | `workers/proc.indexer.wrk.js` | Persist `fee`, `inputTotal`, `inputAddresses` in transfer value. Switch Redis stream to JSON format. |
| 1 | `wdk-indexer-wrk-base` | `workers/lib/db/base/models/transfer.js` | Add `fee`, `inputTotal`, `inputAddresses` to typedef. |
| 1 | `wdk-indexer-wrk-base` | `workers/lib/db/hyperdb/build.js` | Append optional `fee`, `inputTotal`, `inputAddresses` fields to transfer schema. Regenerate specs. |
| 1 | `wdk-indexer-wrk-base` | `package.json` | Version bump. |
| 1 | `wdk-indexer-wrk-btc` | `package.json` | Update base dependency version. |
| 1 | *stream router* (not in workspace) | TBD | Verify `raw` field is passed through verbatim. If router re-serializes, update to preserve JSON payload with new fields. |
| 1 | `wdk-data-shard-wrk` | `workers/proc.shard.data.wrk.js` | Update `_parseRawTransfer()` to parse JSON (new) with CSV fallback (legacy). Extract `fee`, `inputTotal`, `inputAddresses`. |
| 1 | `wdk-data-shard-wrk` | `workers/lib/db/hyperdb/build.js` | Append optional `fee`, `inputTotal`, `inputAddresses` to `wallet-transfers` schema. Regenerate specs. |
| 1 | `wdk-data-shard-wrk` | `package.json` | Version bump for the Phase 1 schema/parser change. |
| 1 | `rumble-data-shard-wrk` | `package.json` | Update `wdk-data-shard-wrk` dependency version if applicable. |
| 2 | `wdk-data-shard-wrk` | `workers/lib/btc.utils.js` (new) | `aggregateBtcSendTransfers()` and `isSentByWallet()` functions. |
| 2 | `wdk-data-shard-wrk` | `workers/api.shard.data.wrk.js` | BTC aggregation inside per-wallet iterators. Update `matcher()` in both `getUserTransfers` and `getWalletTransfers` to use `isSentByWallet()` for `type=sent` filtering. |
| 2 | `wdk-data-shard-wrk` | `package.json` | Version bump for the Phase 2 aggregation code. |
| 2 | `rumble-data-shard-wrk` | `package.json` | Update `wdk-data-shard-wrk` dependency version for the Phase 2 release. |
