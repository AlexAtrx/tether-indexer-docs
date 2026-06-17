**Finding:** Wallet creation does not fail when the Rumble username claim is missing
**File:** rumble-app-node/workers/http.node.wrk.js:76
**Exact code:**
```js
const username = req._info?.user?.username
if (username && Array.isArray(req.body)) {
  for (const wallet of req.body) {
    if (wallet && wallet.type === 'user') wallet.username = username
  }
}
```
**Remark:** RW-1920 says `/wallets` sources the username from Rumble's `preferred_username`; this path treats that claim as optional. If Rumble omits or renames the claim, the user wallet is created without a persisted username, while `decorateWalletWithUma` still adds `uma` domain/limits to every successful user wallet response. That leaves the app advertising a UMA handle/config for a wallet that cannot resolve through `getUmaByUsername`.
**Critical criticism:** Required payment identity is being handled as best-effort middleware decoration instead of an HTTP-boundary invariant. This turns the open `preferred_username` contract into silent data corruption for UMA receive.

---

**Finding:** UMA username persistence is split from the wallet creation transaction
**File:** rumble-data-shard-wrk/workers/proc.shard.data.wrk.js:251
**Exact code:**
```js
const result = await super.addWallet(req)

// Stamp UMA fields onto created user wallets. result aligns 1:1 with
// req.wallets (the base pushes one entry per input wallet, errors included),
// so the username travels with its own wallet. UMA is part of the creation
// contract, so a stamp failure rolls back that wallet and aborts.
if (Array.isArray(result) && Array.isArray(req.wallets)) {
  for (let i = 0; i < result.length; i++) {
    const wallet = result[i]
    if (wallet?.status !== 201 || wallet.type !== WALLET_TYPES.USER) continue
    const umaPayload = getUmaPayloadFromWallet(req.wallets[i])
    if (!umaPayload) continue
    let stored
    try {
      stored = await this._persistWalletUma(wallet.id, umaPayload)
    } catch (err) {
      await this._rollbackWalletCreate(wallet.id, err)
      throw err
    }
    Object.assign(wallet, stored)
  }
}
```
**Remark:** `super.addWallet(req)` commits the wallet in the base data-shard unit of work, then `_persistWalletUma` opens a second unit of work to add the username. A crash, process kill, or failed compensating delete after the base commit leaves an active user wallet without `username`; ORK lookup reservation can also be skipped because the call never returns a stamped wallet. Tether Wallet stores `username` inside the wallet document before `uow.commit`, so the canonical wallet and UMA identity are committed together.
**Critical criticism:** The canonical wallet write and UMA identity write are not atomic. For a public payment-resolution feature, a best-effort rollback after the durable wallet create is too weak and is materially farther from the TW implementation.

---

**Finding:** Data-shard UMA API test expects fields the shard intentionally strips
**File:** rumble-data-shard-wrk/tests/api.shard.data.wrk.unit.test.js:479
**Exact code:**
```js
apiWrk.db.walletRepository.getActiveUserWalletWithUma.resolves({
  id: 'w1', userId: 'u1', username: 'alice9', uma: { domain: 'rumble.test', minSendable: 1000 }
})
const res = await apiWrk.getUmaByUserId({ userId: 'u1' })
t.alike(res, { userId: 'u1', walletId: 'w1', username: 'alice9', domain: 'rumble.test', minSendable: 1000 })
```
**Remark:** `walletToUmaResponse` returns only `{ userId, walletId, username }`, and the app-node applies domain/limits from deployment config. Running `./node_modules/.bin/brittle tests/api.shard.data.wrk.unit.test.js tests/proc.shard.data.wrk.unit.test.js` fails here with actual `{ userId, walletId, username }` and no `domain` or `minSendable`.
**Critical criticism:** The changed test suite enforces the opposite data contract from the changed helper and app-node service. That makes the review signal unreliable and leaves future maintainers unclear whether UMA defaults belong in shard storage or app config.

---

**Finding:** App integration suite's UMA assertions run against the wrong config and hit unstubbed Redis
**File:** rumble-app-node/tests/http.node.wrk.intg.test.js:40
**Exact code:**
```js
    uma: {
      domain: 'uma.test',
      minSendable: 1000,
      maxSendable: 100000,
      defaultSettlementLayer: 'lightning'
    },
    logs: {
      enabled: true,
      rateLimit: {
        maxRequestsPerMinute: 120
      },
      validation: {
        maxBatch: 250,
        maxMessageLength: 2000,
        maxStackLength: 5000,
        maxBodyBytes: 524288
      },
      labels: {
        source: 'mobile-app'
      }
    }
  }))

  wrk.net_r0.jRequest = sandbox.stub()
  wrk.net_r0.jTopicRequest = sandbox.stub()
  wrk.redis_r0.cli_rw.set = sandbox.stub().resolves('OK')
  wrk.redis_r0.cli_rw.get = sandbox.stub().resolves(null)
})
```
**Remark:** The local `tests/test-lib/hooks.js` does not re-merge test config after worker `loadConf('common')`, so the worker uses `config/common.json` (`domain: "localhost"`, `maxSendable: 9007199254740991`) instead of this inline `uma.test` override; the first wallet UMA assertion fails at line 118. The same run then hits the newly restored wallet-create rate limiter, which calls `redis_r0.cli_rw.wdkAppNodeIdxRateLimit`; the test setup only stubs `set`/`get`, so `./node_modules/.bin/brittle tests/http.node.wrk.intg.test.js` falls into Redis `ECONNREFUSED` and `MaxRetriesPerRequestError` locally.
**Critical criticism:** The changed integration tests are environment-dependent and do not actually validate the UMA contract they assert. This is a test harness regression relative to the upstream WDK hook pattern and it blocks reliable CI coverage for the new wallet and payreq routes.
