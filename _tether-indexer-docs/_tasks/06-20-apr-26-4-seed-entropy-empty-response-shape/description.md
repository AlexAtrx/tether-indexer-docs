# Description

## Symptom

Sentry `RUMBLE-WALLET-APP-A5` (android prod): high-frequency zod validation error on the mobile wallet. 5852 hits across 566 users. Started ~2026-03-18.

Affected endpoints (served by `wdk-app-node`):

- `GET /api/v1/seed`
- `GET /api/v1/entropy`

For a user who has never stored a seed / entropy, both return **HTTP 200 with body `{}`** (2 bytes). Mobile zod expects `{ seeds: [...] }` / `{ entropies: [...] }` and rejects the payload.

## Root cause

Chain for an empty-user `GET /api/v1/seed`:

1. `wdk-data-shard-wrk/workers/api.shard.data.wrk.js:141` — `_getUserData` returns `userData && userData.value`, which is `undefined` when no row exists for that user / collection. It bubbles up through `getSeed` / `getEntropy` in the shard.
2. RPC boundary — `undefined` is not representable in JSON, so the Hyperswarm RPC transport delivers `null` to the caller.
3. `wdk-app-node/workers/lib/services/ork.js:153,168` — the thin proxies `getSeed` / `getEntropy` return that `null`.
4. `wdk-app-node/workers/lib/server.js:171,119` — handler does `send(null)` under the response schema `seedListSchema` / `entropyListSchema` (`wdk-app-node/workers/lib/middlewares/response.validator.js:193,213`).
5. `fast-json-stringify` 5.16.1 with any `type: 'object'` schema serializes `null` as `"{}"` (exactly 2 bytes), regardless of `required`. Mobile zod parses it and rejects the missing `seeds` / `entropies` key.

The DB / store path is NOT corrupted. `storeSeed` at `wdk-data-shard-wrk/workers/api.shard.data.wrk.js:660` builds `{ seeds: [...] }` correctly, so users who have data get the right shape back — which is why mobile recovery works for those users.

Empirically verified (local node, `fast-json-stringify@5.16.1`, Fastify with the exact `seedListSchema`):

| handler returns | no schema (pre-PR-79 state) | strict `seedListSchema` (today)       |
|-----------------|-----------------------------|---------------------------------------|
| `undefined`     | 200 `""` (0 bytes)          | 200 `""` (0 bytes)                    |
| `null`          | 200 `"null"` (4 bytes)      | **200 `"{}"` (2 bytes)** ← the bug    |
| `{}`            | 200 `"{}"` (2 bytes)        | 500 `"seeds is required!"`            |
| `{seeds: []}`   | 200 `{"seeds":[]}`          | 200 `{"seeds":[]}`                    |

Pre-PR-79 mobile zod presumably tolerated `"null"` (or the app handled null). Post-PR-79 the empty-user body is `"{}"` which zod rejects.

## Regression source

`tetherto/wdk-app-node` PR #79 "Update swagger doc" (merged 2026-03-02, merge commit `59afa4b`).

Specifically commit `33a8351` ("chore: update swagger schema") added any `type: 'object'` response schema to the `GET /api/v1/seed` and `GET /api/v1/entropy` routes for the first time. Once the routes had a `type: 'object'` response schema, `fast-json-stringify` flipped `null → "{}"`. The later commit `0f6d80e` ("chore: update response schema") tightened the schemas from permissive to strict but did not change the empty-user bytes — both permissive and strict produce `"{}"` for a `null` handler return.

Rollout (lines up with the Sentry start date):

- `dev`:     2026-03-02 (PR #79)
- `staging`: 2026-03-10 (PR #85, merge commit `2dda484`)
- `main`:    2026-03-13 (PR #86, merge commit `2453831`)

## Fix

Pick the smallest delta: normalize at the `wdk-app-node` service layer, right next to where PR #79 landed. In `wdk-app-node/workers/lib/services/ork.js`, change the two thin proxies from

```js
const getEntropy = (ctx, req) => rpcCall(ctx, req, 'getEntropy')
const getSeed    = (ctx, req) => rpcCall(ctx, req, 'getSeed')
```

to

```js
const getEntropy = async (ctx, req) => (await rpcCall(ctx, req, 'getEntropy')) ?? { entropies: [] }
const getSeed    = async (ctx, req) => (await rpcCall(ctx, req, 'getSeed'))    ?? { seeds: [] }
```

Two-line change. Doesn't touch `_getUserData` (which other callers depend on), doesn't relax the response schema, matches the schema contract on the empty-user path.

### Not preferred

- Relaxing `seedListSchema` / `entropyListSchema` to `required: []` — reintroduces the original looseness PR #79 removed for good reason.
- Changing `_getUserData` in `wdk-data-shard-wrk` to return `{ [collection]: [] }` — wider blast radius; other callers (`storeEntropy`, `storeSeed` at `wdk-data-shard-wrk/workers/api.shard.data.wrk.js:643,662`) read `.entropies` / `.seeds` off the result and would still work, but this is a data-layer change for a serialization problem.

## Tests (manager asked to cover all cases)

Integration-level, via the HTTP layer so fast-json-stringify is exercised. For each endpoint (`/api/v1/seed`, `/api/v1/entropy`):

| # | setup                                          | assert                              | today            |
|---|------------------------------------------------|-------------------------------------|------------------|
| 1 | fresh user, no POST                            | 200, body `{seeds: []}` / `{entropies: []}` | `{}` ← bug       |
| 2 | one POST /seed, then GET                       | 200, body `{seeds: [{seed, ...}]}`  | works            |
| 3 | two POST /seed, then GET                       | 200, body `{seeds: [a, b]}`         | works            |
| 4 | POST /seed, then `delSeed`, then GET           | 200, body `{seeds: []}`             | `{}` ← bug (delSeed → `_delUserData` removes the whole row) |
| 5 | mirror of 1-4 on `/entropy`                    | mirror                              | mirror           |

`wdk-data-shard-wrk/tests/api.shard.data.wrk.intg.test.js:748,787` covers cases 2 & 3 for entropy/seed but not the empty / post-delete paths, which is why this slipped through.
