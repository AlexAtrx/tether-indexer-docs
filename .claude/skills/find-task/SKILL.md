---
name: find-task
description: Reverse-lookup from something concrete (a GitHub PR URL, an error signature, a ticket id, a local git diff/branch, or a keyword) to the `_tether-indexer-docs/_tasks/` folder(s) that own it. Use whenever Alex asks "find the ticket folder responsible for this", "search for the task that had this PR in it", "which task covers this error", "did we already work on this", or points at local changes and asks which ticket they belong to.
---

# Find the task folder behind a thing

Alex has something in his hand — a PR link, an error, a branch full of
uncommitted changes, a half-remembered ticket — and wants to know **which
`_tasks/` folder already owns it**, so he can pick the work back up with its
full context instead of starting cold.

There are 80+ folders under `_tether-indexer-docs/_tasks/`. This is a local
search skill: no servers, no network (except an optional `gh` call to read a
PR title). It only reads and reports; it never edits folders or renames them.

## Folder shape (what you are searching)

Each folder is named `NN-DD-mon-YY-TICKET-slug`, optionally suffixed
`[DONE]` (sometimes `[DONE - ...]` with a qualifier). Inside, the high-signal
files to grep are:

- `ticket.md` / `description.md` — the Asana ticket id, title, body.
- `comments.md` — Asana discussion (often names PRs and Slack people).
- `HANDLING.md` — what was changed, **which repos**, and the PR links.
- `root-cause.md` / `analysis.md` — the error/stacktrace for bug tickets.
- `final-spec.md`, `NEXT-STEPS.md`, `verification.md` — scope and follow-ups.

The `[DONE]` suffix is load-bearing: a folder that owns your input AND is
`[DONE]` usually means "fix exists but is unmerged or undeployed" — say so.

## Step 1 — classify the input

- **PR URL** (`github.com/<org>/<repo>/pull/N`) → search for the repo name,
  the PR number, and the full URL. If nothing hits on the number, read the
  PR title with `gh pr view <url> --json title,body` and search on its
  keywords / ticket id (Tether PRs usually carry the `RW-####` / `WDK-####`
  in the title or branch).
- **Error signature** (a code or message stem, e.g.
  `ERR_USER_DATA_SHARD_NOT_FOUND`) → grep `root-cause.md` / `analysis.md` /
  `HANDLING.md` first, then everything. This overlaps with
  [`check-error-on-env`](../check-error-on-env/SKILL.md); that skill calls
  this one for the correlation step.
- **Ticket id** (`RW-1900`, `WDK-1196`) → grep the id directly; note that one
  ticket can span several folders (e.g. WDK-1196 / RW-1683 has folders
  76/77/78/80).
- **Local changes** (a branch or uncommitted diff) → derive search terms from
  the diff: changed repo names, changed file basenames, new function/symbol
  names, and any ticket id in the branch name. Then search on those.
- **Keyword / vague description** → search on the distinctive nouns.

## Step 2 — search

Run a few cheap greps, broad first, from the workspace root.

```bash
cd /Users/alexa/Documents/repos/_tether/_INDEXER

# by ticket id or PR number — fast and usually decisive
grep -rl -iE "RW-1900|pull/231|wdk-data-shard-wrk" \
  _tether-indexer-docs/_tasks/*/ 2>/dev/null

# folder-name match (ticket id / slug live in the directory name itself)
ls -d _tether-indexer-docs/_tasks/*/ | grep -iE "RW-1900|spark|channel"

# error signature, weighted to the diagnosis files
grep -rl -iE "ERR_USER_DATA_SHARD_NOT_FOUND" \
  _tether-indexer-docs/_tasks/*/root-cause.md \
  _tether-indexer-docs/_tasks/*/analysis.md \
  _tether-indexer-docs/_tasks/*/HANDLING.md 2>/dev/null
```

For local changes, derive the terms first:

```bash
git -C <repo> diff --name-only        # changed files → basenames as terms
git -C <repo> branch --show-current   # branch name often carries the ticket id
```

Then feed those basenames/symbols into the grep above.

## Step 3 — rank and confirm

A folder name hit or a ticket-id hit is strong. A single keyword hit in
`comments.md` is weak — open the file and confirm it is really the same work,
not just a passing mention. Prefer matches that line up across more than one
file (folder name + `HANDLING.md` + the PR link is a confident match).

If several folders match (a multi-folder ticket), list them in folder order
and say how they split the work (read the one-line top of each `HANDLING.md`).

## Step 4 — report

For each match, one line:

```
<folder name>  — <ticket id> — <DONE? deployed?> — <why it matches in 6-10 words>
```

Then a single takeaway sentence:

- exactly one clear owner → name it and offer to load it (this is the natural
  hand-off into [`handle-ticket`](../handle-ticket/SKILL.md)).
- `[DONE]` but the input is a live error/PR-still-open → "fix exists in
  `<folder>` but is unmerged/undeployed" is the useful conclusion.
- nothing matches → say so plainly ("no existing task folder — looks new")
  and offer to fetch/create one rather than forcing a weak match.

## Hard rules

- Read-only. Never rename a folder, never drop the `[DONE]` suffix, never
  edit task files from this skill.
- Do not force a match. A confident "no existing ticket" beats a wrong folder.
- No GitHub posting, no network beyond an optional `gh pr view` to read a
  title. No em dashes in anything you hand back to Alex.
