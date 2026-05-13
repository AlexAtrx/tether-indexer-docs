# Rumble Multi-Campaign Promo — Canonical Specification

> **Status:** DRAFT · Iteration 1 (post tech-lead meeting #1)
> **Owner:** Alex Atrash
> **Asana cards:** RW-1691 (Rumble Wallet BE), WDK-1453 (plan), WDK-1454 (implement, BLOCKED on WDK-1453)
> **Last updated:** 2026-05-13
> **Source-of-truth file for this feature.** Update in place after each meeting / decision. Append a row to the Revision log on every change.

Throughout this doc each design point carries one of:
- **[DECIDED]** — agreed in a meeting, do not re-litigate without a revision.
- **[LEANING]** — current default direction, low-cost to change.
- **[OPEN]** — must be resolved before implementation; tracked in §7.

---

## Revision log

| Date | Author | Change |
|---|---|---|
| 2026-05-13 | Alex | Initial draft from tech-lead meeting #1 (see `tech-lead-meeting-1-initial.md`). |
| 2026-05-13 | Alex | **Major mechanic update:** the new campaign is a *creator-tipping* flow. The redeemer enters a code AND a creator's public address; the reward is sent to the **creator**, not the redeemer. Updated §1, §2, §4, §5.2, §5.3, §5.4, added §5.11, expanded §7. See also `code-reality-check.md` for code-level implications. |
| 2026-05-13 | Alex | **Creator-tipping framing retracted** after meeting with Rumble TL — the user still receives the funds; creators are only attribution context for analytics (see `rumble-tech-lead-questions-meeting-answers.md`). Canonical Rumble spec is now `campaign-builder-wallet-backend-spec.md`. Much of §5 (multi-campaign config, recipient validation, dedup invariants, Polygon, funding-wallet strategy) is moot — Rumble owns all business logic; wallet-BE is a thin payout executor. Full SPEC rewrite pending; in the meantime, locked decisions are captured in the **Confirmed decisions** section below. |

## Confirmed decisions (Rumble TL Slack, post-spec)

Atomic answers landing on Slack after `campaign-builder-wallet-backend-spec.md`. Each row is the source-of-truth for that point until incorporated into a full SPEC rewrite.

| Date | Topic | Decision | Notes |
|---|---|---|---|
| 2026-05-13 | Payout wallet type | Stay on `unrelated` — same wallet type the old promo flow used. | Confirmed by Rumble TL on Slack. Matches today's `rumble-app-node/workers/lib/services/promo.js:27` lookup; no change needed to the wallet-resolution path. |
| 2026-05-13 | `/claim/status` endpoint | Decision deferred pending FE-team confirmation that nobody calls it. If unused, drop as part of §5 cleanup. | Asked Rumble TL on Slack; they had never heard of it. Action item: ping the wallet-FE team to confirm no callers, then delete. |
| 2026-05-13 | §1 redeem idempotency | Trust Rumble's response and capture it as-is — no special handling for the "response lost in transit → retry hits `ALREADY_CLAIMED`" edge case. | If we ever retry the `campaign-redeem` call, we accept whatever Rumble returns; if a user is unlucky enough to hit `ALREADY_CLAIMED` after a lost response, they'll see the generic "already claimed" message. Revisit only if this actually bites in production. |

---

## 1. Goal

Refactor the existing single-campaign Rumble promo flow (`rumble-promo-wrk` + `rumble-app-node`) into a **configurable multi-campaign** system that can run a new Rumble **creator-tipping** campaign on Polygon, while leaving the existing HTTP and RPC contracts as stable as the new mechanic allows.

### Feature shape — what's actually different this time

The previous campaign rewarded the redeemer directly: user enters a code → tokens land in the user's own wallet. The new campaign is a **creator-tipping** flow:

1. The user receives a promo code (via Rumble's channels).
2. The user submits the code **and chooses a creator they want to reward** by supplying the creator's public address.
3. The credit is sent to the **creator's address**, not the redeemer's wallet.

Concretely:
- The claim payload gains a new required field: the recipient creator address.
- The redeemer's own wallet is no longer the payout destination. It may still be useful for redeemer-side dedup, but it is no longer the address that receives funds.
- Validation now has two surfaces: the code (as before) **and** the recipient address (new — see §5.11).

## 2. Scope

**In scope (this iteration)**
- Generalise the worker to handle multiple concurrent campaigns from one codebase.
- Add **Polygon** execution path alongside the current Ethereum path.
- Introduce **reusable codes** (one code, many users) under a configurable dedup invariant.
- Add **creator-recipient flow**: claim payload accepts a recipient address that is not the redeemer; payout goes to that address.
- Add recipient-address validation (format + optional creator whitelist — see §5.11).
- Harden EVM transaction construction (typed ABI builder).
- Preserve the existing `rumble-app-node` HTTP **routes** end-to-end. The HTTP **body schema** and the worker RPC **payload** grow one required field (`recipientAddress`); see §5.2 for the back-compat strategy.

**Out of scope (this iteration)** — see §6 for rationale.
- Pluggable non-EVM reward types (discount strings, off-chain rewards, points).
- Multi-token or multi-chain *within a single campaign*.
- Migration off SQLite.
- Migration of promo to the standard WDK proc/api split + Hyperswarm topic transport.
- Full admin UI / API for campaign management.

## 3. Guiding principles

1. **Minimal change.** Reuse surfaces; touch internals only where new requirements force it.
2. **Lock invariants before code.** Especially the dedup rule (§5.4).
3. **No premature generalisation.** Build for "1..N campaigns of the current shape", not "any reward engine".
4. **Operational continuity.** Status enum, rate limiting, Slack alerts, hot-wallet refill flow all stay.

## 4. Architecture overview

Reuse the current two-component shape; the route path does not change. The claim payload now carries a recipient creator address.

```
client → rumble-app-node  POST /api/v1/promo/:campaignId/claim     body: { code, recipientAddress }
                          GET  /api/v1/promo/:campaignId/claim/status
        → CRC32(userId) % promoService[]            (unchanged)
        → rumble-promo-wrk  (Proc + API)            (internals refactored)
        → EVM RPC (Ethereum or Polygon)             (new: chain selected per campaign)
                                                    (new: payout goes to recipientAddress, NOT redeemer)
```

What changes:
- **Routes**: unchanged.
- **HTTP body / RPC payload**: new required field `recipientAddress` (the creator). See §5.2.
- **Worker internals**: payout destination is `recipientAddress`, not `wallet.addresses[blockchain]`. Dedup logic gets a redeemer dimension that may or may not need the redeemer's wallet (see §5.4).
- **Per-chain config**: as before.

A pre-existing snapshot of the current code lives in `tech-lead-questions.md` in this folder. This spec only describes the target.

## 5. Detailed design

### 5.1 Public HTTP surface — **[DECIDED]**

No change. Keep:
- `POST /api/v1/promo/:campaignId/claim` (rate-limited, default 5/10s — preserved)
- `GET  /api/v1/promo/:campaignId/claim/status`
- Status enum `claimed | paying | paid | failed` — preserved.
- HTTP error code mappings preserved.

### 5.2 Worker RPC contract — **[LEANING — adjusted for creator-tipping]**

Method names unchanged; argument keys grow one new field on `claimCode`:

- `claimCode({ code, recipientAddress, wallet, campaignId, userId })`
- `getCodeStatus({ wallet, campaignId, userId })` — unchanged shape; see open question 7.11 on whether status is per-(redeemer, campaign) or per-(redeemer, campaign, recipient).

`recipientAddress` is the **creator's** public address on the campaign's chain. The redeemer is identified by `userId` (always) and `wallet` (kept for now, used for dedup if §5.4 picks a wallet-scoped rule; otherwise unused for execution).

**Back-compat strategy for the existing route (open — pick one in meeting #2):**
- **A. Additive on `/api/v1/promo/:campaignId/claim`:** add an optional `recipientAddress` to the body. Legacy campaigns where the campaign row has `recipientRequired=false` ignore the field; new campaigns require it. One route, two behaviours gated on campaign config.
- **B. V2 route:** introduce `POST /api/v2/promo/:campaignId/claim` with the new required-field shape; the v1 route keeps the old "pay-redeemer" semantics. Cleaner separation, more FE work.

Leaning A while the old campaign is finished (no live v1 traffic). Final call gated on §7.5 (backward-compat) and the Rumble answer to "is the old campaign over?".

### 5.3 Storage / data model — **[LEANING]**

- Keep **SQLite** (`promo.db`). No migration off it this iteration.
- Extend `promo_campaigns` so the campaign row carries the execution shape:
  - `token` (already present) — used as a logical key.
  - `blockchain` (already present) — now any of the supported chains (`ethereum`, `polygon`).
  - `amountPerClaim` (already present).
  - `dedupScope` — new column; values `wallet_per_campaign` | `user_per_campaign` | `user_recipient_per_campaign` | (future) `user_per_campaign_type`. Default decided in §5.4.
  - `reusable` — new column; boolean. `false` matches today's "one-claim-per-code" promo; `true` is the new "shared code, many claimants" mode.
  - `recipientMode` — new column; values `redeemer_self` (legacy) | `external_address` (new creator-tipping campaigns).
  - `recipientWhitelist` — new column; nullable. When set, claims may only target an address in this list (see §5.11).
  - `fundingWalletId` — new column; foreign key into a funding-wallet config (§5.7). Nullable while only one wallet exists.
- Claim records:
  - For `reusable=false` legacy campaigns: row in `promo_codes` is the claim ledger (today's behaviour). `claimedBy` is the redeemer's address (also the payout destination).
  - For `reusable=true` creator-tipping campaigns: a new table `promo_claims(campaignId, code, redeemerUserId, redeemerAddress, recipientAddress, status, claimedAt, paidAt, txHash, payError, nonce)`. Payouts go to `recipientAddress`. Uniqueness is enforced at DB level by an index that matches the chosen `dedupScope` (§5.4).

> **Migration impact:** existing campaigns continue to work by writing into `promo_codes` with `reusable=false`. New campaigns write claim records into `promo_claims`. Internal code paths fork on `reusable`/`recipientMode`. No destructive migration of historical data.

### 5.4 Reusable codes + creator-tipping — dedup semantics — **[OPEN → must lock before code]**

Two dimensions now matter:

- **Redeemer dimension:** how many times can one user redeem a code in a campaign?
- **Recipient dimension:** does a redeemer-recipient pair have to be unique, or can the same redeemer tip the same creator twice?

Concrete options for `dedupScope`:

- **A. `wallet_per_campaign`** — one claim per (campaign, redeemer wallet address). Requires we still fetch the redeemer's wallet from the App Node. Simple unique index.
- **B. `user_per_campaign`** — one claim per (campaign, userId). Tighter against multi-wallet abuse; lets us drop the redeemer-wallet lookup entirely. Trust boundary is the JWT (already trusted for rate limiting and eligibility).
- **C. `user_recipient_per_campaign`** — one claim per (campaign, userId, recipientAddress). A user can tip many different creators in the same campaign but cannot tip the same creator twice. Closer to how a typical tipping mechanic feels.
- **D. `user_per_campaign_type`** — one claim per (userId, campaign type) across all campaigns of that type. Strongest. Requires a new "campaign type" concept in schema.

Default leaning: **B** or **C** depending on what Rumble wants the UX to be:
- If each user gets exactly one code → B is sufficient (one code = one redemption, regardless of who they tip).
- If users can hold/receive multiple codes → C, so a user with N codes can distribute to N different creators.

Confirm with Rumble (questions §1, §3, §6 in `rumble-tech-lead-questions.md`).

### 5.5 Multi-chain execution (Ethereum + Polygon) — **[DECIDED on chains, LEANING on shape]**

- Remove the module-level `VALID_TOKENS = ['USAT']` / `VALID_BLOCKCHAINS = ['ethereum']` constants. Make both per-campaign config.
- Singular `chain` block in worker config becomes a `chains[]` array keyed by chain name; campaign row references one entry by name. Still **one chain per campaign**.
- Replace ad-hoc transfer-bytes encoding with a **typed ABI-based builder** (e.g. ethers `Interface.encodeFunctionData`). Same execution adapter for Ethereum and Polygon.
- Keep the current ethers fallback for gas estimation until the upstream WDK gas-estimation bug is fixed. Isolate ethers behind a small execution adapter interface so the rest of the worker is chain-agnostic. When the WDK bug is fixed → swap the adapter back to WDK without changing callers.
- Stuck-tx retry / fee-bump cron stays; parameterise per-chain (`maxFeePerGas` defaults, bump factor) via config.

### 5.6 Eligibility — **[OPEN]**

Two viable locations:
- **Worker-side (today):** API worker calls `POST /promo_eligibility` on the Rumble backend over HTTP before accepting a claim.
- **App Node-side (cleaner boundary):** `rumble-app-node` performs the eligibility check before calling the worker; worker becomes pure execution.

Leaning: **move to App Node** for the next iteration if cost is acceptable; otherwise **keep in worker** for minimal-change. Decision deferred to meeting #2 (Andre).

### 5.7 Funding-wallet strategy — **[OPEN]**

- **Shared wallet** — single hot wallet pays all campaigns. Simpler refill ops, single Slack alert. Nonce contention if many concurrent campaigns.
- **Per-campaign wallet** — clearer audit trail, isolated funding, per-campaign refill. More keys to manage.

Leaning: **shared** for this iteration (matches the minimal-change principle); revisit if concurrent campaign load grows. Confirm with Andre.

### 5.8 Campaign lifecycle (create / load / sunset) — **[LEANING]**

- **Create:** DB / config-driven. A new campaign is added by inserting a `promo_campaigns` row + (for `reusable=false`) a batch of `promo_codes`. No admin API in this iteration.
- **Enable / disable:** existing `enabled` flag flips; no destructive cleanup.
- **Sunset:** disable via `enabled=false`. Unclaimed rows left in place for audit. A separate cleanup script may follow later.

### 5.9 Code generation & loading — **[OPEN]**

Three modes possible:
- **Pre-generated bulk load** — codes generated offline, loaded via script (today's pattern for `reusable=false`).
- **On-demand generation** — codes generated at claim time. Not needed if reusable codes are the only new requirement.
- **Single reusable code per campaign** — for `reusable=true`, one code string is registered with the campaign and reused.

Leaning: **pre-generated + load script** for legacy promo flow; **single reusable code per campaign** for the new flow. Loader job ownership (engineer-run script vs scheduled) to confirm with Andre.

### 5.10 Operational alerts — **[DECIDED]**

- Preserve Slack low-balance alert on the funding wallet(s). Threshold parameterised per wallet (in case §5.7 moves to per-campaign wallets later).
- Preserve metrics cron (per-campaign status counts to Slack).
- Add per-chain alerting tags so on-call can tell Ethereum failures from Polygon failures.

### 5.11 Recipient creator validation — **[NEW · OPEN]**

The new mechanic means the redeemer types in (or selects) an address that is **not their own**. This is an attack surface the previous campaign did not have. The worker must validate the recipient before queuing a payout:

- **Format:** must be a valid address on the campaign's blockchain (EVM checksum/length check for `ethereum` / `polygon`; reject malformed input cleanly).
- **Whitelist (open):** does Rumble maintain a registry of eligible creator addresses?
  - **A. Open recipients** — any well-formed address is accepted. Simpler, but allows the redeemer to tip any wallet, including their own (self-tipping abuse) or a wallet they control.
  - **B. Rumble-managed whitelist** — Rumble exposes an "is this a known creator address?" check (could piggy-back on `/promo_eligibility` or be a separate endpoint). The worker rejects non-whitelisted recipients.
  - **C. Static whitelist per campaign** — `recipientWhitelist` column on `promo_campaigns` is a CSV/JSON list of permitted addresses. No live Rumble call. Workable for small/curated campaigns; brittle if creator set churns.
- **Self-tipping:** even with an open recipient model, consider rejecting claims where `recipientAddress == redeemerAddress` to remove the easiest abuse path. (Cheap to add, no downside.)

This is the single biggest **new** decision the Rumble meeting must lock. Default leaning: **B** if Rumble can expose an endpoint; **C** otherwise; **A** only if the campaign is explicitly an "open tipping" mechanic.

## 6. Non-goals (this iteration) and why

| Non-goal | Rationale |
|---|---|
| Pluggable non-EVM reward types | Risks turning this into a generic reward engine; not required by the campaign. |
| Multi-token / multi-chain per campaign | "One campaign = one token + one chain" is the safest minimal shape; revisit only on explicit product ask. |
| SQLite → Postgres/Mongo | No concurrency or operational pressure forcing the move. |
| Promo → WDK proc/api split + Hyperswarm topic | Architectural migration with no immediate payoff; promo's custom `promoService[]` pattern already works. |
| Admin UI / API for campaigns | Lifecycle is light enough for DB-driven setup this iteration. |

## 7. Open questions (to resolve in meeting #2)

Each item references the section it gates. Strike through and move to Revision log once locked.

### For our own tech lead (Andre)
1. **Dedup invariant (§5.4):** A (wallet/campaign), B (user/campaign), C (user+recipient/campaign), or D (user/campaign-type)?
2. **Eligibility location (§5.6):** keep on worker via HTTP back-call, or move to `rumble-app-node`?
3. **Funding wallet (§5.7):** one shared wallet, or one per campaign?
4. **Code generation ownership (§5.9):** loader job — engineer-run script, scheduled job, or product-driven?
5. **Backward compatibility (§5.3 / 5.2):** additive on the existing route with a campaign-level flag, or hard v2 route? Gated on whether the old campaign keeps running (Rumble question §1).
6. **WDK gas-estimation upstream fix (§5.5):** is there a tracking ticket / ETA? Drives whether the ethers fallback is short-term or load-bearing.

### For Rumble's tech lead
See `rumble-tech-lead-questions.md` for full text. Items that gate this spec directly:

7. **Recipient model (§5.11):** open address, Rumble-managed whitelist endpoint, or static per-campaign whitelist?
8. **Codes-per-user (§5.4):** does each user get one unique code, or can a user hold many codes (e.g. one per piece of content)? — determines whether `dedupScope=B` or `C`.
9. **Old campaign status (§5.2):** is the previous campaign over? If yes, we can choose option A in §5.2 (additive). If still running, option B (v2 route) becomes more attractive.
10. **Anti-abuse expectations (§5.11):** is self-tipping disallowed? Is the recipient permitted to also be a redeemer in the same campaign?

### Code-reality additions (from `code-reality-check.md`)
11. **Per-chain gas config:** move `MAX_FEE_GWEI`, priority fee, and gas limit out of `gas.js` module constants into per-chain config. **Polygon-blocking.**
12. **Unrelated-wallet Polygon coverage:** does WDK expose a `polygon` address on the `unrelated` wallet today? If we choose `dedupScope=B` (userId-based) we may not need this at all.
13. **API-worker fold:** if eligibility moves to App Node, does the API worker still earn its keep?
14. **Reusable-code data shape:** new `promo_claims` table FK'd to a coupon row vs. reusing `promo_codes` differently. (See §5.3.)
15. **Status semantics (§5.2):** when a user has redeemed multiple codes for different creators, what does `GET /claim/status` return? Per-(user, campaign) summary, or list of per-(user, campaign, recipient) rows?

## 8. Backwards compatibility / rollout

- **Same HTTP routes, same RPC contract** → FE and ork unchanged.
- Old campaigns (`reusable=false`) flow continues via existing `promo_codes` table; new campaign flow uses `promo_claims`. Code paths fork inside the worker on the `reusable` flag.
- Rollout order:
  1. Land worker refactor + Polygon adapter behind feature parity with current Ethereum-only path. Existing campaigns still pass tests.
  2. Insert the new campaign config + code(s) in `promo_campaigns`.
  3. FE switches the user on once spec is locked.
- Rollback is `enabled=false` on the new campaign row plus a worker revert if the refactor itself misbehaves.

## 9. Dev / validation

- Local standalone flow, scripts, config, and auth instructions must be reproducible before handoff. Validate as part of implementation (per meeting note).
- Add at minimum: unit tests for the dedup invariant under both old and new modes; integration test that runs a `reusable=true` campaign end-to-end on a local EVM dev node for both Ethereum and Polygon adapter configurations.
- Update `rumble-promo-wrk` README to document campaign config schema, dedup modes, and per-chain config.

## 10. References

- Asana — RW-1691: https://app.asana.com/1/45238840754660/project/1212521145936484/task/1214395948381748
- Asana — WDK-1453 (plan): https://app.asana.com/1/45238840754660/project/1210540875949204/task/1214776665413533
- Asana — WDK-1454 (implement): https://app.asana.com/1/45238840754660/project/1210540875949204/task/1214776932455068
- Asana — WDK-1441 (rumble-promo-wrk security upgrades, parallel): https://app.asana.com/1/45238840754660/project/1210540875949204/task/1214716439993136
- Requirements doc (FE-shared, access required): https://docs.google.com/document/d/1_0kKQdzYJeX6UBvCeQHssX00uL6vOLQmXDf3dWW9cg0/edit?tab=t.bsufxnpzaz5c
- Repos: `tetherto/rumble-promo-wrk`, `tetherto/rumble-app-node`
- Sibling notes in this folder: `tech-lead-questions.md`, `tech-lead-meeting-1-initial.md`
