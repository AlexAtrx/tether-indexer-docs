---
description: Sanity-check, branch, commit, and push current changes to the AlexAtrx fork, then return draft PR links for each affected tetherto repo.
argument-hint: <repo-name> | <sentence pointing to a feature/file>
---

Commit and push the in-flight changes for: $ARGUMENTS

## Hard rules

- **No AI attribution anywhere.** Commit messages, PR titles, and PR descriptions must NOT contain `Co-Authored-By: Claude`, `Generated with Claude Code`, "AI-assisted", or any similar marker. Pass commit messages with a HEREDOC and write the PR body explicitly so nothing is auto-appended.
- **Push only to the `fork` remote** (the user's `AlexAtrx/*` fork). Never push to `origin` (`tetherto/*`) — the user cannot create branches there. If a repo has no `fork` remote, stop and tell the user.
- **Never use `--no-verify`, `--no-gpg-sign`, `git commit --amend`, or `git push --force`.** If a hook fails, fix the cause and create a new commit.
- **No em dashes** in any commit message, PR title, or PR description (workspace global rule).
- **Workspace topology.** The workspace root is `_INDEXER` itself (commonly `/Users/alexa/Documents/repos/tether/_INDEXER/`), and that directory IS its own git repo — it is the docs repo, with `origin` = `git@github.com:AlexAtrx/tether-indexer-docs.git`. Its `.gitignore` ignores every top-level subdirectory and whitelists docs paths (`_tether-indexer-docs/`, `.claude/`, `*.md` at root, etc.). Code repos (`rumble-app-node`, `wdk-data-shard-wrk`, `wdk-ork-wrk`, etc.) are nested clones living as direct subdirectories of the workspace root and are intentionally ignored by the docs repo's gitignore — each is its own independent git repo.
- **Code repos vs the docs repo.** Code repos are non-`_` direct subdirectories of the workspace root (e.g. `rumble-app-node/`, `wdk-data-shard-wrk/`). The docs repo is the workspace root itself — never `_INDEXER/_tether-indexer-docs/` (that's just one whitelisted path inside the docs repo).

## Step 1 — Resolve the target repo(s) from context

You MUST determine which repo(s) to commit *before* running any git command.

1. Read the conversation that preceded `/commit`. Look for: explicit repo names (e.g. `wdk-data-shard-wrk`, `rumble-ork-wrk`), file paths (the first path segment under the workspace root identifies the repo), or recent Edit/Write tool calls.
2. If `$ARGUMENTS` is provided:
   - If it matches a folder name under the workspace root, use that repo.
   - Otherwise treat it as a hint pointing to a feature/file. Find the file (Glob/Grep) and use the repo it lives in.
3. If preceding conversation has **no** signal about which repo is in play AND `$ARGUMENTS` is empty or ambiguous: run `git -C <workspace-root> status --short` (the workspace root, e.g. `/Users/alexa/Documents/repos/tether/_INDEXER`, is itself the docs repo). If that returns changes and no code repo has changes, this is a **docs-only run** — skip Steps 2-6 entirely and jump straight to Step 7. Otherwise **stop and tell the user you don't know which repo to commit.** Do not guess from arbitrary `git status` calls.
4. Workspace root = `_INDEXER` itself (the cwd `/commit` is invoked from is normally this directory). Candidate code repos = direct subdirectories of the workspace root whose names do not start with `_`. To check changes inside a code repo, you must `cd` into it (or use `git -C <repo>`) — `git status` from the workspace root only sees docs-repo changes.
5. If multiple code repos have changes that belong to the same logical change (e.g. an indexer change paired with a shard change), include them all. Confirm the multi-repo set with the user in one short sentence before proceeding.

For each selected repo, run `git status --short` and `git diff --stat` to confirm there are real changes. If a selected repo has no changes, drop it.

**Filter out noise repos.** A code repo whose diff is only incidental churn unrelated to any fix, feature, or refactor must be skipped entirely (no branch, no commit, no PR). Treat the following as noise when they are the *only* thing changed:

- `package-lock.json` / `yarn.lock` / `pnpm-lock.yaml` drift with no `package.json` change in the same diff
- whitespace-only or trailing-newline edits
- editor/IDE artefacts (`.vscode/`, `.idea/`, `.DS_Store`, `*.swp`)
- generated `dist/` / `build/` / `coverage/` output
- timestamp-only or auto-formatter-only reflows

If after this filter every selected code repo is noise-only, tell the user that no code-repo PRs are needed and proceed straight to the docs commit step (Step 7). If a repo has *both* noise and real changes, stage only the real changes and leave the noise unstaged.

## Step 2 — Sanity check the changes

For every selected repo, before any git write:

1. Re-read each modified file end-to-end (not just the diff). Cross-check the diff against the surrounding function/class.
2. Run the repo's checks if they exist and are fast: `npm run lint`, `npm run typecheck`, `npm test` (only the obviously relevant suite — do not kick off long e2e runs without asking). Use `package.json` scripts as the source of truth; skip a step that doesn't exist.
3. Walk through this checklist and **flag + stop** on any hit:
   - secrets, tokens, `.env` contents, private keys, or prod credentials in the diff
   - `console.log`, `debugger`, `TODO/FIXME` left from debugging
   - commented-out code blocks added by this change
   - HyperDB schema edits that insert fields in the middle (append-only rule — see `.claude/conventions.md`)
   - missing version bump when a shared lib (`wdk-indexer-wrk-base`, `wdk-app-node`, `wdk-data-shard-wrk`, `wdk-ork-wrk`) changed in a way dependents would notice
   - `*.json.example` drift vs the real config keys touched
   - tests that should have been updated but weren't
   - files staged that look unrelated to the stated change (especially `package-lock.json` churn from an unrelated `npm install`)
4. If anything fails: report the specific issue with file:line, **do not commit**, and wait for the user.

## Step 3 — Branch handling

For each selected repo:

1. `git rev-parse --abbrev-ref HEAD` to read the current branch.
2. If the current branch is `dev`, `staging`, `main`, `master`, `prod`, or `production`: `git checkout dev` first (or whichever of those exists as the integration branch — check `git branch -a`), `git pull --ff-only fork dev` if a fork-side dev exists else from `origin`, then create the new branch from there.
3. If the current branch is already a feature branch, keep it (do not create a new one).
4. New branch name: derive a single name that reflects the change type and applies cleanly across all selected repos. Format: `<type>/<short-kebab-summary>` where `<type>` is one of `feat`, `fix`, `refactor`, `chore`, `docs`, `perf`, `test`. If a ticket is referenced in conversation, append `-<ticket-id>` (e.g. `fix/btc-received-tx-display-RW-1601`). Use the **same branch name** across every repo in the multi-repo set.

## Step 4 — Commit

For each repo:

1. Stage only the files that belong to this change. Prefer `git add <path>` over `git add -A` / `git add .` to avoid pulling in unrelated edits or generated files.
2. Write a commit message tailored to **that repo's** diff:
   - Subject (≤72 chars), imperative, no trailing period, no em dashes.
   - Body: one short paragraph on *why* + bullet list of *what* changed in this repo. Reference the ticket ID if known.
   - **Do not** include `Co-Authored-By`, `Generated with Claude Code`, or any AI attribution.
   - Different repos must get **different** messages — each describes its own diff. Do not paste the same body across repos.
3. Pass the message via HEREDOC:
   ```bash
   git commit -m "$(cat <<'EOF'
   <subject>

   <body>
   EOF
   )"
   ```
4. If a pre-commit hook fails: fix the underlying issue, re-stage, create a NEW commit (never `--amend`).

## Step 5 — Push to the fork

For each repo:

1. Confirm a `fork` remote exists pointing to `git@github.com:AlexAtrx/<repo>.git`. If not, stop.
2. `git push -u fork <branch-name>`.
3. If the push is rejected (non-fast-forward against an existing fork branch), stop and ask the user — do not force-push.

## Step 6 — Open draft PR(s)

For each repo, create a draft PR from `AlexAtrx:<branch>` into the upstream integration branch (usually `dev`; verify with `gh repo view tetherto/<repo> --json defaultBranchRef` and the repo's branching convention):

```bash
gh pr create \
  --repo tetherto/<repo> \
  --head AlexAtrx:<branch-name> \
  --base <upstream-base-branch> \
  --draft \
  --title "<title>" \
  --body "$(cat <<'EOF'
<body>
EOF
)"
```

PR content rules:

- **Title**: `<type>: <concise summary>` with optional ticket suffix, ≤72 chars, no em dashes.
- **Audience**: write so a product owner and a reviewing developer can both follow it. Stay at the behavior / outcome level. **Do not** name files, classes, functions, or fields. **Do not** quote code. **Do not** describe the diff line by line.
- **Length**: keep the body tight. Three short sections (Context, Changes, Why) of a couple of sentences or a short bullet list each is enough. If a section would just restate another, drop it.
- **Body** structure (omit a section if it doesn't apply):
  - **Context** — what prompted the change. If a bug, describe the symptom and the impact, not the code path. If a ticket is referenced, render it as `Ticket: [<ticket title>](<url>)` (plus any short ID suffix like `RW-1525 / WDK-1344`) so the title is the clickable link. Do **not** paste the raw URL on its own line.
  - **Changes** — bullet list of *what behavior changed* in this repo, in plain language. Each repo's PR body is repo-specific. No file paths, no symbol names.
  - **Why** — the reasoning / tradeoff, in one or two sentences.
- **Do not** include "Test plan", "How to test", or a testing checklist unless the change is risky enough to warrant manual verification steps. If you do include it, keep it tight.
- **Do not** include AI attribution, "Generated with Claude Code", or co-author lines.
- No em dashes anywhere.

If a PR for the same head branch already exists on that repo, do not create a duplicate — return the existing URL.

## Step 7 — Commit and push the docs repo

After every code repo above has been committed and pushed and PRs are open, also commit any in-flight docs changes. The **docs repo is the workspace root itself** (`_INDEXER/`, e.g. `/Users/alexa/Documents/repos/tether/_INDEXER`) — NOT `_tether-indexer-docs/`, which is just one whitelisted subdirectory inside it. All docs git operations run from the workspace root.

1. Stay at the workspace root (or use `git -C <workspace-root> ...`). Do **not** `cd` into `_tether-indexer-docs/` — that is a subdirectory of the docs repo, not the repo itself. Confirm with `git rev-parse --show-toplevel` if unsure; it should print the workspace root path.
2. The docs repo's `.gitignore` already ignores every code-repo subdirectory and whitelists docs paths (`_tether-indexer-docs/`, `.claude/`, root-level `*.md`, etc.), so `git status --short` from the workspace root only shows real docs changes — no risk of accidentally pulling in code-repo files.
3. **Do not create a new branch.** Stay on `main`. If HEAD is not on `main`, stop and ask the user — do not auto-checkout.
4. `git status --short`. If there are no changes, skip this step entirely (do not create an empty commit).
5. Stage explicitly. Typical paths: `_tether-indexer-docs/_tasks/<date-prefix>-<slug>/...`, `_tether-indexer-docs/TODO.md`, `.claude/commands/<file>.md`, root-level `*.md` updates. Use `git add <path>`; do not `git add -A`.
6. Commit with a descriptive message that references the same ticket / change as the code PRs, e.g.:
   - `docs(tasks): capture <slug> investigation and execution plan`
   - `docs(tasks): record findings for RW-1601 BTC received-tx display`
   - `docs: update TODO and add scope audit for <slug>`
   - `chore(claude): add /commit slash command`
   Subject ≤72 chars, no em dashes, no AI attribution, no `Co-Authored-By`. Pass via HEREDOC.
7. `git push origin main`. Origin already points at `AlexAtrx/tether-indexer-docs` — push directly, there is no fork remote here. If the push is rejected (someone else pushed in the meantime), `git pull --rebase origin main`, resolve any conflict, then push again. Do not force-push.

## Step 8 — Report back

Output a short summary to the user:

- One line per code repo: `<repo>` → branch `<name>` → PR `<url>`
- One line for docs: `tether-indexer-docs (workspace root)` → `main` → commit `<short-sha>` pushed
- If the sanity check stopped you anywhere, report exactly which repo and what you found, and confirm nothing was committed or pushed.
