# Tether Indexer — Project Instructions

This is Alex's workspace for the Tether / Rumble-Wallet indexer repos. Day-to-day
work is driven by Asana tickets (see `brain_v1/projects/tether/TODO.md` for the
current list) and investigations land as task folders under
`_tether-indexer-docs/_tasks/`.

## Project-local skills

When Alex triggers one of these, read the full skill definition from the path
below and follow it exactly. These skills live inside this repo so they stay in
sync with the task-folder conventions used here.

### Fetch Asana Ticket

**Triggers:** any message pairing an Asana task URL with a verb like "get",
"fetch", "pull", "grab", "save", or "create a task for this ticket". Examples:

- "get this ticket https://app.asana.com/.../task/1214000621998015"
- "fetch Asana ticket https://app.asana.com/.../task/..."
- "create a task for this ticket https://app.asana.com/.../task/..."

**Skill file:** `.claude/skills/fetch-asana-ticket/SKILL.md`

**Summary:** Fetches the ticket's description, comments, and attachments from
the Asana API, downloads images, analyses them, and writes everything into a
new `_tether-indexer-docs/_tasks/DD-mon-YY-N-short-title/` folder. Flags any
referenced-but-missing context (Slack threads, logs, external tickets) in a
`missing-context.md` so the ticket can be picked up later with a clear list of
what to ask Alex before starting work.

### Refresh Tether TODOs

**Triggers:** any message asking Alex's TODO / ticket queue to be pulled,
refreshed, or summarised in this `_INDEXER` workspace. Examples:

- "find my TODOs" / "show my TODOs" / "what's on my plate"
- "update my TODOs" / "refresh my TODOs" / "refresh my tickets"
- "get my Asana TODOs" / "pull my Asana tasks" / "sync my tickets"
- "stand-up notes" / "prep me for stand-up"

**Skill file:** `.claude/skills/refresh-todos/SKILL.md`

**Summary:** Pulls every incomplete task assigned to Alex from Asana
(`users/me` task list) and rewrites `_tether-indexer-docs/TODO.md` with
sections by status and priority. Surfaces up to 5 top-priority items with a
1–2 sentence stand-up brief distilled from each ticket's latest comment and
description, and links each item to its local `_tasks/<folder>/` if one
exists. Uses the same Asana token as the fetch skill at
`/Users/alexa/Documents/repos/brain_v1/projects/tether/.asana-token`. Does
not touch the brain_v1 TODO file.
