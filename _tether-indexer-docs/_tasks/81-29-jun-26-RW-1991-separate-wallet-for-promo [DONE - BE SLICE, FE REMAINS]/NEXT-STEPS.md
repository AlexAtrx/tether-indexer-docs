# Next steps for Separate Wallet for promo (RW-1991)

**Ticket:** https://app.asana.com/1/45238840754660/project/1212521145936484/task/1215979674875830

## What we know
- Add a dedicated "promo" wallet for all users at a fixed derivation index (e.g. 10,000).
- Wallet index + details stored in BE; wallet carries a `Promo` type in BE.
- Funds usable only for Tipping (Send Tip flow). Disabled in Send, Receive, Buy, Swap, Cashout.
- FE must disable all buttons for unsupported functions; wallet only surfaces in the tipping flow.
- Milestone, Sprint 5, Priority High, Fix Version (FE): RW 2.6. Assigned to Aliaksei Shaltykou.

## Evidence captured here
- 0 images (no attachments on the ticket)
- 0 non-image attachments
- 4 comments in `comments.md`

## Related task folder
- Backend slice (Alex's ticket): **RW-1998** — `_tasks/82-29-jun-26-RW-1998-backend-promo-make-the-backend-aware-of-the-new-promo-wallet-type-submission-creation-with-custom-index/` (the 1 subtask; now fetched, body is empty).

## What's missing (from `missing-context.md`)
- ~~The actual BE ticket~~ — fetched as RW-1998 (see above); its body is empty though.
- FE design document Eddy requested.
- FE draft PR #1311 on rumble-wallet-app-mobile.

## Before starting work
RW-1991 as written is the FE/milestone ticket. The backend work Alex would own is the
separate "[Backend Promo]" ticket (GID 1216080319140919). Ask Alex whether to fetch and
handle that backend ticket instead of / alongside this one before touching code.
