# Staging Authentication Issue: ERR_DATA_SHARD_NOT_FOUND

**Channel:** #wallet-rumble-dev  
**Thread started:** 13 May 2026 at 10:19 AM  
**Status:** Root cause identified (21 May 2026)

---

## Summary

A user-specific authentication failure was discovered on the Staging environment. Multiple users were unable to log in due to a `[HRPC_ERR]=ERR_DATA_SHARD_NOT_FOUND` error. The issue persisted over several days before a root cause was identified. Investigation revealed a data inconsistency in MongoDB: the UUID stored in the `tw_ork.wdk_ork_wallet_id_lookups` collection did not match the value being logged by the process, pointing to a likely corruption during a failed deployment.

---

## Original Report

**Gocha Gafrindashvili** — 13 May at 10:19 AM

> Hi team 👋  
> Noticed a user specific issue on the Staging environment for user **Gwallet66**.  
> Every authentication attempt fails with the following error: `[HRPC_ERR]=ERR_DATA_SHARD_NOT_FOUND`

**Additional notes:**
- The same user has a wallet on the Production environment and auth works correctly there
- The issue appears to be isolated to Staging only

**CC:** @Francesco C. @Eddy WM  
*(2 screenshots attached showing the error in the app and the raw error log)*

---

## Thread Discussion

### 13 May 2026

**Anton Kurdo** — 10:21 AM  
> Can confirm, from my side too

**Francesco C.** — 10:33 AM  
> cc @Alex maybe you can take a look *(edited)*

**Alex** — 10:38 AM  
> I will...

---

**Eddy WM** — 8:49 PM  
Shared error log:
```
21:39:06 ERROR [api/WalletAPI] connectWithToken: HTTP error
{"status":404,"statusText":"","body":"{\"statusCode\":404,\"error\":\"Not Found\",\"message\":\"[HRPC_ERR]=ERR_DATA_SHARD_NOT_FOUND\"}"}
```
> I'm seeing same error as well right now

---

**Francesco C.** — 9:30 PM  
Shared a log file: `Explore-logs-2026-05-13 21_30_35.txt`

Common labels: `{"agent":"alloy","env":"staging","host":"walletstg1"}`  
Line limit: 1000 (5 displayed) | Total bytes processed: 331 MB

Relevant log entry (storeDevice call):
```json
{"level":30,"time":1778673354047,"pid":7719,"hostname":"walletstg3",
"name":"wrk-ork-api-w-2-2-3189aa2c-4933-4a3f-a95e-fc31a828e222",
"traceId":"mob:282723666:87246f66-496e-435f-9e53-524244afce70",
"msg":"rpc action response: storeDevice - error returned (1164.69ms) :\"[HRPC_ERR]=ERR_DATA_SHARD_NOT_FOUND\""}
```

Follow-up notes from Francesco:
- 9:31 — "this was on get tip jar though not on connect" *(edited)*
- 9:33 — "also on `storeDevice`"
- 9:34 — "weirdly enough Eddy, I cannot find any occurrences today for the connect endpoint"

---

### 14 May 2026

**Gocha Gafrindashvili** — 9:58 AM  
> There are few more users affected:
> - gwallet59
> - ggaphrindashvili

---

**Anton Kurdo** — 10:23 AM  
> @Francesco C. Could you please help here again, for me didn't fix too

Error log shared:
```
ERROR [api/WalletAPI] connectWithToken: HTTP error
{"body": "{\"statusCode\":404,\"error\":\"Not Found\",\"message\":\"[HRPC_ERR]=ERR_DATA_SHARD_NOT_FOUND\"}", "status": 404, "statusText": ""}
```

