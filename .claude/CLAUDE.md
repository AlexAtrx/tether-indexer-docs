# Indexer workspace — Claude entry point

Workspace root: `/Users/alex/Documents/repos/indexer/`
Scope: WDK + Rumble backend. All repos listed in `repos.md` are clones of `github.com/tetherto/<name>`.

## Service layering (always remember)

Only `*-app-node` repos expose HTTP. Every other worker (`*-ork-wrk`, `*-data-shard-wrk`, `*-indexer-wrk-*`, `*-indexer-processor-wrk`) is an INTERNAL HRPC service over Hyperswarm, despite the public-sounding names. Input-format validation (regex/pattern/shape on a request body) belongs in the fastify `schema.body` on the `-app-node` layer; that is the API boundary.

Two HTTP entries:
- `wdk-app-node` — wallet/user authenticated API. Extended by `rumble-app-node`.
- `wdk-indexer-app-node` — public indexer (API-key) for chain queries.

Request paths:
```
user → wdk-app-node (HTTP) → wdk-ork-wrk → wdk-data-shard-wrk → wdk-indexer-wrk-{chain} → chain RPC / Mongo

rumble-server → rumble-app-node (HTTP /api/v{1,2}/notifications)
              → rumble-ork-wrk (HRPC sendNotification[V2])
              → rumble-data-shard-wrk (HRPC addTxWebhook → Mongo tx-webhook queue → cron)
              → wdk-indexer-wrk-{chain} (HRPC getTransactionFromChain) → chain RPC

client → wdk-indexer-app-node (HTTP) → chain indexer topic RPC (`{blockchain}:{token}`)
```

Caveat: internal services can call each other directly via HRPC and skip the HTTP schema. Example: `rumble-app-node/workers/lib/services/moonpay.utils.js` calls the ork's `sendNotification` directly — the fastify schema does not run on that path. Validation at the HTTP layer is necessary but not sufficient on its own.

Every service has a **Proc / API split**: Proc owns mutations and runs jobs, prints a Proc RPC Key at boot; API takes queries and authenticates back to its Proc via `--proc-rpc <KEY>`.

All Hyperswarm services share `topicConf.capability` (handshake secret) and `topicConf.crypto.key`. Mismatch ⇒ services boot but never discover each other (silent failure).

## When the user asks for backend work

1. Read `repos.md` to pick the right repo by role (app node / ork / shard / indexer / wallet lib).
2. Check `architecture.md` for the full request-path breakdown, transfer-ingestion paths (shard polling vs Redis streams), and job schedules.
3. Read `conventions.md` before editing: HyperDB append-only, version-bump rules, shared Hyperswarm secrets.
4. Read `hotspots.md` for open bugs/weak points (RW-1526, RW-1601, balance/trend, etc.) before changing related code.
5. For setup/boot questions, `setup.md`.
6. Codex-oriented durable context now lives in root `AGENTS.md`; `_tether-indexer-docs/___TRUTH.md` was folded into it and should not be treated as an active source.

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
