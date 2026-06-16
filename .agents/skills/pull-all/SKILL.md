---
name: pull-all
description: Safely refresh every Git checkout under the Tether _INDEXER workspace. Use when Alex says "pull all", "/pull-all", asks to pull, refresh, update, or sync all repos in _INDEXER, or wants every clean repo moved to its integration branch and fast-forwarded while preserving dirty worktrees.
---

# Pull All

Refresh every direct-child Git checkout under the workspace root, then refresh the workspace docs repo itself. Preserve user work: skip dirty repos, never stash, reset, clean, rebase, merge, or push.

Run Git directly. Do not invoke `pull-all.sh` or any wrapper script.

## Workspace And Repo Set

1. Resolve the workspace from the invocation directory:
   `git rev-parse --show-toplevel`
2. Use that absolute path as `WORKSPACE`.
3. Discover code repos as direct children of `WORKSPACE` containing `.git/`:
   ```bash
   find "$WORKSPACE" -mindepth 2 -maxdepth 2 -type d -name ".git" -print \
     | sed 's|/.git$||' \
     | sort
   ```
4. Handle `WORKSPACE` itself separately as the docs repo.
5. Print:
   ```text
   Pull-all over <WORKSPACE>: <N> code repos + 1 docs repo
   ```

Only process direct child repos. Do not recurse into nested workdirs such as test harness clones.

## Code Repo Procedure

Process repos sequentially so each repo's output stays readable. For each repo `R`, set `NAME=$(basename "$R")`.

1. Pick the upstream remote.
   - Inspect `git -C "$R" remote -v`.
   - Prefer the remote whose fetch URL matches `git@github.com:tetherto/`.
   - Otherwise use `origin` if it exists.
   - If neither exists, record `no upstream remote` and continue.

2. Skip dirty repos before any fetch or checkout.
   - Run `git -C "$R" status --porcelain`.
   - If any output exists, read the current branch for reporting, record `dirty (skipped)`, and continue.
   - Do not switch branches, fetch, pull, stash, or clean a dirty repo.

3. Fetch with prune.
   - Run `git -C "$R" fetch --prune <remote>`.
   - If it fails, record `fetch failed` with the first stderr line and continue.

4. Resolve the target branch.
   - Check these candidates in order: `dev`, `develop`, `main`, `master`.
   - Use the first existing remote ref:
     `refs/remotes/<remote>/<branch>`.
   - If none exist, record `no dev/develop/main/master` and continue.
   - If a fallback branch is used, show that in the summary, for example `up to date (fell back from dev)`.

5. Switch clean repos to the target branch.
   - If already on `TARGET`, do nothing.
   - If local `TARGET` exists, run `git -C "$R" checkout "$TARGET"`.
   - Otherwise run `git -C "$R" checkout -b "$TARGET" "<remote>/$TARGET"`.
   - If checkout fails, record `checkout failed` with the first stderr line and continue.

6. Pull fast-forward only and stream Git output.
   - Print the per-repo header before pull output:
     ```text
     [NAME] <remote> -> <TARGET>
     ```
   - Run:
     ```bash
     git -C "$R" pull --ff-only --stat <remote> "$TARGET"
     ```
   - Keep the raw Git output visible, including `Updating abc..def`, file lists, diffstat, and `Already up to date.`
   - If Git refuses due to divergence, record `non-ff`.

## Docs Repo Procedure

Run the same safe procedure on `WORKSPACE` itself with these differences:

- Header:
  ```text
  [_INDEXER (docs)] origin -> main
  ```
- Use only `origin`.
- Use only `main`; do not consider `dev`, `develop`, or `master`.
- Skip if dirty before fetching or checking out.

## Summary

After all repos, print a compact table:

```text
== /pull-all summary ==
REPO                              BRANCH    STATUS
--------------------------------  --------  --------------------------------
wdk-app-node                      dev       up to date
rumble-app-node                   dev       pulled (14 files, +320/-87)
wdk-indexer-wrk-btc               dev       dirty (skipped)
hp-svc-facs-store                 main      up to date (fell back from dev)
_INDEXER (docs)                   main      pulled (2 files, +18/-3)

Pulled: P   Up to date: U   Skipped (dirty): D   Failed: F   Total: T
```

Use exactly these summary status strings where applicable:

- `up to date`
- `pulled (N files, +A/-B)` or `pulled` if the diffstat cannot be extracted
- `dirty (skipped)`
- `non-ff`
- `fetch failed`
- `checkout failed`
- `no upstream remote`
- `no dev/develop/main/master`

## Hard Rules

- Never run `git stash`, `git reset --hard`, `git checkout -- <path>`, `git clean`, or destructive commands to fix a dirty repo.
- Never push.
- Never rebase or merge.
- Never force-pull.
- Never delete or rename branches.
- Do not use `--allow-unrelated-histories`.
- Use `git -C "$R" ...`; do not `cd` between repos.
- Run repos sequentially.
- Do not hide or summarize per-repo Git pull output.
- Do not use em dashes in user-visible output.
