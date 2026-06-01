# Next steps for RW-1777 — Renamed Tip Jars show outdated names (Seed Phrase mode)

**Ticket:** https://app.asana.com/1/45238840754660/project/1212521145936484/task/1215023267903766

## What we know
- In seed-phrase mode, the "Choose Balance View" tip-jar list shows old/default tip-jar names instead of renamed values (e.g. `13Channell` instead of `13ChannellRenamed`).
- Tip-jar renaming only happens on rumble web (logged-in user), not in the mobile app.
- Ahsan (FE) investigated and concluded it's a **backend** bug: the `api/v1/seed-phrases/connect/verify` endpoint used to fetch channels/tip jars in seed-phrase mode returns a **stale** list that doesn't include the updated names. FE needs no change.
- Originally Priority Medium, lowered to Low. Reassigned through FE (Patricio → Ahsan) and now to **Alex** for the BE fix.
- Repro device: Pixel 7 (Android 16), app v2.2.0 (686).

## Evidence captured here
- 1 image analysed in `image-analysis.md` (side-by-side proving `13ChannellRenamed` vs stale `13Channell`)
- Ahsan's full Slack root-cause thread captured in `slack-thread.md` (incl. the stale `seed-phrases/connect/verify` JSON payload and Alex's two proposed BE fixes)
- 0 non-image attachments
- 5 comments in `comments.md`

## Root cause (from `slack-thread.md`)
- `/api/v1/seed-phrases/connect/verify` returns wallet rows from stored WDK wallet data **including the stored name**, and never merges the current channel metadata from Rumble — so a channel renamed on Rumble web still returns the old name in seed-phrase mode.
- Username/password flow is correct because it uses `/wallet/v1/channels`, which returns fresh names.
- Proposed BE fix (Alex): (1) keep wallet tip-jar names in sync when Rumble channel names change, or (2) merge current channel names into the seed-phrase verify response before returning wallets. Awaiting opinion from Francesco C. / Eddy WM.

## What's still missing (from `missing-context.md`)
- Confirmation of which service owns `api/v1/seed-phrases/connect/verify` and where tip-jar names are sourced/cached
- Where canonical renames are persisted (rumble-server DB vs wallet/indexer)

## Before starting work
The analysis is now in-folder. Trace `seed-phrases/connect/verify` in `rumble-app-node`: find where it builds the channel/tip-jar list and why it serves a stale name (cache vs missing join to the renamed value), then decide between the two fix options above. Heads-up: a test-account password + seed phrase were in the Slack thread (redacted from `slack-thread.md`) — they should be scrubbed from Slack.
