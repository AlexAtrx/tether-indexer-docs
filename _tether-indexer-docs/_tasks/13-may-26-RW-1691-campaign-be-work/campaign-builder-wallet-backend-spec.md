# Wallet Campaign Builder — Wallet Backend Spec

## Context

Rumble is building a **Wallet Campaign Builder**: an admin tool where internal staff create promo
campaigns (a code that, when redeemed in the Rumble Wallet app, pays the user some USAT/USDT). The
existing one-time-promo-code mechanism on wallet-BE doesn't fit the new model (one shared code per
campaign, redeemable by many users, gated by budget/geo/anti-abuse rules).

We are **moving campaign + code ownership from wallet-BE to Rumble**, leaving wallet-BE responsible
only for actually sending the tokens. The motivation:

- Rumble already owns the data validation needs (user country, SSO consent, account age, creator
  attribution). Today wallet-BE has to call back to Rumble for eligibility — keeping codes on
  wallet-BE and validation on Rumble splits the source of truth.
- Admin staff manage campaigns in the Rumble admin dashboard, alongside other content/promo tools.
- Wallet-BE keeps doing what only it can do: hold keys, look up wallet addresses, sign and submit
  on-chain transactions.


## Today's state (on wallet-BE)

- `promo_campaigns` and `promo_codes` tables exist with the old single-use-code redemption
  pipeline, but the service has been **switched off for months** — no outstanding codes, no
  active redemptions. Nothing to migrate at cutover.
- The historical flow (for reference): wallet app submits a code → wallet-BE looks it up in
  `promo_codes` → wallet-BE calls Rumble `/-wallet/v1/promo_eligibility` for adult/US/SSO →
  if eligible, wallet-BE submits the on-chain transfer → marks the code claimed. Each code was
  single-use, generated up-front.


## Target state

- Wallet-BE no longer stores campaigns or codes. Wallet app submits a code; wallet-BE forwards
  it synchronously to Rumble, which is the source of truth.
- Rumble validates everything (status, geo, budget, anti-abuse, eligibility) and synchronously
  returns **OK** (with the amount/token to pay) or **rejected** (with a structured reason).
- On OK, wallet-BE responds to the wallet app ("received") and **schedules a payout on its own
  side** — wallet-BE owns the queue/worker and the on-chain submission. Rumble does not call
  wallet-BE; there is no payout endpoint exposed by wallet-BE.
- After the payout attempt resolves, wallet-BE calls Rumble with the outcome (settled or failed)
  so Rumble can record the destination address and tx_hash for audit, and release budget on
  failure.

```
   Wallet App                   Wallet-BE                          Rumble
       │                            │                                 │
       │ submit code ──────────────▶│                                 │
       │                            │ POST /-wallet/v1/admin/         │
       │                            │   campaign-redeem ─────────────▶│
       │                            │   (code, id, clientIp)          │
       │                            │                                 │ validate everything
       │                            │                                 │  + state-IP-block;
       │                            │                                 │ commit claim row,
       │                            │                                 │ debit budget
       │                            │ ◄── 200 {claimId, amount,       │
       │ ◄── ok ────────────────────│         token} ─────────────────│   (or 409 {errorCode})
       │                            │                                 │
       │                            │ enqueue payout, look up the     │
       │                            │ user's wallet address locally,  │
       │                            │ submit on-chain tx              │
       │                            │                                 │
       │                            │ on success:                     │
       │                            │ POST /-wallet/v1/admin/         │
       │                            │   campaign-claim-settled ──────▶│ flip claim → settled,
       │                            │   (claimId, txHash,             │ store tx_hash + address
       │                            │    walletAddress)               │
       │                            │                                 │
       │                            │ on failure:                     │
       │                            │ POST /-wallet/v1/admin/         │
       │                            │   campaign-claim-failed ───────▶│ flip claim → failed,
       │                            │   (claimId, reason,             │ store address + reason,
       │                            │    walletAddress)               │ release budget
       │                            │                                 │
       │ ◄── tx push (existing) ────│                                 │
```


## What wallet-BE needs to build

### 1. (New) Forward code redemption to Rumble — synchronous

When the wallet app submits a code, wallet-BE no longer looks it up locally. It calls Rumble's
new admin API **inside the wallet app's redeem request** and uses Rumble's response to decide
what to tell the user.

The three new endpoints below all live under a new admin-API namespace `/-wallet/v1/admin/` on
Rumble, used for back-to-back wallet-BE → Rumble calls. (Pre-existing wallet-BE → Rumble
endpoints under `/-wallet/webhook/` like `transaction-init` are unaffected.)

