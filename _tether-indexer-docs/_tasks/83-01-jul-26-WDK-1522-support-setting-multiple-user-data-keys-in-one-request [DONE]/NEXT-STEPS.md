# Next steps for WDK-1522 — batch user-data set

**Ticket:** https://app.asana.com/1/45238840754660/project/1210540875949204/task/1215365454673850

## What we know
- Feature request (Open Source / Generic Support), High priority, Sprint 5. Assigned to Alex, now in DEV IN PROGRESS.
- Today's user-data key/value API is single-key only: POST /api/v1/user-data { key, value } and GET /api/v1/user-data ?key -> { value }, each a separate shard RPC round-trip.
- Goal: let a client set (and get) several keys in one request — one batch get and one batch post. No multi-delete needed.
- Preferred approach (per ticket): extend POST /api/v1/user-data to accept a batch of key/value entries while keeping single-key backward compatibility, rather than adding a brand-new endpoint.
- Must enforce per-key validation (keyMaxLength, valueMaxSize) AND the maxKeysPerUser limit across the whole batch.
- Wire it through service.ork to a batched shard RPC.
- Update swagger schema/docs and add tests.

## Files named in the ticket
- tether-wallet-app-node/workers/lib/server.js — "User data" routes ~L758-854 (HTTP layer / schema validation)
- tether-wallet-data-shard-wrk/workers/api.shard.data.wrk.js — setUserData / getUserData / deleteUserData ~L208-231 (data-shard RPC)
- tether-wallet-data-shard-wrk lib/utils/userDataKeys.util.js — keyMaxLength, valueMaxSize, maxKeysPerUser, keyPrefix

## Evidence captured here
- 0 images
- 0 non-image attachments
- 0 user comments (system timeline only)

## Before starting work
Self-contained ticket. When handling: run the scope-feature gate first — this is
WDK base (tether-wallet-*), not Rumble, and the ticket is labelled Open
Source / Generic Support, so the change belongs in the shared base and must stay
generic. Confirm the batch-vs-new-endpoint decision (ticket leans extend-existing
with single-key backward compat) and how the batched shard RPC should behave on
partial failure (all-or-nothing vs per-key) before implementing.

## Follow-up ticket (added 2026-07-02)

The duplication found during this work spawned **WDK-1589 "Migrate setting user data on
wdk base layer"** (GID 1216237230149454), fetched at
`_tasks/84-02-jul-26-WDK-1589-migrate-setting-user-data-on-wdk-base-layer/`.
That refactor moves the user-data API from the tether-wallet/rumble forks into the wdk
base; the batch PRs from this ticket (app-node #169, ork #81, data-shard #141) are part
of its merge-order decision.
