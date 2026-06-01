# Comments

## Ahsan Akhtar — 2026-05-26T22:04:36Z
While working on it, I found out it's a backend issue, I have posted my findings here:
https://tether-to.slack.com/archives/C0A5DFYRNBB/p1779832928081659

cc: @Gocha Gafrindashvili @Eddy WM

## Mohamed Elsabry — 2026-05-27T11:45:24Z
In seedphrase mode we can disable rename completely. This task can be closed

## Ahsan Akhtar — 2026-05-27T18:35:08Z
@Mohamed Elsabry Actually the tip jar renaming happens only in rumble web when the user is logged in there, and not in the mobile app! When rename happens on rumble web, the issue on BE is that the api endpoint `api/v1/seed-phrases/connect/verify` used to fetch channels/tip jars in the app (**in seed phrase mode**) doesn't return the list with the updated names (it returns stale), that's what is needed to be fixed on BE! On FE, nothing needs to be changed for this ticket!

## Mohamed Elsabry — 2026-05-27T23:23:22Z
That seem to be a BE issue.
@Ahsan Akhtar don't unassign task unless you pass it to the right person. cc: @Eddy WM

## Ahsan Akhtar — 2026-05-27T23:32:21Z
@Mohamed Elsabry Alright, sure!
As, I've mentioned @Alex Atrash in the [Slack thread](https://tether-to.slack.com/archives/C0A5DFYRNBB/p1779832928081659) where I've explained about this issue, so I am passing on to him! He may keep it assigned or re-assign it as per the need on BE side!

---

## Relevant system stories

- 2026-05-25T20:55Z — Ahsan Akhtar moved task "To Triage" → "In-Progress"
- 2026-05-26T23:23Z — Ahsan Akhtar moved task "In-Progress" → "ToDo - Dev"
- 2026-05-27T11:45Z — Mohamed Elsabry changed Priority Medium → Low
- 2026-05-27T18:36Z — Ahsan Akhtar unassigned himself
- 2026-05-27T23:32Z — Ahsan Akhtar assigned to Alex Atrash (you)
- 2026-05-21 — originally assigned Patricio Vicens → Ahsan Akhtar (2026-05-22)
