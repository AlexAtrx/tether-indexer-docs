# Production evidence (Slack, 2026-06-11) + Sentry RUMBLE-WALLET-APP-D7

New production report of the same RW-1832 failure, this time framed as
"Tip Jar activation fails after the app is restored from the background;
app restart fixes it". Reported by Gocha Gafrindashvili; Sentry issue
RUMBLE-WALLET-APP-D7 ("Failed to toggle tip jar"): **92 events / 22 users**,
ongoing, env production, release 2.3.0. Repro accounts:
goch.gafrindashvili@gmail.com, 21rumbler@gmail.com.

## Backend trace (walletprd3, 2026-06-11 17:27, Francesco's Loki paste)

One HTTP request, `PATCH /api/v1/wallets/9e31f00e-f0fd-4bbb-bbf8-f4c59aa68a20`,
traceId `mob:281396862:11068af2-1f09-4819-8c93-15776553a0d3`:

- 17:27:00.662 `wrk-node-http-3001` Incoming request
- 17:27:00.664 / 00.865 / 01.067 `wrk-ork-api-w-2-0` (pid 902370) receives
  `updateWallet` three times, ~200ms apart; each returns rpcError
  `"[HRPC_ERR]=RPC client closed"` with **elapsed 0.22-0.27 ms**
- 17:27:01.068 `wrk-node-http-3001` Unhandled route error, 500 to client
  (responseTimeMs 406), stack: `NetFacility._request` →
  `rpcCallWithRetryAndFailover` (wdk-app-node `workers/lib/services/ork.js:71`)
  → `server.js:597`

The rpcError buffer decodes to `"[HRPC_ERR]=RPC client closed"`.

## What this trace proves (refines the RW-1832 picture)

1. **The app-node → ork hop is healthy.** All three requests reached the ork
   API worker and got responses back. The closed client is **inside the ork**:
   `updateWallet` → `api.ork.wrk.js _rpcRequest()` →
   `net_r0.jRequest(<shard rpcKey>, 'updateWallet', ...)` — the ork's HRPC
   client **to the user's data shard**. Elapsed 0.22-0.27 ms means the client
   object was already closed locally (instant reject, no network round trip).
2. **Why exactly 3 attempts ~200ms apart in the deployed release:** in the
   deployed `rpcCallWithRetryAndFailover`, `updateWallet` is NOT in the
   retryable allowlist, so `maxAttempts = 1` but `jRequest` is called with
   `retries = 2` (`ork.js:73`, `retryableMethod ? 0 : 2`). hp-svc-facs-net
   retries the SAME ork rpcKey 3 times. Retrying the same ork can never work
   while its shard client is dead, hence the deterministic 500.
3. **"After restore from background" is a trigger, not the cause.** The dead
   client lives server-side in that ork worker; the app foregrounding is just
   when the next PATCH fires. The app-side manual retry succeeding seconds
   later (RW-1832 recordings) shows the ork's shard client does get
   re-established shortly after, just not within the 3 fast in-request retries.

## Does the merged fix (wdk-app-node PR #119, next release) cover this?

Mostly yes, as a mitigation:

- PR #119 (`08ac4c4`) adds `updateWallet` to the retryable allowlist →
  `retryableMethod = true` → per-attempt `jRequest` retries 0, and on
  channel-closed the app-node **rotates to the next ork peer**.
- The error string the ork returns (`[HRPC_ERR]=RPC client closed`) matches
  `isChannelClosedError` (`err.message.includes('RPC client closed')`), so the
  failover path does fire for this exact trace.
- A different ork worker holds its own HRPC client to the same shard, so the
  failover succeeds unless every ork's client to that user's shard is stale at
  once.

Caveats / what it does NOT fix:

- **Root cause remains open:** the ork's HRPC client to the data shard dies
  (idle/reset) and rejects instantly instead of reconnecting on demand. The
  durable fix is reconnect-on-closed in hp-svc-facs-net or the ork's shard
  client lifecycle.
- **Other mutation endpoints are still exposed.** RW-1832 client logs showed
  the same 500 on `POST /api/v1/device-ids`; that path is not in the
  allowlist, so the same family of errors will keep appearing outside tip jar.
- If all orks' shard clients are stale simultaneously (e.g. right after a
  shard restart), failover exhausts and the 500 persists.

## Deployment state (checked 2026-06-12): the fix will NOT ship unless the pin is bumped

Fingerprint: prod stack frame `ork.js:71:14` matches wdk-app-node `b678ef2`
(PR #112 merge, the commit immediately before PR #119), where line 71 is the
`jRequest(..., retryableMethod ? 0 : 2)` call. Production behaviour (3 same-ork
attempts at 200ms spacing, then 500) confirms it.

Chain of custody for the tip-jar fix:

- wdk-app-node PR #119 (`32b3b80`) is merged to **upstream/dev only** (not on
  wdk-app-node main).
- rumble-app-node upstream/main AND upstream/dev pin
  `@tetherto/wdk-app-node` to `git+...#b678ef2` (commit `cdf8ba5`,
  "chore: bump wdk-app-node to latest dev (b678ef2)"). That bump predates
  PR #119 and no later bump exists.
- Therefore a rumble-app-node release cut from today's main/dev ships the
  exact code production already runs. **Action: bump the wdk-app-node pin to
  `32b3b80` (or later dev) in rumble-app-node before the next release cut**,
  otherwise "fixed in the next release" is false.

Related merged-but-undeployed work in the same error family (for reference,
none of it covers the tip-jar updateWallet path):

- wdk-ork-wrk PR #145 (`b72e608`, `facd751`, `a0835d7`): opt-in
  `autoRetry` plumbing on the ork→shard hop, on upstream/dev. Default 0; no
  caller in wdk-ork-wrk passes it, `updateWallet` not covered.
- rumble-ork-wrk PR #163/#164 (`c287ff3`, `a461313`):
  `SHARD_RETRY_OPTS = { autoRetry: 2, autoRetryDelay: 200 }` for the
  rant/tip transfer notification path only.
- rumble-app-node PR #238 (`884746f`): notification ork failover scoped to
  dedupeable payloads.
- wdk-ork-wrk `104c987` (RW-1906 shard lookup retry): fork branch only, not
  merged upstream yet.

## Follow-up raised (2026-06-12)

- **Pin bump PR (draft):** https://github.com/tetherto/rumble-app-node/pull/243
  (`chore/bump-wdk-app-node-pin-RW-1832`, branched from upstream/dev) bumps
  `@tetherto/wdk-app-node` from `b678ef2` to `32b3b80` so PR #119 ships in the
  next release. Surgical SHA swap only; no dependency graph change.
- **storeDevice failover fix (local, uncommitted):** rumble-app-node branch
  `fix/device-ids-storedevice-failover-RW-1832` (from upstream/dev) adds
  `storeDevice` to `RUMBLE_EXTRA_RETRYABLE_METHODS` so
  `POST /api/v1/device-ids` fails over on a closed channel like updateWallet
  does. Unit test extended; tests 5/5 and standard lint clean. Not committed
  per Alex's instruction.

## Sentry

- Issue RUMBLE-WALLET-APP-D7, `sendToSentry(index.android)`, mechanism
  generic, handled true. Trace preview shows the mobile app itself retrying
  the PATCH 3 times (each ~400ms server time) before giving up.
- Token shared in Slack by Ashot (treat as sensitive, do not commit
  anywhere public): see Slack thread 2026-06-11.
