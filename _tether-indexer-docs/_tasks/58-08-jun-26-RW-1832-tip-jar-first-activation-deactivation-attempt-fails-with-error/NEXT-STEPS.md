# Next steps for RW-1832 — Tip Jar first activation/deactivation fails

**Ticket:** https://app.asana.com/1/45238840754660/project/1212521145936484/task/1215245516513506

## What we know
- Toggling a Tip Jar on/off fails on the **first** attempt with an on-screen
  error ("Could not activate Tip Jar"); retrying succeeds. Misleading UX.
- The failing backend call is `PATCH /api/v1/wallets/{walletId}` on
  rumble-app-node (`wallet-8s4anfsr6it9.rmbl.ws`), returning HTTP **500** with
  `{"message":"[HRPC_ERR]=RPC client closed"}`.
- Same `[HRPC_ERR]=RPC client closed` 500 also hit `POST /api/v1/device-ids`
  (FCM token registration) in the same session — so it is **not tip-jar
  specific**, it is the first HRPC call after the app-node's HRPC client to a
  downstream worker had closed. Reconnect happens, so the retry works.
- Tagged **BE - Backend**, High priority, Sprint 3. Repro: 2026-06-02 18:57.

## Evidence captured here
- 10 recording frames in `images/recording 1/` (frame-by-frame in `image-analysis.md`)
- 2 client log files + 2 screen recordings under `attachments/`
- 1 comment in `comments.md` (+ key system events)
- Smoking-gun log trace quoted in `image-analysis.md`
- UI side confirms the failure is **intermittent** (gwallet126 + 18Channell
  succeeded first try; 20Channell, 1Channell, 2Channelll failed first then
  succeeded on retry), consistent with the HRPC-reconnect root cause.

## What's missing (from `missing-context.md`)
- Backend (rumble-app-node + ork/shard) logs for the repro window to see which
  HRPC client closed and why.
- Confirm which env `wallet-8s4anfsr6it9.rmbl.ws` is and log timezone alignment.

## Before starting work
This looks like an HRPC-client-lifecycle bug in rumble-app-node (the API side
treats a "RPC client closed" as a hard 500 instead of reconnecting/retrying the
first request after the proc connection drops). When handling:
1. Get the backend logs (above) to confirm the closed client (ork vs shard).
2. Trace the `PATCH /api/v1/wallets/{id}` handler in rumble-app-node down to the
   HRPC call that throws `[HRPC_ERR]=RPC client closed`; check whether the HRPC
   client is reused/cached across idle periods and whether a closed client is
   reconnected on demand or only on next boot.
3. Decide: reconnect-on-demand vs retry-once-on-`RPC client closed` at the
   app-node boundary. Mind idempotency on both HTTP and internal HRPC paths.
4. Confirm the same fix covers the `device-ids` path, not just tip-jar toggle.