Stack trace:
```
Code: logger.ts
144 | ? console.warn
145 | : console.log
> 146 | consoleFn(`${prefix} ${message}`, ...loggerArgs)
| ^
147 | /* eslint-enable no-console */
148 |
149 | // Notify real-time listeners
Call Stack:
  Logger#log (utils/logger.ts:146:14)
  Logger#error (utils/logger.ts:125:13)
  fetch.then$argument_0 (api/clients/WalletApiClient.ts:268:29)

LOG [LoginContainer] [LoginContainer] No tokens after login error - user stays on login screen

ERROR Sentry Logger [error]: Transport disabled
Code: logger.ts
216 | } else {
217 | // No Error object - capture the message as an exception
> 218 | Sentry.captureException(new Error(message), {
| ^
219 |     tags: { scope: category },
220 |     extra: data
221 | })
Call Stack:
  Logger#sendToSentry (utils/logger.ts:218:32)
  Logger#log (utils/logger.ts:164:24)
  Logger#error (utils/logger.ts:125:13)
  fetch.then$argument_0 (api/clients/WalletApiClient.ts:268:29)

ERROR [LoginContainer] [LoginContainer] Login error
  [ApiError: {"statusCode":404,"error":"Not Found","message":"[HRPC_ERR]=ERR_DATA_SHARD_NOT_FOUND"}]
Code: errors.ts
12 | public originalError?: unknown
13 | ) {
> 14 | super(message)
| ^
15 | this.name = 'ApiError'
16 | }
Call Stack:
  ApiError#constructor (api/types/errors.ts:14:5)
  fetch.then$argument_0 (api/clients/WalletApiClient.ts:273:29)
``` *(edited)*

---

**Eddy WM** — 10:45 AM  
> I think most of us have suddenly started experiencing the shard issue, this is somehow blocking. Hopefully it's figured out so we can proceed

---

**Francesco C.** — 11:15 AM  
> both Alex and me are out today, Alex can you please investigate on Friday? thanks

---

### Friday (16 May 2026)

**Eddy WM** — 8:56 PM  
```
WARN [queries/auth] Failed to unregister device token [ApiError: [HRPC_ERR]=ERR_DATA_SHARD_NOT_FOUND]
```
> Got another shard not found today

---

**Francesco C.** — 8:58 PM  
> I guess Alex didn't have time to investigate this, will try to do it tomorrow morning

---

**Eddy WM** — 8:59 PM  
```
WARN [queries/auth] Failed to unregister device token [ApiError: [HRPC_ERR]=ERR_DATA_SHARD_NOT_FOUND]
```
> Still getting these till now

---

### Monday (18 May 2026)

**Gocha Gafrindashvili** — 11:53 AM  
> Hi,  
> @Alex, @Francesco C. I tried to access the mentioned user `Gwallet66` on v2.2 (677), and the flow redirected me into onboarding.  
> After that, the wallet appeared to regenerate with a new seed/wallet, and balances + transactions were reset.  
> Sharing recording and extracted logs for reference:

*(2 files attached, including `rumble-wallet-2026-05-18 (1).log` — Binary)*

---

**Francesco C.** — 12:00 PM  
> yes I did some investigation over the weekend, I will post my findings soon here cc @Alex 👍

---

### 21 May 2026 (Today)

**Francesco C.** — 2:18 PM  
> I found the issue on staging, apologies for taking so long *(edited)*

---

