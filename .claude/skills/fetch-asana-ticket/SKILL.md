# Fetch Asana Ticket (Tether Indexer)

Fetch a single Asana ticket for the Tether / Rumble-Wallet indexer work, drop all of
its content (description, comments, attachments, images) into a new task folder under
`_tether-indexer-docs/_tasks/`, analyse the images, and flag any missing context so
the ticket can be picked up and worked on later.

## Triggers

Invoke this skill when Alex writes any of:

- "get this ticket <asana-url>"
- "fetch Asana ticket <asana-url>"
- "create a task for this ticket <asana-url>"
- "pull this ticket <asana-url>"
- "grab this Asana ticket <asana-url>"
- Any variation of the above that pairs a verb like get / fetch / pull / grab /
  save / create-task-for with an Asana task URL.

The input is always an Asana task URL of the form:
`https://app.asana.com/<...>/task/<task_gid>` (optionally followed by
`/comment/<comment_gid>` and/or `?focus=true`). Extract `<task_gid>`.

If the user did not paste a URL, ask for one before continuing.

## Required credentials

Asana Personal Access Token is stored at:
`/Users/alexa/Documents/repos/brain_v1/projects/tether/.asana-token`

```bash
TOKEN=$(cat /Users/alexa/Documents/repos/brain_v1/projects/tether/.asana-token | tr -d '\n')
```

Never print the token. Never commit it anywhere under `_INDEXER/`.

## Output location and folder naming

Root: `/Users/alexa/Documents/repos/tether/_INDEXER/_tether-indexer-docs/_tasks/`

Folder name format: `DD-mon-YY-<TICKET-NUMBER>-<kebab-title>/`

- `DD` — two-digit day of today (today's date, not the ticket's created_at)
- `mon` — three-letter lowercase month (`jan`, `feb`, `mar`, `apr`, ...)
- `YY` — two-digit year
- `<TICKET-NUMBER>` — the ticket identifier, e.g. `RW-1683`, `WDK-842`,
  `BUG-217`. Source it from (in order of preference):
  1. A custom field whose `name` looks like "Ticket ID", "Key", "Issue ID",
     or matches the regex `^[A-Z]+-\d+$` in `display_value`.
  2. A tag matching `^[A-Z]+-\d+$`.
  3. The ticket title or description if it begins with / contains
     `^[A-Z]+-\d+\b`.
  If no ticket number can be found, fall back to `NOID` and flag this in
  `missing-context.md` so Alex can rename the folder.
- `<kebab-title>` — the full Asana ticket title, lowercased, with all
  non-alphanumeric runs replaced by a single dash, leading/trailing dashes
  stripped. Do not abbreviate or shorten — keep every word from the title so
  the folder is searchable. Example: ticket "The amount in the push looks
  with incorrect decimals" → `the-amount-in-the-push-looks-with-incorrect-decimals`.

Example: `28-apr-26-RW-1683-the-amount-in-the-push-looks-with-incorrect-decimals/`

If the folder name you'd create already exists, append `-2`, `-3`, ... (don't
overwrite).

## Folder contents to produce

```
<folder>/
  ticket.md            # URL, GID, title, project, section, assignee, status,
                       # created_at, due_on, completed, permalink. One screenful.
  description.md       # Full task description (`notes` / `html_notes`) — raw.
  comments.md          # All stories of type=comment, newest-last, with author
                       # name, timestamp, and body. Include system stories only
                       # if they add signal (assignment changes, section moves).
  attachments/         # Non-image attachments (PDFs, logs, zips, text files).
  images/              # Image attachments (png, jpg, jpeg, gif, webp, heic).
  image-analysis.md    # One section per image: filename, what it shows, what
                       # data / error / value is visible, and how it relates to
                       # the ticket question.
  missing-context.md   # Explicit list of everything referenced in the ticket
                       # but NOT included. See "Flagging missing context" below.
  NEXT-STEPS.md        # Short checklist for a future session picking this up:
                       # what's known, what's missing, what to ask Alex before
                       # starting.
```

## Steps

### 1. Parse the URL

From the URL, extract `<task_gid>` (the number after `/task/`). Confirm it looks
like a long numeric id.

### 2. Check if the ticket is already fetched (early exit)

**Always run this check before any further API calls.** It prevents re-fetching
a ticket that already lives under `_tasks/`, which is the default — Alex should
not have to ask each time whether the ticket has been pulled before.

Use the `task_gid` extracted from the URL to grep every existing `_raw/task.json`:

```bash
grep -l "\"gid\": \"<task_gid>\"" \
  /Users/alexa/Documents/repos/tether/_INDEXER/_tether-indexer-docs/_tasks/*/_raw/task.json \
  2>/dev/null
```

