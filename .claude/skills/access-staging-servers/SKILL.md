---
name: access-staging-servers
description: Connect to the wallet staging cluster (walletstg1 / walletstg2 / walletstg3), inspect or operate the staging rumble-app-node fleet, Redis Sentinel state, and Caddy routing. Use whenever Alex asks anything that requires looking at the actual staging environment — staging PM2 state, live logs, redis sentinel master, config on disk, reproducing a bug against staging.
---

# Access the wallet staging cluster

This skill captures the SSH access pattern and conventions for the **three
wallet staging VMs**. It is self-sufficient: no external setup is required,
every command below works from a fresh session.

This is the staging counterpart to [`access-dev-server`](../access-dev-server/SKILL.md).
The two environments are NOT alike — read "Identity model" carefully before
reusing recipes from the dev skill.

## Cluster overview

Three identical VMs that together serve the staging `rumble-app-node` (the
HTTP wallet API), fronted by Caddy and load-balanced across 3 worker
replicas per box. They share a Redis Sentinel cluster over a Wireguard mesh.

| Host        | Public IP        | WG IP    | Tailscale IP    |
|-------------|------------------|----------|-----------------|
| walletstg1  | 207.5.207.192    | 10.0.0.1 | 100.117.42.56   |
| walletstg2  | 207.5.195.109    | 10.0.0.2 | 100.101.155.20  |
| walletstg3  | 207.5.201.20     | 10.0.0.3 | 100.94.142.18   |

External hostnames (Caddy-fronted, TLS internal):
`wallet-8s4anfsr6it9.rumble.com`, `wallet-8s4anfsr6it9.rmbl.ws`.

There is no per-host role split — they're identical replicas. The only
"live" asymmetry is which box currently holds the Redis Streams Sentinel
master (rotates; query Sentinel rather than hard-coding).

**The full WDK / Rumble stack runs on every staging box.** Each of
walletstg1/2/3 hosts the HTTP wallet layer *plus* the orks, data shards,
chain indexers, processor workers, and any other supporting workers — they
are not isolated to other staging infra. If you're investigating
ork/shard/indexer behaviour on staging, this skill IS the right
environment; pick whichever box you need (or check all three, since
each instance is a full replica).

## Identity model (read before doing anything)

- Local SSH aliases: **`walletstg1`**, **`walletstg2`**, **`walletstg3`**.
  Each `ssh` invocation triggers a Yubikey biometric prompt — Alex must
  touch the key for every new connection. Batch work into a single ssh
  call wherever possible.
- Login user: **`alexs`** (NOT `alexa` as on rumble-dev). Alex is in
  `google-sudoers`, so `sudo` is passwordless.
- Service user: **`fcanessa`** (Francesco Canessa owns staging deploys).
  The `rumble-app-node` workers run under fcanessa's PM2 daemon — NOT
  under a `work` user (there is no `work` user on these boxes).
- Deploys are orchestrated by
  `/home/fcanessa/tmp/rumble_staging_deployment/deployer/server.js`
  (listening on `:9209`), not by `wdk-be-deploy`.

To verify connectivity once before a session:

```bash
ssh walletstg1 'whoami; hostname; uptime'
# expect: alexs / walletstg1 / load average ...
```

## What runs on each box (identical layout)

Every staging box is a full WDK/Rumble replica — the HTTP layer plus all
internal workers. When in doubt, `pm2 list` as fcanessa to see the full
inventory on that host; treat the items below as the always-present core.

- **3× `rumble-app-node` worker processes** bound to `127.0.0.1:3000`,
  `:3001`, `:3002`. Process title: `wrk-node-http-<pid>`. cwd:
  `/srv/data/staging/rumble-app-node`.
- **Orks, data shards, chain indexers, processor workers** — the rest of
  the WDK / Rumble service graph (`*-ork-wrk`, `*-data-shard-wrk`,
  `*-indexer-wrk-{chain}`, `*-indexer-processor-wrk`, etc.) all run under
  the same fcanessa PM2 daemon. They are NOT split off onto separate
  boxes; every staging host carries the full stack.
- **Caddy** on `:443` (`tls internal`) reverse-proxying / load-balancing
  across the three worker ports. Config: `/etc/caddy/Caddyfile`.
- **Docker containers:**
  - `wdk_redis` — the wdk app's Redis
  - `redis-streams` — Redis Streams instance, exposed on `:6380`
  - `redis_sentinel` — Sentinel on `:26379`, monitors cluster `mystreams`
  - `grafana-alloy` — observability agent (Grafana Alloy v1.4.2)
  - `redis-streams-exporter` — Prometheus exporter (stg1 only as of writing)
- **Redis Sentinel cluster `mystreams`**, quorum 2/3. Always query
  Sentinel for the current master — do not hard-code.