**Francesco C.** — 2:24 PM  
Root cause identified. Reference code:  
[https://github.com/tetherto/wdk-ork-wrk/blob/main/workers/lib/data.shard.util.js#L107](https://github.com/tetherto/wdk-ork-wrk/blob/main/workers/lib/data.shard.util.js#L107)

**Mongo Collection:**  
`tw_ork.wdk_ork_lookups` / `tw_ork.wdk_ork_wallet_id_lookups`

> There are a lot of users that have the wrong value compared to the one that the process is logging

**Rack (process):**
```
rack  w-0-0 (stg1)
```

**UUIDs:**
- live UUID (from pm2 logs): `642f16a3-…81db54`
- mongo UUID: `cd64bb43-…f82141`

**Mongo query used to diagnose:**
```js
db.wdk_ork_lookups.findOne({ value: /^wrk-data-shard-proc-w-0-0-/ })
```

> Returns a result with value `wrk-data-shard-proc-w-0-0-cd64bb43-45b8-437e-9cfd-4de3e4f82141` but the data shard ..... editing ..... *(edited)*

> cc @Alex @Vigan maybe you know how this could have been modified? during a failed deployment these id changed? *(edited)*

---

## Root Cause

The `ERR_DATA_SHARD_NOT_FOUND` error is caused by a **UUID mismatch** in the MongoDB collection `tw_ork.wdk_ork_wallet_id_lookups` (and related `tw_ork.wdk_ork_lookups`).

The value stored in the database for the shard process (`wrk-data-shard-proc-w-0-0-`) does not match the UUID that the live process is using (as logged in pm2). This mismatch causes the data shard lookup to fail, returning a 404 Not Found response with the `ERR_DATA_SHARD_NOT_FOUND` error.

**Hypothesis:** The UUIDs may have been changed/corrupted during a failed deployment on the Staging environment.

---

## Affected Users (Staging)

| Username | Notes |
|---|---|
| Gwallet66 | Initially reported; wallet regenerated into onboarding on v2.2 (677), resetting balances and transactions |
| gwallet59 | Confirmed affected |
| ggaphrindashvili | Confirmed affected |
| Anton Kurdo | Dev team member also affected |
| Eddy WM | Dev team member also affected |

---

## Timeline

| Date/Time | Event |
|---|---|
| 13 May, 10:19 AM | Issue reported by Gocha for user Gwallet66 on Staging |
| 13 May, 10:21 AM | Anton Kurdo confirms same issue |
| 13 May, 10:38 AM | Alex assigned to investigate |
| 13 May, 8:49 PM | Eddy WM confirms same error on their side |
| 13 May, 9:30 PM | Francesco C. shares logs — error also on `storeDevice` and `getTipJar` endpoints |
| 14 May, 9:58 AM | Two more affected users reported (gwallet59, ggaphrindashvili) |
| 14 May, 10:23 AM | Anton Kurdo still affected, detailed stack trace shared |
| 14 May, 10:45 AM | Eddy WM flags issue as blocking for the team |
| 14 May, 11:15 AM | Alex and Francesco both out; Alex asked to investigate Friday |
| 16 May, 8:56 PM | Eddy WM reports shard error still occurring |
| 16 May, 8:59 PM | Errors confirmed ongoing |
| 18 May, 11:53 AM | Gocha: accessing Gwallet66 triggers re-onboarding and wallet regeneration (data loss) |
| 18 May, 12:00 PM | Francesco confirms weekend investigation underway |
| 21 May, 2:18 PM | Francesco announces root cause found |
| 21 May, 2:24 PM | Francesco shares detailed root cause: MongoDB UUID mismatch for shard process |

---

## Key Technical Details

- **Error code:** `[HRPC_ERR]=ERR_DATA_SHARD_NOT_FOUND`
- **HTTP response:** `404 Not Found`
- **Affected endpoints:** `connectWithToken`, `storeDevice`, `getTipJar`, `unregisterDeviceToken`
- **Environment:** Staging only (Production unaffected)
- **Relevant code:** [`workers/lib/data.shard.util.js#L107`](https://github.com/tetherto/wdk-ork-wrk/blob/main/workers/lib/data.shard.util.js#L107)
- **Affected DB collections:** `tw_ork.wdk_ork_lookups`, `tw_ork.wdk_ork_wallet_id_lookups`
- **Rack/process:** `w-0-0 (stg1)`
- **UUID mismatch:** Live process UUID (`642f16a3-…81db54`) ≠ MongoDB stored UUID (`cd64bb43-…f82141`)

---

## Open Questions (as of thread end)

1. How did the MongoDB UUID get modified — was it during a failed deployment?
2. Are @Alex and @Vigan aware of any deployment events that could have caused UUID changes?
3. What is the remediation plan to correct the UUID in MongoDB?
4. Are there other affected users beyond the three identified?
