# Code-reality check against tech-lead meeting #1

> Cross-check of `tech-lead-meeting-1-initial.md` against the actual code in
> `rumble-promo-wrk` (commit `023c5a0` on `main`) and `rumble-app-node`.
> Each instruction is tagged ✓ HOLDS / ⚠ PARTIAL / ✗ CORRECTED, with
> file:line evidence. Section B lists gaps the meeting did not surface.

## A. Per-instruction reflection

### A.1 "Reuse `POST /api/v1/promo/:campaignId/claim` + the worker RPC contract"
✓ HOLDS. Routes at `rumble-app-node/workers/lib/server.js:537-560`. RPC methods are stable: `claimCode` and `getCodeStatus` on both API worker (`workers/api.promo.wrk.js:89, 100`) and Proc (`workers/proc.promo.wrk.js:87`). The `:campaignId` is already a path param threaded through end-to-end, so multi-campaign needs zero route changes.

### A.2 "Refactor the worker from single-purpose to reusable multi-campaign"
✓ HOLDS. Schema already shaped for it: `workers/lib/schema.js:5-31` defines `promo_campaigns` and `promo_codes`, both keyed by `campaignId`. The code is single-flavoured at the *behaviour* level, not the *schema* level.

### A.3 "Add reusable codes — same code claimable by multiple users; move dedup from 'code unique + consumable once' to a user/wallet-per-campaign invariant"
⚠ PARTIAL — more invasive than framed. Reality:

- The **registration-level** uniqueness is already `UNIQUE(code, campaignId)` (`schema.js:29`), which is fine for reusable codes — register one row, reuse it.
- The **consumption-level** mechanism today is the atomic UPDATE at `workers/lib/queries/codes.js:40-47`: it flips `status = 'active' → 'claimed'` on the *same row*. For a reusable code that has to serve N claimants, this row-locking does not work — second claimant would see the row already `claimed` and fail.
- The per-address invariant (`getClaimByAddressAndCampaign`, `codes.js:73`) **only exists as an application-level check** in `proc.promo.wrk.js:103-106`. There is **no DB-level UNIQUE(campaignId, claimedBy)** index → a true concurrent dedup invariant for reusable codes needs to be added.

Implication for the spec: reusable codes can't just "relax" the existing path; we need a fork — either a new `promo_claims` table (claim records, FK to a campaign-level coupon row) or a redesign where `promo_codes` stops being the claim ledger. Decide before coding (matches §5.4 of `SPEC.md`).

### A.4 "Lock the dedup invariant before coding"
✓ HOLDS. Today's invariant is per-(address, campaignId), but only enforced at application level. The lock-the-invariant call is exactly right — and it must also become a DB-level UNIQUE constraint, not just a SELECT-before-INSERT.

### A.5 "Support Polygon; current is hard-coded `VALID_BLOCKCHAINS=['ethereum']` + singular `chain` config"
✓ HOLDS, but the meeting enumerated only the surface symptoms. Additional Polygon-blocking hard-codes in the code:

- `workers/lib/constants.js:13` — `VALID_BLOCKCHAINS = ['ethereum']` (used by both the worker and `scripts/generate-codes.js:38`).
- `config/proc.promo.json.example:7` — singular `"chain": { ... }` block.
- `workers/proc.promo.wrk.js:305-313` — explicit `if (this.chain.blockchain === 'ethereum') { ... } else { throw ERR_UNSUPPORTED_BLOCKCHAIN }`.
- `workers/lib/wallet.bot.evm.js:18` — `this.nativeToken = 'ETH'` (used in low-balance Slack alerts; must become `MATIC`/`POL` per chain).
- `workers/lib/gas.js:5` — **`MAX_FEE_GWEI = 20n` module constant**. Polygon's base fee routinely sits at 30-100 gwei → this hard cap will reject *every* Polygon tx unless lifted.
- `workers/lib/gas.js:26` — **`priorityFee = 1100000000n`** (1.1 gwei) hard-coded. Polygon validators commonly want ≥30 gwei priority.
- `workers/lib/gas.js:13` — `gasLimit = 70000n // fixed gas limit`. Worth re-validating on Polygon (USDT/USDC transfers on Polygon land around 60-80k; should hold, but not assumed).

