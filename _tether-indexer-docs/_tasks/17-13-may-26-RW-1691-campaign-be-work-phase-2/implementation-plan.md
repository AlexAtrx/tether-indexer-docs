# RW-1691 Phase 2 Implementation Plan

## Sources Reviewed

- `tetherto/rumble-app-node#219`, head `c3aedd1`, base `22b9196`.
- `tetherto/rumble-promo-wrk#51`, head `c67f7e8`, base `4f708fd`.
- Existing V1 promo worker on the PR bases:
  - `rumble-app-node:workers/lib/services/promo.js`
  - `rumble-app-node:workers/lib/server.js`
  - `rumble-promo-wrk:workers/api.promo.wrk.js`
  - `rumble-promo-wrk:workers/proc.promo.wrk.js`
  - `rumble-promo-wrk:workers/lib/queries/{campaigns,codes}.js`
  - `rumble-promo-wrk:workers/lib/schema.js`
- Prior task context in `_tether-indexer-docs/_tasks/17-13-may-26-RW-1691-campaign-be-work/`, especially `METHOD-MAP.md`, `WALKTHROUGH.md`, `latest-specs-changes.md`, and the Rumble backend API notes.

## Current PR Shape

The current PRs implement the campaign builder as a V2 rewrite:

- `rumble-app-node#219` deletes the old `promo.js` service surface, removes `/api/v1/promo/:campaignId/claim/status`, adds `promo.v2.js`, and exposes `POST /api/v2/promo/claim`.
- `rumble-promo-wrk#51` deletes the old local code/campaign repositories, old V1 wallet bot, and payment scripts; adds `claimCodeV2`, `promo_payouts_v2`, `promo_payout_callbacks_v2`, a callback outbox, cancel/recovery states, and a V2 multi-token wallet bot.

The behavior in those PRs is still the right reference for the Rumble contract:

- Call `POST /-wallet/v1/admin/campaign-redeem` with `{ code, id: userId, clientIp }`.
- On success, trust Rumble's `claimId`, `amount`, `token`, and optional `chain`.
- Queue a wallet-BE payout to the user's `unrelated` wallet address.
- After a status `1` receipt, call `campaign-claim-settled`.
- After a terminal failed payout, call `campaign-claim-failed`.

The implementation shape should change: move the feature back into the V1 method and scheduler names so the diff is small and reviewable.

## Target Shape

Keep the existing V1 worker lifecycle and method names:

- App node calls worker RPC `claimCode`, not `claimCodeV2`.
- Promo API worker exposes `claimCode`, not `claimCodeV2`.
- Promo proc worker keeps `_processClaimedCodes` and `_monitorPayingCodes`.
- Keep the simple V1 state machine: `claimed -> paying -> paid | failed`.
- Do not port the full V2 state machine (`broadcast`, `mined`, `notified`, `cancelling`) unless reviewers explicitly ask for it later.

Rumble remains the business source of truth:

- No local campaign/code validation.
- No local campaign budget, reusable-code, geo, eligibility, first-N, or restrict-days logic.
- The local DB only tracks accepted claims and payout execution.

## App Node Plan

1. Move the logic from `workers/lib/services/promo.v2.js` into the existing `workers/lib/services/promo.js`.
   - Keep `getPromoServiceRpcKey`, `rpcCall`, and unrelated-wallet lookup in the existing service.
   - Add client IP forwarding from `cf-connecting-ip` with fallback to `req.ip`.
   - Call worker RPC `claimCode` with `{ code, userId, clientIp, wallet }`.
   - Strip `[HRPC_ERR]=` from thrown RPC errors before rethrowing.

2. Avoid a separate `promoV2` service export.
   - `workers/lib/services/index.js` should continue exporting `promo`.

3. HTTP route decision:
   - Preferred for the refresh: keep or restore the existing V1 route path and handler wiring, then route it to `service.promo.claimCode`.
   - If FE still requires `POST /api/v2/promo/claim`, expose it as a thin alias to the same `service.promo.claimCode` implementation. Do not duplicate business logic or keep a separate V2 service file.

4. Relax the claim body schema.
   - Old V1 required exactly six characters.
   - New Rumble-owned codes should be `minLength: 1`, `maxLength: 64`, pass-through, no normalization.

5. Keep Rumble rejection codes in `workers/lib/utils/errorsCodes.js`.
   - Map known Rumble codes (`CODE_NOT_FOUND`, `WRONG_GEO`, `ALREADY_CLAIMED`, etc.) to `409`.
   - Keep `ERR_PROMO_SERVICE_UNAVAILABLE` mapped to `503`.

## Promo Worker Plan

### RPC And Claim Flow

