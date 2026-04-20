---
name: read-remote-repo
description: Read code, diffs, or history from any private tetherto/* repo (Rumble, WDK, indexer, wallet libs) by shallow-cloning via the `github-atrx` SSH alias. Use when the file isn't in a local clone, when you need a branch/tag/PR-specific view, or when the user asks about a repo not in `/Users/alex/Documents/repos/indexer/`.
---

# Read remote code for tether repos

## Access model (important)

There are **two** GitHub identities on this machine, and only one can see the private `tetherto/*` org:

- `gh` CLI is logged in as **AlexAtrx**, but this token does **not** have access to private tetherto repos. `gh api repos/tetherto/<private-repo>/...` returns 404 for most indexer/shard/ork/rumble repos.
- SSH alias `github-atrx` (defined in `~/.ssh/config`, key `~/.ssh/id_ed25519_atrx`) **does** have tetherto access. Every local clone uses `git@github-atrx:tetherto/<repo>.git`.

So for remote reads, **use git over SSH via the `github-atrx` alias**, not `gh api`. Use `gh` only for public tetherto repos (e.g. `wdk`, `wdk-wallet`, `wdk-wallet-*`, `wdk-docs`) or for cross-repo code search.

## Decide local vs remote first

```bash
ls /Users/alex/Documents/repos/indexer/ | grep -i '<repo-name>'
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
    "git@github-atrx:tetherto/$REPO.git" "$CACHE"
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
git clone --depth 1 "git@github-atrx:tetherto/$REPO.git" "/tmp/tetherto-cache/$REPO"
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
git ls-remote "git@github-atrx:tetherto/$REPO.git" | head -40
git ls-remote --heads "git@github-atrx:tetherto/$REPO.git"
git ls-remote --tags  "git@github-atrx:tetherto/$REPO.git"
```

Cheap; does not clone anything.

## Recipe 7 — search across a repo (remote)

There is no cheap server-side grep for private repos under this access model. Two viable options:

1. Full shallow clone then `Grep path=/tmp/tetherto-cache/$REPO`.
2. For **public** tetherto repos only: `gh search code '<q>' --repo tetherto/<repo>` works through the AlexAtrx `gh` auth.

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
- If the user is about to **edit** code, propose a full clone outside `/tmp` (or pulling the existing clone under `/Users/alex/Documents/repos/indexer/`) rather than editing the cache copy.
- This skill is read-only. Do not push, PR, or comment from `/tmp/tetherto-cache/` clones.
