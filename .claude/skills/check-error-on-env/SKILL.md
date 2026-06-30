---
name: check-error-on-env
description: Given an error report (a Slack paste, a Sentry issue, or a raw log line), check whether that error is still occurring on a live environment (rumble-dev, walletstg1/2/3, or prod) and correlate it to a known task folder. Use whenever Alex asks "is this error still happening on staging/prod", "check if this error exists on <env>", "did the fix deploy", or pastes a log line / Slack bug report and wants it verified against a real server.
---

# Check an error against a live environment

Alex hands you an error (a Slack message, a Sentry issue, or a pasted log
line) and wants one question answered: **is this still happening on a real
box right now, and do we already have a ticket for it?**

This skill is the orchestration layer. The actual SSH access lives in the
environment skills, which this one calls:

- dev → [`access-dev-server`](../access-dev-server/SKILL.md) (login `alexa`,
  service user `work`, `PM2_HOME=/home/work/.pm2`).
- staging → [`access-staging-servers`](../access-staging-servers/SKILL.md)
  (login `alexs`, service user `fcanessa`, `PM2_HOME=/srv/data/pm2`, three
  identical replicas walletstg1/2/3 — Yubikey touch per ssh).

Read the relevant environment skill before running anything; do not
re-derive identity, paths, or sudo rules here.

## Step 1 — extract the error signature

From whatever Alex pasted, isolate the part that is stable across
occurrences and greppable. Strip the volatile bits:

- Drop pids, hostnames, timestamps, request ids, wallet/user ids, and the
  per-instance worker suffix (e.g. `...-usdt-plasma-0077c05f-29bb-...`).
- Keep the error code and the message stem. Good signatures:
  `ERR_USER_DATA_SHARD_NOT_FOUND`, `HRPC_ERR]=RPC client closed`,
  `ERR_EXISTING_ADDRESS_SPARK_DATA_UPDATE_FORBIDDEN`,
  `getGasLessTransactionReceipt`.
- If the paste names a worker (`wrk-erc20-indexer-proc-...`,
  `idx-bitcoin-proc-...`, `ork-w-...`), keep the worker family — it tells you
  which log files to grep.

State the signature you settled on back to Alex in one line before you go to
the server, so a wrong guess is caught early.

## Step 2 — pick the environment

- If Alex named one (dev / staging / prod), use it.
- A Slack production bug report → prod. Be explicit that prod is read-only
  and that we may only have log access, not PM2 control.
- "Did the fix deploy / is it still happening after the merge" → check the
  env the PR was deployed to (usually staging or dev), and confirm the
  deployed commit before trusting a "not happening" result (a stale deploy
  makes the error look gone when it isn't).
- Staging has three identical replicas. The error can land on any of them,
  so **grep all three** unless Alex points at one. Do not assume sticky
  routing.

## Step 3 — grep the live logs over a time window

Build the signature into a grep over the PM2 log directory for the right
env. Always bound it by time so "still happening" means *recently*, not
*ever in the rotated history*.

Dev (one box):

```bash
ssh rumble-dev 'sudo -u work bash -lc "
  cd /home/work/.pm2/logs
  grep -rh \"ERR_USER_DATA_SHARD_NOT_FOUND\" *-error.log *-out.log 2>/dev/null | tail -20
  echo \"--- count today ---\"
  grep -rhc \"ERR_USER_DATA_SHARD_NOT_FOUND\" *.log 2>/dev/null | paste -sd+ | bc
"'
```

Staging (loop all three; each ssh is a Yubikey touch, so do the whole grep
in one connection per box):

```bash
for h in walletstg1 walletstg2 walletstg3; do
  echo "===== $h ====="
  ssh "$h" 'sudo bash -lc "
    cd /srv/data/pm2/logs
    grep -rh \"HRPC_ERR]=RPC client closed\" *-error.log *-out.log 2>/dev/null | tail -10
  "'
done
```

Notes:
- Pino logs are JSON with epoch-ms `time`. To restrict to today/yesterday,
  match on the date in the rotated filename
  (`<name>-error__YYYY-MM-DD_*.log`) or pipe matched lines through a `jq`
  /`awk` filter on `time`. Prefer the filename window first — it is cheaper
  and avoids parsing every line.
- For a specific worker family, narrow the file glob
  (`grep ... wrk-erc20-indexer-proc-*-error.log`) instead of scanning all
  logs.
- Heredoc / `bash -lc "..."` is required for multi-line remote work on both
  envs (see the environment skills). Keep it to a single ssh round-trip.

## Step 4 — correlate to a known task folder

Before reporting, check whether we already own this error locally:

```bash
grep -rl -iE "ERR_USER_DATA_SHARD_NOT_FOUND" \
  _tether-indexer-docs/_tasks/*/ 2>/dev/null
```

Also scan `root-cause.md` / `HANDLING.md` / `README.md` in any hit. If a
folder owns it, surface its ticket id and whether it is `[DONE]` — a `[DONE]`
folder plus a still-firing error means the fix is unmerged or undeployed,
which is the most useful thing you can tell Alex. (This is the same
reverse-lookup the proposed `find-task` skill does; reuse it if it exists.)

## Step 5 — report

Answer the actual question in the first line:

- **Still happening** — most recent occurrence timestamp, which box(es),
  rough rate (count over the window), the matched line.
- **Not happening** — the window you checked, the deployed commit you
  confirmed, and the last historical occurrence if any. Never report "gone"
  off an unbounded grep or an unverified deploy.

Then: the task folder it maps to (or "no existing ticket — looks new"), and a
one-line recommendation (open a ticket / it's the undeployed fix from
`<folder>` / not a backend error).

## Hard rules

- **Read-only by default.** This skill investigates; it does not restart
  workers, edit config, or redeploy. If the finding calls for an
  operational action, hand back to the environment skill and confirm with
  Alex first.
- **No traces left behind.** Prefer stdin/heredoc over writing files to the
  box. If you used `/tmp`, `rm` it before the session ends (see the
  environment skills' cleanup rule).
- **Prod is the most sensitive.** Confirm the host and that you are only
  reading logs. Do not run `pm2` mutate commands on prod.
- No em dashes in anything you hand back to Alex.
