---
name: refresh-todos
description: Refresh or summarize Alex's Tether/Rumble-Wallet Asana TODO queue in _INDEXER by pulling incomplete assigned tasks and rewriting _tether-indexer-docs/TODO.md with priorities and stand-up focus. Use when Alex asks for TODOs, tickets, Asana tasks, his queue, or stand-up notes.
---

# Refresh Tether TODOs (from Asana)

Pull every incomplete task assigned to Alex from Asana, rewrite
`_tether-indexer-docs/TODO.md` so it reflects the current state of his queue,
and surface the top-priority items with enough detail to talk through them in
the daily stand-up.

This skill is the local-to-_INDEXER counterpart of the brain_v1 TODO sync. It
does NOT touch `brain_v1/projects/tether/TODO.md` — that file is maintained by
the brain_v1 todo-tracker skill. The two files are allowed to drift; this one
is canonical for the indexer / Rumble-Wallet workspace.

## Triggers

Invoke this skill when Alex writes any of:

- "find my TODOs" / "find my todos"
- "update my TODOs" / "refresh my TODOs"
- "get my Asana TODOs" / "pull my Asana tasks"
- "refresh my tickets" / "sync my tickets"
- "what's on my plate (for tether)" / "what am I working on"
- "stand-up notes" / "give me my stand-up" / "prep me for stand-up"
- Any variation pairing a verb (find / update / refresh / sync / pull / get)
  with TODOs / tickets / Asana tasks / my queue, in the context of this
  `_INDEXER` workspace.

If Alex is asking the same question for a *different* project (Monzo,
Driving-Theory, etc.), defer to the brain_v1 todo-tracker skill instead.

## Required credentials

Asana Personal Access Token lives at:
`/Users/alexa/Documents/repos/brain_v1/projects/tether/.asana-token`

```bash
TOKEN=$(cat /Users/alexa/Documents/repos/brain_v1/projects/tether/.asana-token | tr -d '\n')
```

Never print the token. Never write it to any file under `_INDEXER/`. If the
token file is missing, stop and tell Alex — don't try to invent one or look
elsewhere.

## Output location

Single file: `/Users/alexa/Documents/repos/tether/_INDEXER/_tether-indexer-docs/TODO.md`