1. Update API worker `claimCode(req)`.
   - Accept `{ code, userId, clientIp, wallet }`.
   - Validate presence only.
   - Forward the same payload to proc worker RPC `claimCode`.
   - Do not keep `claimCodeV2`.

2. Update proc worker `claimCode({ code, userId, clientIp, wallet })`.
   - Resolve the user's payout address from `wallet.addresses[chain]`.
   - Use Ethereum as the default chain unless Rumble returns a supported `chain`.
   - Call `RumbleAdminClient.redeem({ code, userId, clientIp })`.
   - On Rumble 4xx, throw the Rumble `errorCode` and do not write a local row.
   - On Rumble 5xx/network, throw `ERR_PROMO_SERVICE_UNAVAILABLE` and do not write a local row.
   - On Rumble success, validate only what execution needs: `claimId`, decimal-string `amount`, supported `token`, supported `chain`.
   - Insert the accepted claim into the local execution table with status `claimed`.
   - Return `{ claimId, status: 'received' }` after the row is durable.

3. Post-accept failure rule.
   - If Rumble already returned a `claimId` but local validation or DB insert fails, call `campaign-claim-failed` immediately where possible, then throw `ERR_PROMO_SERVICE_UNAVAILABLE`.
   - Keep this narrow; do not recreate the full V2 failed-callback outbox for malformed responses.

### Repository And Schema

Create a new non-V2 query module under `workers/lib/queries/`, for example `claims.js` or `payouts.js`.

Recommended table: `promo_claims`.

Fields:

```sql
id INTEGER PRIMARY KEY AUTOINCREMENT,
claimId TEXT NOT NULL UNIQUE,
code TEXT NOT NULL,
userId TEXT NOT NULL,
claimedBy TEXT NOT NULL,
blockchain TEXT NOT NULL,
token TEXT NOT NULL,
amountPerClaim TEXT NOT NULL,
status TEXT NOT NULL,
nonce INTEGER,
txHash TEXT,
payError TEXT,
claimedAt INTEGER,
paidAt INTEGER,
failedAt INTEGER,
reportedAt INTEGER,
reportError TEXT,
reportRetries INTEGER NOT NULL DEFAULT 0,
nextReportAt INTEGER,
createdAt INTEGER NOT NULL,
updatedAt INTEGER NOT NULL
```

Why a new table instead of reusing `promo_codes`:

- New codes are reusable, so V1's `UNIQUE(code, campaignId)` model is wrong.
- V1 `promo_codes` depends on `promo_campaigns` for amount/token/chain, but Rumble now returns those per claim.
- A new execution table lets `_processClaimedCodes` keep its shape while avoiding old campaign business state.

Repository methods should mirror the V1 names where possible:

- `insertClaimedCode`
- `getClaimByClaimId`
- `getClaimedCodes`
- `batchUpdateToPaying`
- `updateCodeTxHash`
- `updateCodeToPaid`
- `updateCodeToFailed`
- `getPayingCodes`
- `getMaxNonce`
- `getPendingReports`
- `markReportDelivered`
- `recordReportFailure`

Keep SQL in `workers/lib/queries/`. The proc worker should orchestrate, not embed large SQL strings.

### Payout Loops

1. Update `_processClaimedCodes`.
   - Read from the new repository's `getClaimedCodes`.
   - Keep V1 batching, rate limiting, nonce assignment, balance check, and concurrent sends.
   - Use Rumble-returned `token`, `blockchain`, and `amountPerClaim` from the claim row.
   - Save transaction hashes exactly as V1 does.

2. Update `_monitorPayingCodes`.
   - Read from the new repository's `getPayingCodes`.
   - Keep V1 receipt polling and same-nonce fee-bump resubmission.
   - On receipt `status === 1`, update row to `paid`, then fire Rumble settled webhook.
   - On receipt `status === 0`, update row to `failed`, then fire Rumble failed webhook.
   - If a transaction is still pending or unknown, keep the V1 retry behavior. Do not add the V2 cancel state in this refresh.

3. Add a small reporting retry path.
   - First attempt the Rumble callback immediately when the row changes to `paid` or `failed`.
   - If the callback fails, leave `reportedAt` null and set `nextReportAt`.
   - On the same scheduler tick, or a small helper called after `_monitorPayingCodes`, retry due reports.
   - Rumble's callbacks are idempotent, so this can be at-least-once. No separate callback table or opposite-kind conflict logic is needed because the terminal claim status selects the callback kind.

### Rumble Admin Client

Reuse the PR's `workers/lib/rumble.admin.client.js`, but remove V2 naming from callers.

Required behavior:

- HMAC-SHA256 over `timestamp + JSON.stringify(body)`.
- Headers: `x-signature`, `x-signed-on`.
- Endpoints:
  - `/-wallet/v1/admin/campaign-redeem`
  - `/-wallet/v1/admin/campaign-claim-settled`
  - `/-wallet/v1/admin/campaign-claim-failed`
