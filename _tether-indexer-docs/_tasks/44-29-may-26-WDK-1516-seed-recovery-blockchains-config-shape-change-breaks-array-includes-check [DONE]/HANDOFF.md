# WDK-1516 handoff (self-contained)

This file is the single source of truth for taking WDK-1516 to a committed
state. It needs no other file. Everything required to reproduce the fix, the
test, and the git workflow is embedded below.

## Constraints (carry these forward)

- Minimal, clean change only. No drive-by refactors or unrelated edits.
- Do NOT commit or push unless the human explicitly says so.
- Do NOT post anything to Asana or GitHub.
- No em dashes in any human-facing text (commit messages, PR text, comments).

## Ticket

- ID: WDK-1516, project "WDK Backends", Sprint 3, area Rumble.
- Title: "seed.recovery: blockchains config shape change breaks array .includes() check".
- Asana: https://app.asana.com/1/45238840754660/project/1210540875949204/task/1215220240169119
- Type: bug.

## Problem and root cause

The `blockchains` config changed shape from a flat array to an object keyed by
chain name. Canonical new shape (`wdk-app-node/config/common.json.example`):

```json
"blockchains": {
  "ethereum": { "ccys": ["usat", "usdt", "xaut"] },
  "arbitrum": { "ccys": ["usdt", "xaut"] },
  "polygon":  { "ccys": ["usdt", "xaut"] },
  "bitcoin":  { "ccys": ["btc"], "caseSensitive": { "address": "^[13][a-km-zA-HJ-NP-Z1-9]{25,34}$" } },
  "spark":    { "ccys": ["btc"] },
  "plasma":   { "ccys": ["usdt", "xaut"] }
}
```

`wdk-app-node/workers/lib/services/chains.js` already consumes it as an object
(`Object.entries(ctx.conf.blockchains || {})`), so object shape is the
system-wide assumption. The rumble layer was not updated:
`rumble-app-node/workers/lib/services/seed.recovery.js` still did
`ctx.conf.blockchains?.includes(chain)`. `.includes()` does not exist on a plain
object, so the membership check always threw `ERR_CHAIN_INVALID`, breaking the
v2 seed-recovery (cloud backup) endpoints in production.

Evidence note: the "Prod error" pasted in the Asana description is a
`promo.js claimCode` "RPC client closed" stack (looks copied from WDK-1515) and
does not reference seed.recovery. The real signal is the Slack thread (captured
in this folder as `slack.txt`): "config blockchains shape changed in wdk but we
didn't fully update it for rumble layer, endpoint broken (v1 to v2 seed recovery
endpoint)", with a confirmed 500 during onboarding cloud backup. The bug is also
verifiable by code reading regardless of the mismatched log.

## Audit of affected sites

Only `rumble-app-node` is affected, two call sites in one file:

- `seed.recovery.js` line 27 (`genSeedChallenge`) and line 45
  (`verifySeedChallenge`), both `ctx.conf.blockchains?.includes(chain)`. The
  ticket named only line 45, but `genSeedChallenge` had the identical bug.

Not affected (checked):

- `rumble-app-node/workers/lib/schemas/tx-hash.js` uses a local `blockchains`
  parameter fed from hardcoded arrays (`EVM_BLOCKCHAINS`, `HEX64_BLOCKCHAINS`),
  not `ctx.conf.blockchains`.
- `wdk-app-node/workers/lib/services/chains.js` already treats it as an object.
- No other `conf.blockchains` array-style usage exists in `rumble-app-node` or
  `wdk-app-node`.

## The fix

Repo: `/Users/alexa/Documents/repos/_tether/_INDEXER/rumble-app-node`
File: `workers/lib/services/seed.recovery.js`

Add a null-safe own-key membership helper just after the `MSG_PREFIX` constant,
use it at both call sites, and export it for unit testing. `Object.keys(...)
.includes(chain)` is chosen over `chain in ...` because `in` also matches
inherited `Object.prototype` keys (`toString`, `constructor`), which would let a
crafted `chain` slip past the check; `Object.keys` sees only own enumerable
keys. The `|| {}` preserves the original optional-chaining null-safety.

Exact diff:

