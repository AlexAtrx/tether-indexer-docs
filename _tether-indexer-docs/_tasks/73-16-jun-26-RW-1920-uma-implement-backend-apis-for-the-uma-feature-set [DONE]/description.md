# Description

> **FINAL SPEC (2026-06-16) — see `final-spec.md`.** After confirming that Rumble
> owns usernames (assigned at registration, immutable, exposed as the OIDC
> `preferred_username` claim), the username `suggest`/`check` endpoints are
> dropped. Only the `/wallets` UMA changes remain. The original ticket table is
> kept below for history.

The ticket describes a set of backend APIs to build for the UMA feature set.
Original formatting is a pipe-delimited table; reproduced below.

## New APIs

| Method | Path | Purpose | Request | Response |
|--------|------|---------|---------|----------|
| POST | `/username/suggest` | Suggest a UMA username from email during onboarding | `{ email }` | `{ username }` |
| POST | `/username/check` | Real-time availability check (debounced 500ms while typing) | `{ username }` | `{ available, reason? }` |

## Update on existing APIs

| # | Method | Path | Purpose | Request | Response |
|---|--------|------|---------|---------|----------|
| 3 | POST | `/wallets` | Register wallet + claim username; returns the UMA config | `{ addresses{}, accountIndex, meta{}, username }` | `[{ ...wallet, uma: { domain, minSendable, maxSendable, defaultSettlementLayer } }]` |
| 4 | GET | `/wallets` | Fetch wallets incl. UMA domain/limits | — | `{ wallets: [{ ..., uma{} }] }` |
| 5 | PATCH | `/wallets/:id` | Update a wallet incl. username set/reset (added per Francesco C.); must propagate the UMA config / sync username to Rumble | `{ username?, enabled?, name?, addresses?, accountIndex?, meta? }` | `{ ...wallet, uma{} }` |

> Item 5 (PATCH `/wallets/:id`) added from the discussion. The endpoint already
> exists in Tether Wallet today (see `verification.md`) but does NOT yet accept a
> `username` field and does NOT return `uma{}`; both need to be added, and a
> username set/reset on this path is the event that must sync to Rumble.

---

### Raw notes (verbatim)

```
    POST   │ /username/suggest │ Suggest a UMA username from email during onboarding         │ { email }                                       │ { username }
    POST   │ /username/check   │ Real-time availability check (debounced 500ms while typing) │ { username }                                    │ { available, reason? }

Update on exisiting APIs

3. POST   │ /wallets          │ Register wallet + claim username; returns the UMA config    │ { addresses{}, accountIndex, meta{}, username } │ [{ ...wallet, uma: { domain, minSendable, maxSendable, defaultSettlementLayer } }]
4. GET    │ /wallets          │ Fetch wallets incl. UMA domain/limits                       │ —                                               │ { wallets: [{ ..., uma{} }] }
```
