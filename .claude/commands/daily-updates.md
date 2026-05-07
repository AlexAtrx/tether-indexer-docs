---
description: Refresh Tether TODOs from Asana, then write a stand-up "Daily Update" picking top-priority tickets in the current sprint. Archives each run to _tether-indexer-docs/_daily-updates/YYYY-MM-DD.md and prints it for copy-paste.
argument-hint: [sprint-number] (optional; if omitted, you will be asked)
---

# /daily-updates

Generate Alex's morning stand-up "Daily Update" for the Tether Indexer / Rumble Wallet workspace. Two phases: refresh the TODO file from Asana, then distil it into the stand-up format below.

This command is meant to be run once in the morning. It is fine for a ticket to keep showing up across multiple days while it is in flight; Asana is the source of truth and tickets stay on the list until they close there.

## Output format (target)

Plain text only. No markdown, no Slack mrkdwn, no auto-formatted links. The user pastes this into Slack and applies formatting (bold, links) by hand. Keep it minimal so manual linking is fast: each bullet has the raw ticket title on the bullet line, and the bare URL on the line directly underneath it.

```
Daily Update [<Month D, YYYY>]

Working on Today

- <ticket title>
<asana-permalink>

- <ticket title>
<asana-permalink>

Plans for Tomorrow

- <ticket title>
<asana-permalink>
```

Formatting rules:

- No asterisks, no underscores, no backticks, no `#` headings. The date line and section labels are unstyled.
- No GFM link syntax (`[text](url)`) and no Slack link syntax (`<url|text>`). Just the raw URL on its own line below the title.
- No brackets, parentheses, or angle brackets around the URL. Bare URL only.
- Bullet character is `-` (hyphen + space) at the start of the title line. The URL line is flush-left, no indent, directly under the title.
- One blank line between entries for readability.
- One blank line between section labels (`Working on Today`, `Plans for Tomorrow`) and the first entry below them.
- No em dashes anywhere (workspace global rule). If you need a separator inside prose, use a colon or parentheses.

Rules for the body:

- Title is the **raw Asana task name**, no truncation, no editing. Stripping a `Rumble - ` prefix is fine if the line gets unwieldy, but only if the ticket clearly reads naturally without it.
- The title line may end with a short parenthetical tag like `(no sprint)` when the ticket is included from outside the current sprint (see Step 3).
- Every bullet is a real ticket from the freshly-refreshed TODO. No invented bullets like "Reviewed a bunch of PRs" unless the user adds them by hand after the fact.
- Date is today, formatted like `May 6, 2026`.

## Step 1. Refresh the TODO file from Asana

Run the **refresh-todos** skill in full (do not skip it; the rest of this command depends on a freshly-generated `_tether-indexer-docs/TODO.md`):

