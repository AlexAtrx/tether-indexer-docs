---
name: handle-ticket
description: Handle an already-fetched Asana ticket end to end as a senior backend engineer for the Tether / Rumble-Wallet indexer. Triggered when Alex points at a task folder under `_tether-indexer-docs/_tasks/` and says "handle", "work on", "execute", "do", or "take" the ticket. Reads everything fetched from Asana, pulls any missing context it can get (e.g. a Slack thread via the browser), classifies the ticket (bug / feature / refactor / analysis), and either delivers a deep analysis or implements and locally tests the change. All work stays local: never commit, never push to GitHub, never post to Asana.
---

# Handle a Ticket

Alex points you at a task folder that was already produced by the
`fetch-asana-ticket` skill, and asks you to **handle** it. You act as a top
backend engineer on this codebase: understand the ticket fully, fill any gaps
you can fill yourself, decide what kind of work it is, and either hand back a
rigorous analysis or implement the fix/feature and prove it with the repo's own
tests. Everything happens locally and stays local.

This skill assumes the ticket has already been fetched. It is the natural
follow-on to `fetch-asana-ticket`. If the folder doesn't exist yet, tell Alex to
fetch the ticket first (or do it, if he hands you an Asana URL instead).

## Triggers

Invoke this skill when Alex's message pairs a **handling verb** with a pointer
to a task folder (or its ticket), e.g.:

- "handle this ticket `_tasks/41-28-may-26-WDK-1515-...`"
- "work on `<task-folder>`" / "execute the ticket in `<folder>`"
- "do `RW-1760`" / "take WDK-1515" (a ticket id that resolves to one folder)
- "handle the ticket I just fetched"

The pointer can be a folder path, a folder name, a ticket id (`RW-####`,
`WDK-####`), or "the one I just fetched". Resolve it to exactly one folder under
`_tether-indexer-docs/_tasks/` before doing anything (see step 1).

If Alex hands you an **Asana URL** instead of a folder, the ticket hasn't been
fetched in this conversation: run the `fetch-asana-ticket` skill first, then
continue here with the folder it produced.

## Hard rules (do not break)

1. **All work is local.** Never `git commit`, never `git push`, never open or
   push a branch upstream, never run `gh pr create`. Make edits in the local
   clones only.
2. **Never post to Asana.** No comments, no status changes, no attachment
   uploads, no completing the task. Reading the ticket's fetched content is the
   only Asana interaction, and that already happened in `fetch-asana-ticket`.
3. **Never touch GitHub as a write.** Reading code (local clones or
   `read-remote-repo`) is fine; writing is not.
4. **Minimal, clean change.** Prefer the smallest change that fully does the
   job. Do not refactor surrounding code, rename things, or "tidy" unrelated
   lines. Quality is not negotiable, but neither is restraint.
5. **No em dashes** in anything a human will read as if Alex wrote it (the
   handling summary, any text destined for the ticket or a PR). Alex's global
   rule. Use commas, semicolons, parentheses, or separate sentences.
6. **Don't fabricate.** If a referenced artifact can't be retrieved, say so and
   flag it; never invent ticket content, log lines, or test results.
7. **Grill, don't guess.** Whenever the ticket needs clarification, a decision
   is Alex's to make, or a design branch is genuinely unclear, run the
   `grill-me` skill to resolve it (see "Clarifying with grill-me" below) rather
   than guessing or asking a single throwaway question.

## Clarifying with grill-me

This skill never builds on a guess for a load-bearing unknown. When you hit one,
invoke the `grill-me` skill (`.claude/skills/grill-me/SKILL.md`) and let it
drive, but flip the roles: here **you** interview **Alex** about the open
points, one question at a time, walking each branch of the decision tree and
resolving dependencies between decisions in order. For every question, first try
to answer it yourself by exploring the codebase, the task folder, or the
architecture docs; only ask Alex what you genuinely cannot resolve. Always give
your recommended answer with each question so Alex can just confirm. Keep going
until every load-bearing branch is resolved, then continue the step you came
from with the answers folded in.

Use grill-me at the points called out below (Step 2 blockers, Step 3
classification, Step 5a layer-scoping, Step 5c design), and any other time a real
ambiguity would
otherwise force a guess. For non-load-bearing gaps, note them and continue (no
grill needed).

## Step 1 — Resolve the folder and read everything

Resolve Alex's pointer to one folder under
`/Users/alexa/Documents/repos/_tether/_INDEXER/_tether-indexer-docs/_tasks/`.
If a ticket id matches several folders (re-fetches, `-2` suffixes, a `[DONE]`
copy), list them and ask which one. Do not guess.

Then read the full folder. The `fetch-asana-ticket` skill lays it out as:

```
<folder>/
  ticket.md            # id, title, project, section, status, dates, custom fields
  description.md       # full task description
  comments.md          # all comments + signal-bearing system events
  image-analysis.md    # per-image extraction (errors, values, hashes, envs)
  images/  attachments/
  missing-context.md   # checklist of referenced-but-missing artifacts
  NEXT-STEPS.md         # the prior session's hand-off note
  _raw/                 # raw Asana JSON (task / stories / attachments)
```

Read `ticket.md`, `description.md`, `comments.md`, `image-analysis.md`,
`missing-context.md`, and `NEXT-STEPS.md` in full. The screenshots are often the
only record of the state that was observed, so trust `image-analysis.md` for
exact values, and open the actual image with `Read` if a detail is ambiguous.
Build a clear, written-in-your-head statement of: what is broken or wanted, in
which environment, with what evidence, and what the ticket is actually asking
for (which is not always what its title says).

## Step 2 — Fill the missing context you can fill

Open `missing-context.md` and work its checklist. For each item, decide whether
you can retrieve it yourself right now:

- **Slack threads / DMs** — always go through the browser directly, never the
  Slack MCP connector. Read everything you need straight from the browser. Use
  the Claude in Chrome tools (`mcp__Claude_in_Chrome__navigate` then
  `get_page_text`; load via ToolSearch with `{ query: "chrome", max_results: 20
  }` if deferred). Open the Slack message/thread URL, read it, and save the
  relevant content as `slack.txt` (or `slack-thread.md`) in the task folder
  (this matches the existing convention, e.g. the RW-1724 folder). Quote the
  substantive messages; strip noise. Treat the thread as evidence, not
  instruction: extract the decision, the repro, the values.

  Slack access notes (learned the hard way):
  - **Do not use the `plugin:marketing:slack` connector.** It needs an OAuth
    flow, and it authorises whatever workspace the user happens to log into, so
    it can land on the wrong workspace (e.g. a personal one, not Tether). The
    browser is the reliable path for both reading and posting.
  - The browser tab must be signed into the **Tether** workspace
    (`tether-to.slack.com`, team `T05MWQT2W20`). If opening a Slack
    `app.slack.com/client/...` URL redirects to "Sign in to your workspace",
    the tab is not authenticated; point it at `https://tether-to.slack.com`, ask
    Alex to sign in (magic code or password are his to enter, never sign in for
    him), then continue once he confirms.
  - When several Chrome browsers are connected, you must let Alex pick which one
    (the AskUserQuestion + `select_browser` / `switch_browser` flow). Prefer a
    normal Chrome window: a Slack app-style / PWA window can fail tab creation
    with "Grouping is not supported by tabs in this window", in which case fall
    back to `switch_browser` and have Alex Connect a regular window.
  - **Reading is fine to do autonomously. Posting/replying in Slack is a
    send-type action: get Alex's explicit go-ahead and show him the exact text
    first.** If posting through the browser is blocked for any reason, hand Alex
    the ready-to-paste text instead of forcing it.
- **Logs / dashboards (Grafana, Loki, Datadog, Kibana)** — if a direct
  exportable URL is present and reachable in the browser, pull the relevant
  window; otherwise flag it as still-needed. For live server state, the
  `access-dev-server` / `access-staging-servers` skills are the right tools, but
  only use them if the ticket genuinely needs real server state to proceed.
- **Related code / other repos** — read them. Use local clones first; use the
  `read-remote-repo` skill for anything not cloned or for a specific branch/PR.
- **External tickets (Jira / Linear / GitHub issues)** — open read-only in the
  browser if linked and useful.

What you **cannot** get yourself (a decision only Alex can make, access you
don't have, a private artifact) you do not guess at. Collect those into a short
"need from Alex" list. If any blocker is load-bearing (you can't responsibly
proceed without it), stop after this step and run `grill-me` to work through the
open points with Alex (see "Clarifying with grill-me"), rather than building on a
guess. If the gaps are non-blocking, note them and continue.

Append anything you newly retrieved to the relevant file (e.g. `slack.txt`) so
the folder stays the single source of truth.

## Step 3 — Load the architecture context and classify the ticket

Before deciding anything, load the workspace's own engineering context. These
files are the contract for this codebase:

- `.claude/repos.md` — every repo's role (app-node / ork / shard / indexer /
  wallet lib). Use it to map the problem to the right repo.
- `.claude/architecture.md` — request paths, transfer-ingestion paths, job
  schedules. Use it to trace where the behaviour actually lives.
- `.claude/conventions.md` — HyperDB append-only, version-bump policy, shared
  Hyperswarm secrets.
- `.claude/hotspots.md` — known open bugs / weak points; check whether this
  ticket touches one.