- Normalize network errors to retryable `ERR_PROMO_SERVICE_UNAVAILABLE`.
- Normalize Rumble 4xx to the top-level `errorCode` shape from the staging mock.

### Wallet Bot And Config

1. Keep the V1 `workers/lib/wallet.bot.evm.js` file name.
2. Extend it with the useful V2 behavior:
   - token map support for `USAT` and `USDT`;
   - `sendTransaction({ token, to, amount, nonce }, gas)`;
   - `getGasEstimate({ token, to, amount })`;
   - `getTokenBalance(token)`;
   - configurable `seedKeyName` so this flow can use a fresh campaign payout wallet.
3. Keep existing `chain` config naming if possible. Avoid introducing `chainV2` unless absolutely necessary.
4. Keep default chain single-chain Ethereum for now.

### Scripts

Restore deleted payment scripts:

- `scripts/pay-eth.js`
- `scripts/pay-token.js`
- `scripts/utils/wallet.js`

Update them only as needed for the refreshed config shape and `seedKeyName`.

Do not restore `scripts/generate-codes.js` unless explicitly requested. Rumble now owns code generation and validation, so a local code generator is misleading for this feature.

## What Not To Port From V2

Leave these out of the refresh unless a reviewer explicitly reopens them:

- `claimCodeV2` RPC name.
- `promo.v2.js` app-node service.
- `promo_payouts_v2` and `promo_payout_callbacks_v2` table names.
- Separate callback outbox table.
- `broadcast`, `mined`, `notified`, and `cancelling` statuses.
- Cancel transaction state machine.
- Callback conflict detection between settled and failed.
- Large post-accept validation branches for every edge case.

The cost of those pieces was the main reviewability problem. The refreshed V1 path should keep the behavior required by Rumble without a second payout engine.

## Implementation Order

1. Start from the current PR branches, but revert the V2 structural split in place.
2. App node:
   - move `promo.v2.js` logic into `promo.js`;
   - wire route(s) to `service.promo.claimCode`;
   - update schema and error map.
3. Promo worker schema and repository:
   - add `promo_claims`;
   - add migrations for existing DBs;
   - add the new query module under `workers/lib/queries/`.
4. Promo worker claim flow:
   - add `RumbleAdminClient`;
   - update `claimCode`;
   - durable insert after redeem success.
5. Promo worker payout loops:
   - update `_processClaimedCodes`;
   - update `_monitorPayingCodes`;
   - add immediate settled/failed callbacks and simple report retry.
6. Wallet bot/config:
   - extend V1 wallet bot for token map support and fresh seed key;
   - update `config/proc.promo.json.example`.
7. Restore payment scripts.
8. Tests and lint.

## Test Plan

Promo worker unit tests:

- `claimCode` success calls Rumble redeem, inserts one `promo_claims` row, returns `received`.
- Duplicate `claimId` is idempotent and does not insert a second payout.
- Rumble 4xx returns the Rumble error code and inserts no row.
- Rumble 5xx/network returns `ERR_PROMO_SERVICE_UNAVAILABLE` and inserts no row.
- Malformed post-accept success triggers failed callback and no payout row.
- `_processClaimedCodes` moves `claimed -> paying`, assigns nonces, sends with the returned token/amount, and saves tx hash.
- `_monitorPayingCodes` receipt status `1` moves `paying -> paid` and calls settled.
- `_monitorPayingCodes` receipt status `0` moves `paying -> failed` and calls failed.
- Callback failure leaves the row report-pending and retries later.
- Multi-token wallet bot selects the correct contract/decimals for `USAT` and `USDT`.

App node tests or smoke checks:

- Claim schema accepts non-six-character codes.
- Authenticated claim forwards `{ code, userId, clientIp, wallet }` to `claimCode`.
- HRPC-prefixed errors are returned without `[HRPC_ERR]=`.
- Rumble rejection codes map to `409`; service unavailability maps to `503`.

Validation commands:

- `npm test` in `rumble-promo-wrk`.
- `npm run lint` in `rumble-promo-wrk`.
- `npm test` or the available route test suite in `rumble-app-node`.
- `npm run lint` in `rumble-app-node`.

## Open Checks Before Coding

- Confirm whether FE still requires `POST /api/v2/promo/claim`. If yes, keep it as an alias to the V1 `claimCode` implementation rather than a separate V2 code path.
- Confirm whether the old status endpoint must be removed or can remain unused. If it remains, it should read execution state from `promo_claims`, not old `promo_codes`.
- Confirm production Rumble base URL and HMAC secret source.
- Confirm staging token contract addresses and whether Rumble can return `USDT` before launch.
