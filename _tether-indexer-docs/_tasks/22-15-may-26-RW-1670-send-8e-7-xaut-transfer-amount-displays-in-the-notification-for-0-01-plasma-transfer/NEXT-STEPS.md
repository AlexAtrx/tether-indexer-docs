# Next steps for RW-1670 — `Token Transfer Initiated` push shows scientific-notation amount for sub-cent transfers

**Ticket:** https://app.asana.com/1/45238840754660/project/1212521145936484/task/1214269983129054

## What we know

- Push notification body for "Token Transfer Initiated" renders sub-1e-6 token amounts as JS scientific notation (`8e-7 XAUT`, `1.3e-7 BTC`) instead of a user-friendly string.
- In-app `Transaction Submitted` sheet formats the same amount correctly as `< $0.01` — so the bug is in the push-body builder, not the underlying amount.
- Reproduces on iOS (XAUT / Plasma, prod build v2.0.4 (199)) **and** Android (BTC / Spark, dev v2.2 (668)) — chain-agnostic.
- Sister `Transfer Successful` push was OK on the same Android run, but only because the confirmed amount (`0.00000013 BTC` = `1.3e-7`) happened to render with enough leading zeros to dodge `Number.toString()` exponent form. The success path likely has the same latent bug for amounts < `1e-6`.
- Anton Kurdo took a first pass Apr 27–28 (moved through In Review → Ready for QA). QA (Gocha) bounced it back May 13 because BTC Spark still reproduces. Now reassigned to Alex.

## Evidence captured here

- 2 images analysed in `image-analysis.md` (iOS XAUT/Plasma push, Android BTC/Spark push)
- 0 non-image attachments under `attachments/`
- 11 stories captured in `comments.md` (1 real comment from QA + 10 system events that establish the workflow history)

## Fix location (decided)

**Backend.** Ticket was reassigned to Alex (a backend dev) on 2026-05-15 — per team convention that means the fix should land in the rumble notifications pipeline, not on mobile. Anton's prior fix was mobile-side and only patched one of several send-flow containers, which is exactly why QA caught it again on a different chain. Doing this server-side is the only complete fix because every send-flow container (EVM, Spark, future TON/Tron, web) would otherwise need to be patched independently.

## Prior fix (mobile, EVM-only) — what to learn from it

- PR: [tetherto/rumble-wallet-app-mobile#1101](https://github.com/tetherto/rumble-wallet-app-mobile/pull/1101) by Anton, merged 2026-04-27.
- Diff: in `app/sections/wallet/components/send-flow/SendConfirmationContainer.tsx`, replace `adjustedTokenAmount.toString()` with `formatCryptoAmount(adjustedTokenAmount, tokenDecimals)` in 3 spots — one is the `amountToSend` field POSTed to `rumble-app-node` `/api/v1/notifications`, the other two are the confirmation-screen `usdAmount` / `tokenAmount` display.
- Why it missed BTC Spark: Spark has its own send-flow container (Lightning UX), separate from the generic/EVM `SendConfirmationContainer.tsx`. That container still does `Number#toString()`, sends `1.3e-7` over the wire, and the backend bakes it straight into the push body.
- Implication for this fix: **the backend currently trusts whatever amount string the client sends and uses it verbatim in the push body.** That's the seam to close.

## What's missing (from `missing-context.md`)

- The canonical formatting rule Eddy WM was supposed to advise on (`< $0.01`? `< 0.000001 XAUT`? full-precision token amount?). This is the only blocking question left.

## Before starting work

Ask Eddy WM for the display rule (USD-less-than / token-less-than / full-precision token amount).

Then in code:

1. In `rumble-app-node`, find the `/api/v1/notifications` route handler — the fastify schema for the request body and the code that composes the "Token Transfer Initiated" push body string.
2. Stop trusting the client-provided amount string. Either:
   - Accept the amount as a numeric/BigNumber field (or a string + decimals) and format server-side with a deterministic formatter that never falls into scientific notation, **or**
   - If the schema must keep accepting a string, validate that it isn't in exponent form (`/[eE]/`) at the schema layer and reformat in the handler.
3. Apply the same formatter to the matching `Transfer Successful` push body — it has the latent bug (image #2 only dodged it because `0.00000013` happens to render without an exponent for that precision).
4. Don't revert Anton's mobile-side PR #1101 — it's still useful for the EVM confirmation-screen display, even if the backend now also formats. Just leave it.

## Self-test

Before opening the PR, reproduce both legs:

- POST a `Token Transfer Initiated` notification with `amount` formatted as `8e-7` and as `1.3e-7` and confirm the push body comes out as the agreed display string (not the raw exponent).
- Same for `Transfer Successful` with the same two values.
