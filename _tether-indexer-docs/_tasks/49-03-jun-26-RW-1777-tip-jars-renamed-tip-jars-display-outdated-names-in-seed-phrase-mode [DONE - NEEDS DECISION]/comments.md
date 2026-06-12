# Comments

## Ahsan Akhtar - 2026-05-26T22:04:36.847Z
**Story GID:** 1215158066640738

While working on it, I found out it's a backend issue, I have posted my findings here:
https://tether-to.slack.com/archives/C0A5DFYRNBB/p1779832928081659

cc: @Gocha Gafrindashvili @Eddy WM

## Mohamed Elsabry - 2026-05-27T11:45:24.977Z
**Story GID:** 1215170501070808

In seedphrase mode we can disable rename completely. This task can be closed

## Ahsan Akhtar - 2026-05-27T18:35:08.868Z
**Story GID:** 1215186485191075

@Mohamed Elsabry Actually the tip jar renaming happens only in rumble web when the user is logged in there, and not in the mobile app! When rename happens on rumble web, the issue on BE is that the api endpoint api/v1/seed-phrases/connect/verify used to fetch channels/tip jars in the app (in seed phrase mode) doesn't return the list with the updated names (it returns stale), that's what is needed to be fixed on BE! On FE, nothing needs to be changed for this ticket!

## Mohamed Elsabry - 2026-05-27T23:23:22.068Z
**Story GID:** 1215192469912741

That seem to be a BE issue.
@Ahsan Akhtardon't unassign task unless you pass it to the right person. cc: @Eddy WM

## Ahsan Akhtar - 2026-05-27T23:32:21.024Z
**Story GID:** 1215192601619234

@Mohamed Elsabry Alright, sure!
As, I've mentioned @Alex Atrash in the Slack thread where I've explained about this issue, so I am passing on to him! He may keep it assigned or re-assign it as per the need on BE side!

## Alex Atrash - 2026-05-29T12:11:11.856Z
**Story GID:** 1215247373918742

Confirmed a backend issue.
Asked the team:
https://tether-to.slack.com/archives/C0A5DFYRNBB/p1780056048371429?thread_ts=1779832928.081659&cid=C0A5DFYRNBB

## Alex Atrash - 2026-06-01T13:22:45.900Z
**Story GID:** 1215293132809299

PRs: https://tether-to.slack.com/archives/C0A5DFYRNBB/p1780319680289149

## Gocha Gafrindashvili - 2026-06-03T12:43:09.793Z
**Story GID:** 1215363039782757

@Alex Atrash,
The issue is still active on v2.3 (640)
Device: iPhone 14 Pro IOS 26.5

## Alex Atrash - 2026-06-03T13:16:16.326Z
**Story GID:** 1215369504414984

@Gocha Gafrindashvili the fix of this is still in dev testing.

## Gocha Gafrindashvili - 2026-06-03T13:29:57.071Z
**Story GID:** 1215367342850243

@Alex Atrash, Thanks for the clarification. I'll retest the issue once the fix is released and update the ticket accordingly.

## Alex Atrash - 2026-06-03T13:41:38.211Z
**Story GID:** 1215369543346943

@Gocha Gafrindashvili
For info, the fix is not adjusting channel names automatically.
FE needs to make channel rename call whenever it detects mismatch or the need to update.
The new endpoint is:

PATCH /api/v1/channels/:channelId/tip-jar

I just finished testing on Dev, and testing has passed. When we deploy in Staging this will be ready to be consumed by the front end.

cc @Eddy WM

## Gocha Gafrindashvili - 2026-06-08T09:34:03.095Z
**Story GID:** 1215489003628641

Since the final resolution requires FE-side integration, I’m assigning this back to @Ahsan Akhtar.
Backend changes are completed, and the new endpoint is ready to be consumed by FE:
PATCH /api/v1/channels/:channelId/tip-jar
Please support with the FE integration. We can close the ticket after the end-to-end fix is completed and verified.
cc: @Eddy WM

## Ahsan Akhtar - 2026-06-08T21:38:05.864Z
**Story GID:** 1215525617220883

@Gocha Gafrindashvili I believe this endpoint is not for mobile FE side to consume, I am discussing it here:
https://tether-to.slack.com/archives/C0A5DFYRNBB/p1780953748626589

---

## Relevant system stories

- 2026-05-21T15:08Z - Gocha Gafrindashvili moved this task from "Ready for QA" to "To Triage" in Rumble Wallet
- 2026-05-21T15:13Z - Gocha Gafrindashvili attached Tip jar names.png
- 2026-05-21T15:14Z - Gocha Gafrindashvili assigned to Patricio Vicens
- 2026-05-22T20:24Z - Eddy WM assigned to Ahsan Akhtar
- 2026-05-25T20:55Z - Ahsan Akhtar moved this task from "To Triage" to "In-Progress" in Rumble Wallet
- 2026-05-26T23:23Z - Ahsan Akhtar moved this task from "In-Progress" to "ToDo - Dev" in Rumble Wallet
- 2026-05-27T23:32Z - Ahsan Akhtar assigned to you
- 2026-05-29T12:10Z - Alex Atrash moved this task from "ToDo - Dev" to "In-Progress" in Rumble Wallet
- 2026-06-03T08:43Z - Alex Atrash completed this task
- 2026-06-03T08:43Z - Asana moved this task from "In-Progress" to "Completed" in Rumble Wallet
- 2026-06-03T12:43Z - Gocha Gafrindashvili moved this task from "Completed" to "In-Progress" in Rumble Wallet
- 2026-06-03T12:43Z - Gocha Gafrindashvili marked incomplete
- 2026-06-03T15:22Z - Alex Atrash moved this task from "In-Progress" to "Ready for QA" in Rumble Wallet
- 2026-06-08T09:34Z - Gocha Gafrindashvili assigned to Ahsan Akhtar
- 2026-06-08T11:36Z - Gocha Gafrindashvili moved this task from "Ready for QA" to "In-Progress" in Rumble Wallet
- 2026-06-08T21:38Z - Ahsan Akhtar moved this task from "In-Progress" to "To Triage" in Rumble Wallet
