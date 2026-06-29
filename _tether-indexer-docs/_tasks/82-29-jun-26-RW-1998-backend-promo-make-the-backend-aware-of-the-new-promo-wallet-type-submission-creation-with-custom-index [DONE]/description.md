# Description — [Backend Promo] Make the backend aware of the new 'promo' wallet type (RW-1998)

_The ticket has no description (empty `notes` / `html_notes`)._

All scope lives in the parent ticket RW-1991 "Separate Wallet for promo"
(`_tasks/81-29-jun-26-RW-1991-separate-wallet-for-promo/`). This subtask is the
backend slice of that work: making the BE aware of a new `promo` wallet type that is
submitted / created at a custom derivation index (e.g. 10,000), and storing the wallet
index and details in BE.

Scope distilled from the parent and the subtask title:
- New wallet `type` value: `Promo`, persisted in BE.
- Wallet created at a fixed/custom derivation index (parent suggests 10,000).
- BE stores the wallet index and its details.
- Funds restricted to the tipping (Send Tip) flow only; not Send / Receive / Buy / Swap / Cashout.

## Open design question from FE (Slack, 2026-06-29 — see `slack.txt`)

Today wallet creation is `POST /api/v1/wallets` with `type` restricted to
`'user' | 'channel' | 'unrelated'`. FE wants the cleanest way to make the BE
promo-aware and is asking Alex to pick the approach. Three options on the table:

1. **Metadata flag** — keep existing types, add `meta.promo = true`.
2. **New type** — introduce `type: 'promo'` and extend BE validation to accept it.
3. **Account index** — hardwire a specific `accountIndex` (e.g. 10000).

FE also assumes **promocode redemption will be wired directly to this wallet on the BE
side**, so backend awareness of which wallet is the promo wallet is the real requirement
(the three options are just how to mark/identify it).

These are not mutually exclusive: a likely answer is "new `type: 'promo'` (option 2) as
the source of truth, derived at the dedicated index (option 3)", with metadata reserved
for non-identifying detail. Decision still pending Alex's review of how the wallet-create
path and validation are structured in `wdk-app-node` / `rumble-app-node` — to be done
when this ticket is handled.
