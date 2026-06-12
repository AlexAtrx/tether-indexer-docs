# Description — WDK-1229 / RW-1730

> RESOLVE CONFLICTS + MERGE

---

## UPDATE

**PRS:** https://tether-to.slack.com/archives/C0A5DFYRNBB/p1779809767540199

**Related Asana task:** https://app.asana.com/1/45238840754660/project/1210540875949204/task/1214143657334762?focus=true

---

Currently it takes 30m to restart the dev env - this is too much - it's slowing
down the ability to deploy multiple times a day in DEV for smoke testing PRs.

Find slowest services (Indexer + Processor TON? - others) and either address the
issue if it's obvious and easy to fix
**OR**
Start discussion to remove them from the deployment temporarily (discussion
needed on Slack mentioning Francesco / Vigan about this).

**NOTE from Francesco:** I don't think we should scale the Dev env more than what
we already have - see screenshot.
(https://app.asana.com/app/asana/-/get_asset?asset_id=1213475123348186 — saved in
`images/`)

---

## LOG (from description)

A `time`-wrapped restart run. Key points extracted:

- "RESTARTING SHARDS" phase restarts pm2 ids 40–51 (`shard-0-proc` … `shard-2-2-api`), all `✓`.
- Full `pm2 list` snapshot follows: ~75 processes online — `app-0..2`, `ork-0..2`,
  `monitor`, the `idx-<chain>-{proc,N-api}` indexers (bitcoin, spark, usat-eth,
  usdt-arb, usdt-eth, usdt-plasma, usdt-pol, usdt-ton, usdt-tron, xaut-eth,
  xaut-ton), the `processor-<chain>` workers, `shard-*`, plus pm2 modules
  (`@pm2/io`, `pm2-logrotate`, `pm2-metrics`).
- Restart-count (`↺`) column shows indexers at 1–3 restarts, shards at 1.
- Final phase: "RESTARTING ORKS"
  ```
  ++ jq -r '.[] | select(.name | startswith("ork-w-")) | .pm_id'
  ++ xargs pm2 restart
    error: missing required argument `id|name|namespace|all|json|stdin'
  ```
  → the `ork-w-` selector matched **nothing** (the processes are named `ork-0/1/2`,
  not `ork-w-*`), so `xargs` called `pm2 restart` with no args and errored.

- **Total wall time:** `real 31m24.892s` (user 0m3.419s, sys 0m1.007s).
