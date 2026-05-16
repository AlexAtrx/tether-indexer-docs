# Wallet Campaign Builder - Wallet Backend Spec

> **Status:** implementation-ready draft, pending the open decisions listed near the end.
> **Feature:** RW-1691 Campaign BE work.
> **Owner:** Alex Atrash.
> **Last updated:** 2026-05-13.

This file is self-contained. A backend engineer should be able to understand the product shape,
system boundary, API contracts, wallet-BE responsibilities, rollout plan, and remaining decisions
from this document alone.

## Executive Summary

Rumble is building a Wallet Campaign Builder where internal staff create promo campaigns. Users
redeem a shared campaign code in the Rumble Wallet app. If Rumble accepts the claim, wallet-BE pays
the user on-chain.

The important architecture change is that campaign and code ownership moves to Rumble:

- Rumble owns campaign state, promo-code validation, eligibility, geo checks, anti-abuse,
  redemption limits, budget accounting, reporting, creator attribution, and audit state.
- Wallet-BE owns wallet-address lookup, key custody, transaction signing, transaction submission,
  transaction push notifications, and reporting payout outcomes back to Rumble.

Wallet-BE should not keep promo campaigns or promo codes as business source of truth for this new
flow. Wallet-BE still needs local execution state so accepted claims are paid reliably.

## Locked Product Decisions

- The payout goes to the redeeming user's wallet, not to a creator's wallet.
- Creators are attribution context for analytics and campaign reporting only.
- Promo codes are reusable/shared. For example, a streamer may share one public code and the first
  N eligible users may redeem it.
- Rumble decides whether a code is valid, whether a user is eligible, whether the campaign is
  active, whether budget remains, and what amount/token should be paid.
- Wallet-BE must not reimplement campaign limits, first-N logic, geo rules, SSO/adult checks,
  restrict-days logic, or code accounting.
- Rumble does not call wallet-BE to trigger payouts. Wallet-BE calls Rumble, then pays on its own
  worker/queue, then calls Rumble back with the payout result.
- Use a fresh promo payout wallet for this new flow. Rumble funds and monitors it operationally.

## Implementation Tightenings

These points are intentionally stricter than a high-level product flow, because they affect
reliability:

- Wallet-BE should return success to the wallet app only after the accepted Rumble claim has been
  durably recorded or queued locally. The user-facing behavior is still "accepted quickly; payout
  happens asynchronously", but wallet-BE should not acknowledge the app while the accepted claim
  exists only in memory.
- Old promo tables and code-generation paths should be removed after the new flow is feature-flagged,
  tested, and stable in production. Even if the old campaign has no active users, keeping cleanup
  post-cutover preserves the simplest rollback path.
- Wallet-BE should treat Rumble `campaign-redeem` as the only budget/claim authority. If Rumble is
  unreachable, wallet-BE fails the app request as retryable and does not create a local accepted
  claim.

## Today's System

The old wallet-BE promo flow was stateful on wallet-BE:

1. Wallet app submitted a promo code.
2. Wallet-BE looked up the code in local `promo_codes`.
3. Wallet-BE called Rumble's old `/-wallet/v1/promo_eligibility` endpoint.
4. If eligible, wallet-BE sent an on-chain transfer.
5. Wallet-BE marked the local code as claimed.

The old system used local `promo_campaigns` and `promo_codes` tables. That service has reportedly
been switched off for months, with no active redemptions or outstanding codes expected.

## Target Flow

1. Wallet app submits a promo code to wallet-BE.
2. Wallet-BE forwards the code, encrypted user id, and end-user IP address to Rumble.
3. Rumble validates the claim.
4. If rejected, wallet-BE returns the mapped rejection to the wallet app and does not schedule a
   payout.
5. If accepted, Rumble commits a claim row, reserves/debits campaign budget, and returns
   `claimId`, `amount`, and `token`.
6. Wallet-BE durably enqueues a payout keyed by `claimId`.
7. After enqueue succeeds, wallet-BE returns "received" to the wallet app. The wallet app request
   does not wait for the on-chain transaction.
8. A wallet-BE worker resolves the user's wallet address, signs, and broadcasts the token transfer.
9. Once the transaction is broadcast, wallet-BE calls Rumble's settled callback with `claimId`,
   `txHash`, and `walletAddress`.
