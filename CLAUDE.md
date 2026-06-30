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

### Handle a Ticket

**Triggers:** any message pairing a handling verb like "handle", "work on",
"execute", "do", or "take" with a pointer to an already-fetched task folder
under `_tether-indexer-docs/_tasks/` (a folder path, folder name, ticket id, or
"the one I just fetched"). Examples:

- "handle this ticket `_tasks/41-28-may-26-WDK-1515-...`"
- "work on `<task-folder>`" / "execute the ticket in `<folder>`"
- "do RW-1760" / "take WDK-1515"

If Alex hands an Asana URL instead of a folder, run **Fetch Asana Ticket**
first, then handle the folder it produces.

**Skill file:** `.claude/skills/handle-ticket/SKILL.md`

**Summary:** Handles an already-fetched ticket end to end as a senior backend
engineer. Reads the whole task folder (ticket, description, comments,
image-analysis, missing-context, NEXT-STEPS), fills any gaps it can get itself
(Slack threads via the Claude-in-Chrome browser, saved as `slack.txt`; related
code via `read-remote-repo`), loads `repos.md` / `architecture.md` /
`conventions.md` / `hotspots.md` / `AGENTS.md`, and classifies the ticket as
analysis / bug / feature / refactor. For analysis it writes `root-cause.md` or
`analysis.md` with exact `file:line` tracing and a plainly-stated conclusion
(including "not a backend issue" when true). For a fix/feature/refactor it makes
the minimal clean change across every repo it fans out to, respecting layering,
idempotency on both the HTTP and internal-HRPC paths, separation of concerns,
and HyperDB append-only rules; adds/updates unit tests so they match the change
and runs the repo's tests + lint until green (no need to boot the stack); then
writes `HANDLING.md`. Finally it renames the folder with a `[DONE]` suffix and
gives Alex a short chat summary that lists the repos involved. **All work stays
local: never commits, never pushes to GitHub, never posts to Asana**, and never
uses em dashes in human-facing output.

### Scope a Feature (Rumble vs shared base)

**Triggers:** any message asking which layer/repo owns a change, or whether a
feature is Rumble-only or also touches the rest of the backend. Examples:

- "is this rumble-only" / "is this purely Rumble or does it hit the indexer/wallet"
- "which repo should this go in" / "where should this change live"
- "scope this feature" / "separate the concerns" / "split this by layer"

**Skill file:** `.claude/skills/scope-feature/SKILL.md`

