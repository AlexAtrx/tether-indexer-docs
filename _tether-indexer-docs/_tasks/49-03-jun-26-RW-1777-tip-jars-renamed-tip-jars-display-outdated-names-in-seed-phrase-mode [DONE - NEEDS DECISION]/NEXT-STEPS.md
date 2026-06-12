# Next steps for RW-1777 - Renamed Tip Jars show outdated names

**Ticket:** https://app.asana.com/1/45238840754660/project/1212521145936484/task/1215023267903766

## Current status
- Local Asana data was refetched on 2026-06-09; the live task is open, assigned to Ahsan Akhtar, and currently in To Triage.
- Backend work is marked done in the comments, but the ticket is not closed because final resolution now depends on FE-side integration.
- The key update is Alex's 2026-06-03 comment, story `1215369543346943`: the backend fix does not automatically adjust channel names. FE should call `PATCH /api/v1/channels/:channelId/tip-jar` when it detects a mismatch or needs to update a tip-jar name.
- Ahsan's latest 2026-06-08 comment questions whether that endpoint is intended for mobile FE consumption and links another Slack discussion. That is the current open decision.

## Evidence captured here
- 13 comments in `comments.md`
- 1 image attachment under `images/`, already covered by `image-analysis.md`
- 1 non-image attachment under `attachments/` (Renamed tip jars appears with outdated naming.MP4)
- Raw refreshed Asana payloads in `_raw/task.json`, `_raw/stories.json`, and `_raw/attachments.json`

## What's missing
- The June 8 Slack discussion outcome on whether mobile FE should consume `PATCH /api/v1/channels/:channelId/tip-jar`.
- Concrete PR URLs or merged branches behind Alex's June 1 "PRs" Slack pointer.

## Before starting work
Resolve the endpoint ownership/consumer question from Ahsan's June 8 Slack thread first. If mobile FE should not call this endpoint directly, the next backend task is to identify the intended API path for seed-phrase mode to refresh stale tip-jar names.
