# PR #200 Meeting Notes

PR: https://github.com/tetherto/rumble-data-shard-wrk/pull/200

Title: `fix(txwebhook): per-blockchain retry policy for tx hash misses`

Current head: `27d7590 refactor tx webhook retry policy handling`

Related tickets:

- `RW-1525`
- `WDK-1344`
- Asana: `Rumble - Add blockchain specific retryCount/retryDelay for tx webhook`

## Short Version

This PR fixes a retry hole in the Rumble transaction webhook flow.

Before this change, transaction webhooks created with a normal `transactionHash` could stay `pending` forever if the indexer returned no matching transaction. That includes invalid hashes, not-yet-confirmed hashes, and hashes that exist but do not match the expected `from` / `to` transfer. The worker kept re-reading the same pending row, but it never incremented `retryCount`, never set `retryAt`, and never marked the row `failed`.

The PR makes normal tx-hash misses enter the same lifecycle as gasless receipt misses:

- retry a bounded number of times
- wait until `retryAt` before the next attempt
- mark the row `failed` when the retry budget is exhausted
- mark the row `completed` when the transaction is actually confirmed and Rumble has been notified

The important design choice is that tx-hash retries use a per-blockchain policy, not the existing gasless policy. That is because Bitcoin/Spark can naturally take longer than EVM-like chains, while gasless receipt lookup is a different phase with its own short retry budget.

## The One-Liner For The Meeting

"The bug was not that we were retrying too slowly. The bug was that plain transaction-hash webhooks were not entering the retry state machine at all, so bad or delayed hashes stayed pending forever. I added retry phases so gasless receipt lookup and real chain transaction lookup can use different retry policies."

## System Flow

This flow crosses more than one component.

### 1. Rumble/App sends a transfer notification

The public surface is in `rumble-app-node`:

- `POST /api/v1/notifications`
- `POST /api/v2/notifications`

The request can include either:

- `transactionHash`
- `transactionReceiptId`

For rant/tip flows, the request also carries fields like:

- `payload`
- `dt`
- `id`
- `from`
- `to` or `toAddress`
- `blockchain`
- `token`
- `amount`

Regular `TOKEN_TRANSFER` notifications do not always create tx webhooks. The webhook creation is specifically for the Rumble rant/tip confirmation flows.

### 2. `rumble-ork-wrk` resolves wallet context and creates the tx webhook

The ork worker resolves:

- sender wallet
- recipient wallet
- sender address for the blockchain
- recipient address for the blockchain
- recipient user shard

If the request used `transactionReceiptId`, the ork converts it into `transactionHash` and sets:

```js
isTransactionReceipt = true
```

Then for Rumble rant/tip flows it calls `_addTxWebhook()`, which routes to the correct data shard.

### 3. `rumble-data-shard-wrk` stores a pending webhook row

In the data shard:

```js
storeTxWebhook(req)
```

sets:

```js
req.status = TX_WEBHOOK_STATUS.PENDING
```

and saves the row in the tx-webhook repository.

For rant webhooks, it also calls Rumble's init endpoint:

```txt
POST /-wallet/webhook/transaction-init
```

This is the "we have started tracking this payment" stage.

### 4. The proc worker polls pending tx webhooks

The scheduled job is:

```js
_processTxWebhooksJob()
```

Default schedule from config:

```json
"processTxWebhooks": "*/10 * * * * *"
```

That means the job wakes up every 10 seconds. The repository only yields rows that are still pending and ready:

- `status = pending`
- and either no `retryAt`
- or `retryAt <= Date.now()`

This is already supported in both HyperDB and MongoDB repositories.

### 5. The worker checks chain/indexer state

The worker calls:

```js
_isTxCompleted(txHook)
```

That method has two phases now:

1. `gaslessReceipt`
   - Only for hooks created from `transactionReceiptId`.
   - First check whether the gasless receipt has resolved to a real chain transaction hash.

2. `txHash`
   - Once we have a real transaction hash, call:

```js
blockchainSvc.getTransactionFromChain(blockchain, token, transactionHash)
```

Then the worker filters the returned transfers by expected sender and recipient addresses.