Net: the meeting's "generalise chain configuration, token config, transaction building, gas estimation, send flow" line is correct in direction, but the gas-module hard-coded fee/priority numbers are the highest-risk blocker. They need per-chain config, not just per-campaign config.

### A.6 "Keep one campaign = one token + one chain for now"
✓ HOLDS. Schema already enforces this shape (`token` and `blockchain` are single-valued columns on `promo_campaigns`).

### A.7 "Review funding-wallet strategy (shared vs per-campaign)"
✓ HOLDS — and constrained further by chain. Today: `workers/lib/wallet.bot.evm.js:21-42` loads exactly one seed phrase from `store_s0` under key `'seedPhrase'`. `proc.promo.wrk.js:306` instantiates exactly one `WalletBotEvm`. Even if we don't isolate per *campaign*, Polygon and Ethereum need separately funded addresses (gas-token differs), so **per-chain wallet is forced** even if per-campaign isn't.

### A.8 "Lightweight campaign lifecycle (DB or config-driven, no admin system)"
⚠ PARTIAL. The current `scripts/generate-codes.js` (lines 96-158) couples **create-campaign + generate-N-unique-codes** into one atomic CLI invocation. For a reusable-code campaign, that script doesn't fit (you'd want create-campaign + register-one-reusable-code, or create-campaign + no codes). Either the script needs a `--reusable-code <STR>` mode or a sibling script is required. Either way the meeting's "DB-driven" framing is true, but the existing tooling doesn't cover the new shape.

### A.9 "Clarify code-generation ownership with Andre"
✓ HOLDS — and there's an operational angle the meeting did not call out: `generate-codes.js:179` writes to `db/promo.db` **relative to the project root** — i.e. the same SQLite file the worker reads. In production this means either (a) the loader runs on the same host as the proc and the proc must be stopped or tolerant of concurrent writers, (b) someone SSHs in to add rows by SQL, or (c) we add a remote registration RPC. Worth raising with Andre alongside ownership.

### A.10 "Decide eligibility location (worker vs app-node)"
✓ HOLDS — and there's a corollary worth surfacing. Eligibility today lives on the **API worker**, not the Proc: `workers/api.promo.wrk.js:64-87` (`_checkPromoEligibility`), called from `api.promo.wrk.js:95` before delegating to the Proc. If eligibility moves up to `rumble-app-node`, the API worker becomes a near-empty proxy: `claimCode` reduces to "forward to Proc", `getCodeStatus` reduces to "look up row in SQLite". At that point the natural next question is: **do we still need a separate API worker, or fold both methods into the Proc?** That collapse would be a real simplification, not just a relocation.

Also note `api.promo.wrk.js:84` — there's a `legacyEligibilityErrorCode` flag for backward-compat error mapping. Useful precedent for how to gate the upcoming `reusable=true` behaviour.

### A.11 "Preserve backward compatibility if old campaigns may still run"
✓ HOLDS. Two paths inside the worker, gated on a flag on the campaign row, is consistent with how `legacyEligibilityErrorCode` is already used.

### A.12 "Clean up tx path inside worker (WDK + ethers fallback because of WDK gas-estimation bug)"
✓ HOLDS. The bypass is explicit and commented at `workers/lib/wallet.bot.evm.js:88-90`:
> Use `_account` (ethers HDNodeWallet) directly to bypass WDK's `quoteSendTransaction` which calls estimateGas even when gasLimit is provided.

If the WDK fix lands, the swap-back is one method. Worth raising whether anyone is tracking the WDK ticket (open question §7.6 in `SPEC.md`).

### A.13 "Replace ad-hoc transfer encoding with typed ABI builder"
✓ HOLDS. `workers/lib/erc20.js:1-15` is literal hex-string concatenation:
```js
const TRANSFER_SELECTOR = 'a9059cbb'
function encodeTransfer (to, amount) { return '0x' + TRANSFER_SELECTOR + padAddress(to) + padUint256(amount) }
```
The project already pulls in ethers (transitively via WDK and used directly at `wallet.bot.evm.js:90`), so swapping in `ethers.Interface.encodeFunctionData` is zero-new-dep. Easy win.

### A.14 "Keep SQLite"
✓ HOLDS. `workers/proc.promo.wrk.js:58-64` and `workers/api.promo.wrk.js:34-40` both use `@bitfinex/bfx-facs-db-sqlite` against `db/promo.db`. No driver in scope for change.

