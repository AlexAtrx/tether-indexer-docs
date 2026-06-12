# Next steps for WDK-1516 seed.recovery blockchains config shape change

**Ticket:** https://app.asana.com/1/45238840754660/project/1210540875949204/task/1215220240169119

## What we know
- `rumble-app-node` `workers/lib/services/seed.recovery.js:45` does
  `ctx.conf.blockchains?.includes(chain)`, which assumes `blockchains` is a flat
  array.
- The blockchains config shape reportedly changed to an object keyed by chain
  name (cited: `wdk-app-node/config/common.json.example#L28`), so `.includes()`
  is undefined on the object and the check breaks.
- Proposed fix: use `chain in ctx.conf.blockchains` or
  `Object.keys(ctx.conf.blockchains).includes(chain)`, plus audit other sites
  that treat `blockchains` as an array.
- Ticket is open, Sprint 3, assigned to Alex, no priority set, not blocked.

## Evidence captured here
- 0 images analysed
- 0 non-image attachments
- 0 comments (problem statement is entirely in `description.md`)

## What's missing (from `missing-context.md`)
- The pasted "prod error" stack trace is a `promo.js claimCode` "RPC client
  closed" error, NOT a seed.recovery / `.includes()` failure — likely copied
  from a different incident. Confirm the real evidence before treating this as
  a reproduced prod break.
- Grafana panel contents (link requires access).
- Exact current `blockchains` config shape (pull via read-remote-repo when
  handling).

## Before starting work
The root cause is stated precisely enough to verify by code reading. Before
calling it a confirmed prod bug, confirm with Alex whether the seed.recovery
`.includes()` break was actually observed in prod (the pasted log does not show
it). Then verify line 45 in the repo, confirm the config shape change, grep for
other `blockchains` array-style usages, and make the minimal fix with a unit
test. No Slack/external context needed to start.