For Bitcoin, there is a special fallback: if exact `from` + `to` matching fails, match by `toAddress` only, then patch `from`. This is important because Bitcoin/UTXO data can be less straightforward than EVM transfer data.

### 6. On success, Rumble gets the completion webhook

When the transaction is completed, the worker posts to Rumble:

```txt
POST /-wallet/webhook/transaction-complete
```

The payload includes things Rumble needs to update its side:

- fiat amount in cents
- crypto amount
- crypto currency
- transaction hash
- blockchain
- Rumble `dt`
- Rumble `id`
- rant payload, when present
- transfer index
- donor user id

Then the tx webhook row is marked:

```js
TX_WEBHOOK_STATUS.COMPLETED
```

## The Original Bug

The old logic only returned `retry: true` in one case:

- gasless receipt is not resolved yet

For a normal transaction hash, this could happen:

1. Rumble creates a webhook with `transactionHash`.
2. Worker asks the indexer for the transaction.
3. Indexer returns `[]`.
4. `_isTxCompleted()` returns:

```js
{
  isCompleted: false,
  transaction: null
}
```

5. `_processTxWebhooksJob()` only increments retry state inside:

```js
if (txResult?.retry) {
  ...
}
```

6. Since `retry` was missing, the worker did nothing:

- no retry count increment
- no retry delay
- no failed status
- no completed status

The row stayed pending forever.

This is exactly the class of issue Usman flagged: webhooks stuck for months because they never get a retry count.

## Why This Matters To Frontend/Product

This PR does not change frontend code directly.

But it changes the backend state that Rumble-facing UX depends on.

For rant/tip flows, Rumble needs a backend confirmation webhook before it can reliably treat the payment as complete. If the tx webhook row is stuck pending forever, the product can end up with a payment-related state that never resolves from the user's point of view.

That can surface as things like:

- Rumble not receiving transaction completion for a rant/tip payment
- a creator/user flow waiting on a confirmation that never arrives
- support/debugging seeing an old pending tx-webhook row with no terminal status
- operational noise because the worker keeps revisiting the same row forever

The app's transaction history screens are a separate flow. This PR does not change `/token-transfers`, wallet balances, or the receive-address logic. It fixes the Rumble transaction webhook confirmation path.

That distinction is important in the meeting:

- If the question is "will this make a missing BTC transaction appear in Latest Transactions?" the answer is no, not directly.
- If the question is "will this stop Rumble rant/tip tx webhooks from staying pending forever?" the answer is yes.

## What Changed In PR #200

### 1. Plain tx-hash misses now retry

`_isTxCompleted()` now returns retry information when the chain transaction is not completed:

```js
return {
  isCompleted,
  transaction,
  retry: !isCompleted,
  retryPhase: isCompleted ? null : TX_WEBHOOK_RETRY_PHASE.TX_HASH
}
```

This is the core behavioral fix.

The worker no longer has a silent no-op state for:

- unconfirmed tx hash
- not-yet-indexed tx hash
- invalid/non-existent tx hash
- matching failure against expected addresses

All of those now consume retry budget and eventually land in a terminal state.

### 2. Retry phases were added

New constant:

```js
TX_WEBHOOK_RETRY_PHASE = {
  GASLESS_RECEIPT: 'gaslessReceipt',
  TX_HASH: 'txHash'
}
```

This matters because there are two different wait conditions:

- `gaslessReceipt`: waiting for the receipt/UserOp hash to resolve into a real transaction hash
- `txHash`: waiting for the actual blockchain transaction to exist, be indexed, and match the expected transfer

Without a phase, the caller cannot know which retry policy is appropriate.

### 3. Tx-hash retries now use per-blockchain policy

New defaults:

```js
TX_WEBHOOK_RETRY_POLICY_BY_BLOCKCHAIN = {
  default: { maxRetries: 10, retryDelay: 15_000 },
  bitcoin: { maxRetries: 10, retryDelay: 300_000 },
  spark: { maxRetries: 10, retryDelay: 300_000 }
}
```

Meaning:

- default / EVM-like chains: 10 tries, 15 seconds apart
- bitcoin: 10 tries, 5 minutes apart
- spark: 10 tries, 5 minutes apart