10. If wallet-BE gives up on the payout, it calls Rumble's failed callback with `claimId`,
    `reason`, and `walletAddress` if known.

```
Wallet App                 Wallet-BE                         Rumble
    |                           |                                |
    | submit promo code         |                                |
    |-------------------------->|                                |
    |                           | campaign-redeem                |
    |                           | code, id, clientIp             |
    |                           |------------------------------->|
    |                           |                                | validate code/user/IP/budget
    |                           |                                | commit claim + reserve budget
    |                           | claimId, amount, token         |
    |                           |<-------------------------------|
    |                           | durably enqueue payout          |
    | received                  |                                |
    |<--------------------------|                                |
    |                           |                                |
    |                           | resolve wallet + broadcast tx   |
    |                           |                                |
    |                           | campaign-claim-settled          |
    |                           | claimId, txHash, walletAddress |
    |                           |------------------------------->|
    |                           |                                |
```

## Public Wallet API

Preferred implementation is to keep the existing wallet-app redeem surface unless wallet-FE
confirms a new route is required:

- `POST /api/v1/promo/:campaignId/claim`

Expected wallet-app request body:

```json
{
  "code": "TETHER10"
}
```

The `campaignId` path parameter is legacy wallet-BE routing context. In the new flow, Rumble is the
campaign source of truth, so wallet-BE must not use `campaignId` for campaign validation, budgeting,
code lookup, payout amount selection, or token selection.

Before coding, confirm with wallet-FE:

- whether this existing route remains the intended app contract;
- whether any new request fields are expected;
- whether `GET /api/v1/promo/:campaignId/claim/status` is still called.

If the status endpoint is still called, define its new response semantics against wallet-BE payout
execution state. It should not depend on local promo-code state. If FE confirms there are no callers,
remove or stop exposing it as part of cleanup.

## Rumble Admin API

All three new Rumble endpoints live under:

- `/-wallet/v1/admin/`

Auth uses the same wallet-BE -> Rumble HMAC pattern already used for `transaction-init`,
`transaction-complete`, and `jar-sync`:

- IP allowlist
- `x-signature`
- `x-signed-on`

Wallet-BE should reuse the existing signing primitive and environment-specific secret/config.

## 1. Redeem Code With Rumble

Endpoint:

- `POST {rumble}/-wallet/v1/admin/campaign-redeem`

Request body:

```json
{
  "code": "TETHER10",
  "id": "<encrypted user id>",
  "clientIp": "<IP of the mobile-app request as seen by wallet-BE>"
}
```

Field rules:

- `code` is the promo code submitted by the wallet app. Wallet-BE should not apply campaign
  semantics to it.
- Default code handling is pass-through: wallet-BE forwards the code string as received from the
  wallet app after JSON schema/type validation. Wallet-BE should not uppercase, lowercase, trim, or
  otherwise normalize the code unless wallet-FE and Rumble explicitly agree that wallet-BE owns that
  normalization.
- `id` is the encrypted Rumble user id, matching the existing convention used by wallet-BE ->
  Rumble calls.
- `clientIp` is the end user's IP from the inbound mobile request, not wallet-BE's server IP.
  Use the wallet-BE/app-node trusted-proxy IP extraction path. If there is no single shared helper,
  introduce one or document the exact Fastify/request property used; current local app-node code
  already relies on Fastify `req.ip` for IP-based rate-limit keys.

Success response:

```json
{
  "data": {
    "claimId": "claim_123",
    "amount": "10.00",
    "token": "USAT"
  }
}
```

Success semantics:

- Rumble has committed the claim and reserved/debited campaign budget.
- `claimId` is the canonical correlation key for wallet-BE payout tracking and all later callbacks.
- `amount` is a decimal human-unit string, not base units. It must be a JSON string, never a JSON
  number, to avoid float drift. Rumble should send fixed-precision decimal strings with no
  exponential notation; wallet-BE converts the string using the configured decimals for `token`.
- `token` must be one of the supported campaign payout tokens for the environment.
- The redeem response does not include `walletAddress`. Wallet-BE resolves the user's wallet
  address locally.

