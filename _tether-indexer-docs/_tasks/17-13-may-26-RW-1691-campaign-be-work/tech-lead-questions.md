# Tech-lead meeting — campaign feature questions

Context: RW-1691 (Rumble Wallet BE) + WDK-1453 plan / WDK-1454 implement (Promo Worker refactor for configurable multi-campaign reusable code).

## Architecture today (one-screen recap)

- **Worker `rumble-promo-wrk`** — Proc + API workers over Hyperswarm RPC. SQLite (`promo.db`) with two tables, `promo_campaigns` and `promo_codes`. **Reward = ERC-20 transfer** of USAT on Ethereum, sent from a hot wallet on the worker, gas-bumped by a 5s cron. Hard-coded: `VALID_TOKENS=['USAT']`, `VALID_BLOCKCHAINS=['ethereum']`, singular `chain` block in config.
- **`rumble-app-node`** — two routes:
  - `POST /api/v1/promo/:campaignId/claim` (rate-limited 5/10s)
  - `GET /api/v1/promo/:campaignId/claim/status`
  Both fetch the user's single `unrelated` wallet, then RPC into one of several workers selected by `CRC32(userId) % promoService[]`. No state on the App Node side.
- **Contract**: `claimCode({ code, wallet, campaignId, userId })` and `getCodeStatus({ wallet, campaignId, userId })`. Statuses: `claimed | paying | paid | failed`. 6-char codes. Eligibility today is enforced by an HTTP `POST /promo_eligibility` call from the **worker** back into the Rumble backend.

## Questions

### Scope of "reusable / multi-campaign"
1. Is every future campaign the same shape (one ERC-20 token on one chain, rewarded from a hot wallet), or do we need pluggable reward types (off-chain discount codes, multi-chain transfers, points)?
2. Does a single campaign ever need to support more than one token/chain, or is "one campaign = one token + one chain" still a safe invariant?
3. One shared hot wallet across all campaigns, or one wallet per campaign? (Affects nonce ownership, audit, refill ops.)

### Campaign lifecycle / admin
4. How are new campaigns created — config file at deploy, a new admin API on `rumble-app-node`, or DB-only?
5. Codes: pre-generated and bulk-loaded, generated on demand, or both? Who owns the loader job?
6. How is a campaign sunset — `enabled=false` only, or full cleanup of unclaimed codes?

### Eligibility & invariants
7. Keep the worker's HTTP callback into Rumble backend (`/promo_eligibility`), or move that check up into `rumble-app-node` so the worker becomes pure-execution?
8. Is the dedup rule "one claim per wallet per campaign", or stricter (one claim per user across all campaigns of a type)?

### Integration boundary
9. Stay on the current `promoService[]` round-robin pattern, or align with the WDK proc/api split (Hyperswarm topic, shared `topicConf.capability`) the rest of the stack uses?
10. The `unrelated` wallet assumption in `services/promo.js` — does any planned campaign need to pay a different wallet type (related, custodial)?

### Rollout
11. RW-1691 (Sprint 1) vs WDK-1453/1454 (Sprint 2) — what is the cut line, and which ships first?
12. The FE interface Alex's comment is waiting on — does FE drive the campaign-config shape, or does BE?

**Highest-leverage to lock first: 1, 4, 7, 9.**
