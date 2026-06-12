---
name: review-pr
description: Review a GitHub PR (or several linked PRs) for the Tether / Rumble-Wallet indexer. Triggered when Alex says "review" with one or more PR links. Reads the diffs, compares against the local clones, weighs architecture and shared-library dependencies across the Rumble / Tether-Wallet / open-source sides, and returns only the problems (severity-ordered, no positives) — each with exact file, exact line to comment under, and a short plain-English comment to paste. Never posts anything to GitHub.
---

# Review a PR

Alex hands you a PR link (sometimes several) and the single word **"review"**.
You read the change, judge it hard, and hand back only the things that are
wrong, each ready to paste as a GitHub review comment — but you **never** post
it yourself.

This skill is the single canonical PR reviewer for this workspace. It replaces
the old `/pr-review` slash command and takes precedence over the generic
built-in `review` skill.

## Triggers

Invoke this skill when Alex's message is essentially **the word "review" plus
one or more GitHub PR URLs**, e.g.:

- "review https://github.com/tetherto/rumble-app-node/pull/123"
- "review <link1> <link2>" (multiple PRs — treat as one linked change set, see step 4)
- "review this" with a PR link, "can you review", "PR review", etc.

If Alex pairs a PR link with a *different* explicit instruction (e.g. "just
summarise this PR", "what does this PR do"), follow that instruction instead —
this skill is specifically the critical review flow.

## Hard rules (do not break)

1. **Never post anything to GitHub.** No review, no inline comment, no
   approval, no request-changes, no `gh pr review`, no `gh pr comment`, no
   `gh api ... -X POST`. The entire first phase of every review is read-only on
   GitHub. Only post if Alex *verbally and explicitly* tells you to in a later
   message — and even then, only what he asked for. Default is always: output
   the comments to Alex in chat, he pastes them himself.
2. **Only the bad stuff.** No positives, no summary of what the PR does, no
   padding, no compliments. If something is fine, it does not appear.
3. **Never use em dashes (—) in the comments you produce.** Em dashes make a
   comment look AI-written; these comments must read as a human engineer wrote
   them. Use commas, semicolons, parentheses, or separate sentences. (Alex's
   global rule, and it matters here specifically for human-looking comments.)

## What "review" means here — the procedure

### Step 1 — Get the diff and compare against local code

- Identify the repo and PR number from each URL (`tetherto/<repo>`). If only a
  bare number is given, ask which repo — do not guess.
- Pull the PR metadata and diff with `gh`:
  ```bash
  gh pr view <N> --repo tetherto/<repo> --json title,body,headRefName,baseRefName,files,additions,deletions
  gh pr diff <N> --repo tetherto/<repo>
  ```
- If `gh` returns 404 (access model in `.claude/skills/read-remote-repo/SKILL.md`),
  fall back to the SSH/git route: fetch `pull/<N>/head` via the `github-atrx`
  alias into `/tmp/tetherto-cache/<repo>/` and diff against the PR base.
- The repo is almost always cloned at the workspace root
  (`/Users/alexa/Documents/repos/_tether/_INDEXER/<repo>`). Compare the diff
  against that **local** copy so you see the surrounding code, not just the
  patch hunks. Read each changed file end-to-end and the functions/classes the
  diff touches, not only the added/removed lines. Most real problems live in
  how the change interacts with the lines around it.

### Step 2 — Check out the branch when it helps

If understanding the change needs you to see it integrated into the whole repo
(new call sites, how a shared helper is now used, whether something wires up),
check out the PR branch in the local clone for assurance:

```bash
cd /Users/alexa/Documents/repos/_tether/_INDEXER/<repo>
gh pr checkout <N>          # or: git fetch origin pull/<N>/head:pr-<N> && git checkout pr-<N>
```

Look around, run greps, trace call paths. **When done, restore the original
branch** (`git checkout <previous-branch>`) so you don't leave Alex's clone on
a PR branch. Do not commit, push, or modify anything.

### Step 3 — Think about architecture and dependencies (the core)

This system is **microservices that share common libraries**, so the most
dangerous bugs cross a boundary. Before judging the diff, load the relevant
context:

- `.claude/repos.md` — each repo's role (app-node / ork / shard / indexer / wallet lib).
- `.claude/architecture.md` — full request paths, transfer-ingestion paths, job schedules.
- `.claude/conventions.md` — HyperDB append-only rules, version-bump rules, shared Hyperswarm secrets.
- `.claude/hotspots.md` — known open bugs / weak spots; flag any interaction with these.

There are **three sides**, and dependencies between them matter a lot:

- **Rumble side** — `rumble-*` (app-node, ork, data-shard, promo-wrk, wallet-backend, ...).
- **Tether Wallet side** — `wdk-*` (app-node, ork, data-shard, indexer-*, core).
- **Open-source / shared base** — `bfx-*`, `hp-svc-facs-*`, `svc-facs-*`, `tether-wrk-*base`, `wdk-indexer-wrk-base`, wallet libs.

Dependency-aware questions to always ask of a PR:

- Does it change a **shared library** or base worker that other services
  depend on? A change in a `*-base` / `svc-facs-*` / `wdk-core` repo can break
  consumers that aren't in this PR. Find the callers/consumers.
- Does it bump or change a dependency **version** (package.json, git dep,
  HyperDB schema version)? Mismatched versions across services boot fine but
  silently never talk to each other (shared `topicConf` secret / schema).
- Does validation live at the right layer? Input-shape validation belongs in
  the fastify `schema.body` on the `-app-node` layer. But internal services
  call each other directly over HRPC and skip that schema — so a check that
  only exists at the HTTP layer may not protect the internal call path.
- Does it edit a **HyperDB schema** by inserting a field in the middle?
  (violates the append-only rule in `conventions.md`.)
- Rumble extends WDK (`rumble-app-node` extends `wdk-app-node`, etc.) — does a
  change on one side assume something the other side doesn't guarantee? Check
  the downstream `rumble-*` overlays of any `wdk-*` code that changed.
- Did config examples drift (`*.json.example`)? Did tests that cover the risk
  surface get updated?

### Step 4 — Multiple PRs are one change

If Alex gives several PR links at once, they are **linked** — together they fix
one bug, do one refactor, or ship one feature/improvement, usually across
several microservices. Review them as a single unit:

- Work out the relationship between them first.
- Judge each PR partly by whether it stays consistent with the others
  (matching version bumps, matching contract on both sides of an HRPC call,
  shared-lib change landed everywhere it's needed).
- Cross-PR mismatches are exactly what this skill exists to catch — call them out.

### Step 5 — Review critically

Look for, roughly in this severity order:

- **Correctness** — off-by-one, null/undefined, race, cron syntax, wrong units,
  wrong topic name, silent catch.
- **Security / data safety** — auth bypass, plaintext secrets, shared-secret
  misuse, injection, log hygiene, HyperDB append-only break, Mongo index lock,
  breaking wire format.
- **Design / layering** — ork talking to indexers directly, HTTP layer doing
  storage logic, validation at the wrong layer, etc.
- **Reliability** — error swallowed, pipe cleared/not flushed on abort/failure,
  memory-only dedupe, missing retry/timeout.
- **Performance** — fan-out math, N+1 queries, unbounded loops.
- **Maintainability** — dead code, duplicated logic, magic numbers, names that
  lie, comments describing WHAT instead of WHY, missing tests for the risk surface.

## Output format

Return **only the problems**, ordered worst-first (correctness/security/data-loss
first, then design, then the rest). No hard cap — list every real issue, but
skip pure nits unless they compound (e.g. three dead imports in one file → one
combined comment). One block per issue:

```
### [N]. <one-line title>
**File:** <relative/path/in/repo>[:<line-or-range>]
**Under this line:**
`the exact line of code from the PR to comment beneath`
**Comment to post:**
> <paste-ready comment>
```

Requirements per finding:

- **File** — the exact file path.
- **Under this line** — quote the *exact* code line the comment should sit
  under (copy it from the PR, don't paraphrase) so Alex finds it instantly. Use
  "entire file" only when the whole file is structurally wrong (shouldn't
  exist, is a duplicate, etc.).
- **Comment to post** — the text Alex pastes onto GitHub, written so that:
  - it is in plain, layman's terms, no jargon;
  - it is self-contained — a reader gets it without other context or another comment;
  - it has no implicit meaning or hidden assumptions;
  - it states the problem, names the consequence, and suggests the fix if obvious;
  - it is short (or average length at most), never long;
  - it contains **no em dashes**.

If the PR genuinely has nothing worth flagging, say "No blocking issues found."
in one line and stop. Do not invent findings to fill the list.

## Never

- Never post, comment, review, or approve on GitHub in this phase. Read-only.
- Never edit files in the repo to "suggest" fixes — put proposed code inside
  the comment body as a fenced block if needed.
- Never leave the local clone on the PR branch or with local edits.
- Never list good points, never summarize the PR, never pad.
- Never write a long or jargon-heavy comment, and never use an em dash — short,
  plain, human.
