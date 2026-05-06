---
description: Pull every git repo under the _INDEXER workspace onto its dev branch (fallback develop/main/master), plus the workspace docs repo on main. Skips repos with uncommitted local changes and reports per-repo status with the git pull output.
---

# /pull-all

Refresh every git checkout under the workspace root, then refresh the workspace's own docs repo. End state goal:

- every code repo sits on its integration branch (`dev`, falling back to `develop`, `main`, `master` in that order) and is fast-forwarded to the upstream tip,
- the workspace docs repo (the workspace root itself) sits on `main` and is fast-forwarded to its upstream tip,
- any repo with uncommitted local work is left alone and reported, never silently stashed or reset.

Run git directly. **Do not** invoke `pull-all.sh` or any wrapper script.

## Step 1. Resolve the workspace and the repo set

1. Workspace root = the directory `/pull-all` is invoked from. Confirm it is itself a git repository (the docs repo) with `git rev-parse --show-toplevel`. Use that absolute path as `WORKSPACE` for the rest of the run.
2. Discover code repos as the direct child directories of `WORKSPACE` that contain a `.git/` entry:
   ```bash
   find "$WORKSPACE" -mindepth 2 -maxdepth 2 -type d -name ".git" -print \
     | sed 's|/.git$||' \
     | sort
   ```
   Treat each result as one code repo. The workspace root itself (the docs repo) is handled separately in Step 3.
3. If no code repos are found, still proceed with the docs repo step.

Print a one-line header before starting:

```
Pull-all over <WORKSPACE>: <N> code repos + 1 docs repo
```

## Step 2. For each code repo, do this

Process repos sequentially so the streamed output stays interleaved cleanly per repo. Let `R` be the absolute path of the current repo and `NAME` be `basename "$R"`.

1. **Pick the upstream remote.**
   - List remotes: `git -C "$R" remote -v`.
   - If a remote URL matches `git@github.com:tetherto/` (fetch line), use that remote's name. This avoids pulling from the user's `AlexAtrx` fork by accident.
   - Otherwise fall back to `origin` if it exists.
   - If neither exists, record `no upstream remote` for `NAME` and continue to the next repo. Do not touch the repo.

2. **Detect uncommitted local changes.**
   - Run `git -C "$R" status --porcelain`. If the output is non-empty (any modified, staged, or untracked file), **do not switch branches, do not fetch, do not pull.** Record `dirty (skipped) on <current-branch>` in the report and continue. This is the user's safety net: their in-flight work must not be moved.
   - Read the current branch with `git -C "$R" rev-parse --abbrev-ref HEAD` for the report.

3. **Fetch with prune.**
   - `git -C "$R" fetch --prune <remote>`.
   - If fetch fails, record `fetch failed: <stderr first line>` and continue.

4. **Resolve the target branch.**
   - For each candidate in this exact order: `dev`, `develop`, `main`, `master`, check whether the remote ref exists with `git -C "$R" show-ref --verify --quiet "refs/remotes/<remote>/<branch>"`. The first hit is `TARGET`.
   - If none of the four exist on the chosen remote, record `no dev/develop/main/master on <remote>` and continue.

5. **Switch to the target branch if not already on it.**
   - If `current-branch == TARGET`, skip the switch.
   - Else if a local branch named `TARGET` already exists (`git -C "$R" rev-parse --verify --quiet "refs/heads/TARGET"`): `git -C "$R" checkout "$TARGET"`.
   - Else create a tracking branch: `git -C "$R" checkout -b "$TARGET" "<remote>/$TARGET"`.
   - The repo was confirmed clean in step 2, so checkout is safe. If the checkout still fails, record `checkout failed: <stderr first line>` and continue.

6. **Pull and stream the raw output.**
   - Run `git -C "$R" pull --ff-only --stat <remote> "$TARGET"` and capture both stdout and stderr.
   - Print the verbatim git output to the user under the per-repo header (do not reformat, summarise, or strip the diffstat). The user wants to eyeball how much code came down, so keep messages like `Updating abc..def`, the file list, the `N files changed, +A, -B` line, or `Already up to date.` exactly as git printed them.
   - If git refuses with a non-fast-forward error, record `non-ff: local <TARGET> diverged from <remote>/<TARGET>` and continue. Never auto-merge or rebase.

Per-repo header to print before step 6's pull output:

```
[NAME] <remote> -> <TARGET>
```

## Step 3. The docs repo (workspace root)

Run the same procedure on `WORKSPACE` itself, with these differences:

- The branch priority list is just `[main]`. Do not consider `dev`, `develop`, or `master` for the docs repo, even if they exist locally.
- The remote is `origin` as-is (the docs repo's `origin` points at the user's `AlexAtrx/tether-indexer-docs` fork, not `tetherto/`, so the `tetherto` filter from Step 2.1 does not apply here).
- All other rules carry over: skip if dirty, fetch with prune, fast-forward only, stream raw `git pull` output.

Header for the docs repo:

```
[_INDEXER (docs)] origin -> main
```

## Step 4. Final summary

After every repo (code repos + docs repo) is done, print a compact table. Keep it tight; this is the at-a-glance view.

```
== /pull-all summary ==
REPO                              BRANCH    STATUS
--------------------------------  --------  --------------------------------
wdk-app-node                      dev       up to date
rumble-app-node                   dev       pulled (14 files, +320/-87)
wdk-indexer-wrk-btc               dev       dirty (skipped)
hp-svc-facs-store                 main      no dev branch (fell back to main)
_INDEXER (docs)                   main      pulled (2 files, +18/-3)

Pulled: P   Up to date: U   Skipped (dirty): D   Failed: F   Total: T
```

Status vocabulary (use exactly these strings; pick the first one that applies):

- `up to date` — git pull printed `Already up to date.`
- `pulled (N files, +A/-B)` — extracted from git's diffstat. If the diffstat is missing, `pulled` alone is fine.
- `dirty (skipped)` — uncommitted local changes blocked the run.
- `non-ff` — local branch diverged from the upstream tip.
- `fetch failed` — fetch errored.
- `checkout failed` — checkout errored even though the repo was clean.
- `no upstream remote` — neither a `tetherto`-matched remote nor `origin` existed.
- `no dev/develop/main/master` — none of the four candidate branches existed on the chosen remote.

If the same repo took a fallback branch (e.g. dev was missing so we used main), suffix the status with ` (fell back from dev)` or similar so it is visible at a glance.

## Hard rules

- Never run `git stash`, `git reset --hard`, `git checkout -- <path>`, `git clean`, or any other destructive command to "fix" a dirty repo. Skip it and report it. The user explicitly wants in-flight work preserved.
- Never push. Never force-pull. Never `--rebase`. Never `--allow-unrelated-histories`.
- Never delete or rename a branch.
- The docs repo's only allowed branch is `main`. Do not switch it to anything else even if `dev` happens to exist locally.
- Use `git -C "$R" ...` everywhere. Do not `cd` between repos; it makes the streamed output harder for the user to follow and risks leaving the shell in the wrong directory if a step errors out.
- Do not call out to `pull-all.sh` or any other shell wrapper. Every git operation in this command must be issued directly.
- Run repos sequentially. Do not background or parallelise; the user wants the per-repo pull output in a readable order.
- No em dashes anywhere in the output (workspace global rule).
