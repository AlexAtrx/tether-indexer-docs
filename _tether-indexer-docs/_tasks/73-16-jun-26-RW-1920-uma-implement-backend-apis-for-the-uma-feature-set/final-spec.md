# RW-1920 — Final spec (as of 2026-06-16)

## Decision that drives this spec

Rumble is the decision maker for usernames. Per
https://rumble.support/en/help/usernames-requirements and confirmed in the
Rumble auth flow:

- Usernames are **created at registration**, are **unique**, and are
  **immutable** ("can you change it? Not at this time").
- Rumble exposes the username as the OIDC `preferred_username` claim in the
  id_token it issues (`iss: https://auth.rumble.com`).
- We **adopt Rumble's username rules verbatim** and do not apply Tether
  Wallet's stricter UMA format rules on the Rumble path.

Because the username already exists, is immutable, and is handed to us in the
token, there is **nothing to suggest, check, set, reset, or sync**. Rumble
builds no username API.

## Final endpoint set for RW-1920

| # | Endpoint | Status | Notes |
|---|----------|--------|-------|
| 1 | `POST /username/suggest` | **DROPPED** | No onboarding suggestion; the user cannot pick a username. |
| 2 | `POST /username/check` | **DROPPED** | Nothing to check; the user cannot type/choose a username. |
| 3 | `POST /wallets` | **KEEP (modified)** | Registers the wallet and returns the UMA config. `username` is no longer claimed from client input; it is sourced from the token's `preferred_username` (the `username` field is omitted, or just echoes the Rumble value). |
| 4 | `GET /wallets` | **KEEP** | Returns `uma{}` (domain/limits) per wallet, unchanged from the ticket. |
| 5 | `PATCH /wallets/:id` | **KEEP for other fields; username angle DROPPED** | Still used for non-username wallet edits (addresses/meta). No username set/reset, because usernames are immutable. |

**Net scope:** real UMA work is **#3 and #4** (port the TW UMA surface to the
Rumble side, sourcing the username from `preferred_username`), plus PATCH only
for non-username wallet fields. #1, #2, and the username part of #5 fall away.

## Still to confirm with Rumble

- `preferred_username` is always present in the token for wallet users and stays
  stable for the life of the account.

## Reference

- TW already implements the full UMA surface (suggest/check/lnurlp-by-username/
  uma{}); see `verification.md` section 0 and `tw-reference/`. We are porting the
  `/wallets` + lnurlp-by-username parts to Rumble, minus the username-management
  endpoints that Rumble's model makes unnecessary.
