# Handling — RW-1998 [Backend Promo] Make the backend aware of the new 'promo' wallet type

## Type
Feature (additive validation change at the API boundary)

## What was wrong / wanted
Wallet creation/listing only accepted `type` of `user | channel | unrelated`. The promo
feature (parent RW-1991, FE PR rumble-wallet-app-mobile#1311) needs the backend to be
aware of a dedicated `promo` wallet, created at a custom derivation index (10,000), so a
promo wallet can be submitted/created and identified server-side.

## Decision taken
Two readings of the ticket were possible. Alex chose **"accept the promo type only"**:
make the BE accept `type: 'promo'` on wallet create/list. The custom index 10,000 is
already supported by the existing `accountIndex` field (`integer, minimum 0`), so no
schema change is needed for the index. Rewiring promo-code redemption to target the promo
wallet was deliberately **left out of scope** (see "Open points" below).

Tech lead guidance ("the cleanest would be type promo") = option 2 of the three FE
proposed (metadata flag / new type / hardwired index). New type is the source of truth.

## Change
Single source of truth widened, plus a doc string kept accurate:

- `wdk-app-node/workers/lib/schemas/common.js:97` — `walletEnum` now
  `['user', 'channel', 'unrelated', 'promo']`. This enum feeds the POST `/api/v1/wallets`
  body `type`, the GET `/api/v1/wallets` `type` querystring, and the `walletTypes` array
  filter, so all three accept `promo` from one edit.
- `wdk-app-node/workers/lib/server.js:442` — GET route description updated to list
  `promo` alongside the other types (Swagger accuracy only).
- `wdk-app-node/package.json` — version `0.1.1` -> `0.1.2` per the shared-lib
  version-bump policy.

Why this is the minimal correct change: `type` is only enum-constrained at the
`wdk-app-node` fastify `schema.body` (the API boundary). Downstream it is a free-form
string: `wdk-ork-wrk` `addWallet` (api.ork.wrk.js:431) only normalizes addresses and
passes `type` through, and the HyperDB `wallets` schema stores `type` as
`{ type: 'string' }` with no enum (wdk-data-shard-wrk/workers/lib/db/hyperdb/build.js:12).
So widening the boundary enum is sufficient for create, list, store, and balance/transfer
ingestion (blockchain.svc.js:362 only filters by type when a `walletTypes` filter is
explicitly passed).

## Repos touched
- `wdk-app-node` — added `promo` to `walletEnum`; GET description; version bump; unit +
  integration tests.
- `rumble-app-node` — promo-code redemption now resolves the dedicated `promo` wallet
  (`workers/lib/services/promo.js` `resolveUserWallet`), falling back to the user's
  `unrelated` wallet when no promo wallet is provisioned yet; unit tests added.
- `wdk-data-shard-wrk` — `addWallet` now enforces one `promo` wallet per user
  (`proc.shard.data.wrk.js` `isDup`, mirroring the existing `user` one-per-user rule),
  so duplicate promo wallets cannot break the type-keyed redemption resolver above;
  version bump + lockfile sync + unit test. Inherited by `rumble-data-shard-wrk` via
  `super.addWallet`.

## Layering / idempotency / separation notes
- **Layering:** the change sits exactly at the API boundary (fastify `schema.body` /
  querystring) where input-shape validation belongs. No lower layer needed editing.
- **Idempotency:** no new mutation or job logic; the `addWallet` path is unchanged, the
  edit only widens an accepted enum value. Nothing new to dedupe.
- **Separation:** ork and data-shard keep treating `type` as an opaque string; no
  storage logic leaked upward and no validation pushed down.
- **HyperDB append-only:** no schema change (wallet `type` is already an unconstrained
  string), so append-only rules are not engaged.

## Fan-out (deploy-time, not done here because it needs a pushed commit)
Per the version-bump policy, a `wdk-app-node` change must be picked up by its consumers:
- `rumble-app-node` reuses the **base** POST/GET `/api/v1/wallets` route and the base
  `commonSchema.walletEnum` via the pinned `@tetherto/wdk-app-node` git dependency, so it
  inherits `promo` automatically once the base package pin is bumped and `npm install`
  is re-run. No rumble source change is required. Its `channelOwnershipHandler`
  (rumble-app-node/workers/lib/services/auth.js:108) only acts on `type === 'channel'`,
  so promo wallets pass through untouched.
- `wdk-indexer-app-node` is the other declared consumer of `wdk-app-node`; bump its pin
  too if it surfaces these wallet schemas.
These pin bumps + `npm install` are a release step (they require the wdk-app-node commit
to be pushed first) and are intentionally not done under the local-only handling rule.

## Tests
- `wdk-app-node`: `npm test` — 196/199 pass; `npm run lint` (standard) — clean.
  - Added `tests/unit/schemas/common.test.js` — asserts `walletEnum` is
    `['user','channel','unrelated','promo']` and that `walletTypes` derives from it.
  - Added `tests/integration/base.http.server.test.js` — POST `/api/v1/wallets` accepts a
    `promo` wallet at `accountIndex: 10000` and forwards both `type` and `accountIndex`
    to the ork; GET `/api/v1/wallets?type=promo` returns 200 (not 422).
  - The 3 failing tests (`GET /api/v1/chains`, `POST /api/v1/wallets - body size limit`,
    `JwtGuard - noAuth delegates to testMode handler`) are **pre-existing and unrelated**:
    on a pristine tree (my changes stashed) the suite is 193/196 with the same 3 failures.
    My change adds 3 new passing tests and introduces zero new failures.
- `rumble-app-node`: `npm run lint` (standard) — clean; new
  `tests/promo-resolve-wallet.unit.test.js` — 4/4 pass (promo preferred, unrelated
  fallback, non-unique promo rejected, no-wallet error). `npm test` has one pre-existing
  unrelated failure (`http.node.wrk.intg.test.js` balance integration test, needs the
  real stack) that fails identically on a pristine tree.

## Update — promo-code redemption IS now wired (follow-up done)
On a later pass Alex asked to "do the needful" for redemption. `resolveUserWallet` in
`rumble-app-node/workers/lib/services/promo.js` now resolves `type: 'promo'` first and
falls back to the user's `unrelated` wallet when no promo wallet exists yet. This removes
the rollout hazard noted below (unmigrated users keep claiming with their unrelated
wallet instead of erroring) while promo-provisioned users get funds in the promo wallet.
Both `claimCode` and `getCodeStatus` go through this resolver, so payout and status are
consistent. `rumble-promo-wrk` is unchanged: it still sends to `wallet.addresses[chain]`,
which is now the promo wallet's address.

## Update 3 — RW-1991 requirement change (2026-06-29 14:56) + FE alignment
PO (Mohamed) updated the parent ticket: the fixed-index wording was struck through to
"marked with Promo and can be created at next available index". The promo wallet is now
identified purely by its `Promo` type and derived at the next available account index, NOT
pinned to 10,000.

Effect on the BE work: none required. This validates the existing decisions:
- Identify by `type: 'promo'` (already implemented) = "marked with Promo". ✓
- accountIndex required but NOT pinned to 10,000 (already implemented) = "next available
  index" with the index still stored in BE. ✓
- one promo wallet per user (already enforced at the shard) = "a wallet for all users". ✓

FE PR rumble-wallet-app-mobile#1311 is aligned with this BE contract:
- create-wallet type enum adds `'promo'` (`type: z.enum([... 'promo'])`), matching
  `walletEnum`.
- `accountIndex: z.number()` is required in the FE create-wallet schema, matching the
  BE "require accountIndex for type promo" rule; the FE derives the next available index
  and sends it. No 10,000 hardcode on either side.

## Update 2 — review round 3 fixes (migration robustness + contract)
Three further review findings, all fixed:
1. **Claim status lost pre-migration claims.** `getCodeStatus` resolved the promo wallet
   once it existed, but the promo worker keys status by `userId + claimedBy address`, so a
   claim made earlier against the unrelated wallet returned `ERR_CODE_NOT_FOUND`. Fixed in
   `rumble-app-node/workers/lib/services/promo.js`: split into `getPromoWallet` /
   `getUnrelatedWallet`; `getCodeStatus` now tries the promo wallet, then falls back to the
   unrelated wallet on `ERR_CODE_NOT_FOUND`, so in-flight pre-migration claims stay visible.
   `claimCode` keeps writing new claims to the promo wallet (no fallback on the write path).
2. **`ERR_USER_PROMO_WALLET_NOT_UNIQUE` mapped to HTTP 500.** Added it to
   `rumble-app-node/workers/lib/utils/errorsCodes.js` as 409, matching
   `ERR_USER_UNRELATED_WALLET_NOT_UNIQUE`, so the duplicate-promo condition is a domain
   conflict, not a server error.
3. **Promo wallet could be stored without a derivation index.** The ticket requires the
   index to be stored. Added an `allOf` conditional to the POST `/api/v1/wallets` schema
   (`wdk-app-node/workers/lib/server.js`): `type === 'promo'` now requires `accountIndex`.
   Index is required but not pinned to 10000 (RW-1991 says "or any other index"). Not also
   enforced at the shard: no internal HRPC caller creates promo wallets (only the FE HTTP
   path does), so a storage-layer guard would defend a path that does not exist; left as a
   noted option rather than speculative validation.

Tests added: wdk-app-node integration `POST .../wallets` promo-without-accountIndex -> 422;
rumble-app-node unit `getCodeStatus` promo-hit and unrelated-fallback paths.

## Assumptions / open points
- **Promo-code redemption rewiring: DONE** (see Update above). Original deferral note kept
  for history: it resolved `type: 'unrelated'` and would have broken claims for users
  without a promo wallet if switched naively; the fallback resolves that.
- **One promo wallet per user IS now enforced** at the shard (see Repos touched). The
  index is deliberately NOT pinned to 10000 server-side: the parent RW-1991 says
  "index 10,000 (or any other index)", so hardwiring it would contradict the spec; the FE
  picks the index. The existing `isDupAccountIndex` guard already rejects two wallets at
  the same index per user. The `rumble-data-shard-wrk` wallet-anomaly report keys off
  `type === 'unrelated'`, so promo wallets at a non-zero index are not falsely flagged.
- "Funds usable only for tipping / disable other buttons" is FE behaviour (RW-1991), not
  enforced by the backend.
