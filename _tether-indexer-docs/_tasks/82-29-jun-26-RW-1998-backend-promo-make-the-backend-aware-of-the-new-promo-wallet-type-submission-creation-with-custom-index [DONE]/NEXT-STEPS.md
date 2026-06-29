# Next steps for [Backend Promo] ... (RW-1998)

**Ticket:** https://app.asana.com/1/45238840754660/task/1216080319140919
**Parent (FE milestone):** RW-1991 — `_tasks/81-29-jun-26-RW-1991-separate-wallet-for-promo/`

## What we know
- This is the **backend slice** of "Separate Wallet for promo" (RW-1991), assigned to Alex.
- Goal: make the BE aware of a new `promo` wallet type, created/submitted at a custom
  derivation index (parent suggests 10,000), and store the wallet index + details in BE.
- Funds restricted to the tipping (Send Tip) flow only.
- Ticket body itself is **empty** — no spec, no comments, no attachments.

## Open design decision (FE asked, Alex to answer) — see `slack.txt`
Wallet creation today: `POST /api/v1/wallets`, `type` ∈ `'user' | 'channel' | 'unrelated'`.
FE wants the BE promo-aware and offered three approaches:
1. Metadata flag (`meta.promo = true`).
2. New `type: 'promo'` + extend BE validation.
3. Hardwired `accountIndex` (e.g. 10000).
Promocode redemption is expected to wire funds directly to this wallet on the BE side, so
the core requirement is BE being able to identify the promo wallet reliably. Leaning
option 2 (source of truth) + option 3 (derivation index); confirm against the actual
create/validation path before committing.

## Evidence captured here
- 0 images, 0 attachments, 0 user comments (only system events).
- `slack.txt` — FE backend-design request with the three options above.

## What's missing (from `missing-context.md`)
- The actual BE requirements / acceptance criteria — ticket is blank.
- BE design: which repo owns the `Promo` type, storage of index + details, the
  submission/creation API contract, custom-index derivation.
- FE design doc (requested by Eddy) and FE draft PR #1311 for the contract the BE must match.

## Before starting work
Ticket is empty, so do not start coding from it alone. Confirm the BE contract with Alex
(or read FE PR #1311 to reverse the expected shape) before touching
`wdk-app-node` / `rumble-app-node` / data-shard. The FE work is already in draft and is
"waiting for" this BE ticket, so the FE PR is the best source of the expected API shape.