Chain scope:

- Current rollout is single-chain Ethereum unless Rumble explicitly adds `chain` to the redeem
  response.
- If multi-chain support becomes required, Rumble's success response should include a `chain`
  field and wallet-BE should use `(chain, token)` to resolve wallet address, token contract,
  decimals, RPC config, gas config, and funding wallet.

Rejected response:

```json
{
  "error": {
    "code": "ALREADY_CLAIMED",
    "message": "..."
  }
}
```

Expected rejection status:

- `409`

Known error codes:

- `CODE_NOT_FOUND` - code does not exist.
- `CAMPAIGN_NOT_ACTIVE` - campaign is not active or outside its valid window.
- `WRONG_GEO` - user's country is not in the campaign target list.
- `STATE_BLOCKED` - user's `clientIp` resolves to an excluded US state.
- `ALREADY_CLAIMED` - user already redeemed this code.
- `RESTRICT_DAYS_HIT` - user redeemed another code too recently.
- `BUDGET_EXHAUSTED` - campaign budget is fully allocated.
- `ELIGIBILITY_FAILED` - user fails adult/US/SSO checks.
- `USER_NOT_FOUND` - encrypted `id` could not be resolved to a Rumble user.

Wallet-BE behavior:

- For `409`, return the existing app-facing promo error shape with the mapped reason.
- For timeout, network failure, or Rumble `5xx`, return a generic retryable error to the app.
- Do not schedule a payout unless Rumble returned success.
- Do not pre-accept locally if Rumble is unavailable. Rumble is the only source of budget truth.
- Do not automatically retry `campaign-redeem` inside wallet-BE on timeout or `5xx` unless Rumble
  adds an idempotency key/contract for redeem attempts. Let the app/user retry the redeem request so
  the user-visible state matches Rumble's response.
- If a duplicate client submission or future idempotent retry path hits Rumble after a lost
  response and Rumble returns `ALREADY_CLAIMED`, trust Rumble's response and surface the
  already-claimed outcome.

## 2. Durably Schedule And Execute Payout

After Rumble returns OK, wallet-BE must durably record or enqueue the payout before responding OK to
the wallet app.

Minimum payout record fields:

- `claimId`
- encrypted user id or internal user reference needed to resolve wallet address
- `amount`
- `token`
- target `chain` if/when supported; otherwise implicit Ethereum
- payout status
- wallet address once resolved
- tx hash once broadcast
- last error / retry metadata

Execution behavior:

1. Persist/enqueue the payout using `claimId` as an idempotency key.
2. Return "received" to the wallet app after durable enqueue succeeds.
3. Resolve the user's wallet address locally for the target chain.
4. Convert `amount` to base units using configured token decimals.
5. Submit the token transfer from the configured promo funding wallet.
6. Let the existing transaction push path notify the wallet app when funds arrive.

If durable enqueue fails after Rumble accepted the claim, wallet-BE should return a server error to
the app and raise an operational alert. This is an exceptional state because Rumble may now hold
reserved budget without a queued payout.

## 3. Notify Rumble On Successful Broadcast

Endpoint:

- `POST {rumble}/-wallet/v1/admin/campaign-claim-settled`

Call timing:

- Call after the on-chain transaction is successfully broadcast and wallet-BE has a tx hash.
- Do not wait for block confirmation unless Rumble changes the requirement.
- "Settled" in this contract means "broadcast with tx hash", not "confirmed on-chain".
- This contract has no later "dropped", "replaced", "reverted", or "confirmed" notification. Rumble
  accepts the broadcast tx hash as the audit event for this iteration. If Rumble needs finality
  tracking later, that should be a separate contract.

Request body:

```json
{
  "claimId": "claim_123",
  "txHash": "0x...",
  "walletAddress": "0xYYY..."
}
```

Response:

- `200 OK`

Retry/idempotency:

- Rumble must accept duplicate settled calls for the same `claimId` without double-effect.
- Wallet-BE should retry this callback durably if Rumble is temporarily unreachable.
- Wallet-BE must not call both settled and failed for the same claim.

## 4. Notify Rumble On Failed Payout

Endpoint:

- `POST {rumble}/-wallet/v1/admin/campaign-claim-failed`

