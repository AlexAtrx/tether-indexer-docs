# Missing context

- [ ] **Decisions:** "please advise here @Eddy WM" — the description punts the *expected* string to Eddy WM. We need the canonical formatting rule he agreed to: is sub-cent rendered as `< $0.01`? as `< 0.000001 XAUT`? as the literal token amount with N decimals? **Need from Alex:** the answer Eddy gave (or to ping Eddy/anton.kurdo). **Source:** description.

- [ ] **Backend code path:** "Token Transfer Initiated" pushes are sent from the rumble notifications pipeline. Per Anton's PR description, the mobile client POSTs the pre-formatted amount string to `rumble-app-node`'s `/api/v1/notifications` endpoint, and the backend uses that string verbatim in the push body. Need to `Grep` `rumble-app-node` for the `/api/v1/notifications` route handler and confirm where the body string is composed (and whether there's any server-side formatting at all today). **Source:** inferred from PR #1101 body + architecture.

**Resolved:**

- ~~Anton's prior PR — what was tried, why BTC Spark slipped through~~ — Found and analysed: [tetherto/rumble-wallet-app-mobile#1101](https://github.com/tetherto/rumble-wallet-app-mobile/pull/1101) "fix(send): format token amounts for API and confirmation UI" (merged 2026-04-27, branch `fix/send-notification-amount-scientific-notation`, +4/-3 in `app/sections/wallet/components/send-flow/SendConfirmationContainer.tsx`). Anton replaced `adjustedTokenAmount.toString()` with `formatCryptoAmount(adjustedTokenAmount, tokenDecimals)` in three spots (the value POSTed to `/api/v1/notifications` plus `usdAmount`/`tokenAmount` for the confirmation screen). The fix is **mobile-only** and **EVM-only**: only the generic/EVM `SendConfirmationContainer.tsx` was touched. **BTC/Spark uses a different send-flow component** (Spark UX is Lightning-style and has its own container), so it still POSTs `Number#toString()` of a sub-microtoken amount → backend bakes `1.3e-7` straight into the push body. This is exactly what QA caught on 2026-05-13.

- [ ] **Environments / systems:** description gives a real prod (internal testing) account (`masharumble`) and seed phrase. Reproduction on Pixel 7 was on dev (build 668). **Need from Alex:** which env we should reproduce in — and whether the seed in the description is still funded on Plasma `< 0.1 XAUT`. **Source:** description + comment 2026-05-13.

**Resolved:**

- ~~Fix Version (BE) is empty / FE vs BE ownership~~ — Alex confirmed (2026-05-15): ticket is assigned to him as a backend dev, so the team intends the fix to land in the backend (rumble notifications pipeline). Fix Version (BE) being empty is just unset metadata, not a signal.
