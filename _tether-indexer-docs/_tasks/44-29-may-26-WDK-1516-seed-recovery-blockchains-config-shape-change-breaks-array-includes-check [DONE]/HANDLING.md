# Handling — WDK-1516 seed.recovery: blockchains config shape change breaks array .includes()

## Type
bug

## What was wrong / wanted
The `blockchains` config changed shape from a flat array to an object keyed by
chain name (see `wdk-app-node/config/common.json.example` and the canonical
consumer `wdk-app-node/workers/lib/services/chains.js`, which already iterates it
with `Object.entries`). The rumble layer was not updated: `seed.recovery.js`
still did `ctx.conf.blockchains?.includes(chain)`. `.includes()` does not exist
on a plain object, so the membership check always threw `ERR_CHAIN_INVALID`,
breaking the v2 seed-recovery (cloud backup) endpoints in prod.

Note on evidence: the "Prod error" pasted in the ticket description is a
`promo.js claimCode` "RPC client closed" stack (looks copied from WDK-1515 and
does not reference seed.recovery). The real signal is the Slack thread captured
in `slack.txt`: "config blockchains shape changed in wdk but we didn't fully
update it for rumble layer, endpoint broken (v1 to v2 seed recovery endpoint)",
with a confirmed 500 during onboarding cloud backup. The root cause is
verifiable by code reading regardless, and the new object shape is confirmed in
the config example.

## Change
Replaced the array-style membership check with an object-key check, applied at
both call sites in `rumble-app-node/workers/lib/services/seed.recovery.js`
(the ticket only named line 45 in `verifySeedChallenge`, but `genSeedChallenge`
at the old line 27 had the identical bug). Extracted a small null-safe helper
rather than duplicating the expression:

    const isChainSupported = (conf, chain) =>
      Object.keys(conf?.blockchains || {}).includes(chain)

- `genSeedChallenge`: `if (!isChainSupported(ctx.conf, chain))`
- `verifySeedChallenge`: `if (!isChainSupported(ctx.conf, chain))`

`Object.keys(...).includes(chain)` was chosen over `chain in ...` because `in`
also matches inherited `Object.prototype` keys (`toString`, `constructor`),
which would let a crafted `chain` value slip past the validity check;
`Object.keys` only sees own enumerable keys. The `|| {}` preserves the original
null-safety of the optional-chaining version.

## Repos touched
- rumble-app-node — fixed both `blockchains` membership checks in
  `workers/lib/services/seed.recovery.js`; added unit test
  `tests/seed-recovery-chain-support.unit.test.js`. No other repo needed: the
  audit (below) found no other site consuming `ctx.conf.blockchains` as an array,
  and `wdk-app-node` already treats it as an object.

## Audit of other call sites
- `rumble-app-node/workers/lib/schemas/tx-hash.js` uses a local `blockchains`
  parameter fed from hardcoded arrays (`EVM_BLOCKCHAINS`, etc.), not
  `ctx.conf.blockchains`. Unaffected.
- `wdk-app-node/workers/lib/services/chains.js` already reads the object shape
  via `Object.entries(ctx.conf.blockchains || {})`. Correct.
- No other `conf.blockchains` array-style usage found in `rumble-app-node` or
  `wdk-app-node`.

## Layering / idempotency / separation notes
This is a read-only config-shape membership check inside the rumble-app-node
HTTP service layer; it is not a mutation and has no HRPC contract or HyperDB
schema impact, so idempotency and append-only rules do not apply. The fix stays
within the same service module and does not move any concern across layers. It
matches the object-shape convention already established in `wdk-app-node`.

## Tests
- rumble-app-node: `npx standard` (lint) — clean (0 errors), full repo.
- rumble-app-node: `npx brittle 'tests/*.unit.test.js'` — 14/14 pass, 20/20
  asserts (9 pre-existing tx-hash + 5 new). Added
  `tests/seed-recovery-chain-support.unit.test.js` covering: chain present in
  object config, chain absent, inherited prototype keys rejected, null-safe when
  config missing, and undefined/empty chain.
- The full `npm test` run also includes `tests/http.node.wrk.intg.test.js`,
  which fails (HTTP 500 on `/api/v1/wallets/.../balance`). This is a
  stack-dependent integration test that boots a worker needing redis/mongo/ork;
  none run in this sandbox. It has no reference to `seed.recovery` or the
  `blockchains` membership check, so the failure is pre-existing and unrelated
  to this change.

## Assumptions / open points
- Treated the bug as confirmed based on the Slack thread plus the verifiable
  code/config mismatch; the pasted prod log in the description is a mismatched
  (WDK-1515) trace and was disregarded. If Alex wants the exact seed.recovery
  prod log for the record, that is the one outstanding "nice to have".
- The fix targets the current object shape only (matching the rest of the
  system); it does not retain backward compatibility with the old array shape,
  which no longer exists in the config.