**Summary:** Decides which layer and repo owns each concern of a feature BEFORE
any code is written, so Rumble-specific logic lands in the `rumble-*` forks
(`rumble-app-node` / `rumble-ork-wrk` / `rumble-data-shard-wrk`, or a Rumble-only
worker) and never leaks into the shared WDK / Tether-Wallet / indexer base
(`wdk-*` / `bfx-*` / `svc-facs-*` / `*-base` / wallet libs). Default assumption is
**Rumble-only unless proven shared**. Uses one litmus test ("would a non-Rumble
consumer of this base want this change?"); when a base edit is unavoidable it
keeps the base generic via a hook and puts specifics in the fork (the RW-1998
`_isDuplicateWallet` / `_enablePromoWalletType` precedents). Produces a per-concern
layer map and **stops to ask Alex only when ownership is genuinely ambiguous**.
This skill is also run automatically by `handle-ticket` as a mandatory gate at
the start of its implementation flow (Step 5a), so it fires on every code change.

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

### Review a PR

**Triggers:** the word "review" (or "PR review" / "can you review" / "review
this") paired with one or more GitHub PR URLs. Examples:

- "review https://github.com/tetherto/rumble-app-node/pull/123"
- "review <link1> <link2>" (multiple PRs = one linked change set)

**Skill file:** `.claude/skills/review-pr/SKILL.md`

**Summary:** Reads the PR diff(s) via `gh`, compares against the local clone
(checking out the PR branch when integration context is needed), and weighs
architecture plus shared-library dependencies across the three sides (Rumble
`rumble-*`, Tether Wallet `wdk-*`, open-source/shared `bfx-*` / `svc-facs-*` /
`*-base` / wallet libs). Returns **only problems, severity-ordered (no cap,
skip pure nits, no positives)**, each with exact file, the exact line to
comment under, and a short plain-English paste-ready comment with **no em
dashes** (comments must read as human-written). Multiple PRs given together are
reviewed as one linked change. This is the single canonical PR reviewer: it
replaces the old `/pr-review` slash command and supersedes the generic built-in
`review` skill. **Never posts anything to GitHub** unless Alex later says so
explicitly.

### Access Dev Server

**Triggers:** any message asking to look at, run commands on, or operate the
Rumble dev VM. Examples:

- "ssh into rumble-dev" / "check rumble-dev" / "what's PM2 doing on dev"
- "tail the indexer log on dev" / "show me the ork log"
- "restart the orks on dev" / "is everything online on dev"
- Any investigation that requires looking at the actual server state (live
  PM2 list, on-disk config, restart timing, real logs).

**Skill file:** `.claude/skills/access-dev-server/SKILL.md`

**Summary:** Codifies the SSH access pattern for `rumble-dev` (Tailscale-
resolved, default key, login user `alexa`, `sudo -u work` for everything
PM2/wdk-related), the on-disk layout under `/home/work/wdk/` and
`/home/work/.pm2/`, the heredoc pattern needed for multi-line scripts,
common recipes (PM2 list, logs, restart, health check), and a hard
cleanup rule: never leave AI-authored files or scripts on the server —
prefer stdin/heredoc over writing to disk, and if `/tmp/` was used, `rm`
before the session ends.

### Access Staging Servers

**Triggers:** any message asking to look at, run commands on, or operate
the wallet staging cluster (`walletstg1` / `walletstg2` / `walletstg3`).
Examples:

- "ssh into walletstg1" / "check walletstg2" / "what's on staging"
- "tail the rumble-app-node log on staging" / "show staging caddy config"
- "who's the redis sentinel master in staging" / "is staging healthy"
- Any investigation that requires looking at staging server state.

**Skill file:** `.claude/skills/access-staging-servers/SKILL.md`

**Summary:** Codifies the SSH access pattern for the 3-node staging
cluster — Yubikey-gated SSH aliases, login user `alexs`, service user
`fcanessa` (NOT `work` like dev), PM2_HOME=`/srv/data/pm2`, the app at
`/srv/data/staging/rumble-app-node` (3 worker replicas per box on
ports 3000/3001/3002 behind Caddy at :443), Redis Sentinel cluster
`mystreams` over a Wireguard mesh, on-disk layout, common recipes
(worker listing, log tail, Caddy/Sentinel inspection, controlled
rolling restart), and the same hard cleanup rule as the dev skill.

### Check an Error on an Environment

**Triggers:** any message handing over an error (a Slack bug report, a
Sentry issue, or a raw log line) and asking whether it is still happening on
a live box, or whether a fix actually landed. Examples:

- "is this error still happening on staging/prod"
- "check if this error exists on dev / walletstg1"
- "did the fix deploy" / "is this still firing after the merge"
- pasting a log line or Slack report and asking to verify it on a real server

**Skill file:** `.claude/skills/check-error-on-env/SKILL.md`

**Summary:** Orchestration layer on top of `access-dev-server` /
`access-staging-servers`. Extracts a stable greppable signature from the
pasted error (strips pids/timestamps/ids/worker suffixes), picks the
environment, greps the live PM2 logs over a bounded time window (all three
staging replicas unless told otherwise), and correlates the hit to a known
`_tasks/` folder so a still-firing error against a `[DONE]` ticket reads as
"fix unmerged or undeployed". Read-only by default (never restarts or
redeploys), confirms the deployed commit before trusting a "not happening"
result, leaves no traces on the box, and never uses em dashes back to Alex.

### Find a Task Folder

**Triggers:** any message asking which `_tasks/` folder owns something
concrete in hand — a PR link, an error, a ticket id, local changes, or a
keyword. Examples:

- "find the ticket folder responsible for this [local changes]"
- "search for the task that had this PR in it: <github pr url>"
- "which task covers this error" / "did we already work on this"

**Skill file:** `.claude/skills/find-task/SKILL.md`

**Summary:** Local reverse-lookup over the 80+ folders under
`_tether-indexer-docs/_tasks/`. Classifies the input (PR URL / error
signature / ticket id / local git diff / keyword), greps the high-signal
files (`ticket.md`, `comments.md`, `HANDLING.md`, `root-cause.md`) plus the
folder names, ranks matches and confirms weak ones, and reports each with
ticket id and `[DONE]`/deploy status so a `[DONE]` folder behind a live error
reads as "fix unmerged or undeployed". Read-only (never renames or edits
folders); a confident "no existing ticket" beats a forced match. Natural
hand-off into `handle-ticket`; reused by `check-error-on-env` and
`sentry-triage` for their correlation step.

### Triage a Sentry Issue

**Triggers:** any message handing over a `sentry.rumble.work` issue link, or
relaying a Sentry error (often from the tech lead) and asking why it happens
or whether it is a backend issue. Examples:

- "investigate this Sentry issue <sentry.rumble.work url>"
- "why is this timing out in prod" with a Sentry link
- "is this a backend issue" with a pasted Sentry error

**Skill file:** `.claude/skills/sentry-triage/SKILL.md`

**Summary:** Uses the already-configured `sentry` MCP server
(`sentry-mcp-rumble` wrapper → `sentry.rumble.work`, org `rumble`; no token
needed from Alex). Resolves the issue in the right project/environment
(`rumble-wallet-backend` vs mobile `rumble-wallet-app`), reads the latest
event + stacktrace + tags, and traces it to the responsible `file:line`
across the layered WDK/Rumble services (respecting the app-node-HTTP vs
internal-HRPC split; using `read-remote-repo` for the deployed release).
States plainly whether it is a backend defect, a benign client rejection
reaching Sentry as an Error, or not ours. Correlates via `find-task`,
cross-checks live logs via `check-error-on-env`, optionally writes
`sentry-investigation-YYYY-MM-DD.md` into the task folder, and hands off to
`handle-ticket`. Read-only in Sentry (never resolves/assigns/mutes); no em
dashes back to Alex.