- node_exporter on `:9100`, pm2-metrics exporter on `:12345`, deployer on
  `:9209`.

The PM2 daemon for the workers lives under fcanessa, with
`PM2_HOME=/srv/data/pm2` (inferred from the pm2-logrotate module path
`/srv/data/pm2/modules/pm2-logrotate/...`). Confirm with `ls /srv/data/pm2`
on first use of this skill in a session.

## How to run anything as `fcanessa`

PM2-related operations belong to fcanessa. `sudo -u fcanessa pm2 list`
without environment setup returns empty (wrong / missing `PM2_HOME`).

Use one of these patterns. Try the first; fall back to the second if it
returns empty.

```bash
# Pattern 1 — login shell, picks up fcanessa's profile
ssh walletstg1 'sudo -iu fcanessa pm2 list'

# Pattern 2 — explicit PM2_HOME if Pattern 1 still returns empty
ssh walletstg1 'sudo -u fcanessa PM2_HOME=/srv/data/pm2 pm2 list'
```

For multi-line scripts, use the same Pattern B heredoc form as the dev skill:

```bash
ssh walletstg1 'sudo -iu fcanessa bash -s' <<'REMOTE'
set -u
pm2 jlist | jq -r '.[] | [.pm_id, .name, .pm2_env.status] | @tsv'
REMOTE
```

The **single-quoted heredoc tag (`<<'REMOTE'`) is required** — without it,
your local shell expands `$var` before the script reaches the server. Same
trap as on rumble-dev.

### When NOT to use `sudo -u fcanessa`

Anything global to the box (disk, kernel, network sockets, docker, caddy
config, system logs) runs fine as `alexs`:

```bash
ssh walletstg1 'df -h /; free -m; uptime; sudo docker ps'
ssh walletstg1 'sudo ss -tlnp | head'
```

Redis lookups can run as `alexs` directly — Sentinel and the Redis
containers are exposed on host ports:

```bash
ssh walletstg1 'redis-cli -p 26379 sentinel masters'
ssh walletstg1 'redis-cli -p 6380 INFO replication'  # streams instance
ssh walletstg1 'redis-cli -p 6379 INFO replication'  # wdk_redis instance
```

## On-disk layout (per box)

```
/srv/data/staging/
├─ rumble-app-node/          # the deployed app, cwd of the wrk-node-http workers
└─ ... (other staging artifacts may live here — verify before assuming)

/srv/data/pm2/               # PM2_HOME for fcanessa's daemon
├─ modules/pm2-logrotate/...
├─ modules/pm2-metrics/...
└─ logs/                     # rotated per-process logs
                             #   (confirm exact path on first use)

/home/fcanessa/tmp/rumble_staging_deployment/
└─ deployer/server.js        # the deploy controller (port 9209)

/etc/caddy/Caddyfile         # reverse-proxy config
```

## Common recipes

### List app-node workers + which port each binds

```bash
ssh walletstg1 'sudo ss -tlnp | grep -E ":300[012]"'
ssh walletstg1 'ps -ef | grep wrk-node-http | grep -v grep'
```

### Read app code on the server

The app cwd is `/srv/data/staging/rumble-app-node`. Read like any local file:

```bash
ssh walletstg1 'ls /srv/data/staging/rumble-app-node/'
ssh walletstg1 'cat /srv/data/staging/rumble-app-node/package.json'
```

For a different branch / tag / PR, or to look at non-deployed code, fall
through to the `read-remote-repo` skill — don't `git fetch` on the box.

### Tail logs

PM2 logs land under PM2_HOME (`/srv/data/pm2/logs/` per the observed
pm2-logrotate module path). Confirm the exact filename pattern on first
use:

```bash
ssh walletstg1 'sudo ls -la /srv/data/pm2/logs/ 2>/dev/null | head -20'

# Live tail via pm2 (works once PM2 env is right)
ssh walletstg1 'sudo -iu fcanessa pm2 logs <process-name> --lines 100'

# Snapshot tail of a specific file
ssh walletstg1 'sudo tail -n 200 /srv/data/pm2/logs/<name>-out.log /srv/data/pm2/logs/<name>-error.log'
```

### Caddy and routing

```bash
ssh walletstg1 'cat /etc/caddy/Caddyfile'
ssh walletstg1 'sudo systemctl status caddy --no-pager | head'
ssh walletstg1 'curl -sk https://localhost/healthz -o /dev/null -w "%{http_code}\n"'  # adjust path
```

### Redis Sentinel state

```bash
ssh walletstg1 'redis-cli -p 26379 sentinel masters'                 # current master IP/port
ssh walletstg1 'redis-cli -p 26379 sentinel sentinels mystreams'     # peer sentinels
ssh walletstg1 'redis-cli -p 26379 sentinel slaves mystreams'        # replicas
```