- **Endpoint:** `POST {rumble}/-wallet/v1/admin/campaign-redeem` *(Rumble side — Rumble will implement)*
- **Auth:** IP allowlist + HMAC signature, **same pattern wallet-BE already uses for
  `transaction-init` / `transaction-complete` / `jar-sync`**. Headers: `x-signature`,
  `x-signed-on`. Wallet-BE already has the signing primitive — reuse it.
- **Request body:**
  ```json
  {
    "code":     "TETHER10",
    "id":       "<encrypted user id>",
    "clientIp": "<IP of the mobile-app request as seen by wallet-BE>"
  }
  ```
  The `id` field is the encrypted user id — same shape and convention as the `id` field in
  `transaction-init` / `transaction-complete` / `promo_eligibility` payloads.
  `clientIp` is the originating mobile-app IP (from the inbound request's `remote_addr` /
  `X-Forwarded-For` chain), forwarded to Rumble so Rumble can apply **state-level geo-IP
  blocking** (e.g. NY-state residents are legally ineligible for these campaigns; Rumble
  resolves IP→US-state and rejects with `STATE_BLOCKED` if the state is on the exclusion list).
  Wallet-BE's own IP is **not** what we want here — pass the end user's IP.
- **Responses:**
  - `200 {"data": {"claimId": "...", "amount": "10.00", "token": "USAT"}}` — Rumble has committed
    the redemption. Wallet-BE: respond OK to the wallet app, then proceed to §2.
  - `409 {"error": {"code": "<reason>", "message": "..."}}` — rejected. Wallet-BE surfaces the
    reason to the wallet app. Reason codes:
    - `CODE_NOT_FOUND` — code doesn't exist
    - `CAMPAIGN_NOT_ACTIVE` — campaign isn't started or is outside its valid window
    - `WRONG_GEO` — user's country isn't in the campaign's target list
    - `STATE_BLOCKED` — user's `clientIp` resolves to an excluded US state (e.g. NY)
    - `ALREADY_CLAIMED` — user already redeemed this code
    - `RESTRICT_DAYS_HIT` — user redeemed another code too recently
    - `BUDGET_EXHAUSTED` — campaign budget is fully allocated
    - `ELIGIBILITY_FAILED` — user fails adult/US/SSO check
    - `USER_NOT_FOUND` — encrypted `id` couldn't be resolved to a Rumble user
  - Other 5xx — treat as transient, surface a generic "try again" error to the wallet app.
    **Do not** schedule a payout if Rumble didn't return OK.

Note: the response does **not** include `walletAddress`. Wallet-BE resolves the user's address
locally (it owns that mapping) — Rumble doesn't need to fetch or carry it during redeem.


### 2. (Stays on wallet-BE) Schedule and execute the payout

After Rumble returns OK, wallet-BE:

1. Responds OK to the wallet app immediately ("received, you'll see tokens shortly").
2. Enqueues a payout on whatever internal queue/worker pattern wallet-BE prefers — the wallet
   app's redeem request returns *before* the on-chain tx is submitted; users see the tokens land
   via the existing transaction push channel.
3. Looks up the user's wallet address locally for the target blockchain.
4. Submits the on-chain transfer for `amount` of `token` to that address.

This is essentially what wallet-BE already does for the existing promo-code flow — just gated by
Rumble's redeem response instead of a local `promo_codes` row.


### 3. (New) Notify Rumble on successful payout

Once the on-chain tx is broadcast (no need to wait for block confirmation), call Rumble's settled
webhook so Rumble can record the tx hash and destination address for audit.

- **Endpoint:** `POST {rumble}/-wallet/v1/admin/campaign-claim-settled` *(Rumble side)*
- **Auth:** same HMAC pattern as §1.
- **Request body:**
  ```json
  {
    "claimId":       "<from §1 response>",
    "txHash":        "0x...",
    "walletAddress": "0xYYY..."
  }
  ```
- **Response:** `200 OK`. Idempotent — wallet-BE may retry; Rumble will accept duplicate calls
  for the same `claimId` without double-effect.


### 4. (New) Notify Rumble on payout failure

If the on-chain submission fails (RPC error, dead chain, insufficient gas reserve, etc.), call
Rumble's failed webhook so Rumble can release the budget and flag the claim for admin
recovery/audit.

- **Endpoint:** `POST {rumble}/-wallet/v1/admin/campaign-claim-failed` *(Rumble side)*
- **Auth:** same HMAC pattern as §1.
- **Request body:**
  ```json
  {
    "claimId":       "<from §1 response>",
    "reason":        "<short, human-readable>",
    "walletAddress": "0xYYY..."
  }
  ```
- **Response:** `200 OK`. Also idempotent.

