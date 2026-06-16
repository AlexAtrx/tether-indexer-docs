# Next steps for [UMA] Implement backend APIs for the UMA feature set

**Ticket:** https://app.asana.com/1/45238840754660/project/1212521145936484/task/1215700770299763

> **FINAL SPEC agreed (2026-06-16): see `final-spec.md`.** Username
> suggest/check are dropped (Rumble owns immutable usernames via
> `preferred_username`); scope is now just `POST /wallets` + `GET /wallets`
> UMA changes, sourcing the username from the token. PATCH stays only for
> non-username wallet edits.

## What we know
- RW-1920, Rumble Wallet, Priority Medium, currently in "To Triage" (Sprint 4
  was cleared on 2026-06-15, so it may be parked pending spec).
- Feature: backend APIs for the UMA (Universal Money Address) feature set.
- Two new endpoints:
  - `POST /username/suggest` → suggest a UMA username from `{ email }`, returns `{ username }`.
  - `POST /username/check` → availability check on `{ username }`, returns `{ available, reason? }`.
- Two existing endpoints to extend with UMA config:
  - `POST /wallets` → register wallet + claim username; response gains
    `uma: { domain, minSendable, maxSendable, defaultSettlementLayer }`.
  - `GET /wallets` → returns wallets including `uma{}` domain/limits.

## Discussion + verification (added 2026-06-16)
- Slack discussion captured in `comments.md`: Francesco confirms the API matches
  Tether Wallet and notes a `PATCH /wallets` exists; Alex raises the
  username-ownership / Rumble-sync question; Eddy agrees in principle.
- Code verification written in `verification.md`. Key results:
  - `GET/POST/PATCH /api/v1/wallets` already exist in Tether Wallet (wdk-app-node);
    PATCH added to the spec table as item 5.
  - The UMA-specific parts are NOT built: no `username` request field, no `uma{}`
    response, no `/username/suggest` or `/username/check`, no `defaultSettlementLayer`.
    `minSendable`/`maxSendable` exist (hardcoded) in wdk-indexer-wrk-spark; the UMA
    identifier today is `sparkIdentityPubkey@host`, not `username@domain`.
  - No username is stored anywhere in the backend yet.
  - PATCH `/wallets/:id` is the natural home for username set/reset and is the
    event that would sync to Rumble; the sync channel exists
    (rumble-data-shard-wrk `rumble.server.util.js`) but has no username route.

## Evidence captured here
- 0 images
- 0 non-image attachments
- 0 Asana comments (system stories only); Slack discussion added manually
- `verification.md` with the TW-API + PATCH verification

## What's missing (from `missing-context.md`)
- No UMA spec / design doc / acceptance criteria — only an API table.
- Unclear whether this is full UMA-protocol interop or a Rumble-internal subset.
- Username validation/availability rules undefined.
- Target repo/layer and username-storage location not specified.
- Current `/wallets` contract needed before layering in `uma{}`.

## Before starting work
This is a feature ticket with a thin spec. The verification shows the verbs
exist but all UMA-specific work is greenfield. **Blocker before coding: confirm
the username-ownership + Rumble-sync contract** (Alex's open question, agreed in
principle by Eddy but unspecced) and get the UMA design doc / acceptance
criteria + username rules. Then confirm the target repo (`wdk-app-node` TW vs
`rumble-app-node`) and where username is stored (new field on the wallet entity
vs a dedicated usernames collection in the data-shard). Once scoped, this is a
fan-out across app-node (HTTP schema + routes), ork (HRPC), data-shard (HyperDB
storage + uniqueness check), wdk-indexer-wrk-spark (`username@domain` identifier),
and rumble-data-shard-wrk (`syncUsername` webhook).
