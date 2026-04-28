# Final Finding - Rumble tx webhook retry count / delay

Date: 2026-04-28

## Verdict

The ticket analysis is correct. The bug is in `rumble-data-shard-wrk`, specifically in `workers/proc.shard.data.wrk.js`.

Plain `transactionHash` webhooks can remain `pending` forever because `_isTxCompleted()` only returns `retry: true` while a gasless / `transactionReceiptId` is still unresolved. When a normal transaction hash is not found, unconfirmed, non-existent, or does not match the expected transfer, `_isTxCompleted()` returns:

```js
{
  isCompleted: false,
  transaction: null
}
```

The caller, `_processTxWebhooksJob()`, only increments `retryCount`, sets `retryAt`, and eventually marks the row `failed` inside this branch:

```js
if (txResult?.retry) {
  ...
}
```

So the tx-hash miss never enters the retry branch. The row stays `pending`, keeps matching `getTxWebhooks()`, and is retried indefinitely without changing `retryCount`, `retryAt`, `status`, or `processedAt`.

This also affects gasless hooks after their receipt has resolved. Once `getGasLessTransactionReceipt()` returns a hash, `_isTxCompleted()` replaces the local `transactionHash` and falls through to the same `getTransactionFromChain()` block. If that underlying transaction is not indexed or confirmed yet, the same no-`retry` return happens.

## Local Evidence

Verified in `rumble-data-shard-wrk` on local `dev`:

- `workers/proc.shard.data.wrk.js:232-335`
  - `_processTxWebhooksJob()` reads pending rows from `this.db.txWebhookRepository.getTxWebhooks()`.
  - It only writes retry state when `txResult?.retry` is truthy.
  - It currently uses `this.gaslessMaxRetries` and `this.gaslessRetryDelay` for all retry writes.
  - It marks terminal failures with `TX_WEBHOOK_STATUS.FAILED`, matching PR #179's persisted-status lifecycle.

- `workers/proc.shard.data.wrk.js:337-374`
  - Gasless receipt unresolved path: if `getGasLessTransactionReceipt()` has no hash, it returns `{ isCompleted: false, retry: true }`.
  - Gasless receipt resolved path: sets the local `transactionHash = receipt.hash`, then falls through to the common tx-hash lookup.
  - Common tx-hash path: calls `blockchainSvc.getTransactionFromChain()` and returns only `{ isCompleted, transaction }`.
  - Missing/unconfirmed/non-existent transactions from indexers are represented as an empty array, so the common tx-hash path returns `isCompleted: false` with no retry flag.

- `workers/lib/db/hyperdb/repositories/txwebhook.js:37-44` and `workers/lib/db/mongodb/repositories/txwebhook.js:75-87`
  - Repositories already respect `retryAt`.
  - Pending rows are selected only when `retryAt` is unset or due.
  - This means the scheduling mechanism exists; the tx-hash path simply never writes into it.

- `workers/lib/utils/constants.js:20-24`
  - `TX_WEBHOOK_STATUS` already has `pending`, `completed`, and `failed`.
  - No schema change is needed to fix this ticket.

- `config/common.json.example:13-23`
  - Supported chain keys visible locally: `ethereum`, `plasma`, `arbitrum`, `polygon`, `tron`, `ton`, `solana`, `bitcoin`, `spark`.

## Solution Starting Point

Implement the fix in `rumble-data-shard-wrk` only.

### Files to change

- `workers/proc.shard.data.wrk.js`
- `workers/lib/utils/constants.js` or a small adjacent retry-policy helper
- `config/proc.shard.data.json.example`
- `config/common.json.example` only to remove or move the misleading top-level gasless retry example values
- `tests/proc.shard.data.wrk.unit.test.js`

### 1. Add tx-hash retry policy

Add a tx-hash retry policy separate from the gasless receipt policy. Treat `wrk` config as the contract because the worker already reads `this.conf.wrk`.

Important config state verified locally:

- `workers/proc.shard.data.wrk.js` reads `this.conf.wrk?.gaslessMaxRetries` and `this.conf.wrk?.gaslessRetryDelay`.
- `config/proc.shard.data.json.example` currently does not contain those keys.
- `config/common.json.example` and local `config/common.json` put those keys at top level, where this worker does not read them.
- Net effect: the configured top-level values are not honored by this worker; it falls back to the hardcoded defaults (`3`, `10_000`). That is hidden today because the example values match the hardcoded defaults.

