# Next steps for WDK-1589 migrate setting user data on wdk base layer

**Ticket:** https://app.asana.com/1/45238840754660/project/1210540875949204/task/1216237230149454

## What we know
- Vigan (tech lead) assigned this High-priority Sprint 5 refactor after Alex's Slack
  thread showed the user-data key/value API is duplicated in `tether-wallet-*` and
  `rumble-*` while the wdk base only carries the storage layer.
- Motivation is open sourcing: the base must offer full user-data support so every
  product (TW, City, RW, generic) inherits one implementation.
- Related: WDK-1522 (batch set/get, folder 83, `[DONE]`, PRs open on the tether-wallet
  fork: app-node #169, ork #81, data-shard #141).
- Vigan believed wdk-app-node already had this; it does not. Only partial support exists
  on the base data shard.

## Evidence captured here
- 0 images, 0 non-image attachments, 0 user comments (system stories only in `comments.md`)
- Slack thread that scoped the work: `slack-context.md`
- Refactor plan: `plan.md`

## What's missing (from `missing-context.md`)
- Merge-order decision for the WDK-1522 batch PRs (merge first vs fold into this refactor)
- Whether a "City" fork carries its own user-data copy

## Status: implemented locally (2026-07-02)
All 9 repos changed, tested, and adversarially reviewed; two review findings fixed.
See `HANDLING.md` for the full record and the PR checklist (pin bumps must ship with
the fork dedup; deploy order data-shard -> ork -> app-node). Next step: /commit to
open the 3 base PRs, then close TW PRs #169/#81/#141, then fork PRs after base merges.
