# Task 03 — Propose a separate FE-guard ticket

**Priority:** medium — worth doing regardless of how RW-1428 itself resolves.

**Why:** Alex's Slack fallback is "FE only displays addresses that are registered with the backend". That's the cleanest way to prevent repeat reports while reconciliation catches up. It's *not* a root-cause fix — it would close RW-1428 symptomatically — so it's worth proposing as a separate small FE ticket rather than bundling it here.

## Proposed ticket shape

- **Title:** "[FE - Wallet] Receive flow: only render BE-registered BTC addresses"
- **Stack:** FE
- **Type:** Bug *(or Task — borderline; "Bug" if you want it scoped to fixing the symptom of RW-1428, "Task" if you want it as a hardening item)*
- **Priority:** Medium
- **Description bullets:**
  - The Receive flow currently sources the BTC ON-CHAIN address from client-local state (`walletSync` + related modules), not from the BE `/wallets` response.
  - When the local store contains a wallet the BE doesn't know about (observed: `localWalletCount=5` vs `backendWalletCount=4` for `pagZrxLHnhU`), the user is shown an address the BE will never index transactions for. Funds sent to it appear as a balance but never as a transaction (RW-1428).
  - **Acceptance:** the Receive flow's `[QRCodeDisplay]` only renders BTC addresses present in the latest `/api/v1/wallets` response. If no BE-registered BTC address exists for the active wallet, surface a clear "wallet not yet provisioned" state rather than a stale local address.
  - **Out of scope:** root-cause fix for the FE/BE address divergence (tracked in RW-1409 + the BE-derivation investigation under RW-1428).
- **Link to:** RW-1428 (this ticket) and RW-1409 (reconciliation job).

## Before filing

- Confirm with Alex that this is the right scope (he floated it in Slack but it's not yet an Asana ticket).
- Decide whether to file under Rumble Wallet V3 or a different sprint; default to Rumble Wallet V3 to match the current bug class.

## When done

- Add the new ticket URL to `_consolidated/01-summary.md` cross-references and `_consolidated/04-related-context.md`.
- Mark this task complete here.
