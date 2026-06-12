# Next steps for [Push] Notes on Transfer push notifications

**Ticket:** https://app.asana.com/1/45238840754660/project/1210591027686188/task/1211923806576795

## What we know
- Environment: iPhone 16, iOS 18.6.1 Steps to Reproduce: Create two wallets Log in to the wallet 1 Log in to the wallet 2 Send 3 USDT from wallet 1 to wallet 2 Check push notificatio...
- Latest comment from Francesco Canessa asks: https://app.asana.com/0/1211860479278757/1211860479278757 can you see if this is still valid? low prio probably
- The latest link is an `@Alex Atrash` mention/user-list URL, not a separate task. The real duplicate is Asana task `1211920420543997`, `[Receive] Unclear message while receiving funding`.
- Current `rumble-data-shard-wrk` source still has the old transfer-copy wording: `initiated to your wallet` and `completed into your wallet.` Amount formatting has likely been fixed by `formatAmount`.

## Evidence captured here
- 1 images analysed in `image-analysis.md`
- 0 non-image attachments under `attachments/`
- 6 comments in `comments.md`

## What's missing (from `missing-context.md`)
- nothing flagged

## Before starting work
If Alex re-assigns this ticket for analysis or fix, ask for the missing items above first before digging into the codebase. If nothing is missing, jump to investigation.
