# Tether Indexer — Project Instructions

This is Alex's workspace for the Tether / Rumble-Wallet indexer repos. Day-to-day
work is driven by Asana tickets (see `_tether-indexer-docs/TODO.md` for the
current local queue) and investigations land as task folders under
`_tether-indexer-docs/_tasks/`.

## Project-local skills

When Alex triggers one of these, read the full skill definition from the path
below and follow it exactly. Codex skill files live under `.agents/skills/`.
They stay inside this repo so they stay in sync with the task-folder
conventions used here.

### Fetch Asana Ticket

**Triggers:** any message pairing an Asana task URL with a verb like "get",
"fetch", "pull", "grab", "save", or "create a task for this ticket". Examples:

- "get this ticket https://app.asana.com/.../task/1214000621998015"
- "fetch Asana ticket https://app.asana.com/.../task/..."
- "create a task for this ticket https://app.asana.com/.../task/..."

**Skill file:** `.agents/skills/fetch-asana-ticket/SKILL.md`

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

**Skill file:** `.agents/skills/refresh-todos/SKILL.md`

**Summary:** Pulls every incomplete task assigned to Alex from Asana
(`users/me` task list) and rewrites `_tether-indexer-docs/TODO.md` with
sections by status and priority. Surfaces up to 5 top-priority items with a
1–2 sentence stand-up brief distilled from each ticket's latest comment and
description, and links each item to its local `_tasks/<folder>/` if one
exists. Uses the same Asana token as the fetch skill at
`/Users/alexa/Documents/repos/brain_v1/projects/tether/.asana-token`. Does
not touch the brain_v1 TODO file.

### Read Remote Repo

**Triggers:** any request to read code, diffs, or history from a private
`tetherto/*` repo that is not present locally, or that needs a specific branch,
tag, commit, or PR view.

**Skill file:** `.agents/skills/read-remote-repo/SKILL.md`

**Summary:** Prefers local clones under this `_INDEXER` workspace, then falls
back to `gh` or shallow git clones for remote reads. This skill is read-only and
does not push, open PRs, or edit `/tmp/tetherto-cache/` clones.

### Address PR Comments

**Triggers:** any request to evaluate, address, reply to, push back on, refactor
for, fix, commit, push, or otherwise handle GitHub PR review comments. Also use
when Alex asks for short Slack-ready answers about PR comments.

**Skill file:** `.agents/skills/address-pr-comments/SKILL.md`

**Summary:** Links the PR to its original ticket/context, reads thread-aware
GitHub review comments, decides which comments deserve code changes versus
short replies, applies scoped local refactors on the PR branch, commits and
pushes only when asked, and uses Alex's concise human reply style with no AI or
co-author attribution.