Make `wrk` the contract. Add both existing gasless settings and the new tx-hash policy to `config/proc.shard.data.json.example`. Remove the misleading top-level gasless settings from `config/common.json.example`, or move them into the correct worker config example.

Suggested shape in `config/proc.shard.data.json.example`:

```json
{
  "gaslessMaxRetries": 3,
  "gaslessRetryDelay": 10000,
  "txWebhookRetryPolicyByBlockchain": {
    "default": { "maxRetries": 10, "retryDelay": 15000 },
    "bitcoin": { "maxRetries": 10, "retryDelay": 300000 },
    "spark": { "maxRetries": 10, "retryDelay": 300000 }
  }
}
```

Use `default` for ETH-class / fast chains: `ethereum`, `plasma`, `arbitrum`, `polygon`, `tron`, `ton`, `solana`. Use BTC policy for `bitcoin` and `spark`; Spark carries `btc` in `config/common.json.example`, so BTC-class timing is the natural default unless product explicitly disagrees.

### 2. Return retry phase from `_isTxCompleted()`

Make `_isTxCompleted()` tell the caller why it is retrying.

Recommended shape:

```js
if (isTransactionReceipt) {
  const receipt = await this.blockchainSvc.getGasLessTransactionReceipt(blockchain, token, transactionHash)

  if (receipt?.hash) {
    transactionHash = receipt.hash
  } else {
    return { isCompleted: false, retry: true, retryPhase: 'gaslessReceipt' }
  }
}

const txArr = await this.blockchainSvc.getTransactionFromChain(blockchain, token, transactionHash)
let transaction = null
if (Array.isArray(txArr) && txArr.length > 0 && from && to && fromAddress && toAddress) {
  transaction = txArr.find(x => x.from === fromAddress && x.to === toAddress)
  if (blockchain === 'bitcoin' && !transaction) {
    transaction = txArr.find(x => x.to === toAddress)
    if (transaction) {
      transaction.from = fromAddress
    }
  }
}

const isCompleted = !!(transaction && transaction.timestamp)

return {
  isCompleted,
  transaction,
  retry: !isCompleted,
  retryPhase: isCompleted ? null : 'txHash'
}
```

Use `retry: !isCompleted`, not the repeated expression, so the intent is obvious.

This explicitly handles both:

- normal `transactionHash` miss
- gasless receipt resolved to a transaction hash, but the underlying transaction is not indexed / confirmed yet

### 3. Choose retry policy by retry phase

In `_processTxWebhooksJob()`, choose policy from the returned phase:

```js
const retryPolicy = txResult.retryPhase === 'gaslessReceipt'
  ? { maxRetries: this.gaslessMaxRetries, retryDelay: this.gaslessRetryDelay }
  : this._getTxWebhookRetryPolicy(txHook.blockchain)
```

Then use the selected policy in the existing branch:

```js
const retryCount = (txHook.retryCount || 0) + 1
const retryAt = Date.now() + retryPolicy.retryDelay

if (retryCount >= retryPolicy.maxRetries) {
  await uow.txWebhookRepository.updateStatus(txHook.transactionHash, TX_WEBHOOK_STATUS.FAILED, Date.now())
} else {
  await uow.txWebhookRepository.save({
    ...txHook,
    status: TX_WEBHOOK_STATUS.PENDING,
    retryCount,
    retryAt
  })
}
```

This avoids the subtle bad outcome where a gasless hook keeps using `3 x 10s` after its receipt has resolved and the worker is now waiting for the actual chain transaction.

### 4. Preserve terminal behavior

- before max retries: save the row as `pending` with incremented `retryCount` and computed `retryAt`
- at max retries: `updateStatus(transactionHash, TX_WEBHOOK_STATUS.FAILED, Date.now())`
- on success: `updateStatus(transactionHash, TX_WEBHOOK_STATUS.COMPLETED, Date.now())`

## Implementation Sketch

Add defaults:

```js
const TX_WEBHOOK_RETRY_POLICY_BY_BLOCKCHAIN = Object.freeze({
  default: Object.freeze({ maxRetries: 10, retryDelay: 15_000 }),
  bitcoin: Object.freeze({ maxRetries: 10, retryDelay: 300_000 }),
  spark: Object.freeze({ maxRetries: 10, retryDelay: 300_000 })
})
```

Initialize with override using per-chain deep merge plus validation. Do not use a shallow spread of chain objects.

```js
_buildTxWebhookRetryPolicyByBlockchain () {
  const override = this.conf.wrk?.txWebhookRetryPolicyByBlockchain || {}
  const result = {}

  for (const blockchain of new Set([
    ...Object.keys(TX_WEBHOOK_RETRY_POLICY_BY_BLOCKCHAIN),
    ...Object.keys(override)
  ])) {
    result[blockchain] = {
      ...(TX_WEBHOOK_RETRY_POLICY_BY_BLOCKCHAIN[blockchain] || {}),
      ...(override[blockchain] || {})
    }
    this._validateTxWebhookRetryPolicy(blockchain, result[blockchain])
  }

  return result
}

_validateTxWebhookRetryPolicy (blockchain, policy) {
  if (!Number.isInteger(policy?.maxRetries) || policy.maxRetries < 1) {
    throw new Error(`ERR_INVALID_TX_WEBHOOK_RETRY_MAX_RETRIES:${blockchain}`)
  }
  if (!Number.isInteger(policy?.retryDelay) || policy.retryDelay < 1) {
    throw new Error(`ERR_INVALID_TX_WEBHOOK_RETRY_DELAY:${blockchain}`)
  }
}
```

Then in `init()`:

```js
this.txWebhookRetryPolicyByBlockchain = this._buildTxWebhookRetryPolicyByBlockchain()
```

The validation is required. Without it, a partial or malformed override like `{ bitcoin: { maxRetries: 5 } }` can produce `retryDelay: undefined`, making `Date.now() + retryDelay` become `NaN`. Repositories treat falsy `retryAt` as ready to process, so a bad policy can recreate constant retries.

Resolve policy:

```js
_getTxWebhookRetryPolicy (blockchain) {
  return this.txWebhookRetryPolicyByBlockchain[blockchain] ||
    this.txWebhookRetryPolicyByBlockchain.default
}
```

Do not add DB fields.

## Tests To Add

Add focused unit tests in `rumble-data-shard-wrk/tests/proc.shard.data.wrk.unit.test.js`:

- plain tx-hash miss schedules retry with default policy (`retryCount` increments, `retryAt` uses `15_000`, status remains `pending`)
- plain bitcoin tx-hash miss schedules retry with BTC policy (`300_000`)
- plain spark tx-hash miss schedules retry with BTC policy (`300_000`)
- plain tx-hash miss at max retry marks `failed`
- gasless receipt unresolved still uses existing gasless policy
- gasless receipt resolved but chain tx missing uses tx-hash per-chain policy
- completed tx marks `completed` and does not increment retry state
- Bitcoin address mismatch does not throw when fallback `find()` returns nothing

## Reviewer Notes

- This intentionally changes post-receipt gasless retry behavior: unresolved receipt still uses gasless settings, but once a receipt resolves to a real transaction hash, missing chain confirmation uses the tx-hash per-chain policy. That is the safer behavior for slow chains and should be called out in the PR description.
- Keep retry delay flat unless Francesco explicitly confirms exponential. The Slack thread mentioned exponential as ideal, but the concrete agreed numbers were flat: `15s x 10` for ETH-class chains and `5m x 10` for BTC.
- Make `wrk` config the contract. `config/proc.shard.data.json.example` must contain `gaslessMaxRetries`, `gaslessRetryDelay`, and `txWebhookRetryPolicyByBlockchain`; the current top-level gasless examples in `common.json.example` are not honored by this worker.
- Deep-merge retry policy overrides per chain and fail startup on invalid values. Do not allow missing or non-positive `maxRetries` / `retryDelay`.

## What Not To Do

- Do not delete exhausted rows.
- Do not add new schema fields.
- Do not use the gasless retry budget for all tx-hash misses.
- Do not leave Spark on the fast-chain default unless product explicitly asks for that.
- Do not shallow-merge retry policy overrides.