**If grep returns a path** (the parent directory of that `_raw/task.json` is the
existing task folder):

1. Compute today's prefix as `DD-mon-YY-` using today's date (the same format
   used at folder creation time).
2. If the existing folder's leading `DD-mon-YY-` differs from today's prefix,
   rename the folder so only the date prefix changes — keep the rest
   (`<TICKET-NUMBER>-<kebab-title>` and any `-2` / `-3` collision suffix)
   identical:
   ```bash
   mv "<old_folder_path>" "<parent>/<today_prefix><rest_of_old_name>"
   ```
   If the prefix already matches today, skip the rename.
3. Report back to Alex: a one-liner saying the ticket was already fetched, plus
   the (possibly renamed) folder path. Do not list contents or re-summarise.
4. **Stop the skill here.** Do NOT fetch stories, attachments, images, or
   re-write any of the markdown files. The whole point of this check is to
   avoid clobbering existing analysis.

**If grep returns nothing**, the ticket has not been fetched before — proceed
to step 3.

**If grep returns more than one match** (rare; usually means the ticket was
fetched twice with a `-2` suffix), don't try to merge them. List all matches to
Alex and ask which folder to refresh; do not auto-rename in this case.

**Force re-fetch:** if Alex's request explicitly says "re-fetch", "refresh",
"force", "redo", or similar, skip this early-exit check and run the full fetch
flow, but still write into the existing folder name rather than creating a new
one (preserve their notes if any).

### 3. Fetch the task

```bash
curl -s -H "Authorization: Bearer $TOKEN" \
  "https://app.asana.com/api/1.0/tasks/<task_gid>?opt_fields=name,notes,html_notes,completed,assignee.name,assignee_status,due_on,created_at,modified_at,permalink_url,projects.name,memberships.section.name,memberships.project.name,tags.name,num_likes,num_subtasks,custom_fields.name,custom_fields.display_value,parent.name,parent.gid"
```

Save the raw JSON response to `<folder>/_raw/task.json` (create `_raw/` for raw
fetches — useful later for re-processing without re-hitting the API).

### 4. Fetch stories (comments + system events)

```bash
curl -s -H "Authorization: Bearer $TOKEN" \
  "https://app.asana.com/api/1.0/tasks/<task_gid>/stories?opt_fields=created_at,created_by.name,text,html_text,type,resource_subtype,is_pinned"
```

Save raw to `<folder>/_raw/stories.json`.

Write `comments.md` as a chronological list. Include only:
- `type=comment` stories (always)
- `type=system` stories whose `resource_subtype` is one of:
  `assigned`, `marked_complete`, `marked_incomplete`, `added_to_section`,
  `due_date_changed`, `attachment_added`
  — these carry signal for triage.

### 5. Fetch attachments list

```bash
curl -s -H "Authorization: Bearer $TOKEN" \
  "https://app.asana.com/api/1.0/attachments?parent=<task_gid>&opt_fields=name,resource_subtype,download_url,view_url,host,permanent_url,size,created_at"
```

Save raw to `<folder>/_raw/attachments.json`.

For each attachment, also pull full details (download_url on the list endpoint
can be empty on some hosts):

```bash
curl -s -H "Authorization: Bearer $TOKEN" \
  "https://app.asana.com/api/1.0/attachments/<attachment_gid>?opt_fields=name,resource_subtype,download_url,view_url,host,permanent_url,parent.gid,size,created_at"
```

### 6. Also pull comment-level attachments

Some Asana comments have their own attachments (pasted screenshots inside a
comment). Those appear as `attachment_added` system stories or via
`attachments?parent=<story_gid>`. For any story whose text/html mentions
"attached", or any `attachment_added` system story, fetch
`attachments?parent=<story_gid>` too, and merge the results.

### 7. Download each attachment

For each attachment with a non-empty `download_url`:

```bash
# download_url is a short-lived signed URL; no auth header needed for S3 redirects,
# but pass -L so curl follows redirects.
curl -sL -o "<folder>/<dest>/<safe_filename>" "<download_url>"
```

Classification:
- extension in {png, jpg, jpeg, gif, webp, heic, bmp, svg} → `images/`
- everything else → `attachments/`

`safe_filename` = original name with spaces replaced by `-`, kept lowercase-ish,
prefixed with the attachment `gid` when the original name collides or is generic
(e.g. `image.png` → `<gid>-image.png`).

If `download_url` is empty and the host is `external` (URL attachment), don't
download — instead record the external URL in `missing-context.md` under a
"External links to review" section.

