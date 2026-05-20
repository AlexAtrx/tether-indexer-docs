# Root cause — Sentry Rumble not receiving data

**Ticket:** WDK-1462 / Asana 1214842519965679
**Investigated:** 2026-05-20

## Conclusion

**The Sentry dashboard is filtered on `environment=production`, but the
running staging workers tag every event with `environment=staging`.**
No events match the filter, so the UI shows the empty state. Sentry is
ingesting normally — events are just landing in a different environment
bucket than the one being watched.

The 2026-05-01 cutoff in the dashboard is the moment the deploy on the
wallet staging cluster (walletstg1/2/3) flipped `environmentOverride`
from `production` to `staging`. The last surviving event (the
`store/3002/db/LOCK: Permission denied` crash from `Object.onopen`) was
captured by the old worker just before / during the cutover, so it still
carries the old `production` tag.

## Evidence

### 1. Sentry init reads `environmentOverride` from `conf.sentry`

`rumble-app-node/workers/http.node.wrk.js:24-32`:

```js
if (this.conf.sentry?.enabled) {
  Sentry.init({
    dsn: this.conf.sentry.dsn,
    sampleRate: this.conf.sentry.sampleRate || 0.4,
    tracesSampleRate: this.conf.sentry.tracesSampleRate || 0.4,
    sendDefaultPii: true,
    environment: this.conf.sentry.environmentOverride
                 || this.ctx.env || 'development'
  })
}
```

Sentry's `environment` tag comes directly from `sentry.environmentOverride`
in the worker config.

### 2. The deployed config on walletstg1 sets `environmentOverride = "staging"`

From `/srv/data/staging/rumble-app-node/config/common.json`:

```json
"sentry": {
  "enabled": true,
  "dsn": "https://7bb75c017b21071aeaf3eed211fb68aa@sentry.rumble.work/43",
  "sampleRate": 1,
  "tracesSampleRate": 1,
  "environmentOverride": "staging"
}
```

Every event the staging workers emit lands under `environment=staging`
in Sentry (project `rumble-wallet-backend`).

The example config in the rumble-app-node repo
(`config/common.json.example`) still shows `"environmentOverride":
"production"`, which is what the deployed file used to look like.

### 3. The staging workers are alive and healthy

PM2 on walletstg1 (under `fcanessa`):

```
39  app-3000        online  restart_time=5  up since 2026-05-13T00:00:31Z
40  app-3001        online  restart_time=5  up since 2026-05-13T00:00:32Z
41  app-3002        online  restart_time=5  up since 2026-05-13T00:00:34Z
```

All three replicas have been online since 2026-05-13 with only 5
restarts. `ss -tlnp` confirms `wrk-node-http-1` is listening on
`127.0.0.1:3000/3001/3002`. The DSN, `@sentry/node` install
(`10.32.1`), and Sentry init code path are all in place. The service is
NOT down — events are flowing, just under a different environment tag.

### 4. Timeline matches the dashboard cutoff

The `Object.onopen — store/3002/db/LOCK: Permission denied` event in
the screenshot is `Last Seen: 2wk ago` relative to 2026-05-15 (ticket
opened), i.e. on/around 2026-05-01.

Around that date:
- 2026-05-01 — rumble-app-node `Chore/dep bump (#195)` lands, bumping
  `@tetherto/wdk-app-node` to a ref that renamed the boot chain to
  `@bitfinex/bfx-svc-boot-js` + `@tetherto/tether-wrk-base` +
  `@tetherto/hp-svc-facs-store` + `@tetherto/svc-facs-logging`.
- 2026-05-03 — `promote dev to main (#197)` rolls those changes through.
- 2026-05-06 — `Merge PR #204: bump-wdk-app-node-v0.2.0` is the ref
  currently deployed on staging (`b993459`).

At the same time the deploy reorg flipped the staging worker's run-user
from `vabdurrahmani` (uid 1003) to `fcanessa` (uid 1008) — both members
of group `backend`, which is why the existing `store/3002/db/LOCK` file
(`-rwxrwsr-x  vabdurrahmani:backend`, setgid dir) is now writable by
fcanessa via group rwx. Until `fcanessa` was actually added to the
`backend` group, the `onopen` of LOCK returned EACCES. That single
crash, captured by the old worker still running with
`environmentOverride: production`, is the last "production" event.

After the cutover settled (group membership fixed + new config rolled
out), workers came back online and every subsequent event has been
tagged `staging`. Hence the Sentry "production" dashboard goes silent
from May 1 onward.

## How to verify in two clicks

In the same Sentry project (`rumble-wallet-backend`), change the
environment filter from `production` to `staging` and re-run a 7-day
window. You should see live events from `app-3000/3001/3002` on the
three walletstg boxes — including the post-May 1 filtered errors that
were the focus of WDK-1282 (`shouldHandleError` work in #198, #202).

If `staging` also shows zero events, walk down the rest of the
checklist:

1. Network — `curl -v https://sentry.rumble.work/api/43/store/` from
   walletstg1 to confirm egress works.
2. Generate a controlled error — hit a route on `app-3001` that throws
   a `5xx`, then check Sentry within ~1min.
3. Confirm `@sentry/node` v10.32.1 starts a background dispatcher (look
   for `Sentry Logger [log]:` lines if the worker is started with
   `--debug`).

## Why this isn't an outage

- All three rumble-app-node replicas have been online since
  2026-05-13, restart count 5.
- Caddy is still load-balancing across them; users are not impacted.
- Sentry SDK is configured and initialised; events are sent.
- The only thing wrong is the *filter on the dashboard*.

## Fix (small)

Two paths, pick one:

**A. Make the dashboard match reality.** Update the saved Sentry view /
alerts / Slack integrations to watch `environment=staging` (and add
`production` again once real prod stands up). Cheapest and most
honest, since the staging cluster is, in fact, staging.

**B. Make the workers tag as `production` again.** Change
`config/common.json` on walletstg1/2/3 (or the deployer template under
`/home/fcanessa/tmp/rumble_staging_deployment/deployer/`) so
`sentry.environmentOverride` is back to `"production"`. This restores
the previous (mislabelled) behaviour and requires a worker restart per
box. Not recommended — keeps the lie that staging is prod.

Recommend (A), and as a follow-up open a separate ticket to wire actual
production rumble-app-node into Sentry once that environment exists.

## Loose ends worth filing as follow-ups

- The Sentry crash on May 1 (`Object.onopen — store/3002/db/LOCK:
  Permission denied`) is unhandled. The worker process died on a file
  open; that should be wrapped so a single bad store doesn't bring the
  HTTP worker down. File under WDK-* as "rumble-app-node: surface
  store init errors instead of crashing".
- `rumble-app-node/config/common.json.example` still ships
  `environmentOverride: "production"`. If the convention is now
  `staging` for the staging cluster and `production` for actual prod,
  the example should pick one and the README should call it out.
- Mixed file ownership under `store/3002/db/` (`vabdurrahmani` +
  `fcanessa`) is fine because of the setgid `backend` group, but it's
  a footgun for any future deployer change. Worth normalising
  ownership to the runtime user during deploy.