### A.15 "Retain rate limiting + status enum"
✓ HOLDS. Rate limit at `rumble-app-node/workers/lib/server.js:540-545` (5/10s default). Status enum `claimed|paying|paid|failed` matches `workers/lib/constants.js:3-9` and `rumble-app-node/workers/lib/schemas/promo.js:78` exactly.

### A.16 "Preserve low-balance Slack alerts"
✓ HOLDS. Already implemented at `workers/proc.promo.wrk.js:251-287` (`_ensureSufficientBalance`) with both a proactive threshold (`hotWalletLowThreshold`) and a reactive "not enough for this batch" guard. Both call `sendLowBalanceAlert`.

### A.17 "Keep current deployment model (`promoService[]`, not standard WDK topic split)"
⚠ FRAMING SHARPENED. The promo worker **already uses the Proc/API split** (`api.promo.wrk.js:19-25` requires `--proc-rpc <key>`, exactly like the WDK pattern). What's *non-standard* is not the proc/api split itself but the **discovery mechanism**:

- `rumble-app-node/workers/lib/services/promo.js:8-17` uses `Object.values(ctx.conf.promoService)` + `CRC32(userId)` modulo to pick an RPC key from a hard-coded list.
- The standard WDK pattern (per `architecture.md`) is topic-based discovery via `topicConf.capability` + topic name (e.g. `@wdk/data-shard`).

So the migration the meeting is deferring is "swap explicit RPC-key list → Hyperswarm topic discovery". Worth restating that way in the next meeting so it's clear what's actually on the table.

### A.18 "Validate local dev and docs reproducibility"
✓ HOLDS. `README.md` is 24 lines and covers only the three command invocations. There is no doc covering config schema, dedup modes, per-chain config, or how the API/Proc handshake works in production. `docs/payment-high-level-explanation.md` is about *closing out* a campaign (transferring funds back), not running one.

## B. Gaps the meeting did not surface

These are not in the meeting notes but the code makes them load-bearing.

1. **Gas-module hard-codes are the highest-risk Polygon blocker** (§A.5). Move `MAX_FEE_GWEI`, the 1.1 gwei priority fee, and possibly `gasLimit` from module constants to per-chain config before any other Polygon work.

2. **Reusable-code consumption needs a new table or a redesign** (§A.3). The atomic `UPDATE ... WHERE status='active'` row-flip in `codes.js:40-47` is unfit for many-claimants-one-code. Decide: introduce `promo_claims` (FK to a reusable code row), or stop using `promo_codes` as the claim ledger.

3. **API-worker existence is on the table if eligibility moves up** (§A.10). If `rumble-app-node` takes over the eligibility call, the API worker has barely any logic left. Folding it into the Proc is a real simplification — ask Andre.

4. **Unrelated-wallet-by-chain assumption.** `rumble-app-node/workers/lib/services/promo.js:30-37` always asks WDK for the `unrelated` wallet, then passes its full `addresses` map to the worker, which keys in by `blockchain`. For Polygon to work the unrelated wallet must already expose a `polygon` address from WDK. If WDK doesn't, the App Node side **does** need a small change — contradicting the "App Node unchanged" framing. Verify.

5. **Code-loader writes to the same SQLite file the worker uses** (§A.9). Production code-loading is not solved today. Reusable-code campaigns make this easier (one row to insert) but it still needs an explicit owner + procedure.

6. **`legacyEligibilityErrorCode` flag is a precedent worth reusing** (§A.10). The repo already gates legacy vs new error mapping by config — same pattern can gate `reusable=false` vs `reusable=true` behaviour and the API-worker-fold migration, keeping rollout reversible.

## C. Recommended additions to `SPEC.md` open questions

To roll into the existing §7 in `SPEC.md` before meeting #2:

- 7.7 — Per-chain gas config (`maxFeePerGas` cap, priority fee, gas limit): move to `chains[]` config?
- 7.8 — Does the WDK `unrelated` wallet expose a Polygon address today? If not, who owns adding it (WDK or App Node shim)?
- 7.9 — If eligibility moves to App Node, fold API worker into Proc — keep two workers or collapse?
- 7.10 — Reusable-code data shape: new `promo_claims` table FK'd to a coupon row, vs reusing `promo_codes` differently? (This is the concrete form of §5.4 once we accept that the consumption mechanism — not just the index — must change.)