### 8. Write `ticket.md`

```markdown
# <task title>

- **URL:** <permalink_url>
- **GID:** <task_gid>
- **Project:** <memberships[0].project.name>
- **Section:** <memberships[0].section.name>
- **Assignee:** <assignee.name> (<assignee_status>)
- **Status:** <completed ? "completed" : "open">
- **Created:** <created_at>
- **Modified:** <modified_at>
- **Due:** <due_on or "—">
- **Tags:** <comma-separated tag names or "—">
- **Custom fields:** <name: display_value, ...>
```

### 9. Write `description.md`

The raw `notes` field (plain text). If `notes` is empty but `html_notes` has
content, convert the HTML to reasonable Markdown (preserve headings, lists,
links, code).

### 10. Analyse images

For each file in `<folder>/images/`, open it with the `Read` tool and produce a
section in `image-analysis.md`:

```markdown
## <filename>

**Source comment:** <author / timestamp if from a comment, else "Task description">

**What it shows:** <one-sentence summary of the screenshot>

**Key content:**
- <error messages, exact values, stack traces, URLs, transaction hashes,
  addresses, amounts, timestamps, env indicators (staging/prod), browser/tool
  shown>

**Relevance:** <how this connects to the ticket question — which part of the
problem it evidences or contradicts>
```

Be concrete — extract numbers, hashes, error strings verbatim. These
screenshots are usually the only record of the state Alex saw; they need to be
readable from text alone later.

### 11. Flag missing context → `missing-context.md`

Scan the description, every comment, and the image analysis for references to
things that are NOT included in what you just fetched. Explicitly flag each
one. Categories:

- **Slack threads** — any `slack.com` URL, any mention of "slack", "dm",
  "thread", "#channel", or "I'll ping ... on slack"
- **Logs** — any mention of "logs", "grafana", "kibana", "datadog", "loki",
  "splunk", "cloudwatch"; any URL to those tools; any comment saying
  "check the logs" / "see logs" without the log snippet attached
- **External tickets** — URLs to Jira, Linear, GitHub issues/PRs, other Asana
  tickets referenced as "related" or "see also"
- **People / decisions** — "as discussed with X", "waiting on Y", "X said we
  should ..." where the actual statement is not in the fetched content
- **Attachments** — any mention of "I attached", "see screenshot", "file
  uploaded" where the listed attachments don't obviously correspond
- **Environments / systems** — any mention of a service, env, box, db, or
  dashboard that a future reader would need access to but that isn't linked

Format each item as:

```markdown
- [ ] <category>: "<short quote from the ticket>" — **Need from Alex:** <what
  to ask for>. **Source:** <comment author, timestamp, or "description">
```

If nothing is missing, write:

```markdown
No external references or missing artifacts detected. The ticket is
self-contained.
```

### 12. Write `NEXT-STEPS.md`

A short hand-off note for the next session that opens this folder:

```markdown
# Next steps for <short ticket title>

**Ticket:** <permalink_url>

## What we know
- <2–5 bullets summarising the problem as stated in the ticket + comments>

## Evidence captured here
- <count> images analysed in `image-analysis.md`
- <count> non-image attachments under `attachments/`
- <count> comments in `comments.md`

## What's missing (from `missing-context.md`)
- <terse list — or "nothing flagged">

## Before starting work
If Alex re-assigns this ticket for analysis or fix, **ask for the missing items
above first** before digging into the codebase. If nothing is missing, jump to
investigation.
```

### 13. Report back

In the final chat response, give Alex:

- The folder path just created
- The number of comments, images, and other attachments saved
- A one-line summary of the ticket problem
- The count of missing-context items flagged (and, if small, list them
  inline so Alex can answer right there)

Keep it under ~10 lines.

## Rules

- Never fabricate ticket content. If the API call fails, stop and report the
  error — don't proceed with partial data silently.
- Never print, commit, or leak the Asana token.
- Don't edit any code in the repo as part of this skill. This skill only
  gathers context.
- Rate-limit: Asana API allows ~150 req/min for a PAT. If you batch many
  attachment-detail calls, that's fine for a single ticket, but don't parallel-
  fetch more than ~10 at once.
- The `_raw/` directory is for the unmodified JSON responses. Keep it — it
  makes it trivial to re-run analysis later without hitting Asana again.

## Known Asana context (for reference)

- Workspace GID: `45238840754660`
- Project GIDs often seen in these tickets:
  - Rumble Wallet: `1212521145936484`
  - WDK: `1210540875949204`
  - BUG: `1210591027686188`

The skill does NOT need to pass project GID — fetching a task by its own GID
returns project membership already.
