# Staging log investigation - 2026-06-15 retest

## Test evidence

- Tester retest comment: 2026-06-15T08:15:44Z.
- Screenshot attachment `IMG_0992.jpg`: uploaded 2026-06-15T08:15:36Z.
- Screenshot device time: `12:13`; this lines up with `08:13Z` if the tester is UTC+4.
- Screenshot app/build: TestFlight, `v2.4.0(207)`.
- Screenshot errors:
  - `Could not activate ggaph...ili's Tip Jar`
  - `Could not deactivate Cattsssss Tip Jar`

## Deployed backend checked

- Host: `walletstg1`.
- `rumble-app-node`: `main` at `4ed0d1d`, package version `1.2.1`.
- Deployed `@tetherto/wdk-app-node` pin: `32b3b80479dcef34b66871d459f89e4d7804f7f4`.
- The deployed code includes the RW-1832 mitigation:
  - `updateWallet` is in `CORE_RETRYABLE_METHODS`.
  - `RPC client closed` is recognized as channel-closed.
  - `rumble-app-node` adds `storeDevice` to the extra retryable set.

Relevant local source:
- `wdk-app-node/workers/lib/server.js`: `PATCH /api/v1/wallets/:id` calls `service.ork.updateWallet`.
- `wdk-app-node/workers/lib/services/ork.js`: `updateWallet` failover and `RPC client closed` matching are present.
- `rumble-app-node/workers/lib/server.js`: `PATCH /api/v1/channels/:channelId/tip-jar` is a rename route, not activation/deactivation.

## Log window checked

Primary window: 2026-06-15T08:00Z-08:25Z.

Likely tester trace prefix: `mob:281396862`, same prefix seen in the earlier RW-1832 production evidence. In this window, the backend saw successful reads only:

- 2026-06-15T08:13:18.307Z `GET /api/v1/wallets` -> 200, `1932.73ms`
- 2026-06-15T08:13:18.328Z `GET /api/v1/users/ag5ezVDrcxU/token-transfers?...` -> 200, `1918.99ms`
- 2026-06-15T08:13:19.770Z `GET /api/v1/user-data?key=user_manual_backup_completed` -> 200
- 2026-06-15T08:13:19.826Z `GET /api/v1/seed` -> 200
- 2026-06-15T08:14:38Z-08:14:39Z more `GET /api/v1/seed` and token-transfer reads -> 200

No `PATCH /api/v1/wallets/:id` appeared for this trace prefix in the retest window.

All-day 2026-06-15 staging sweep:

- `PATCH /api/v1/wallets/:id` count: 3 total.
- All 3 returned HTTP 200:
  - 2026-06-15T08:41:58.996Z `mob:285118108:542387cf-...` -> 200
  - 2026-06-15T08:45:22.900Z `mob:285118140:b33438bd-...` -> 200
  - 2026-06-15T08:52:01.542Z `mob:285118220:17461106-...` -> 200
- `RPC client closed` / `CHANNEL_CLOSED` / `ERR_RPC_CALL_FAILED`: 0.
- `updateWallet` errors: 0.
- HTTP >= 500 requests: 0.
- App log matches for `tip-jar`: 0.

## Interpretation

If the tester's build was pointed at staging, the screenshoted failure did not come from a backend `PATCH /api/v1/wallets/:id` failure on `walletstg1`: the backend never received the mutation in the retest window, and every wallet mutation seen on June 15 succeeded.

This points to a frontend-side failure mode or client/runtime issue after background restore: the app may be showing the toast before sending the request, suppressing/canceling the request after restore, using stale local Tip Jar state, or hitting a different API host than `walletstg1`.

Caveat: the task title says `Prod` and the screenshot is TestFlight. The later Sentry check in `sentry-investigation-2026-06-15.md` confirmed the matching mobile events were tagged `production` and hit `wallet-9p1aan4nff.rmbl.ws`, with backend HTTP 500 responses carrying `[HRPC_ERR]=RPC client closed`. These staging logs only prove the failure did not occur on `walletstg1`.

## Needed from frontend / QA

Ask the frontend team for the device-side logs or Sentry breadcrumbs around 2026-06-15 12:13 local / 08:13Z, specifically:

- API host/base URL used by build `v2.4.0(207)`.
- Failed request URL/method/status/body for the two Tip Jar toasts.
- Any mobile trace IDs for the failed toggle attempts.
- Whether the request was canceled, skipped, or generated a local error before reaching HTTP.
