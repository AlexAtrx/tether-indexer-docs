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