Call timing:

- Call only after wallet-BE decides the payout cannot be completed, after any internal retry policy
  has been exhausted.

Request body:

```json
{
  "claimId": "claim_123",
  "reason": "insufficient gas reserve",
  "walletAddress": "0xYYY..."
}
```

Field rules:

- `reason` should be short, human-readable, and safe to store in Rumble admin/audit UI.
- `walletAddress` should be included if it was resolved before failure.
- If failure happens before address resolution, confirm with Rumble whether `walletAddress` may be
  `null` or omitted.

Response:

- `200 OK`

Retry/idempotency:

- Rumble must accept duplicate failed calls for the same `claimId` without double-effect.
- Wallet-BE should retry this callback durably if Rumble is temporarily unreachable.
- Wallet-BE must not call both settled and failed for the same claim.

## Wallet-BE Local State

Wallet-BE should remove promo campaign/code ownership from this flow, but it still needs local
execution state for reliable payout processing.

Wallet-BE may use the existing worker/queue/storage pattern or introduce a small payout table, but
the local state must be keyed by `claimId` and represent execution only.

Wallet-BE local state should decide:

- whether an accepted claim has been durably queued;
- whether wallet-BE has resolved the user's wallet address;
- whether wallet-BE has broadcast a transaction;
- whether wallet-BE has reported settled/failed back to Rumble;
- whether wallet-BE needs to retry local execution or callback delivery.

Wallet-BE local state must not decide:

- whether a code exists;
- whether a campaign is active;
- whether a user is eligible;
- whether a user already claimed;
- whether budget is available;
- what amount should be paid.

Those are Rumble decisions.

## Token, Chain, And Funding Configuration

Initial supported tokens:

- `USAT`
- `USDT`

Current chain:

- Ethereum, unless Rumble adds `chain` to the redeem response.

Wallet-BE must own local configuration for:

- token symbol -> contract address
- token symbol -> decimals
- chain -> RPC configuration
- chain -> funding wallet / seed
- chain -> gas settings
- low-balance alert thresholds

Operational requirements:

- Use a fresh promo payout wallet for this new flow.
- Rumble funds and monitors the payout wallet operationally.
- Wallet-BE keeps or adapts low-balance Slack alerts.
- Wallet-BE must reject or operationally fail closed if Rumble returns an unsupported token.

## Cleanup And Migration

The old promo service has been off for months and has no outstanding codes, so no data migration is
expected.

Cleanup should happen after the new flow is feature-flagged, tested, and stable in production:

- remove local promo-code validation from the new path;
- retire the old `/-wallet/v1/promo_eligibility` dependency after the migration window;
- drop or archive `promo_campaigns` and `promo_codes`;
- remove old code-generation paths that are no longer used.

Do not drop the old tables before the new flow is cut over unless the team explicitly confirms no
rollback path depends on them.

## Observability And Operations

Wallet-BE should expose or alert on:

- Rumble redeem request failures and latency;
- Rumble rejection counts by error code;
- payout queue depth and oldest queued claim age;
- payout broadcast failures by reason;
- callback retry backlog and oldest unreported claim age;
- funding wallet native-token balance;
- funding wallet payout-token balances;
- successful settled callback count;
- failed callback count.

Operationally important stuck states:

- Rumble accepted a claim, but wallet-BE failed to durably enqueue it.
- Wallet-BE queued a payout, but the worker cannot resolve a wallet address.
- Wallet-BE broadcast a transaction, but cannot deliver the settled callback.
- Wallet-BE exhausted payout retries, but cannot deliver the failed callback.

## Rollout

1. Rumble implements Campaign Builder admin state and campaign creation.
2. Rumble implements `campaign-redeem` with claim creation and budget accounting.
3. Wallet-BE implements redeem forwarding, durable payout enqueue, and payout execution keyed by
   `claimId`.
4. Rumble implements settled/failed callbacks.
5. Wallet-BE implements durable callback retry/outbox for settled/failed notifications.
6. Stage end-to-end with real HMAC auth, staging token contracts, and a funded staging payout
   wallet.
7. Enable behind a feature flag.
8. Monitor rejects, queued payouts, payout failures, callback retries, tx hashes, and wallet
   balance.