These values come from the Slack discussion:

- 15s x 10 was considered okay for ETH-like chains
- 5m x 10 was suggested for BTC
- per-blockchain config was agreed as the simple approach

### 4. Gasless retry behavior is preserved

Existing gasless settings remain:

```js
gaslessMaxRetries = 3
gaslessRetryDelay = 10_000
```

The worker still uses those when the gasless receipt itself has not resolved.

The important change is what happens after the receipt resolves:

1. Receipt resolves to a chain transaction hash.
2. Worker switches to tx-hash lookup.
3. If the actual chain transaction is not ready yet, it uses the per-chain tx-hash policy, not the short gasless policy.

That avoids incorrectly failing a slow chain transaction after only `3 x 10s`.

### 5. The retry policy selection was encapsulated

Current code:

```js
const retryPolicy = this._getTxWebhookRetryPolicy(txHook, txResult.retryPhase)
```

The method handles:

- gasless receipt phase
- tx-hash phase
- blockchain fallback to default policy

This was done after review feedback. It keeps `_processTxWebhooksJob()` focused on processing state transitions instead of embedding policy-selection branching in the middle of the job.

### 6. Config now lives where the worker reads it

The worker reads:

```js
this.conf.wrk
```

So the PR moved the example config into:

```txt
config/proc.shard.data.json.example
```

and removed misleading top-level gasless settings from:

```txt
config/common.json.example
```

This avoids a config trap where someone changes `common.json` and expects the proc worker to honor it, while the worker is actually reading `wrk`.

### 7. Config overrides are validated at startup

The PR validates two things separately:

1. Raw override shape
2. Final merged policy values

Raw override shape catches bad config like:

```js
txWebhookRetryPolicyByBlockchain: {
  bitcoin: []
}
```

or:

```js
txWebhookRetryPolicyByBlockchain: {
  bitcoin: 'abcd'
}
```

Final policy validation catches bad values like:

```js
txWebhookRetryPolicyByBlockchain: {
  default: { maxRetries: 0 }
}
```

The split is intentional. The final merged policy can look valid because defaults filled in missing fields, but the raw config can still be malformed. We want malformed config to fail startup loudly.

### 8. Partial blockchain overrides are supported

This is intentional:

```json
{
  "bitcoin": { "maxRetries": 5 }
}
```

means:

- override Bitcoin `maxRetries`
- keep Bitcoin's default `retryDelay`

And:

```json
{
  "ethereum": { "retryDelay": 25000 }
}
```

means:

- override Ethereum retry delay
- keep default max retries

That is why the code does a per-chain merge instead of a simple shallow object spread. A shallow merge would replace the whole `bitcoin` object and lose `retryDelay`.

## Why Not Just Reuse Gasless Retries?

Because gasless receipt lookup and tx-hash lookup are different problems.

Gasless receipt retry answers:

"Has this receipt/UserOp resolved to a real chain transaction hash yet?"

Tx-hash retry answers:

"Can the indexer find the real transaction, and does it match the expected transfer?"

The second question is chain-dependent.

Bitcoin can take longer to confirm and index than EVM-like chains. Spark is BTC-related in this config and uses the same slower default. Using `3 x 10s` for Bitcoin/Spark would be too aggressive and could mark a legitimate delayed transaction as failed.

## Why Flat Retry, Not Exponential?

Francesco mentioned exponential retry as ideal, but the concrete numbers agreed in the Slack thread were flat:

- ETH-like chains: `15s x 10`
- BTC: `5m x 10`

The PR implements the concrete agreed policy instead of inventing an exponential backoff contract.

This is also lower risk because:

- the existing gasless logic already uses flat delay
- the repository already works with a single `retryAt`
- no new scheduler/backoff model is introduced
- operational behavior is easy to reason about

If the team wants exponential later, it can be added as a separate config contract.

## Why Mark Failed Instead Of Deleting?

This follows the lifecycle from PR #179.

PR #179 changed tx webhooks so terminal rows are retained with status:

- `pending`
- `completed`
- `failed`

Keeping failed rows is useful because:

- support/debugging can inspect what happened
- the worker stops reprocessing the same bad row
- the system has an explicit terminal state
- it avoids hiding failures by deleting evidence