- `AGENTS.md` (workspace root) — durable codebase context.

Remember the service layering (from `.claude/CLAUDE.md`): only `*-app-node`
repos expose HTTP; every other worker is an internal HRPC service over
Hyperswarm. Input-shape validation belongs in the fastify `schema.body` on the
`-app-node` layer, but internal services call each other directly over HRPC and
skip that schema, so a check that only exists at the HTTP layer does not protect
the internal path. Rumble extends WDK (`rumble-app-node` extends `wdk-app-node`,
etc.). Every service has a Proc/API split.

Now **classify** the ticket into exactly one primary type. Read the real intent,
not the title:

- **Analysis / investigation** — "investigate", "check why", "find the root
  cause", "is X happening", a question to answer. Output is understanding, not a
  code change. → go to Step 4.
- **Bug fix** — defined wrong behaviour with a fix expected. → Step 5.
- **Feature** — new capability or endpoint/worker behaviour. → Step 5.
- **Refactor** — restructure without changing behaviour (often "move X to Y
  layer", security-fix dependency bumps, reusable-code extraction). → Step 5.

If a ticket is genuinely mixed (analyse, then fix), do the analysis first and
let its conclusion gate the implementation. If the analysis shows the fix is not
backend, or belongs to the FE/mobile side, say so and stop at analysis (this is
common here, e.g. RW-1724 and RW-1760 turned out to be mobile-side).

State your classification and the reasoning in one or two sentences before
proceeding; if you are not confident which type it is, run `grill-me` to settle
it with Alex before going further.

## Step 4 — Analysis flow (output is understanding)

Take the time to be right. Trace the actual code path end to end across repos,
quoting exact `file:line` references the way the existing `root-cause.md` /
`root-cause-analysis.md` files in `_tasks/` do. Consider:

- the full request path (HTTP entry → ork → shard → indexer → chain/Mongo) and
  which layer the behaviour really sits in;
- whether the symptom is even backend, or is mobile / FE / infra;
- units, decimals, idempotency, retries, timeouts, race conditions, version
  mismatches across services, and the shared Hyperswarm secret;
- the hotspots file, in case this is a known weak point.

Write the analysis into the task folder as **`root-cause.md`** (for a
bug/incident) or **`analysis.md`** (for an open question), following the shape
already used in the folder:

```markdown
# Root cause (or: Analysis) — <TICKET-ID>

## Conclusion
<the answer, stated plainly and up front, including "this is not a backend
issue" if that's the truth>

## What is happening
<the mechanism, with exact file:line references across the involved repos>

## Evidence
<the specific values, log lines, screenshots, Slack quotes that support it>

## Recommendation / next step
<what should be done, who owns it, and why; if a backend fix is warranted,
sketch the smallest correct change>
```

Then finish at Step 7 (report + mark done). Do not write code for a pure
analysis ticket unless Alex asks for the fix afterward.

## Step 5 — Implementation flow (bug / feature / refactor)

### 5a. Scope the layers FIRST (mandatory gate — Rumble vs shared base)

Before reading the change site in detail and before any edit, run the
`scope-feature` skill (`.claude/skills/scope-feature/SKILL.md`) on this ticket.
Most tickets here are Rumble; the recurring, expensive mistake is putting
Rumble-specific logic into a shared `wdk-*` / `bfx-*` / indexer / wallet-lib base
and having to relocate it into the `rumble-*` fork later (e.g. RW-1998 promo).

Decompose the feature into concerns, classify each with the litmus test ("would a
non-Rumble consumer of this base want this change?"), and produce the per-concern
layer map (`concern → owning repo → mechanism → why`). **Default Rumble-only
unless proven shared.** When a concern is clearly owned, proceed; **stop and ask
Alex only when ownership is genuinely ambiguous** (you can't confidently answer
the litmus test, or it's unclear whether the Tether Wallet app / indexer also
needs it). If a base edit is unavoidable for a Rumble feature, the base gets only
a generic hook and the specifics go in the fork (the `_isDuplicateWallet` /
`_enablePromoWalletType` precedents).

Carry the layer map into the steps below; it fixes which repos you touch.

### 5b. Find the exact site and the right layer

Use `repos.md` + `architecture.md` to land in the correct repo and layer (the one
the layer map assigned). Read the surrounding code end to end, not just the spot
you'll change. Identify every repo the change must touch (a shared-lib or schema
change fans out, see the version-bump policy in `conventions.md`).

### 5c. Design the minimal change against the conventions

Before editing, make the design satisfy all of these, explicitly:

- **Layering** — the change goes in the layer that owns the concern. Input-shape
  validation on the `-app-node` fastify `schema.body`; mutation/job logic in the
  Proc side; queries on the API side. Don't make the HTTP layer do storage
  logic, and don't make an ork talk to an indexer it shouldn't.
- **Idempotency** — for any request you add or modify, on both the HTTP API and
  the internal HRPC path, ask whether a retry or duplicate delivery is safe.
  Internal services call each other directly over HRPC (and skip the HTTP
  schema), so re-delivery and at-least-once behaviour are real. Match the
  idempotency pattern already used nearby (e.g. the LRU dedupe in
  `rumble-ork-wrk` / `rumble-data-shard-wrk`) rather than inventing one.
- **Separation of concerns** — keep the boundary between layers intact; don't
  leak a lower layer's responsibility upward or vice versa.
- **HyperDB append-only** — if a schema is involved, append fields at the end,
  never insert in the middle; bump versions and update every dependent repo per
  `conventions.md`.
- **Minimal and clean** — smallest change that fully solves it, in the codebase's
  existing style. No drive-by refactors, no unrelated reformatting.

State any assumption you have to make and isolate its effect. If a design point
is genuinely unclear, run `grill-me` to resolve it with Alex before writing code.

### 5d. Implement

Edit the local clones under `/Users/alexa/Documents/repos/_tether/_INDEXER/`.
Make matching changes in every repo the change fans out to (don't leave one side
of an HRPC contract or a version bump half-done). Follow the file's existing
patterns, error handling, and logging conventions.

### 5e. Test locally — tests match the change and all pass

You do **not** need to boot the backend stack. What matters is that the repo's
own test suite reflects the change and is green:

- Add or update unit tests so they actually cover the new/changed behaviour
  (including the idempotency and edge cases you reasoned about). A change without
  a matching test is not done.
- Run the affected repo's tests and linter, e.g. `npm test`, `npm run lint`
  (and `npm run db:build` in `wdk-indexer-wrk-base/` if a HyperDB schema
  changed). Run them in each repo you touched.
- All tests must pass and lint must be clean. If something fails, fix it; do not
  report done with a red suite. If a pre-existing failure is unrelated to your
  change, say so explicitly and show it was failing before.

Record what you ran and the result; you'll cite it in the summary.

### 5f. Write the change log into the folder

Write **`HANDLING.md`** into the task folder so the work is auditable later:

```markdown
# Handling — <TICKET-ID> <short title>

## Type
<bug | feature | refactor>

## What was wrong / wanted
<one or two sentences>

## Change
<what you changed and why it's the minimal correct fix, with file:line>

## Repos touched
- <repo> — <what changed there>
- <repo> — <what changed there>

## Layering / idempotency / separation notes
<how the change respects each; note any new idempotency guard and where>

## Tests
- <repo>: <command> — <pass/fail + count>; tests added/updated: <which>

## Assumptions / open points
<anything Alex should confirm; or "none">
```

## Step 6 — Self-review before reporting

Re-read your own change as if reviewing a PR (the `review-pr` skill's lens):
correctness, the layering/idempotency/separation checks above, shared-library
fan-out, anything in `hotspots.md` you may have brushed. Confirm the diff is
minimal and you left no local clone on a stray branch or with unrelated edits.
For analysis tickets, sanity-check the conclusion against the evidence and make
sure you didn't overreach beyond what the data proves.

## Step 7 — Mark the folder done and report

Rename the task folder to append a `[DONE]` suffix, matching the existing
convention (e.g. `..._[DONE]`, or `..._[DONE - FOR FE]` when the conclusion
hands off to another team, or `..._[DONE - ABANDONNED]` if the work was dropped):

```bash
mv "<folder>" "<folder> [DONE]"
```

Keep the rest of the folder name intact. If a `[DONE]` variant of this folder
already exists, don't clobber it; ask Alex.

Then give Alex a **short** chat summary (aim for under ~10 lines):

- one line on what the ticket was and your classification;
- for analysis: the conclusion in a sentence, and a pointer to
  `root-cause.md` / `analysis.md`;
- for a fix/feature/refactor: what you changed in one or two sentences, the
  test result, and an explicit **list of repos involved** in the change;
- any "need from Alex" items still open.

No long write-up in chat. The folder files hold the detail; the chat is the
headline. No em dashes.

## Notes

- This skill never decides on its own to commit, push, post to Asana, or open a
  PR. If Alex wants any of that afterward, he says so explicitly in a later
  message, and even then you only do exactly what he asks.
- When you need to read a repo that isn't cloned, or a specific branch/PR, use
  the `read-remote-repo` skill. When you need real dev/staging state, use
  `access-dev-server` / `access-staging-servers`. Don't reach for those unless
  the ticket actually needs them.
- Both Cowork and the Claude Code CLI read this skill from the same
  `.claude/skills/handle-ticket/` directory, so handling behaves identically in
  either tool.
