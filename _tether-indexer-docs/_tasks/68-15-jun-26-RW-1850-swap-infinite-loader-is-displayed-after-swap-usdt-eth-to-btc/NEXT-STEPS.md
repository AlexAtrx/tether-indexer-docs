# Next steps for RW-1850

**Ticket:** https://app.asana.com/1/45238840754660/project/1212521145936484/task/1215363295179921

## What we know
- Device/environment: iPhone 16 on iOS 26.5, staging build 2.3.0 (638).
- Repro path: swap from USDT ETH to BTC on-chain with an amount over $10, then open Transaction history and filter Type = Swapped.
- Actual result: the transaction history view shows an infinite loader and the description says there is an error in the attached log.
- Expected result text says: "No errors and an infinite loader should be"; confirm whether that meant the loader should not appear before implementing.

## Evidence captured here
- 0 images analysed in `image-analysis.md`
- 2 non-image attachments under `attachments/`: screen-20260603-142114-1780485643980.mp4, rumble-wallet-2026-06-03.log
- 0 comments in `comments.md`

## What's missing (from `missing-context.md`)
- nothing flagged

## Before starting work
If Alex re-assigns this ticket for analysis or fix, ask for the missing items above first before digging into the codebase. If nothing is missing, jump to investigation.