```diff
diff --git a/workers/lib/services/seed.recovery.js b/workers/lib/services/seed.recovery.js
index 7eb9d81..bd10bc5 100644
--- a/workers/lib/services/seed.recovery.js
+++ b/workers/lib/services/seed.recovery.js
@@ -9,6 +9,10 @@ const { jTopicRpcCall } = require('./indexer')
 const CACHE_PREFIX = 'seed-phrase'
 const MSG_PREFIX = 'rumble-seed-login'
 
+// `blockchains` config is an object keyed by chain name (was a flat array).
+const isChainSupported = (conf, chain) =>
+  Object.keys(conf?.blockchains || {}).includes(chain)
+
 const genSeedChallenge = async (ctx, req) => {
   const { address, chain } = req.body
 
@@ -24,7 +28,7 @@ const genSeedChallenge = async (ctx, req) => {
   if (!userId) {
     throw new Error('ERR_ADDRESS_NOT_FOUND')
   }
-  if (!ctx.conf.blockchains?.includes(chain)) {
+  if (!isChainSupported(ctx.conf, chain)) {
     throw new Error('ERR_CHAIN_INVALID')
   }
 
@@ -42,7 +46,7 @@ const verifySeedChallenge = async (ctx, req) => {
   if (!/^[0-9]{6}$/.test(userMsg)) {
     throw new Error('ERR_MSG_INVALID')
   }
-  if (!ctx.conf.blockchains?.includes(chain)) {
+  if (!isChainSupported(ctx.conf, chain)) {
     throw new Error('ERR_CHAIN_INVALID')
   }
   const ckey = `${CACHE_PREFIX}:${chain}:${address}`
@@ -87,5 +91,6 @@ const verifySeedChallenge = async (ctx, req) => {
 
 module.exports = {
   genSeedChallenge,
-  verifySeedChallenge
+  verifySeedChallenge,
+  isChainSupported
 }
```

## The test (new file)

Path: `rumble-app-node/tests/seed-recovery-chain-support.unit.test.js`
Full content:

```js
'use strict'

const { test } = require('brittle')
const { isChainSupported } = require('../workers/lib/services/seed.recovery')

// New config shape: object keyed by chain name (WDK-1516 regression fix).
const objConf = {
  blockchains: {
    ethereum: { ccys: ['usdt'] },
    arbitrum: { ccys: ['usdt'] },
    bitcoin: { ccys: ['btc'] }
  }
}

test('accepts a chain present in the object-shaped blockchains config', t => {
  t.ok(isChainSupported(objConf, 'ethereum'))
  t.ok(isChainSupported(objConf, 'bitcoin'))
})

test('rejects a chain absent from the object-shaped config', t => {
  t.absent(isChainSupported(objConf, 'dogecoin'))
})

test('rejects inherited Object.prototype keys (no prototype-chain match)', t => {
  t.absent(isChainSupported(objConf, 'toString'))
  t.absent(isChainSupported(objConf, 'constructor'))
})

test('is null-safe when blockchains config is missing', t => {
  t.absent(isChainSupported({}, 'ethereum'))
  t.absent(isChainSupported(undefined, 'ethereum'))
})

test('rejects undefined / empty chain', t => {
  t.absent(isChainSupported(objConf, undefined))
  t.absent(isChainSupported(objConf, ''))
})
```

## Current local state (important)

The fix above is ALREADY applied in the working tree, but on the wrong branch:
`wdk-1442-fastify-v5-security` (that is just what happened to be checked out).
There is also a stale, empty `.git/index.lock` in the repo that a prior sandbox
left behind; remove it before any git op.

The desired end state is the same fix on a fresh branch off the latest dev.
Local `dev` has diverged from `upstream/dev` (it carries a merge of
`upstream/main`), so branch directly off `upstream/dev` rather than fast-
forwarding local dev. Remotes: `upstream` = `git@github.com:tetherto/...`
(canonical), `origin` = `AlexAtrx` fork, `vigan` = another fork.

## Run this (Claude Code CLI, real terminal)

