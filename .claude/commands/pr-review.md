---
description: Review a PR. Output only issues, with file, exact code, and paste-ready comments.
argument-hint: <pr-url-or-number> [repo if just a number]
---

Review the PR: $ARGUMENTS

## What to do

1. **Fetch and read the PR fully.**
   - If `$ARGUMENTS` is a URL like `https://github.com/tetherto/<repo>/pull/<N>`, extract `<repo>` and `<N>`.
   - If only a number is given, ask which repo (don't guess).
   - Try `gh pr view <N> --repo tetherto/<repo>` and `gh pr diff <N> --repo tetherto/<repo>` first.
   - If `gh` returns 404 (access model in `.claude/skills/read-remote-repo/SKILL.md`), fall back to the SSH/git route: fetch `pull/<N>/head` via the `github-atrx` alias into `/tmp/tetherto-cache/<repo>/` and diff against the PR base.
   - Read the PR description, every changed file end-to-end (not just the diff), and the surrounding functions/classes the diff touches.

2. **Cross-check against local code for context and side effects.**
   - If the repo is cloned under `/Users/alex/Documents/repos/indexer/<repo>/`, prefer that for Grep/Read.
   - Hunt for:
     - callers/consumers of changed functions, schemas, config keys, cron fields
     - downstream Rumble overlays (`rumble-*`) that extend the same code
     - shared-lib impact (`wdk-indexer-wrk-base`, `wdk-app-node`, `wdk-data-shard-wrk`, `wdk-ork-wrk`) and whether dependents need a version bump (see `.claude/conventions.md`)
     - HyperDB schema edits (append-only rule)
     - config example drift (`*.json.example`)
     - tests that should have been updated
   - Read `.claude/hotspots.md` for areas already known to be fragile; flag interactions with those.

3. **Review critically.** Look for:
   - correctness bugs (off-by-one, null/undefined, race, cron syntax, wrong units, wrong topic name, silent catch)
   - design / layering violations (ork talking to indexers directly, HTTP layer doing storage logic, etc.)
   - performance (fan-out math, N+1 queries, unbounded loops, pipe not flushed on abort)
   - reliability (error swallowed, pipe cleared on failure, memory-only dedupe, missing retry/timeout)
   - maintainability (dead code, duplicated logic, magic numbers, names that lie, comments that describe WHAT instead of WHY)
   - security (auth bypass, plaintext secrets, shared-secret misuse, injection, log hygiene)
   - schema / migration safety (HyperDB append-only, Mongo index lock, breaking wire format)
   - missing tests for the risk surface

## Output format

**Only issues, risks, or weak spots. No positives, no summary of what the PR does.** One block per issue:

```
### [N]. <one-line title>
**File:** <relative/path/in/repo>[:<line-or-range>]
**Code:**
```<lang>
<exact code from the PR, or the phrase "entire file" if the whole file is the problem>
```
**Comment to post:**
> <paste-ready review comment, engineer-to-engineer, no fluff, no em dashes>
```

Rules for the output:

- Concise, direct, engineer-to-engineer. No hedging, no filler, no formal tone.
- **Never use em dashes (—) anywhere.** Use commas, semicolons, parentheses, or separate sentences.
- The "Comment to post" is what will literally be pasted onto GitHub. Make it land: state the problem, name the consequence, suggest the fix if obvious. Keep it short.
- Quote the exact code from the PR (copy it, don't paraphrase). Use "entire file" only when the whole file is structurally wrong (e.g. file shouldn't exist, is a duplicate, etc.).
- Order issues by severity: correctness/security/data-loss first, then design, then nits. Skip pure nits unless they compound (e.g. three dead imports in one file → one combined comment).
- If the PR is fine and you genuinely find nothing, say: "No blocking issues found." and stop. Do not pad.

## Do not

- Do not push anything to GitHub. No `gh pr review`, no `gh pr comment`, no `gh api ... -X POST`. Only fetch/read.
- Do not approve or request changes programmatically. The user pastes comments themselves.
- Do not edit files in the repo to "suggest" fixes. Put proposed code inside the comment body as a fenced block if needed.
- Do not summarize the PR or list what's good about it.
