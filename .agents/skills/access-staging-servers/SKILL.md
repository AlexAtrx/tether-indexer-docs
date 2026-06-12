---
name: access-staging-servers
description: Connect to the wallet staging cluster over SSH and inspect live staging services. Use when Alex asks to verify staging behavior, staging PM2 state, staging logs, staging config on disk, Redis Sentinel state, Caddy routing, or staging Mongo/ORK/shard data on walletstg1, walletstg2, or walletstg3.
---

# Access Staging Servers

Use this skill for the wallet staging cluster only. Staging hosts are
`walletstg1`, `walletstg2`, and `walletstg3`; each runs the full WDK/Rumble
stack, not just the HTTP app.

## Safety Rules

- Treat staging as shared live infrastructure. Read-only checks are fine; ask
  before restarting, editing, deleting, or running migrations.
- Batch work into one SSH session when possible. Each new `ssh walletstgN`
  may trigger Alex's YubiKey touch. Prefer single-host checks or sequential
  host checks over fast fan-out loops; the security-key backed SSH key can fail
  intermittently with `device not found` or `invalid format` when many SSH
  connections are opened back-to-back. If that happens, retry the same read-only
  command after Alex has touched/reattached the YubiKey instead of changing the
  command into a privileged workaround.
- Do not leave files or scripts on staging. Prefer `ssh ... 'bash -s' <<'REMOTE'`
  heredocs. If a temp file is unavoidable, put it in `/tmp`, use a neutral name,
  remove it before finishing, and verify removal.
- Never print secrets in the chat. Redact Mongo URIs, RPC keys, capability
  strings, tokens, and private config values.
- Do not commit or patch code on staging. Read deployed files only; normal code
  changes happen locally and deploy through the standard flow.

## Identity And Layout

- SSH aliases: `walletstg1`, `walletstg2`, `walletstg3`.
- Login user: `alexs`; passwordless `sudo` is available.
- Service user: `fcanessa`.
- PM2 home: usually `/srv/data/pm2`; verify if PM2 output is empty.
- Deployed staging repos live under `/srv/data/staging/`, including
  `rumble-app-node`, `rumble-ork-wrk`, and `rumble-data-shard-wrk`.
- PM2 logs normally live under `/srv/data/pm2/logs/`.
- Runtime Node is available in `fcanessa`'s login environment. For ad-hoc Node
  parsers or deployed package inspection, use `sudo -iu fcanessa node ...`;
  plain `sudo node ...` may fail with `node: command not found`.

First connectivity check:

```bash
ssh walletstg1 'whoami; hostname; uptime'
```

## PM2

Run PM2 as `fcanessa`. Prefer the login-shell form:

```bash
ssh walletstg1 'sudo -iu fcanessa pm2 list'
```

If that is empty, use explicit `PM2_HOME`:

```bash
ssh walletstg1 'sudo -u fcanessa PM2_HOME=/srv/data/pm2 pm2 list'
```

For multi-line read-only checks:

```bash
ssh walletstg1 'sudo -iu fcanessa bash -s' <<'REMOTE'
set -euo pipefail
pm2 jlist | jq -r '.[] | [.pm_id, .name, .pm2_env.status, .pm2_env.pm_cwd] | @tsv'
REMOTE
```

## Logs And Config

List logs:

```bash
ssh walletstg1 'sudo ls -la /srv/data/pm2/logs/ | head -40'
```

Tail a known process log:

```bash
ssh walletstg1 'sudo tail -n 200 /srv/data/pm2/logs/<name>-out.log /srv/data/pm2/logs/<name>-error.log'
```

Read deployed code/config:

```bash
ssh walletstg1 'sed -n "1,120p" /srv/data/staging/rumble-ork-wrk/config/common.json'
ssh walletstg1 'node -e "const p=require(\"/srv/data/staging/rumble-ork-wrk/package.json\"); console.log(p.version, p.dependencies)"'
```

For log parsing with Node, run it through the service user's login shell so the
same Node version and PATH used by PM2 are available:

```bash
ssh walletstg1 'sudo -iu fcanessa node - <<'"'"'NODE'"'"'
const fs = require("fs")
console.log(fs.readdirSync("/srv/data/pm2/logs").length)
NODE'
```

## Mongo Lookup Checks

For ORK lookup investigations, use the deployed repo's Mongo driver and config.
Do not print the URI. Run JavaScript from stdin:

```bash
ssh walletstg1 'cd /srv/data/staging/rumble-ork-wrk && node - <<'"'"'NODE'"'"'
const { MongoClient } = require("mongodb")
const conf = require("./config/facs/db-mongo.config.json").m0

async function main () {
  const client = new MongoClient(conf.uri)
  await client.connect()
  const db = client.db(conf.database)
  // Add focused read-only queries here.
  await client.close()
}

main().catch((err) => {
  console.error(err.message)
  process.exit(1)
})
NODE'
```

Useful read-only queries for shard lookup problems:

```js
await db.collection("wdk_ork_lookups").find(
  { value: /^wrk-data-shard-proc-/ },
  { projection: { _id: 0, type: 1, key: 1, value: 1, userId: 1 } }
).limit(20).toArray()

await db.collection("wdk_ork_lookups").aggregate([
  { $match: { value: /^wrk-data-shard-proc-/ } },
  { $group: { _id: "$value", n: { $sum: 1 }, types: { $addToSet: "$type" } } },
  { $sort: { _id: 1 } }
]).toArray()
```

`wdk_ork_lookups.value` holds the shard group for `users`, `wallets`, and
`channels`. `wdk_ork_wallet_id_lookups` maps address to wallet id; it does not
hold the shard group directly.

## Shard Identity Checks

The data-shard API announces the shard group returned by its paired proc
worker. To compare live shard groups with Mongo lookup values, collect:

- live `wrk-data-shard-*` process names and status from PM2;
- data-shard startup logs containing `Announced shard group`;
- `rumble-data-shard-wrk/status/*.json` and `rumble-data-shard-wrk/status`
  proc `instanceId` values if present;
- distinct `wdk_ork_lookups.value` values from Mongo.

If live shard groups and Mongo lookup values differ for the same rack prefix
such as `wrk-data-shard-proc-w-0-0-*`, existing users pointing to the old value
will hit `ERR_DATA_SHARD_NOT_FOUND`.
