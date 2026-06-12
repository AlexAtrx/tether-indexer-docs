# Next steps for RW-1760 — full balance loads in ~1 min, climbs progressively

**Ticket:** https://app.asana.com/1/45238840754660/project/1212521145936484/task/1214949587112861

## What we know
- On cold start the Home/Balance total climbs in stages over ~1 min instead of
  showing one final number. iPhone 14 Pro, iOS 26.4.2, app v2.2.0 (596).
- Root cause is **client-side**, in `rumble-wallet-app-mobile`: on `READY`,
  `RumbleBalanceProbes` mounts one probe per `accountIndex`, each fetching all
  networks/tokens; `useAggregatedBalances` merges as each probe settles, so the
  total visibly climbs. Worse on heavy accounts (many wallets = many probes).
- Alex and anton both classed it as **not an indexer/backend bug**. Alex flagged a
  secondary client bug: pull-to-refresh invalidates `wallet.identifier` keys while
  probes cache under `activeWalletId`, so refresh misses the queries Home reads.
- anton's repro is narrow: only on the **second login to Account A** after
  switching A → B → A, ~6/10 of the time, only on large-wallet accounts.
- The **only backend thread**: George suggested using an existing BE endpoint that
  returns total balance per token/wallet for the fresh-install case; anton says
  that endpoint returns an **incorrect** total that doesn't match actual balance.
- Status: moved back to "To Triage" on 2026-06-05; mobile fix owned by
  anton + Aliaksei.

## Evidence captured here
- 0 still images
- 1 non-image attachment (the ~1 min screen recording) under `attachments/`
- 16 comments + key system events in `comments.md`

## What's missing (from `missing-context.md`)
- The mobile repo is not cloned here; all the cited hooks live in
  `tetherto/rumble-wallet-app-mobile` @ `885d6a6`.
- Which BE endpoint George means, and confirmation that the "wrong total balance"
  is the backend slice Alex wants verified/fixed.
- Why this ticket is in Alex's fetch queue given the fix is assigned to the mobile
  team.

## Before starting work
This is primarily a **mobile / React Query** bug. The only plausible backend task
is verifying the total-balance endpoint anton says returns a wrong number (test
wallet seed is in `comments.md` / `missing-context.md`). **Ask Alex which slice he
owns here before touching code** — confirm it's the BE total-balance endpoint and
not the mobile probe orchestration.
