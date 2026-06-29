# Tether Indexer — Project Instructions

This is Alex's workspace for the Tether / Rumble-Wallet indexer repos. Day-to-day
work is driven by Asana tickets (see `_tether-indexer-docs/TODO.md` for the
current local queue) and investigations land as task folders under
`_tether-indexer-docs/_tasks/`.

## Always-loaded context

When starting work in this workspace, load this `AGENTS.md` file first. It is
the durable context file for Codex. Then load `_tether-indexer-docs/TODO.md`
only when the current queue or priorities matter.

For implementation work, prefer the closest source and task context over memory:
read the relevant `_tether-indexer-docs/_tasks/<folder>/`, then verify claims
against code with `rg`, `sed`, `git show`, or tests before citing line numbers.
Use `.claude/repos.md`, `.claude/architecture.md`, `.claude/hotspots.md`,
`.claude/conventions.md`, and `.claude/setup.md` as supporting maps when they
match the task.

`_tether-indexer-docs/___TRUTH.md` was intentionally folded into this file and
should not be recreated as a parallel source of truth.

## Durable engineering context

- Only `*-app-node` repos expose HTTP. `wdk-app-node` is the authenticated
  wallet/user API, `rumble-app-node` extends it for Rumble routes, and
  `wdk-indexer-app-node` is the public API-key indexer API. Every `*-ork-wrk`,
  `*-data-shard-wrk`, `*-indexer-wrk-*`, and `*-indexer-processor-wrk` service
  is internal HRPC over Hyperswarm. Request-body validation belongs at the
  Fastify `schema.body` HTTP boundary, but internal HRPC callers can bypass it.
- Main paths:
  - Wallet/user: `wdk-app-node` -> `wdk-ork-wrk` -> `wdk-data-shard-wrk` ->
    `wdk-indexer-wrk-{chain}` -> chain RPC.
  - Rumble notifications: `rumble-app-node` `/api/v{1,2}/notifications` ->
    `rumble-ork-wrk` `sendNotification[V2]` -> `rumble-data-shard-wrk`
    `addTxWebhook` -> Mongo tx-webhook queue -> cron -> chain indexer RPC.
  - Public indexer: `wdk-indexer-app-node` -> chain indexer topic RPC
    (`{blockchain}:{token}`).
- Services follow a Proc/API split. Proc workers own writes/jobs and emit a proc
  RPC key at boot; API workers answer reads and authenticate to the Proc with
  `--proc-rpc <KEY>`.
- Hyperswarm discovery depends on shared `topicConf.capability` and
  `topicConf.crypto.key`. Mismatches usually look like healthy services that
  never discover each other.
- Chain indexers and shards support `dbEngine: hyperdb | mongodb`. Ork and
  processor lookup storage support `lookupEngine: autobase | mongodb`. Rumble
  shard deployments are Mongo-oriented; upstream `wdk-data-shard-wrk` defaults
  still lean HyperDB in examples.
- Transfer ingestion has two active paths: shard polling via `syncWalletTransfers`
  and Redis streams (`@wdk/transactions:{chain}:{token}` -> processor ->
  `@wdk/transactions:shard-{shardGroup}`). Freshness bugs need evidence across
  indexer, processor, shard, and app rather than assuming the chain indexer is
  stale.
- `_wdk_docker_network_v2` is a Rumble-focused local stack, not a full
  multi-chain production mirror. Its `make up` target starts Mongo and Redis;
  `make up-all` is the broader stack.

## Repo role map

- HTTP/API: `wdk-app-node`, `rumble-app-node`, `wdk-indexer-app-node`.
- Routing/lookup: `wdk-ork-wrk`, `rumble-ork-wrk`.
- Canonical wallet, balance, user-data, and transfer storage:
  `wdk-data-shard-wrk`, with Rumble overlay behavior in `rumble-data-shard-wrk`.
- Stream bridge: `wdk-indexer-processor-wrk`.
- Chain workers: `wdk-indexer-wrk-base`, `wdk-indexer-wrk-evm`,
  `wdk-indexer-wrk-btc`, `wdk-indexer-wrk-solana`, `wdk-indexer-wrk-ton`,
  `wdk-indexer-wrk-tron`, and `wdk-indexer-wrk-spark`.
- SDK-side code such as `wdk-core` lives outside the indexer runtime path.

## Known hotspots

Before changing nearby code, read `.claude/hotspots.md`, the relevant task
folder, and the source itself.

- RW-1526: `sparkDepositAddress` is registered and matched as wallet-owned BTC
  history, causing MoonPay-to-Spark deposits to appear in BTC transfer history
  while BTC balance excludes them.
- RW-1601: Rumble notification schemas accept numeric `amount` values and
  templates interpolate raw amounts, so IEEE-754 artifacts can reach users. The
  safer contract is decimal strings plus defensive formatting.
- `/api/v1/balance/trend`: `syncBalancesJob` has known partial-success and
  abort/flush failure modes; empty trend data is not necessarily an app bug.
- Legacy transfer APIs return flat wallet-transfer rows. No grouped logical
  transaction-history v2 pipeline is shipped in runtime code.