```bash
cd /Users/alexa/Documents/repos/_tether/_INDEXER/rumble-app-node

# config
DEV_REMOTE="upstream"                                   # tetherto canonical
DEV_BRANCH="dev"
NEW_BRANCH="wdk-1516-seed-recovery-blockchains-config"  # rename to taste

# 1. clear the stale lock left by the sandbox
rm -f .git/index.lock

# 2. discard the in-tree edits (re-applied cleanly below) and start clean
git checkout -- workers/lib/services/seed.recovery.js 2>/dev/null || true
rm -f tests/seed-recovery-chain-support.unit.test.js
git diff --quiet && git diff --cached --quiet || { echo "tree not clean"; git status --short; exit 1; }

# 3. branch off the latest dev
git fetch "$DEV_REMOTE"
git checkout -b "$NEW_BRANCH" "${DEV_REMOTE}/${DEV_BRANCH}"

# 4. apply the fix
git apply <<'PATCH'
diff --git a/workers/lib/services/seed.recovery.js b/workers/lib/services/seed.recovery.js
index 7eb9d81..bd10bc5 100644
--- a/workers/lib/services/seed.recovery.js
+++ b/workers/lib/services/seed.recovery.js
@@ -9,6 +9,10 @@ const { jTopicRpcCall } = require('./indexer')
 const CACHE_PREFIX = 'seed-phrase'
 const MSG_PREFIX = 'rumble-seed-login'
 
+// `blockchains` config is an object keyed by chain name (was a flat array).
+const isChainSupported = (conf, chain) =>
+  Object.keys(conf?.blockchains || {}).includes(chain)
+
 const genSeedChallenge = async (ctx, req) => {
   const { address, chain } = req.body
 
@@ -24,7 +28,7 @@ const genSeedChallenge = async (ctx, req) => {
   if (!userId) {
     throw new Error('ERR_ADDRESS_NOT_FOUND')
   }
-  if (!ctx.conf.blockchains?.includes(chain)) {
+  if (!isChainSupported(ctx.conf, chain)) {
     throw new Error('ERR_CHAIN_INVALID')
   }
 
@@ -42,7 +46,7 @@ const verifySeedChallenge = async (ctx, req) => {
   if (!/^[0-9]{6}$/.test(userMsg)) {
     throw new Error('ERR_MSG_INVALID')
   }
-  if (!ctx.conf.blockchains?.includes(chain)) {
+  if (!isChainSupported(ctx.conf, chain)) {
     throw new Error('ERR_CHAIN_INVALID')
   }
   const ckey = `${CACHE_PREFIX}:${chain}:${address}`
@@ -87,5 +91,6 @@ const verifySeedChallenge = async (ctx, req) => {
 
 module.exports = {
   genSeedChallenge,
-  verifySeedChallenge
+  verifySeedChallenge,
+  isChainSupported
 }
PATCH

# 5. write the test
cat > tests/seed-recovery-chain-support.unit.test.js <<'TEST'
'use strict'

const { test } = require('brittle')
const { isChainSupported } = require('../workers/lib/services/seed.recovery')

// New config shape: object keyed by chain name (WDK-1516 regression fix).
const objConf = {
  blockchains: {
    ethereum: { ccys: ['usdt'] },
    arbitrum: { ccys: ['usdt'] },
    bitcoin: { ccys: ['btc'] }
  }
}

test('accepts a chain present in the object-shaped blockchains config', t => {
  t.ok(isChainSupported(objConf, 'ethereum'))
  t.ok(isChainSupported(objConf, 'bitcoin'))
})

test('rejects a chain absent from the object-shaped config', t => {
  t.absent(isChainSupported(objConf, 'dogecoin'))
})

test('rejects inherited Object.prototype keys (no prototype-chain match)', t => {
  t.absent(isChainSupported(objConf, 'toString'))
  t.absent(isChainSupported(objConf, 'constructor'))
})

test('is null-safe when blockchains config is missing', t => {
  t.absent(isChainSupported({}, 'ethereum'))
  t.absent(isChainSupported(undefined, 'ethereum'))
})

test('rejects undefined / empty chain', t => {
  t.absent(isChainSupported(objConf, undefined))
  t.absent(isChainSupported(objConf, ''))
})
TEST

# 6. verify
npm run lint
npx brittle 'tests/*.unit.test.js'
```

## Expected verification result

- `npm run lint` (standard): clean, exit 0.
- `npx brittle 'tests/*.unit.test.js'`: 14/14 tests pass, 20/20 asserts
  (9 pre-existing tx-hash + 5 new seed-recovery).
- Do NOT rely on the full `npm test`: it also runs
  `tests/http.node.wrk.intg.test.js`, a stack-dependent integration test that
  boots a worker needing redis/mongo/ork and returns HTTP 500 without them. That
  failure is pre-existing and unrelated to this change (it has no reference to
  seed.recovery). If a real stack is available, it can be run separately.

## Done criteria

Fix on a fresh branch off `upstream/dev`, lint clean, the 5 new unit tests
green, nothing committed or pushed until the human says so.
