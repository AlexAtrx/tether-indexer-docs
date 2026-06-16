# Missing context

This ticket is a thin spec with no comments, no attachments, and no links. The
description is just an API table. Several things a future session would need are
not present:

- [ ] **Spec / design doc**: The ticket lists endpoint shapes but no UMA design
  doc, protocol reference, or acceptance criteria. — **Need from Alex:** is there
  a UMA spec / Notion / Figma / parent epic that defines `domain`,
  `minSendable`, `maxSendable`, `defaultSettlementLayer` semantics and the
  username rules? **Source:** description.

- [ ] **UMA protocol scope**: "UMA" (Universal Money Address) implies LNURL-style
  lightning address interop. — **Need from Alex:** are we implementing the full
  UMA spec (uma.me) or just the Rumble-internal username + wallet metadata
  subset described here? **Source:** title + description.

- [ ] **Username rules**: `/username/suggest` and `/username/check` need rules
  (charset, length, reserved words, normalization, collision strategy). — **Need
  from Alex:** the validation/availability rules and where the username registry
  lives. **Source:** description.

- [ ] **Target repo / layer**: These are HTTP endpoints, so they land on
  `rumble-app-node` (or `wdk-app-node`), but the ticket does not say which, nor
  which ork/shard handlers back them. — **Need from Alex:** confirm the repo set
  and whether username storage is a new HyperDB collection on the data-shard.
  **Source:** inferred from API shapes.

- [ ] **Existing `/wallets` contract**: Items 3 and 4 modify existing endpoints.
  — **Need from Alex / codebase:** current `POST /wallets` and `GET /wallets`
  request/response so the `uma{}` additions are layered without breaking
  callers. **Source:** description ("Update on existing APIs").

- [ ] **Sprint status**: Sprint was cleared (removed from Sprint 4) and the task
  sits in "To Triage". — **Need from Alex:** is this actually scheduled to start,
  or parked pending triage/spec? **Source:** stories (2026-06-15).

- [ ] **Username ownership + Rumble sync contract (BLOCKER)**: Alex flagged that
  TW handles usernames while Rumble generates them, and asked whether the backend
  must call Rumble APIs to sync on set/reset. Eddy agreed in principle but it is
  unconfirmed and unspecced. The code has no username storage at all today (see
  `verification.md`). **Confirmed via the API specs: Rumble's SSO owns a username
  (`preferred_username`, issued in the OIDC id_token from `auth.rumble.com`); the
  wallet backend proxies all auth to Rumble but does not read that claim today.**
  So the open decision is whether the UMA username = Rumble's `preferred_username`
  (→ must call Rumble to suggest/check/set, and Rumble exposes no such endpoint
  yet) or a separate TW-owned handle (→ only needs a sync webhook back to Rumble).
  — **Need from Alex / Eddy / Rumble:** confirm which model, and the Rumble-side
  endpoint contract, before any implementation. **Source:** Slack discussion
  (Alex 1:56 PM, Eddy 1:59 PM) + `rumble-docs` API specs.
