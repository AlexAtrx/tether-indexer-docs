# PR #200 Review Comments Assessment

PR: https://github.com/tetherto/rumble-data-shard-wrk/pull/200

Scope: review comments only. No GitHub replies were posted.

## Summary Recommendation

Most of Sarge's comments are pointing at real readability issues, but the proposed shallow-merge simplification should not be accepted as-is unless you intentionally drop support for partial blockchain overrides.

The best path is:

1. Acknowledge the readability feedback.
2. Refactor the retry policy call site so `_processTxWebhooksJob()` does not choose between gasless and tx-hash retry policies inline.
3. Keep deep/partial override support.
4. Keep override shape validation, because final policy validation alone can miss malformed override input after merging.
5. Optionally rename the override validation helper so its purpose is clearer.

## Comment 1: Francesco's Startup Validation Comment

Comment:

> Could we double check this? I think values like `txWebhookRetryPolicyByBlockchain: { bitcoin: [] }` or `{ bitcoin: "abcd" }` pass startup validation but probably we want this to fail.

Assessment:

This makes sense. The original builder could merge malformed override values in a way that allowed bad config shapes to pass or fail unclearly.

Recommendation:

Do not push back. This was a valid catch and your later commit already addressed it.

Current state:

The added tests for `bitcoin: []` and `bitcoin: "abcd"` are worth keeping. This thread is outdated because the code changed after the comment, but the underlying point was correct.

## Comment 2: Sarge's Builder Simplification With Shallow Merge

Comment:

Sarge suggested simplifying the builder with a shallow merge like:

```js
const retryConfig = {
  ...TX_WEBHOOK_RETRY_POLICY_BY_BLOCKCHAIN,
  ...config.txWebhookRetryPolicyByBlockchain
}
```

He asked why each blockchain needs manual property merging if the final result is validated.

Assessment:

This makes partial sense, but only if config overrides are required to be complete policy objects.

The shallow merge would work for:

```json
{
  "bitcoin": { "maxRetries": 10, "retryDelay": 300000 }
}
```

But it would break the partial override behavior currently covered by tests:

```json
{
  "bitcoin": { "maxRetries": 5 },
  "ethereum": { "retryDelay": 25000 }
}
```

With a shallow merge, `bitcoin` would become `{ "maxRetries": 5 }`, losing the default Bitcoin `retryDelay`. Final validation would then fail because `retryDelay` is missing.

Recommendation:

Push back on the shallow-merge version if partial overrides are intentional. The pushback should be technical and narrow: shallow merge changes the config contract.

Better response:

"I agree the builder can be easier to read, but I do not think a shallow merge is equivalent. It removes support for partial per-chain overrides, which the current tests cover. I can refactor the builder to make the merge/validation clearer while keeping that behavior."

Refactor direction:

Keep deep per-chain merging, but simplify the flow.

## Comment 3: Sarge's `validatePolicyOverride` Question

Comment:

> Why validatePolicyOverride when we validate the retry policy at the end? Do we really need this?

Assessment:

The question is reasonable, but removing the helper is not a good idea if partial override merging remains.

The final policy validation checks the final merged values:

- `maxRetries` is a positive integer.
- `retryDelay` is a positive integer.

It does not necessarily prove that the user-provided override had the right shape.

For example, with deep merge logic, malformed values like these need to fail as bad input:

```js
txWebhookRetryPolicyByBlockchain: {
  bitcoin: []
}
```

```js
txWebhookRetryPolicyByBlockchain: {
  bitcoin: 'abcd'
}
```

If the code merges from a valid default policy first, malformed override values can become easy to hide unless the override shape is validated before merging.

Recommendation:

Push back on removing shape validation. Acknowledge that the helper name could be clearer.

Refactor direction:

Rename:

```js
_validateTxWebhookRetryPolicyOverride()
```

to:

```js
_validateTxWebhookRetryPolicyOverrideShape()
```

That makes it obvious this helper validates the raw config override shape, while `_validateTxWebhookRetryPolicy()` validates the final merged policy values.

## Comment 4: Sarge's "Call This Function For All Blockchains" Comment

Comment:

> I'd personally prefer if we call this function for all the blockchains, as opposed to calling manually for each blockchain.

Assessment:

This is mostly a readability/style comment, but it is reasonable.

The current code already loops over the final result:

```js
for (const [blockchain, policy] of Object.entries(result)) {
  this._validateTxWebhookRetryPolicy(blockchain, policy)
}
```

So functionally, it already validates all blockchains. But the intent could be clearer if that loop lived in a named helper.

Recommendation:

Do not strongly push back. This is a good low-cost cleanup.

Refactor direction:

Add a helper:

```js
_validateTxWebhookRetryPolicies (policiesByBlockchain) {
  for (const [blockchain, policy] of Object.entries(policiesByBlockchain)) {
    this._validateTxWebhookRetryPolicy(blockchain, policy)
  }
}
```

Then the builder can call:

```js
this._validateTxWebhookRetryPolicies(result)
```

This makes the validation step read as one operation.

## Comment 5: Sarge's Retry Policy Encapsulation Comment

Comment:

> Can't we encapsulate this functionality inside the `this._getTxWebhookRetryPolicy(txHook.blockchain)` function? Passing txHook and then getting the relevant retryPolicy, instead of defining policy result separately here?

Assessment:

This makes sense. `_processTxWebhooksJob()` currently knows too much about which retry policy applies:

```js
const retryPolicy = txResult.retryPhase === TX_WEBHOOK_RETRY_PHASE.GASLESS_RECEIPT
  ? { maxRetries: this.gaslessMaxRetries, retryDelay: this.gaslessRetryDelay }
  : this._getTxWebhookRetryPolicy(txHook.blockchain)
```

That condition is policy-selection logic, not job orchestration logic.

Recommendation:

Do not push back. Acknowledge and refactor.

Suggested refactor:

```js
const retryPolicy = this._getTxWebhookRetryPolicy(txHook, txResult.retryPhase)
```

Then:

```js
_getTxWebhookRetryPolicy (txHook, retryPhase) {
  if (retryPhase === TX_WEBHOOK_RETRY_PHASE.GASLESS_RECEIPT) {
    return {
      maxRetries: this.gaslessMaxRetries,
      retryDelay: this.gaslessRetryDelay
    }
  }

  return this.txWebhookRetryPolicyByBlockchain[txHook.blockchain] ||
    this.txWebhookRetryPolicyByBlockchain.default
}
```

Important detail:

Passing only `txHook` is not enough unless the phase is added to `txHook`. The retry phase comes from `_isTxCompleted()`, so the helper should receive both `txHook` and `txResult.retryPhase`, or receive `txHook` and the whole `txResult`.

My preference:

```js
this._getTxWebhookRetryPolicy(txHook, txResult.retryPhase)
```

That keeps the helper input explicit without passing the full result object.

## Proposed Refactor Shape

The builder can be made clearer without changing behavior:

```js
_buildTxWebhookRetryPolicyByBlockchain () {
  const overrides = this.conf.wrk?.txWebhookRetryPolicyByBlockchain || {}
  this._validateTxWebhookRetryPolicyOverrides(overrides)

  const result = { ...TX_WEBHOOK_RETRY_POLICY_BY_BLOCKCHAIN }

  for (const [blockchain, override] of Object.entries(overrides)) {
    result[blockchain] = {
      ...(result[blockchain] || result.default),
      ...override
    }
  }

  this._validateTxWebhookRetryPolicies(result)
  return result
}
```

With helpers:

```js
_validateTxWebhookRetryPolicyOverrides (overrides) {
  if (!overrides || typeof overrides !== 'object' || Array.isArray(overrides)) {
    throw new Error('ERR_INVALID_TX_WEBHOOK_RETRY_POLICY')
  }

  for (const [blockchain, override] of Object.entries(overrides)) {
    this._validateTxWebhookRetryPolicyOverrideShape(blockchain, override)
  }
}

_validateTxWebhookRetryPolicyOverrideShape (blockchain, policy) {
  if (!policy || typeof policy !== 'object' || Array.isArray(policy)) {
    throw new Error(`ERR_INVALID_TX_WEBHOOK_RETRY_POLICY:${blockchain}`)
  }
}

_validateTxWebhookRetryPolicies (policiesByBlockchain) {
  for (const [blockchain, policy] of Object.entries(policiesByBlockchain)) {
    this._validateTxWebhookRetryPolicy(blockchain, policy)
  }
}
```

This addresses the readability comments while preserving the current behavior:

- Partial blockchain overrides keep working.
- Malformed override shapes still fail startup validation.
- Final merged policies are still validated.
- `_processTxWebhooksJob()` becomes cleaner.

## Final Call

Best overall response:

Do not argue against the general readability feedback. Acknowledge it and refactor.

Push back only on the shallow-merge suggestion, because it changes the config semantics by dropping partial override support.

If the team does not care about partial overrides, then Sarge's shallow merge approach is acceptable, but the tests should be changed to require full policy objects for each override. Otherwise, keep partial overrides and refactor as described above.
