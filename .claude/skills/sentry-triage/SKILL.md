---
name: sentry-triage
description: Pull a Sentry issue from the Rumble self-hosted Sentry (sentry.rumble.work), read its latest event and stacktrace, trace it to the responsible file:line across the layered WDK / Rumble services, and produce a root-cause note. Use whenever Alex hands over a sentry.rumble.work issue link or shares a Sentry error from the tech lead and asks "why is this happening", "investigate this", or "is this a backend issue".
---

# Triage a Sentry issue

Alex (often relaying the tech lead) hands you a Sentry issue and wants a
backend engineer's read: what is actually failing, where in the code, is it
ours, and do we already have a ticket for it.

## Connection (already configured — do not ask for a token)

The `sentry` MCP server is wired up in `.mcp.json` as the
`sentry-mcp-rumble` wrapper, pointed at the self-hosted instance. You do not
need a token from Alex; the wrapper carries it. Past sessions where Alex
pasted a `sntryu_...` token were one-time setup of that wrapper — it is done.

- Host: `https://sentry.rumble.work/`  Org slug: **`rumble`**
- Projects and their environments (confirm with `find_projects`, do not
  assume — they change):
  - `rumble-wallet-backend` → `production`, `staging`
  - `rumble-wallet-app` (mobile) → `development`, `production` (no `staging`)

If the `mcp__sentry__*` tools are deferred, load them in one ToolSearch
call before starting:

```
ToolSearch "select:mcp__sentry__whoami,mcp__sentry__find_projects,mcp__sentry__search_issues,mcp__sentry__search_issue_events,mcp__sentry__search_events,mcp__sentry__analyze_issue_with_seer,mcp__sentry__get_issue_tag_values"
```

Sanity-check the connection once with `whoami` before relying on a "0 events"
result — an auth failure can masquerade as "nothing found".

## Step 1 — resolve the issue

- From a `sentry.rumble.work/organizations/rumble/issues/<id>` URL, pull that
  issue directly (id or short-id) in its project.
- From a pasted error with no link, `search_issues` in the project Alex named
  (default `rumble-wallet-backend` for a backend error) using the message
  stem / error code as the query, scoped to a sensible time window and
  environment.
- Pin down **which project and environment** the occurrence is tagged with
  before drawing conclusions. The Tip-Jar case (RW-1907) was tagged on the
  mobile app `production`, not backend `staging` — chasing the wrong project
  wastes the whole investigation.

## Step 2 — read the latest event

Pull the most recent event for the issue (`search_issue_events` /
`search_events`) and extract:

- the exception type + message and the **stacktrace frames** (file, function,
  line) — this is what you trace.
- tags that localize it: `environment`, `release`, `server_name` /
  `hostname`, `transaction`, `url`/`api host`, `user.id`, OS/device for
  mobile.
- frequency: first seen, last seen, count, and whether it is still arriving
  (a stale issue whose last event predates a known fix is the answer by
  itself).

## Step 3 — trace it to our code

This is the backend-engineer step the raw Sentry view does not do.

1. Map the stacktrace / `transaction` / `server_name` to a service using
   `repos.md` (role) and `architecture.md` (request path). Remember the
   layering: only `*-app-node` is HTTP; orks/shards/indexers are internal
   HRPC. An error surfacing at the app-node boundary often originates a hop
   deeper (e.g. RW-1940 was thrown in `wdk-data-shard-wrk` and propagated up
   over HRPC).
2. Open the cited file:line in the local clone. If the repo is not cloned or
   the deployed release differs from local `HEAD`, use
   [`read-remote-repo`](../read-remote-repo/SKILL.md) to read the exact
   release/branch. Do not guess paths from memory (see root `CLAUDE.md`).
3. State plainly whether it is a backend defect, a benign client-side
   rejection reaching Sentry as an Error (the RW-1940 shape — the fix is to
   downgrade the log level, not to change behaviour), or not our code at all.

Optionally run `analyze_issue_with_seer` for a second opinion, but treat it
as a hint to verify against the code, not as the conclusion.

## Step 4 — correlate and cross-check

- Run [`find-task`](../find-task/SKILL.md) on the error signature to see if a
  `_tasks/` folder already owns it. A `[DONE]` folder + a still-arriving event
  means the fix is unmerged or undeployed.
- If the question is "is it still happening on the boxes" (not just in
  Sentry), hand to [`check-error-on-env`](../check-error-on-env/SKILL.md) to
  grep the live logs — Sentry sampling/retention can hide a live error.

## Step 5 — report and (optionally) write it up

Lead with the answer: what is failing, the exact `file:line`, whether it is
ours, and the recommended action. Then frequency/scope and the matching
ticket (or "new — no folder yet").

If this is tied to a fetched task folder, write the analysis into it as
`sentry-investigation-YYYY-MM-DD.md` (the existing convention — see folder
72) or `root-cause.md`, in the same format `handle-ticket` produces. This is
the natural hand-off into [`handle-ticket`](../handle-ticket/SKILL.md) for
the actual fix.

## Hard rules

- **Read-only in Sentry.** Investigate only. Do not `update_issue` (resolve /
  assign / mute), `create_project`, or change anything in Sentry unless Alex
  explicitly says so.
- Confirm project + environment before trusting a result; verify "0 events"
  against `whoami` and the time window.
- Verify file:line against the actual deployed release, not just local HEAD.
- No GitHub/Asana posting from this skill. No em dashes in anything you hand
  back to Alex.