The file is fully regenerated on every refresh (overwrite, don't merge). The
prior version is fine to lose — Asana is the source of truth, and any
hand-written edits Alex wants to keep belong in the brain_v1 TODO instead.

## Known Asana context

- Workspace GID: `45238840754660`
- Alex's `user_task_list` GID (workspace "tether.to"): `1211860479278757`
- Project GIDs commonly seen:
  - Rumble Wallet V3: `1212521145936484`
  - WDK Indexer + Wallet Backends: `1210540875949204`
  - BUG: `1210591027686188`
  - V1 Bugs Tracking: `1211195910521628`

## Steps

### 1. Fetch the assigned, incomplete task list

```bash
curl -s -H "Authorization: Bearer $TOKEN" \
  "https://app.asana.com/api/1.0/user_task_lists/1211860479278757/tasks?completed_since=now&opt_fields=name,completed,due_on,assignee_status,modified_at,permalink_url,memberships.project.name,memberships.project.gid,memberships.section.name,custom_fields.name,custom_fields.display_value&limit=100"
```

Notes:

- `completed_since=now` is the documented filter for "incomplete only" on the
  user-task-list endpoint.
- One task can appear in multiple projects/sections via `memberships`.
- Pagination: if the response includes `next_page`, follow it. With ~25
  assigned tasks this is rarely needed, but handle it anyway.

Save the raw response to a scratch path (don't commit it) only if you need
multiple passes — otherwise hold it in memory.

### 2. Normalise each task

For each task, extract:

- `gid`
- `name` (strip leading `Rumble - ` / `Rumble: ` / `Rumble [...] ` noise when
  used in headlines, but keep the original for the link text)
- `permalink_url`
- `memberships` → list of `{project_name, project_gid, section_name}`
- `due_on`
- `modified_at`
- Custom fields, by name:
  - `Priority` → High / Medium / Low (or null)
  - `Task Progress` → e.g. "In Progress", "Done", null
  - `Sprint`
  - `Task Type` (Bug / Feature / Chore / etc.)
  - `Stack` (BE / FE)
  - `RW` → external ticket id like `RW-1622`
  - Any other ticket-id field that looks like `RW-####`, `WDK-####`,
    `BUG-####` — surface it as a short tag.

### 3. Decide ranking and sectioning

Group tasks into sections, in this order:

1. **Top priorities (stand-up focus)** — see step 4. Maximum 5 items. These
   are the items Alex will mention in the next stand-up.
2. **In Progress / In Review** — `Task Progress` is "In Progress", or section
   name contains "In Progress", "In Review", "PR Open", "Dev In Progress".
3. **High priority — To Do** — `Priority = High` and not already above.
4. **Medium / Low — To Do** — everything else still incomplete.
5. **Blocked / Deferred** — section name contains "Blocked", "Deferred", "On
   Hold", or `assignee_status = later`.
6. **PR Reviews requested** — only if you can detect them (tasks where Alex
   is a collaborator/reviewer rather than assignee won't show up here; this
   section is usually filled in manually). If nothing detected, omit.
7. **Placeholder / onboarding tasks** — tasks named "Task 1" / "Task 2" /
   "Task 3" or otherwise auto-generated. Always last; collapse to one bullet
   each.

Within each section, sort by:

1. `due_on` ascending (no due date sorts last)
2. `modified_at` descending

If a task appears in multiple project memberships, prefer the project that
matches one of the known project names above; fall back to the first
membership. Do NOT duplicate a task across sections — each task appears
exactly once in the body of the file (the project membership is shown inline
on the bullet).

### 4. Pick the top priorities and pull stand-up detail

Top-priority candidates, in order of preference:

1. `Task Progress = "In Progress"` AND `Priority = High`
2. `Task Progress = "In Progress"` (any priority)
3. `Priority = High` and modified within the last 14 days
4. `Priority = High` (oldest if nothing else)

Cap at 5. If there are fewer than 3 in-progress items, fill from the High
queue so Alex has enough material for a stand-up.

For each top-priority item, fetch the latest signal so the stand-up bullet is
specific (not just the title):

```bash
# Latest two non-system comments
curl -s -H "Authorization: Bearer $TOKEN" \
  "https://app.asana.com/api/1.0/tasks/<gid>/stories?opt_fields=created_at,created_by.name,text,type,resource_subtype&limit=20"
```

From the response, take the most recent 1–2 comment-type stories. Also pull
the task description if you need more context:

```bash
curl -s -H "Authorization: Bearer $TOKEN" \
  "https://app.asana.com/api/1.0/tasks/<gid>?opt_fields=notes,html_notes"
```

Distil the comments + description into **one or two short sentences** that
answer:

- What is the actual problem / feature?
- What state is it in right now (PR open, blocked on X, waiting on review,
  draft, etc.)?
- What is Alex doing next on it (if known)?

Keep the language plain — this is for spoken stand-up, not a PR description.
No em dashes (user global rule). Don't quote raw comments; summarise.

### 5. Cross-reference local task folders

Scan `_tether-indexer-docs/_tasks/*` for folder names that mention the
ticket id or a slugified version of the title. If a match exists, append a
local pointer to the bullet:

`local: \`_tasks/<folder-name>/\``

This is what makes the file useful inside `_INDEXER` — the brain_v1 version
doesn't have these pointers.

### 6. Write the file

Overwrite `_tether-indexer-docs/TODO.md` with the structure below. Keep it
scannable; aim for under ~150 lines total.

```markdown
# Asana TODO — assigned to Alex (Tether Indexer)

Generated: <YYYY-MM-DD HH:MM UTC>
Source: Asana `users/me` task list (incomplete only)
Refresh: ask Codex to "refresh my Asana TODOs".

**Summary:** <N> assigned tasks (<N_real> real + <N_placeholder> placeholder)
across <N_projects> projects. <N_in_progress> in progress, <N_high> high
priority.

---

## Top priorities — stand-up focus

> Up to 5 items. These are what Alex talks through in the next stand-up.

### 1. <ticket title>
[<ticket id or RW/WDK code>](<permalink>) · <project> · <priority> · <task progress>
> <one or two short sentences distilled from the latest comment + description:
> what the problem is, where it stands, what's next>
local: `_tasks/<folder>/` *(only if a matching local task folder exists)*

### 2. <ticket title>
...

---

## In progress / In review
- [ ] [<title>](<permalink>) — `<RW-####>` · <priority> · <project>:<section>
      <task-progress note if useful, else omit>
      local: `_tasks/<folder>/` *(if matched)*

## High priority — To Do
- [ ] [<title>](<permalink>) — `<id>` · <project>:<section> · due <YYYY-MM-DD or "—">

## Medium / Low — To Do
- [ ] [<title>](<permalink>) — `<id>` · <priority> · <project>:<section>

## Blocked / Deferred
- [ ] [<title>](<permalink>) — `<id>` · <reason if visible> · <project>:<section>

## Placeholder / onboarding
- [ ] [Task 1](<permalink>) · due <date>
- [ ] [Task 2](<permalink>) · due <date>
```

Rules for the body bullets:

- Always link the title to the Asana permalink. Link text = full task name,
  raw, no edits (so a Cmd-F for the Asana title works).
- Use single-bullet entries. No nested checklists per task.
- Never invent a ticket id. If the `RW` / `WDK` custom field is empty, leave
  the id off — don't guess from the title.
- Never write em dashes (`—` is fine in the section template above where it
  appears as a separator only; in prose, use a colon, parentheses, or two
  short sentences instead). User has a hard rule against em dashes in
  generated content.
- Mark overdue items (`due_on` in the past) by appending ` **OVERDUE**` after
  the due date.

### 7. Report back

In the chat reply, give Alex a tight summary:

- Path of the file written.
- Counts: total assigned, in progress, high priority, blocked, placeholders.
- The 1-line headline of each top-priority item, in the order they appear in
  the file, so he can scan them without opening the file.
- Anything weird worth flagging (e.g. a ticket sitting in a "Completed"
  section but still marked incomplete; tickets with no project membership;
  duplicated tickets across projects).

Aim for under ~12 lines of chat output. The detail belongs in the file, not
in chat.

## Commands and aliases

| What Alex types                              | Action                                                    |
|----------------------------------------------|-----------------------------------------------------------|
| "find my TODOs", "show my TODOs"             | If file is fresh (modified within last 6 hours), just read and summarise it. Otherwise refresh first, then summarise. |
| "update my TODOs", "refresh my TODOs"        | Always re-fetch from Asana and rewrite the file.          |
| "get my Asana TODOs", "pull my Asana tasks"  | Same as refresh.                                          |
| "refresh my tickets", "sync my tickets"      | Same as refresh.                                          |
| "stand-up notes", "prep me for stand-up"     | Refresh, then output ONLY the "Top priorities" section verbatim into chat (no need to read other sections aloud). |
| "what changed since last refresh"            | Diff the `modified_at` timestamps against the previous file's timestamps. Show only tasks newer than the previous "Generated" header. |

If Alex asks for "my TODOs" without a project hint, default to this skill —
he is in the `_INDEXER` workspace and the indexer queue is what he means
99% of the time. If the question is broader ("all my TODOs across
everything"), call the brain_v1 todo-tracker skill instead.

## Rules

- Never fabricate task content. If the API returns an error, stop and report
  it; don't write a partial file.
- Never print, commit, or log the Asana token.
- Don't touch `brain_v1/projects/tether/TODO.md` from this skill.
- Don't edit code anywhere as part of this skill — gather + format only.
- The file is regenerated each run. Do not try to preserve hand edits;
  Asana is the source of truth.
- Rate-limit: PAT allows ~150 req/min. With ~25 tasks and 5 top-priority
  detail fetches you'll be well under. Don't fan out more than 10 parallel
  fetches.
- If the token file is missing or unreadable, stop with a clear message and
  point Alex at `brain_v1/projects/tether/.asana-token`.
