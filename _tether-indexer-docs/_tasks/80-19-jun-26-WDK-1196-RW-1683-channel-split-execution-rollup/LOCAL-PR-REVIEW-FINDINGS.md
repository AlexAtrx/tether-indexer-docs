# Local PR review findings

Date: 2026-06-19

Scope: local-only review. No GitHub postings, no code edits.

Reviewed PRs:

- `tetherto/wdk-data-shard-wrk#251`
- `tetherto/rumble-data-shard-wrk#251`
- `tetherto/rumble-data-shard-wrk#252`
- `tetherto/wdk-ork-wrk#162`
- `tetherto/rumble-ork-wrk#174`
- `tetherto/wdk-app-node#131`
- `tetherto/rumble-app-node#255`

## Finding 1 - Rumble data-shard is not pinned to the WDK hook contract

**File:** `rumble-data-shard-wrk/package.json:48`

**Exact code:**

```json
"@tetherto/wdk-data-shard-wrk": "git+https://github.com/tetherto/wdk-data-shard-wrk.git#49e4444b8ff0063d3797cc441085b4df25c3c2f1",
```

`rumble-data-shard-wrk#251` depends on the new hook contract introduced by
`wdk-data-shard-wrk#251`, but the package still installs the old WDK commit.
The new overlay delegates non-channel wallets to `super`:

```js
_isDuplicateWallet (newWallet, existing) {
  if (newWallet.type === WALLET_TYPES.CHANNEL) {
    return existing.type === WALLET_TYPES.CHANNEL && existing.channelId === newWallet.channelId
  }
  return super._isDuplicateWallet(newWallet, existing)
}

_validateNewWallet (newWallet) {
  if (newWallet.type === WALLET_TYPES.CHANNEL) {
    if (!newWallet.channelId) {
      return 'ERR_CHANNEL_ID_INVALID'
    }
  } else if (newWallet.channelId) {
    return 'ERR_CHANNEL_ID_INVALID'
  }
  return super._validateNewWallet(newWallet)
}
```

The pinned WDK commit does not contain `_isDuplicateWallet`,
`_validateNewWallet`, or `_buildExtraWalletFields`. A clean install from the
current package/lockfile can therefore throw on non-channel wallet creation.

The new unit test masks the package mismatch by faking exactly the hooks that
are missing from the installed WDK package:

```js
// Generic addWallet hooks (mirror the wdk-data-shard base defaults) so the
// Rumble channel overrides can delegate via super.
_isDuplicateWallet (newWallet, existing) { return newWallet.type === 'user' && existing.type === 'user' }
_validateNewWallet () { return null }
_buildExtraWalletFields () { return {} }
```

**Critical criticism:** This PR is not wired to the real dependency contract it
needs. Update `package.json` and `package-lock.json` to a WDK data-shard commit
containing `wdk-data-shard-wrk#251`, then test against that real base instead of
a fake base class.

## Finding 2 - Rumble ORK channel-routing override is dead with the current WDK pin

**File:** `rumble-ork-wrk/package.json:45`

**Exact code:**

```json
"@tetherto/wdk-ork-wrk": "git+https://github.com/tetherto/wdk-ork-wrk.git#b72e6085870020340d60139ba823e19dfe869479",
```

`rumble-ork-wrk#174` adds a Rumble shard util override:

```js
// Use the Rumble shard util, which owns channel -> shard routing.
_createShardUtil () {
  return new RumbleDataShardUtil(this)
}
```

The pinned WDK ORK commit constructs `new DataShardUtil(this)` directly in
`_start`; it does not call `_createShardUtil()`. It also still contains the old
WDK-owned channel lookup methods. With a clean install, the new Rumble-owned
`RumbleDataShardUtil` is not actually activated.

**Critical criticism:** The channel-routing split is dead overlay code until the
dependency is bumped to a WDK ORK commit containing `wdk-ork-wrk#162`.

## Finding 3 - Timeout fallback returns null, but app-node serializes it as an empty string

**File:** `rumble-data-shard-wrk/workers/api.shard.data.wrk.js:48`

**Exact code:**

