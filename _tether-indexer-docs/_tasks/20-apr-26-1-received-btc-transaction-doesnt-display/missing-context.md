# Missing context

## Slack threads

- [ ] **Slack thread**: "Analysis: https://tether-to.slack.com/archives/C0A5DFYRNBB/p1775069742706779" — **Need from Alex:** the contents of this analysis thread (channel C0A5DFYRNBB, message 1775069742706779, posted 2026-04-02). Alex linked it as his own analysis on 2026-04-02T14:27, so this is likely the key root-cause write-up. **Source:** Alex Atrash comment, 2026-04-02T14:27.

## External tickets / related work

- [x] **Related Asana ticket**: `https://app.asana.com/1/45238840754660/project/1212521145936484/task/1213680013630981` — **fetched** into `related-ticket-1213680013630981-migration-reconciliation-job/`. It's RW-1409 "[Backend] Migration Reconciliation Job", in-progress; working theory for the parent bug is a migration-time FE/BE address-set divergence. See the subfolder's `missing-context.md` for the artifacts that ticket still needs (two Slack threads, the report PR, report location, reconciliation code path, etc.).
- [ ] **Second related Asana ticket**: Alex mentioned "two other tickets" on 2026-04-09T11:15 but only named one. **Need from Alex:** the URL of the second ticket. **Source:** Alex Atrash comment, 2026-04-09T11:15.

## Attachments — content of media not yet reviewed

- [x] **Screen recording** `screen-20260406-172125-1775485270371.mp4` (2.9 MB) attached by andrey.gilyov on 2026-04-06 — **Captured**: 7 frame-screenshots extracted into `attachments/video-file-screenshots/` and analysed in `image-analysis.md`. The video reproduces the missing-tx bug on 2026-04-06 on app v2.0.3 and, critically, shows the app serving `bc1qgm7k56yqdzzn30vzzxrjnle6nkdn2wgt0m9ph2` to the user as their BTC ON-CHAIN receive address — i.e. the "mystery" address is coming from the app itself, not from somewhere external. (Minor TODO: verify the exact character sequence of the address against the video, since the share-sheet wrap in Frame 7 is ambiguous.)
- [x] **Log file** `rumble-wallet-2026-04-06.log` (2.0 MB) attached by andrey.gilyov on 2026-04-06 — **fully analysed in `log-analysis.md`**. Headline findings: the segwit receive address `bc1qgm7k56…` does not appear anywhere in the log (i.e. no backend endpoint serves it — it's from client-local state); the tx-history call `GET /api/v1/users/:userId/token-transfers?token=btc&…` is identified and returns empty; `walletSync` logs show `localWalletCount=5 vs backendWalletCount=4`, so there's a 5th local wallet the BE doesn't know about.

## Environments / systems

- [x] **Backend `token-transfers` endpoint on staging**: pinned via the client log. Exact call:
  `GET https://wallet-8s4anfsr6it9.rmbl.ws/api/v1/users/:userId/token-transfers?token=btc&walletTypes=user&walletTypes=channel&walletTypes=unrelated`
  On 2026-04-06 it returns `200 {"transfers":[]}` for `pagZrxLHnhU` with `token=btc`, but `48 transfers` with no token filter — so the server-side filter keyed off `/wallets` BTC addresses is excluding the segwit UTXO correctly *from its own perspective*. Needed code ownership is now straightforward to pull via a grep of the FE repo for that URL path; not blocking.
- [x] **Mystery receive address** `bc1qgm7k56yqdzzn30vzzxrjnle6nkdn2wgt0m9ph2` — source now identified as **client-local state, not any BE endpoint** (see `log-analysis.md`). The address is absent from every backend response in the log. The client has 5 local wallets vs 4 backend wallets; the extra local wallet is the prime suspect. Remaining question is a code-side investigation (which FE module / hook / selector feeds `[QRCodeDisplay]`), not more data gathering — no ask of Alex needed here.

## People / decisions

- [ ] Usman Khan's open question from 2026-03-19T07:29 about "why this user has only 1 wallet. Shouldn't user have 1 unrelated wallet and 1 user wallet at least?" was implicitly answered by his own 2026-03-19T12:47 comment showing two wallets — but it's worth confirming whether the initial single-wallet snapshot was a stale cache or a real state change. **Need from Alex:** was there a re-provisioning of klemensqwerty between 03-19 07:29 and 12:47 UTC, or is `/wallets` eventually-consistent?