Note on retries: wallet-BE may retry the on-chain submission itself before deciding it's failed.
Once wallet-BE decides "I've given up", call this webhook. Do *not* call §3 and §4 for the same
claim.


### 5. (Decommission) Drop `promo_campaigns` and `promo_codes`

The old promo service has been off for months and has no outstanding codes, so this is just
dead-code cleanup — can land any time. Wallet-BE:

- Drops the `promo_campaigns` + `promo_codes` tables.
- Removes the local code-validation logic and the old eligibility round-trip
  (`/-wallet/v1/promo_eligibility` on Rumble).

No data migration needed.


## What stays the same on wallet-BE

- Wallet-BE remains the source of truth for **user → wallet address mapping**.
- Wallet-BE remains the **only** holder of signing keys and the **only** entity that submits
  on-chain transactions. Rumble has no on-chain capability.
- Wallet-BE keeps pushing transaction events to the wallet app via the existing channel — that's
  how users see their tokens arrive after a campaign payout settles.
- The existing `/-wallet/v1/promo_eligibility` endpoint on Rumble stays in place during the
  migration window for backward compat. Once the new redeem flow is fully cut over, it can be
  retired.


## What wallet-BE does *not* need to build

- **No payout API exposed by wallet-BE.** Rumble does not call wallet-BE for this feature.
- **No address-by-user-id lookup endpoint** exposed to Rumble. Address resolution is internal to
  wallet-BE; Rumble learns the address only when wallet-BE reports it back in §3 or §4.
- **No own state for promo codes** going forward — Rumble holds that.


## Open questions / decisions to make on the call

1. **Idempotency of §1:** if wallet-BE retries the redeem call after a network glitch with the
   same `{code, id}`, Rumble's intended behaviour is to return `ALREADY_CLAIMED` on the
   second call (since the first one already committed the row). Wallet-BE should treat this as a
   "the user already used this code" outcome — but if wallet-BE's retry actually corresponds to a
   single user submission that lost its response, this would mistakenly show "already claimed"
   to a user who never got their tokens. Worth thinking about how wallet-BE wants to dedupe
   client-submitted requests vs server-retry attempts.
2. **Stuck claims:** if wallet-BE crashes between Rumble OK (§1) and the settle/failed webhook
   (§3/§4), the claim sits in `accepted` on Rumble forever, holding budget. Rumble's admin UI
   will surface a "release stuck claim" action for manual recovery, but worth asking: how often
   does wallet-BE expect to crash mid-flight? Should we eventually add a TTL sweeper on Rumble?
3. **Failure-mode for Rumble being unreachable during §1 redeem:** how should wallet-BE behave
   if the redeem webhook times out or 5xxs? Recommend: return a generic "try again" to the
   wallet app, do NOT pre-accept locally. (Rumble is the only place where the budget invariant
   lives.)
4. **Test/staging environments:** which Rumble env(s) does wallet-BE point at today, and how do
   we wire the new endpoints in staging vs production?


## Rollout phases

1. **Stage 1 (Rumble only — already underway):** admin can create/edit campaigns. No claim flow
   live yet; nothing for wallet-BE to do.
2. **Stage 2 (joint):** Rumble implements `/-wallet/v1/admin/campaign-redeem` + accept logic +
   the matching claim row + budget accounting. Wallet-BE implements the forward-to-Rumble redeem
   (§1) and gates its payout flow on Rumble's OK. Feature-flagged.
3. **Stage 3 (joint):** Rumble implements `/-wallet/v1/admin/campaign-claim-settled` and
   `/-wallet/v1/admin/campaign-claim-failed`. Wallet-BE calls them after each payout attempt.
   Admin UI surfaces tx_hash + address on the claim row. End-to-end tested.
4. **Stage 4 (cleanup):** flip the feature flag in prod. Watch for issues. Once stable,
   wallet-BE can drop the dormant `promo_campaigns` / `promo_codes` tables (§5) and Rumble can
   retire `/-wallet/v1/promo_eligibility`.


## Estimated wallet-BE effort (rough)

For the wallet-BE team's planning — not a commitment:

- §1 forward-to-Rumble redeem: small (replace local lookup with HTTP forward + error mapping).
- §2 schedule/execute payout: should largely already exist (wallet-BE already does on-chain
  payouts for the current promo flow + tips/rants). Probably mostly removing the local-code
  branch and reusing existing tx-submission code with new inputs.
- §3 and §4 callbacks: small (two new outbound HTTP calls, HMAC-signed, post-payout).
- §5 decommission: small (drop tables/code) once flag is flipped.

No new on-chain infrastructure needed — this is a thinner-and-more-focused version of what
wallet-BE already does.