- Skill file: `.claude/skills/refresh-todos/SKILL.md`
- It re-fetches assigned incomplete tasks from the Asana `users/me` endpoint, normalises them, and overwrites `/Users/alexa/Documents/repos/tether/_INDEXER/_tether-indexer-docs/TODO.md`.
- Keep the in-memory normalised task list (each task's `gid`, `name`, `permalink_url`, `Sprint`, `Priority`, `Task Progress`, project memberships and section names). You will reuse it in Step 3 instead of re-parsing the markdown.
- If the refresh fails (token missing, API error, etc.), stop and report. Do not generate a stale daily update from yesterday's file.

After the refresh succeeds, give Alex a one-line acknowledgement that the TODO was refreshed before moving on (e.g. "TODO refreshed: 25 tasks, 5 in flight").

## Step 2. Determine the current sprint

The user wants to confirm the sprint number every run. Ask in one short question:

> "Current sprint number? (e.g. 1, 2, ...)"

If the user passed a sprint number as `$ARGUMENTS` (e.g. `/daily-updates 1`), skip the question and use it directly. Validate it parses as a positive integer; if not, ask anyway.

To make the question more useful, before asking, scan the in-memory task list and gather the distinct `Sprint` values present (e.g. "Sprint 1", "Sprint 2"). Surface them in the question:

> "Current sprint number? (seen in tickets: 1, 2). Default: <lowest sprint with incomplete tickets>."

If the user replies with just a number, treat it as `Sprint <N>` and match against the custom field's display value (case insensitive, trim "Sprint " prefix on both sides).

Store the chosen value as `CURRENT_SPRINT` (e.g. `Sprint 1`).

## Step 3. Pick the bullets

From the in-memory task list, restrict to tickets whose `Sprint` custom field equals `CURRENT_SPRINT`. Tickets with no Sprint value are excluded from the daily update entirely (they live in TODO.md but are not stand-up material).

### Working on Today

Include every sprint ticket that is **actively in flight**, in this order:

1. `Task Progress = "In Progress"` (any priority).
2. Section name contains `In Progress`, `Dev In Progress`, `In Review`, `PR Open`, `PR OPEN`, or `PR MERGED + DEPLOYED TO DEV` (still soaking, not closed).
3. Tickets the user mentioned in the last refresh's "Top priorities" block (cross-reference by `gid`) that have `Priority = High` or `Critical` and are not already covered above.

No hard cap. Carry-over is expected: a ticket can appear on this list for days while it is in flight. If a ticket has no Sprint value but is clearly in flight (e.g. `DEV IN PROGRESS` on a critical ticket), include it anyway and append `(no sprint)` after the bullet so Alex sees it.

Sort by:

1. Priority (Critical > High > Medium > Low > none).
2. `Task Progress` weight: In Progress > In Review / PR Open > Deployed-to-dev > others.
3. `modified_at` descending.

### Plans for Tomorrow

Pick the next 1 to 3 sprint tickets that Alex would naturally pick up next:

1. `Priority = High` or `Critical`, `Task Progress` empty or "To Do", section name contains `To Do` / `TO DO` / `Triage`.
2. If fewer than 1, fall back to Medium-priority To Do items in the same sprint.
3. Skip anything in `Blocked`, `Deferred`, `On Hold`, `Completed`, `Done`.

Sort the same way as Today (priority then modified_at desc). Cap at 3 by default; bump to 4 only if the in-flight list is empty.

### Skip rules

- Skip placeholder tickets named exactly `Task 1`, `Task 2`, `Task 3`.
- Skip tickets sitting in a "Completed" board section even if Asana still flags them incomplete (the TODO file flags these separately; they are not stand-up material).
- Skip the `Blocked / Deferred` group.

## Step 4. Render and archive

1. Build the output text following the plain-text format at the top of this file. Each ticket is two lines: title on the bullet line, raw `permalink_url` on the next line.

2. Determine the archive path:
   ```
   /Users/alexa/Documents/repos/tether/_INDEXER/_tether-indexer-docs/_daily-updates/<YYYY-MM-DD>.md
   ```
   The directory `_daily-updates/` may not exist yet on first run; create it. If a file for today already exists, **overwrite it** (running `/daily-updates` twice in one morning should produce one canonical artifact for that date, not append).

3. Write the rendered text to that file verbatim. The file extension stays `.md` for tooling compatibility, but the contents are plain text.

4. Print the same text to chat, fenced as a triple-backtick code block. The fence is for clean copy-paste only; the user copies the contents of the fence and pastes into Slack, where they apply bold/link formatting manually.

5. After the code block, in plain prose, add a one-line footer noting:
   - The archive path.
   - Counts: `<X> in flight, <Y> queued for tomorrow, sprint = <CURRENT_SPRINT>`.
   - Any ticket that you included with the `(no sprint)` tag, so Alex can decide whether to add a sprint label in Asana.

## Step 5. Done

That's it. No commits, no PRs, no edits to code repos. The only files this command writes are:

- `_tether-indexer-docs/TODO.md` (via the refresh-todos skill).
- `_tether-indexer-docs/_daily-updates/<YYYY-MM-DD>.md` (this command).

## Hard rules

- Always run the refresh in Step 1 first. Do not generate a daily update off a stale TODO file, even if the file was regenerated earlier today by another command. The Asana queue moves between morning and evening.
- Never invent ticket titles or links. If a ticket isn't in the refreshed in-memory list, it doesn't go on the update.
- Never print or commit the Asana token.
- Never edit the brain_v1 TODO from this command.
- No em dashes in the rendered output.
- If the user ran `/daily-updates` with no arguments AND the workspace already has today's file written within the last 30 minutes, still re-run the refresh (Asana may have moved); just overwrite today's file with the new render.