This PR builds on that status model instead of changing it.

## Why No DB Migration Or New Fields?

No schema change is needed.

The existing tx-webhook row already has:

- `retryCount`
- `retryAt`
- `status`
- `processedAt`

The repositories already know how to:

- save pending rows with retry state
- only yield rows whose retry time has arrived
- update rows to `completed` or `failed`

The bug was that one branch never wrote into those existing fields. So this PR fixes behavior, not storage shape.

## Why The Bitcoin Fallback Was Touched

The PR also guarded the Bitcoin fallback match.

Bitcoin/UTXO transfer data does not always match the same exact `from` semantics as account-based chains. There was already a Bitcoin fallback that matches by recipient address and then patches `from`.

The fix makes sure we only patch `transaction.from` if a fallback transaction was actually found.

This prevents a crash when:

- chain is Bitcoin
- exact `from` + `to` match fails
- fallback `to` match also fails

In that case we should retry/fail through the policy, not throw while trying to set a property on `undefined`.

## What This PR Does Not Do

This PR does not:

- change transaction history endpoints
- change wallet balance sync
- change address generation
- change frontend receive-address behavior
- change Rumble app-node public request schemas
- change ork routing or shard resolution
- add a new DB field
- delete old failed webhooks
- introduce exponential backoff

It specifically fixes tx-webhook processing in the data shard worker.

## Expected Behavior After This PR

### Case 1: Normal hash, fast chain, tx not found yet

Example: Ethereum/Polygon/etc.

Expected:

1. `_isTxCompleted()` returns `retry: true`, `retryPhase: txHash`.
2. Worker increments `retryCount`.
3. Worker schedules retry for about 15 seconds later.
4. After 10 attempts, worker marks the row `failed`.

### Case 2: Bitcoin hash, tx not found yet

Expected:

1. `_isTxCompleted()` returns `retry: true`, `retryPhase: txHash`.
2. Worker uses Bitcoin policy.
3. Worker schedules retry for about 5 minutes later.
4. After 10 attempts, worker marks the row `failed`.

This gives Bitcoin a longer confirmation/indexing window.

### Case 3: Gasless receipt not resolved yet

Expected:

1. `_isTxCompleted()` returns `retryPhase: gaslessReceipt`.
2. Worker uses gasless policy.
3. Retry remains `3 x 10s`, as before.

### Case 4: Gasless receipt resolved, actual tx hash not indexed yet

Expected:

1. Worker resolves receipt to chain tx hash.
2. Chain lookup returns no completed transaction.
3. `_isTxCompleted()` returns `retryPhase: txHash`.
4. Worker uses per-chain tx-hash policy.

This is a key correctness point. Once we are waiting for the chain transaction, the wait profile should be chain-specific.

### Case 5: Transaction found and completed

Expected:

1. Worker posts `transaction-complete` to Rumble.
2. Worker marks row `completed`.
3. Row stops being processed.

### Case 6: Bad hash or wrong transfer

Expected:

1. Worker retries up to the configured cap.
2. Worker marks row `failed`.
3. Row stops being processed.

This is better than pending forever.

## Meeting Talking Points

### If someone asks "why was this needed?"

Because there was a missing state transition. Plain tx-hash misses were neither completed nor retried nor failed. They just stayed pending forever.

### If someone asks "why not one retry value for all chains?"

Because indexer/confirmation timing is chain-specific. A 15-second retry cadence is reasonable for ETH-like chains but too aggressive for Bitcoin. The Slack decision also pointed toward per-blockchain config.

### If someone asks "why keep gasless separate?"

Because gasless receipt lookup is not the same as waiting for a chain transaction. The receipt phase can stay short, but once we have a real tx hash, we should use the chain policy.

### If someone asks "why not shallow merge the config?"

Because shallow merge changes the config contract. We want this to work:

```json
{ "bitcoin": { "maxRetries": 5 } }
```

That should keep Bitcoin's default retry delay. Shallow merge would replace the whole Bitcoin object and fail because `retryDelay` disappears.

### If someone asks "why validate overrides if final policy is validated?"

Because those are two different checks.

