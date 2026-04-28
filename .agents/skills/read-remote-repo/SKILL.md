---
name: read-remote-repo
description: Read code, diffs, or history from any private tetherto/* repo (Rumble, WDK, indexer, wallet libs), preferring local clones under `/Users/alexa/Documents/repos/tether/_INDEXER/` and falling back to `gh` or shallow git clones. Use when the file is not in a local clone, when a branch/tag/PR-specific view is needed, or when remote history is required.
---

# Read remote code for tether repos

## Access model (important)

There are local clones for most `tetherto/*` repos directly under:
`/Users/alexa/Documents/repos/tether/_INDEXER/`

- `gh` CLI is logged in as **AlexAtrx** and has `repo` access to private
  `tetherto/*` repos. Use it for PR metadata, issue metadata, and API reads.
- SSH git access via `git@github.com:tetherto/<repo>.git` works for clone,
  fetch, diff, and history reads. Existing local clones usually have
  `upstream` set to this URL.

For file contents, diffs, and history, prefer local clones first, then git.
For PR metadata and repository metadata, prefer `gh`. If one route fails,
fall back to the other before giving up.

## Decide local vs remote first

```bash
ls /Users/alexa/Documents/repos/tether/_INDEXER/ | grep -i '<repo-name>'
```

- Present + default branch + no specific ref requested → read locally with `Read`/`Grep`.
- Reach for remote when:
  - the repo isn't in the workspace
  - you need a specific ref (branch, tag, commit SHA)
  - you need PR-scoped files or a diff
  - local clone is stale and the user wants latest `main`

## Cache dir

All remote reads go into `/tmp/tetherto-cache/<repo>/`. This avoids re-cloning across tool calls within a session. If the cache exists, `git -C` into it and `fetch` instead of re-cloning.

## Recipe 1 — fetch one file (fastest)

```bash
REPO=wdk-data-shard-wrk
REF=main                                # branch / tag / SHA
FILE=workers/proc.shard.data.wrk.js

CACHE=/tmp/tetherto-cache/$REPO
if [ ! -d "$CACHE/.git" ]; then
  git clone --depth 1 --filter=blob:none --no-checkout \
    "git@github.com:tetherto/$REPO.git" "$CACHE"
fi
git -C "$CACHE" fetch --depth 1 origin "$REF"
git -C "$CACHE" sparse-checkout init --cone
git -C "$CACHE" sparse-checkout set "$(dirname "$FILE")"
git -C "$CACHE" checkout FETCH_HEAD -- "$FILE"

# now read it
cat "$CACHE/$FILE"
```

After this, use the normal `Read`/`Grep` tools against `$CACHE/<path>`.

## Recipe 2 — clone a whole subdirectory

Same as Recipe 1 but `sparse-checkout set workers/ config/` (multiple paths). Combines well with `Grep path=$CACHE/workers`.

## Recipe 3 — full shallow clone (when you need many files)

```bash
git clone --depth 1 "git@github.com:tetherto/$REPO.git" "/tmp/tetherto-cache/$REPO"
```

No sparse filter. Use for broad structural scans or when you will `Grep` the whole repo.

## Recipe 4 — fetch a PR

```bash
REPO=wdk-data-shard-wrk
PR=205
CACHE=/tmp/tetherto-cache/$REPO

# ensure cache exists (Recipe 1 bootstrap)
git -C "$CACHE" fetch --depth 1 origin "pull/$PR/head:pr-$PR"
git -C "$CACHE" checkout "pr-$PR"

# or get just the diff without checkout
git -C "$CACHE" fetch --depth 2 origin "pull/$PR/head"
git -C "$CACHE" log --oneline FETCH_HEAD -5
git -C "$CACHE" diff FETCH_HEAD~1 FETCH_HEAD
```

For PR metadata (title, reviewers, status), `gh` can still reach public metadata on private repos via issue/PR search sometimes, but the reliable path is to open the PR in the browser or parse with `git log`/`git show` locally.

## Recipe 5 — history / blame / commit lookup

```bash
CACHE=/tmp/tetherto-cache/$REPO
git -C "$CACHE" fetch --depth 50 origin main           # deepen as needed
git -C "$CACHE" log --oneline --follow -- <path>
git -C "$CACHE" show <sha>:<path>
```

If a `--depth 1` clone is too shallow for `git log`, run `git fetch --deepen 50` (or `--unshallow` for full history).

## Recipe 6 — list refs before cloning

```bash
git ls-remote "git@github.com:tetherto/$REPO.git" | head -40
git ls-remote --heads "git@github.com:tetherto/$REPO.git"
git ls-remote --tags  "git@github.com:tetherto/$REPO.git"
```

Cheap; does not clone anything.

## Recipe 7 — search across a repo (remote)

There is no cheap server-side grep for private repos under this access model. Two viable options:

1. Full shallow clone then `Grep path=/tmp/tetherto-cache/$REPO`.
2. Use `gh search code '<q>' --repo tetherto/<repo>` when GitHub code search
   is sufficient and the query can run against the repo.

## Resolve the right repo name

Common shorthand → canonical name (see `.claude/repos.md` for the full list):

- "the shard" → `wdk-data-shard-wrk` (WDK) or `rumble-data-shard-wrk` (Rumble overlay). Ask if unclear.
- "the ork" → `wdk-ork-wrk` (WDK) or `rumble-ork-wrk`.
- "the app node" / "the HTTP server" → `wdk-app-node` (authenticated wallet/user) or `wdk-indexer-app-node` (public API-key) or `rumble-app-node` (Rumble overlay).
- "base indexer" → `wdk-indexer-wrk-base`.
- "EVM/BTC/SOL/TON/TRON/Spark indexer" → `wdk-indexer-wrk-<chain>`.
- "processor" → `wdk-indexer-processor-wrk`.

## Housekeeping

- Cache dir `/tmp/tetherto-cache/` survives within the shell session. Don't delete it proactively; the user may make several related reads.
- If disk pressure becomes an issue, `du -sh /tmp/tetherto-cache/*` and remove oldest.
- Prefer sparse-checkout (Recipe 1/2) over full clone (Recipe 3) when you know the path. Cloning `wdk-data-shard-wrk` fully is ~100MB; sparse is kilobytes.

## When in doubt

- Cite repo/path@ref on findings: `tetherto/wdk-data-shard-wrk:workers/proc.shard.data.wrk.js@main`.
- If the user is about to **edit** code, use or pull the existing clone under
  `/Users/alexa/Documents/repos/tether/_INDEXER/<repo>/` rather than editing
  the cache copy.
- This skill is read-only. Do not push, PR, or comment from `/tmp/tetherto-cache/` clones.
