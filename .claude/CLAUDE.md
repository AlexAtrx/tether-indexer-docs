# Indexer workspace — Claude entry point

Workspace root: `/Users/alex/Documents/repos/indexer/`
Scope: WDK + Rumble backend. All repos listed in `repos.md` are clones of `github.com/tetherto/<name>`.

## When the user asks for backend work

1. Read `repos.md` to pick the right repo by role (app node / ork / shard / indexer / wallet lib).
2. Check `architecture.md` for the request-path and proc/api split.
3. Read `conventions.md` before editing: HyperDB append-only, version-bump rules, shared Hyperswarm secrets.
4. Read `hotspots.md` for open bugs/weak points (RW-1526, RW-1601, balance/trend, etc.) before changing related code.
5. For setup/boot questions, `setup.md`.
6. Authoritative long-form truth lives in `_tether-indexer-docs/___TRUTH.md`; refer back to it if this summary is thin.

## Remote code access

All repos live under the private `github.com/tetherto/*` org. The user is authenticated
via `gh` CLI (`AlexAtrx`, scopes include `repo`). Use the `read-remote-repo` skill
under `skills/` when you need code for a repo that isn't cloned locally, or to check a
different branch/PR than the local checkout.

## Never do

- Do not invent file paths from memory. Verify with Grep/Read before citing.
- Do not edit HyperDB schemas by inserting fields in the middle (see `conventions.md`).
- Do not commit unless the user asks.
- Do not use em dashes in PR/issue/commit output (user global rule).
