# Missing context

Most of the externally-referenced data was retrievable via `gh api`. Updated
state below.

## Resolved during fetch

- Dependabot alerts #3 and #7 — pulled via `gh api`, full content captured in
  `dependabot-alerts.md` and `_raw/dependabot-alert-{3,7}.json`. **Both alerts
  are already in `state: fixed`** as of 2026-04-26. The ticket may already be
  effectively complete; needs verification.

## Still missing / needs Alex

- [ ] **Why the ticket is still open if both alerts are fixed.** Either (a) the
  fix was done but the ticket was never closed (likely — last modified
  2026-04-30 without mention of the fix), or (b) the fix was done in a branch
  that hasn't merged. **Need from Alex:** confirm which, and either close the
  ticket or point at the merge commit/branch so we can verify.
- [ ] **External tickets:** "Rumble - Update Fastify plug ins" — Asana task
  `1213226894059885` is listed as a hard prerequisite ("Please do fastify
  upgrade first"). **Need from Alex:** status of that ticket. If it's done, the
  ordering constraint is moot; if not, this ticket should stay blocked.
  **Source:** description.
- [ ] **Scope / follow-ups:** description asks for follow-up cards: "look at
  npm audit and try to address all critical and high dependencies you see in
  the rumble and dependent packages. Please create another (or many other)
  cards to track this". **Need from Alex:** which repos count as "rumble and
  dependent packages" — at minimum the Rumble app-node, ork, shard, indexers
  (TRON, TON, ETH, BTC, EVM, …), wallet libs — and whether to file one card
  per repo or one bundle. **Source:** description.
- [ ] **People / decisions:** "We discuss it. I think the reason was that Tron
  is to be used in WL later?" — Alex's reply to Mohamed Elsabry's question
  about why a Tron ticket is filed under Rumble. **Need from Alex:** confirm
  whether Tron is in the Rumble Wallet release scope — affects whether the
  remaining open alert (`elliptic`, low) is worth fixing here vs. punting.
  **Source:** Alex Atrash, 2026-04-28.
- [ ] **Open alert with no upstream fix:** alert #1 (`elliptic <= 6.6.1`,
  severity low, no `first_patched_version`). **Need from Alex:** decision —
  dismiss with risk note, accept, or pin to a fork. **Source:**
  `_raw/dependabot-alerts-all.json`.