9. After stable production cutover, remove old promo-code tables and legacy eligibility wiring.

## Acceptance Criteria

- Wallet-BE forwards submitted promo codes to Rumble `campaign-redeem` with `code`, encrypted `id`,
  and end-user `clientIp`.
- Wallet-BE does not normalize promo-code casing or whitespace unless that behavior is explicitly
  agreed with wallet-FE and Rumble.
- Wallet-BE forwards `amount` handling only from a decimal JSON string; a numeric JSON `amount`
  response is rejected as an invalid Rumble response.
- Wallet-BE does not schedule payouts when Rumble rejects, times out, or returns `5xx`.
- Wallet-BE does not automatically retry `campaign-redeem` on timeout or `5xx` without a Rumble
  idempotency contract.
- Wallet-BE durably queues accepted claims by `claimId` before returning success to the wallet app.
- Wallet-BE resolves the user's wallet address locally and never asks Rumble for wallet-address
  lookup.
- Wallet-BE pays the redeeming user, not a creator address.
- Wallet-BE converts decimal `amount` to base units using configured token decimals.
- Wallet-BE supports configured `USAT` and `USDT` payout contracts for the active environment.
- Wallet-BE calls `campaign-claim-settled` after transaction broadcast with `claimId`, `txHash`,
  and `walletAddress`.
- Wallet-BE does not send later confirmation/dropped/replaced/reverted callbacks for this iteration.
- Wallet-BE calls `campaign-claim-failed` after payout retries are exhausted.
- Settled/failed callbacks are retried durably until accepted or until the agreed retry policy
  alerts.
- Wallet-BE does not call both settled and failed for the same `claimId`.
- Old local promo-code validation is not used for the new flow.
- Low-balance alerting exists for the new payout wallet.

## Open Decisions Before Coding

1. Confirm the wallet-app route and request schema with FE.
2. Confirm whether `GET /api/v1/promo/:campaignId/claim/status` is still used. If it is, define
   the new response semantics.
3. Confirm code normalization ownership: pass-through from wallet-BE, or trim/upcase before calling
   Rumble.
4. Confirm exact app-facing error mapping for each Rumble rejection code.
5. Confirm staging and production Rumble base URLs for the new admin API.
6. Confirm per-env HMAC secret/config keys and whether the existing signer can be reused as-is.
7. Confirm token contract addresses and decimals for `USAT` and `USDT` in each environment.
8. Confirm Rumble always returns `amount` as a fixed-precision JSON string, never a number.
9. Confirm whether response `token` is always enough, or whether Rumble wants to support multiple
   chains and should include `chain`.
10. Confirm the exact trusted-proxy client-IP extraction helper/property to use for `clientIp`.
11. Confirm whether `walletAddress` can be omitted/null on failed callback if address resolution
   fails before a wallet address is known.
12. Confirm callback retry expectations: max retry age, alert threshold, and whether callbacks
   should be retried forever until Rumble accepts them.
13. Confirm who owns manual recovery for claims accepted by Rumble but not yet settled/failed.
14. Confirm Rumble does not expect any post-broadcast dropped/replaced/reverted/finality callback
    for this iteration.

## Non-Goals

- Wallet-BE does not build a campaign admin API.
- Wallet-BE does not expose a payout API to Rumble.
- Wallet-BE does not expose address-by-user-id lookup to Rumble.
- Wallet-BE does not enforce campaign budgets, geo rules, eligibility, restrict-days rules, or
  first-N-user logic.
- Wallet-BE does not store promo codes as source of truth.
- Wallet-BE does not pay creators for this feature.

## Implementation Notes

- Use `claimId` as the idempotency key for local payout records and callbacks.
- Prefer durable queue/outbox behavior over in-memory post-response work.
- Keep the old business-logic-heavy promo path isolated from the new Rumble-owned campaign flow.
- Preserve low-balance alerts and transaction push behavior.
- Treat Rumble `5xx` during redeem as retryable and non-accepting; never pre-accept locally.
- Treat duplicate callback responses as success if Rumble returns `200 OK`.
- Fail closed on unsupported token, missing token config, missing wallet config, or missing chain
  config.