The Sentinel reports the master's Tailscale IP (e.g. `100.101.155.20` =
walletstg2). Map back to the host using the table at the top of this skill.

### Wireguard mesh

```bash
ssh walletstg1 'sudo wg show'           # peer status, last handshake, transfer
ssh walletstg1 'ip -4 addr show wg0'    # confirm 10.0.0.X
```

### Restart workers (DISRUPTIVE — confirm with Alex first)

This is staging, not prod, but it's still shared infra. Always confirm
before restarting.

```bash
# Restart one app-node worker on one box
ssh walletstg1 'sudo -iu fcanessa pm2 restart <process-name>'

# Restart all app-node workers on one box
ssh walletstg1 'sudo -iu fcanessa bash -s' <<'REMOTE'
pm2 jlist | jq -r '.[] | select(.name | test("rumble-app-node|wrk-node-http")) | .pm_id' | xargs -I{} pm2 restart --silent {}
REMOTE
```

To restart the cluster, do one box at a time and verify Caddy still has at
least two healthy upstreams before moving on. Do NOT restart all three
simultaneously.

### Quick health check across the cluster

```bash
for h in walletstg1 walletstg2 walletstg3; do
  echo "=== $h ==="
  ssh "$h" 'uptime; sudo ss -tln | grep -E ":300[012]" | wc -l'  # expect 3 listening
done
```

(Note: that's three Yubikey touches — once per ssh.)

## Cleanup rules (HARD REQUIREMENT)

Same standing instruction as for rumble-dev: **never leave AI-authored
files, scripts, or markers on staging boxes.** Concretely:

1. **Prefer stdin / heredoc over writing scripts to disk.** Pattern B
   above runs the script via `bash -s` from stdin — nothing lands on the
   box.
2. If you absolutely must write a temp file, put it under `/tmp/` only,
   use a neutral name (no `claude` / `ai` / `bot` markers), and `rm -f`
   it before the session ends. Confirm with `ls /tmp/...` returning
   nothing.
3. Never write to `/srv/data/`, `/home/fcanessa/`, `/etc/`, `/opt/`, or
   any path owned by another user / root outside `/tmp/`.
4. Do not commit on the server. The clone under
   `/srv/data/staging/rumble-app-node` is a deployment checkout — any
   code change goes through normal PR flow on your laptop, then a
   deploy via fcanessa's deployer.
5. Redact secrets when copying command output to local docs (sentinel
   auth, RPC keys, capability strings, etc.).

## Gotchas

- **Yubikey per ssh.** Every new `ssh walletstgN` call prompts for the
  Yubikey. Batch work into one ssh invocation where possible; pre-warn
  Alex when a recipe needs multiple connections.
- **No `work` user, no `wdk-be-deploy`.** Reusing dev-skill recipes that
  call `sudo -u work` or `wdk-be-deploy` will fail silently or talk to
  the wrong PM2 daemon. The staging service user is `fcanessa`.
- **`sudo -u fcanessa pm2 ...` returns empty without env.** Use `sudo
  -iu fcanessa pm2 ...` (login shell) or set `PM2_HOME=/srv/data/pm2`
  explicitly. Verify `PM2_HOME` path on first use in case it has changed.
- **Worker process title is opaque.** All three workers per box are
  named `wrk-node-http-<pid>` regardless of port. The mapping from PID
  to port comes from `sudo ss -tlnp | grep :300X`, not from the
  process name.
- **Caddy load-balances round-robin across `:3000/:3001/:3002`.** A
  single external request can hit any of the three replicas — don't
  assume sticky routing when reproducing a bug; tail logs on all three
  ports, or all three boxes, depending on scope.
- **Sentinel master rotates.** Don't memorize "stg2 is the master" —
  query Sentinel each time.
- **Tailscale-resolved aliases.** If `ssh walletstg1` errors with
  "Could not resolve hostname", check `tailscale status` locally.
- **Public IPs are in `207.5.x.x` (these are the externally-routable
  addresses).** Caddy is the only exposed surface (`:443`); the app
  worker ports are bound to `127.0.0.1` only.

## When to use this skill vs. `access-dev-server`

- **Dev (`rumble-dev`)** — single box, full WDK stack (orks, shards,
  chain indexers, app nodes), service user `work`, deployed via
  `wdk-be-deploy`. Use the `access-dev-server` skill.
- **Staging (`walletstg1/2/3`)** — three-box HA cluster, each box runs
  the full WDK/Rumble stack (rumble-app-node behind Caddy, orks, data
  shards, chain indexers, processor workers — all under fcanessa's PM2
  daemon), deployed via `rumble_staging_deployment/deployer`. Use this
  skill for anything that needs to look at staging, including chain
  indexers / orks / shards.
