# Next steps for [Tip Jar] Activation fails after app is restored from background - Prod

**Ticket:** https://app.asana.com/1/45238840754660/project/1212521145936484/task/1215639503643719

## What we know
- After bringing the app back from background, Tip Jar activation fails and returns an error.
- The issue persists during the current app session and resolves only after restarting the app.
- The task says the affected build/device is v2.4 (207), iPhone 14 Pro, iOS 27, Prod.
- Captured evidence includes one screenshot and one screen recording attachment.

## Evidence captured here
- 1 images analysed in `image-analysis.md`
- 1 non-image attachments under `attachments/`
- 4 comments in `comments.md`
- `staging-log-investigation-2026-06-15.md` records the June 15 staging log scan: no failed backend Tip Jar mutation reached `walletstg1` in the tester's retest window.
- `sentry-investigation-2026-06-15.md` records the Sentry scan: backend `staging` has no events, but matching mobile `production` events show both Tip Jar PATCHs returned HTTP 500 `[HRPC_ERR]=RPC client closed`.

## Linked tickets
- RW-1832 is linked in `linked-tickets.md`; read it before debugging because it contains the prior Tip Jar first-toggle investigation and HRPC client closed evidence.

## What's missing (from `missing-context.md`)
- 3 item(s) flagged in `missing-context.md`

## Before starting work
Use the Sentry evidence to request/check production backend logs for `wallet-9p1aan4nff.rmbl.ws` around `2026-06-15T08:13:52Z`-`08:13:58Z`, especially `POST /api/v1/device-ids` and the two `PATCH /api/v1/wallets/:id` requests listed in `sentry-investigation-2026-06-15.md`.