The raw override check catches malformed config like arrays or strings. The final policy check catches invalid merged values. We need both to fail bad config early and clearly.

### If someone asks "why mark failed instead of ignore/delete?"

Because PR #179 already established the status lifecycle. Failed is observable and terminal. Delete would hide the evidence.

### If someone asks "does this change frontend behavior?"

Not directly. It changes backend completion/failure behavior for Rumble rant/tip tx webhooks. The frontend benefit is that flows depending on Rumble transaction completion stop being able to hang forever because of an unbounded pending backend row.

### If someone asks "does this fix missing BTC transaction history?"

No. That is a separate transaction-history/address-sync issue. This PR only fixes tx webhook processing for Rumble confirmation callbacks.

## Review Feedback And Current State

The PR originally added the behavior fix and then was refined based on review comments.

Current state includes:

- tx-hash retry behavior
- per-chain policy defaults
- config override support
- startup validation
- clearer retry policy selection
- helper that validates all final policies
- tests for the retry phases and validation cases

Specific review-driven changes:

- policy selection moved into `_getTxWebhookRetryPolicy(txHook, retryPhase)`
- validation was split into raw override shape validation and final merged policy validation
- final policy validation now loops through all policies in a helper
- the code keeps partial override support instead of switching to shallow merge

## Files Changed

### `workers/proc.shard.data.wrk.js`

Main behavior change.

Adds:

- retry phase return values
- tx-hash retry on incomplete result
- per-chain policy selection
- config building/validation helpers

### `workers/lib/utils/constants.js`

Adds:

- `TX_WEBHOOK_RETRY_PHASE`
- `TX_WEBHOOK_RETRY_POLICY_BY_BLOCKCHAIN`

### `config/proc.shard.data.json.example`

Adds worker-owned config:

- `gaslessMaxRetries`
- `gaslessRetryDelay`
- `txWebhookRetryPolicyByBlockchain`

### `config/common.json.example`

Removes misleading top-level gasless retry values.

### `workers/lib/db/base/repositories/txwebhook.js`

Updates comments so `retryCount` and `retryAt` are no longer described as gasless-only.

### `tests/proc.shard.data.wrk.unit.test.js`

Adds coverage for:

- plain tx-hash miss retry
- gasless receipt unresolved retry
- gasless receipt resolved then tx-hash retry
- per-blockchain policy
- max retry failure
- partial override merging
- invalid config validation

## Test Evidence

Focused worker tests pass:

```txt
npx brittle tests/proc.shard.data.wrk.unit.test.js
```

Result:

```txt
24/24 tests pass
77/77 asserts pass
```

Touched files pass Standard:

```txt
npx standard workers/proc.shard.data.wrk.js tests/proc.shard.data.wrk.unit.test.js
```

Repo-wide checks had unrelated baseline failures:

- `npm run lint` fails because of trailing blank lines in unrelated files.
- `npm run test:unit` stops in an unrelated notification util test with `ERR_NOTIFICATION_SEND_FAILED`.

## Risk Assessment

### Low-risk parts

- No DB schema change.
- No public API schema change.
- Existing status lifecycle is reused.
- Existing `retryAt` repository behavior is reused.
- Existing gasless retry behavior is preserved for unresolved receipts.

### Main behavior change

Rows that previously stayed pending forever will now eventually become `failed`.

That is intentional.

If a chain legitimately needs more time, the mitigation is config:

```json
"txWebhookRetryPolicyByBlockchain": {
  "bitcoin": { "maxRetries": 20, "retryDelay": 300000 }
}
```

or:

```json
"txWebhookRetryPolicyByBlockchain": {
  "default": { "maxRetries": 20 }
}
```

### Operational implication

After deployment, old stuck pending rows may start moving:

- some may complete if the transaction is now indexed and matches
- some may be scheduled with `retryAt`
- some may eventually become failed

That is expected and healthier than indefinite pending.

## Suggested Closing Argument

This PR is deliberately narrow. It does not redesign webhooks or transaction history. It closes the missing lifecycle branch for normal transaction hashes and makes the retry timing match the chain being queried.

The system already had the storage fields and terminal statuses. The missing piece was making tx-hash misses use them.