- BTC history/balance is fragile: sender-side rows lack fee/change/input context
  in shard history, self-transfer dedupe is weak, and balance reads rely on
  `scantxoutset` with busy-state failures.
- Solana `sync-tx` is disabled at proc startup unless code has changed.
- Notification dedupe and manual-notification idempotency are memory-only unless
  a later task added durable storage.
- MoonPay missing `externalCustomerId` paths warn and skip delivery;
  `SWAP_COMPLETED` has historically been unsupported.
- Rumble Swagger/docs auth has had dangerous fallback credentials when
  `docsAuth` config is missing. Verify before exposing docs.

## Project-local skills

When Alex triggers one of these, read the full skill definition from the path
below and follow it exactly. Codex skill files live under `.agents/skills/`.
They stay inside this repo so they stay in sync with the task-folder
conventions used here.

### Fetch Asana Ticket

**Triggers:** any message pairing an Asana task URL with a verb like "get",
"fetch", "pull", "grab", "save", or "create a task for this ticket". Examples:

- "get this ticket https://app.asana.com/.../task/1214000621998015"
- "fetch Asana ticket https://app.asana.com/.../task/..."
- "create a task for this ticket https://app.asana.com/.../task/..."

**Skill file:** `.agents/skills/fetch-asana-ticket/SKILL.md`

**Summary:** Fetches the ticket's description, comments, and attachments from
the Asana API, downloads images, analyses them, and writes everything into a
new `_tether-indexer-docs/_tasks/DD-mon-YY-N-short-title/` folder. Flags any
referenced-but-missing context (Slack threads, logs, external tickets) in a
`missing-context.md` so the ticket can be picked up later with a clear list of
what to ask Alex before starting work.

### Refresh Tether TODOs

**Triggers:** any message asking Alex's TODO / ticket queue to be pulled,
refreshed, or summarised in this `_INDEXER` workspace. Examples:

- "find my TODOs" / "show my TODOs" / "what's on my plate"
- "update my TODOs" / "refresh my TODOs" / "refresh my tickets"
- "get my Asana TODOs" / "pull my Asana tasks" / "sync my tickets"
- "stand-up notes" / "prep me for stand-up"

**Skill file:** `.agents/skills/refresh-todos/SKILL.md`

**Summary:** Pulls every incomplete task assigned to Alex from Asana
(`users/me` task list) and rewrites `_tether-indexer-docs/TODO.md` with
sections by status and priority. Surfaces up to 5 top-priority items with a
1–2 sentence stand-up brief distilled from each ticket's latest comment and
description, and links each item to its local `_tasks/<folder>/` if one
exists. Uses the same Asana token as the fetch skill at
`/Users/alexa/Documents/repos/brain_v1/projects/tether/.asana-token`. Does
not touch the brain_v1 TODO file.

### Read Remote Repo

**Triggers:** any request to read code, diffs, or history from a private
`tetherto/*` repo that is not present locally, or that needs a specific branch,
tag, commit, or PR view.

**Skill file:** `.agents/skills/read-remote-repo/SKILL.md`

**Summary:** Prefers local clones under this `_INDEXER` workspace, then falls
back to `gh` or shallow git clones for remote reads. This skill is read-only and
does not push, open PRs, or edit `/tmp/tetherto-cache/` clones.

### Access Staging Servers

**Triggers:** any request to inspect, verify, reproduce, or diagnose behavior
on the wallet staging cluster (`walletstg1`, `walletstg2`, `walletstg3`),
including staging PM2 state, live logs, deployed config, Caddy routing, Redis
Sentinel, or staging Mongo/ORK/shard lookup data.

**Skill file:** `.agents/skills/access-staging-servers/SKILL.md`

**Summary:** Connects to the wallet staging cluster over SSH, runs read-only
checks safely, uses `fcanessa`'s PM2 daemon correctly, and provides a
redaction-safe Mongo lookup workflow for ORK/data-shard investigations. Avoids
leaving files on staging and requires confirmation before disruptive actions.

### Address PR Comments

**Triggers:** any request to evaluate, address, reply to, push back on, refactor
for, fix, or otherwise handle GitHub PR review comments. Also use when Alex
asks for short Slack-ready answers about PR comments.

**Skill file:** `.agents/skills/address-pr-comments/SKILL.md`

**Summary:** Links the PR to its original ticket/context, checks out the PR
branch locally, reads thread-aware GitHub review comments, decides which
comments deserve local code changes versus reply-only handling, applies scoped
local refactors without committing or pushing on the first pass, and drafts a
short casual console reply for every PR comment without posting to GitHub until
Alex explicitly approves a specific write action.

### Pull All

**Triggers:** "pull all", "/pull-all", or requests to pull, refresh, update, or
sync every repo in this `_INDEXER` workspace.

**Skill file:** `.agents/skills/pull-all/SKILL.md`

**Summary:** Refreshes every direct-child Git repo by skipping dirty worktrees,
preferring `tetherto` remotes, switching clean repos to `dev` with
`develop`/`main`/`master` fallbacks, fast-forward pulling with raw Git output,
and handling the workspace docs repo separately on `main`.