```js
// Runs the balance fan-out under USER_BALANCE_BUDGET_MS. If a slow chain pushes the
// read past the budget we return an unknown (null) balance, which the cached balance
// route already declines to cache, instead of letting the ork RPC time out.
async _runWithinBalanceBudget (fn, ctx = {}) {
  let timer
  const deadline = new Promise((_resolve, reject) => {
    timer = setTimeout(() => reject(new Error('ERR_USER_BALANCE_BUDGET_EXCEEDED')), USER_BALANCE_BUDGET_MS)
  })
  const work = fn()
  work.catch(() => {})
  try {
    return await Promise.race([work, deadline])
  } catch (err) {
    if (err.message !== 'ERR_USER_BALANCE_BUDGET_EXCEEDED') throw err
    this.logger.warn({ errorCode: 'ERR_USER_BALANCE_BUDGET_EXCEEDED', ...ctx }, 'user balance fetch exceeded budget, returning unknown balance')
    return { balance: null, tokenBalances: {} }
  } finally {
    clearTimeout(timer)
  }
}
```

The inherited app-node balance response schema still declares string-only
balances:

```js
const balanceSchema = {
  type: 'object',
  properties: {
    balance: { type: 'string' },
    tokenBalances: {
      type: 'object',
      additionalProperties: { type: 'string' }
    }
  },
  required: ['balance', 'tokenBalances'],
  additionalProperties: false
}
```

I verified locally with the repo's `fast-json-stringify` dependency that this
schema serializes:

```js
{ balance: null, tokenBalances: { BTC: null } }
```

as:

```json
{"balance":"","tokenBalances":{"BTC":""}}
```

**Critical criticism:** `rumble-data-shard-wrk#252` says it returns an unknown
`null` balance, but HTTP clients receive empty decimal strings. Either make the
app response contract nullable or return a valid explicit string/error shape.

## Validation notes

- `wdk-data-shard-wrk`: `npm run test:unit` passed.
- `rumble-ork-wrk`: `npm run test:unit` passed.
- `rumble-data-shard-wrk`: `npm run test:unit` hit existing unrelated
  `rumble.server.util` logging expectation failures; the new channel-hook tests
  passed, but they fake the missing base hooks described in finding 1.
- `wdk-ork-wrk` and `rumble-app-node`: targeted test commands were not reliable
  because the package scripts expanded into broader suites with environment
  failures. The relevant app-node serializer behavior was verified directly with
  `fast-json-stringify`.

## Resolution (2026-06-19)

- **Finding 1 (rumble data-shard pin) and Finding 2 (rumble ork pin): ignored as repeated.**
  These restate the known pin-sequencing blocker already documented in `README.md`
  and written into each dependent PR body. The rumble pins cannot point at the
  cleaned WDK commits until the WDK removal PRs merge on tetherto and produce real
  SHAs; pinning to unpushed local commits would make a clean install fail outright.
  The local unit tests fake the WDK base hooks on purpose so the Rumble logic can be
  tested before that merge. No code change. Order: data-shard -> ork -> app-node,
  bump each rumble pin after its WDK PR merges.

- **Finding 3 (timeout null serializes to empty string): valid, fixed.**
  Verified empirically: with the string-only app-node balance schema,
  `fast-json-stringify` serializes `{ balance: null }` as `{"balance":""}`, so the
  intended "unknown" balance reached clients as an empty string. Fixed on
  `fix/balance-request-timeout-budget` (commit `eaea0fb`): the budget-exceeded path
  now throws a defined `ERR_USER_BALANCE_BUDGET_EXCEEDED` instead of returning a
  fabricated balance shape, with unit coverage added. PR tetherto/rumble-data-shard-wrk#252
  updated.

  Direction correction (per Slack, 2026-06-19): the WDK-side balance budget
  (`wdk-data-shard-wrk` commit `9e4ae78`, PR tetherto/wdk-data-shard-wrk#250) is
  **no-go**. The team is removing/moving balance logic off the WDK layer into Rumble
  under WDK-1459 (Israel's balance-move,
  https://app.asana.com/1/45238840754660/project/1210540875949204/task/1214792055861213).
  So the timeout safeguard belongs on the Rumble side (this `fix/balance-request-timeout-budget`
  branch, PR #252) and should land **with** WDK-1459, not standalone and not via the
  WDK per-currency fix. Do not pin Rumble to #250. Keep #252 as draft until the
  WDK-1459 balance-move lands, then fold this safeguard in.
