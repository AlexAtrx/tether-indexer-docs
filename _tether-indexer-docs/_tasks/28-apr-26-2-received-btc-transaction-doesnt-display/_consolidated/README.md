# RW-1428 — Received BTC transaction doesn't display

Single-folder, self-contained workspace for everything useful on this ticket.

**Ticket:** https://app.asana.com/1/45238840754660/project/1212521145936484/task/1213704628745111
**Last refreshed from Asana:** 2026-04-28

## Files in this folder

Read in numeric order — each file builds on the previous.

| File | What it contains |
|---|---|
| `01-summary.md` | One-page status, headline findings, current ball-in-court |
| `02-evidence.md` | All observable data: tx, addresses, log calls, /wallets payloads, video frames, screenshots |
| `03-investigation.md` | Combined analysis: log dissection, image/video walk-through, WDK-derivation falsification of Eddy's theory |
| `04-related-context.md` | RW-1409 (Migration Reconciliation Job) summary and how it ties in |
| `05-open-questions.md` | Still-missing context and questions to ask |
| `evidence/` | All referenced files: ticket screenshots, key video frames, FE log, screen recording |
| `tasks/` | Actionable next-step tasks (read after the numbered files) |

## Outside this folder (in the parent task directory)

These sit alongside `_consolidated/` as supporting reference, not part of the curated reading order. Consult only if you want ground-truth source material:

| Path | What it contains |
|---|---|
| `../_raw/task.json` | Raw Asana API response for this ticket (metadata, custom fields, html_notes) |
| `../_raw/stories.json` | Raw Asana stories — every comment + system event, authoritative source for the timeline in `02-evidence.md` |
| `../_raw/attachments.json` | Raw Asana attachments listing |
| `../related-ticket-1213680013630981-migration-reconciliation-job/` | Full task folder for RW-1409 (the linked Migration Reconciliation Job ticket) — its own `_raw/`, comments, description, NEXT-STEPS, and a `slack-thread-pr-review.md`. Use this if `04-related-context.md` is too thin and you need RW-1409's primary data. |

## Quick orient

- **Bug:** User received 0.00021337 BTC; balance shows on the BTC screen, but the transaction list is empty.
- **Where the bug lives:** FE serves a segwit `bc1qgm7k56…` address as the user's BTC ON-CHAIN receive address, but the backend's `/wallets` response for that user contains *taproot* `bc1p…` addresses only. The server-side `token-transfers?token=btc` filter is keyed off `/wallets`, so funds received on the segwit address yield zero transfers.
- **Smoking gun in the log:** `walletSync` reports `localWalletCount=5, backendWalletCount=4`. The 5th local wallet (the one the segwit address lives on) is the bug.
- **Eddy's "very old WDK derivation" theory is falsified** — `tetherto/wdk-wallet-btc` only ever supported bip44 + bip84 (segwit `bc1q…`), never bip86/taproot. Verified across all branches and all commits since 2025-05-01.
- **Status:** In-Progress · Priority High · Severity Critical · Sprint 1 · Fix Version (FE) RW 2.0.3 · Assignee Alex.
- **Ball is in your court** — last move (2026-04-20) was Eddy's deflection; reply with the falsified-theory rebuttal (draft in `tasks/01-reply-to-eddy-falsify-theory.md`).
