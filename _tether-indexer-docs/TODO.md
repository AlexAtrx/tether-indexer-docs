# Asana TODO — assigned to Alex

Generated: 2026-04-20 21:05 UTC  
Source: Asana `get_my_tasks` (incomplete only)  
Regenerate: ask Claude to "refresh my Asana TODO".

**Summary:** 24 assigned tasks total — 21 real tickets + 3 placeholder onboarding tasks. 4 tickets appear under two projects (shown in both sections below), so section-level counts sum higher than 21.

**Accuracy notes to check in Asana:**
- `RW-955` (Xaxis) sits under section *Completed* with custom-field `Task Progress = Done`, but Asana still lists it as incomplete (it wasn't "Mark Complete"-ed). Consider closing it.
- 19 of 21 tickets have no `due_on` set.

## Rumble Wallet V3

### Next steps

- [ ] [Remove the initiated transfer notification](https://app.asana.com/1/45238840754660/project/1212521145936484/task/1213287908612993)
      `RW-977`  ·  High  ·  Deferred  ·  due 2026-02-19

### ToDo - Dev

- [ ] [Rumble - Add blockchain specific retryCount/retryDelay for tx webhook](https://app.asana.com/1/45238840754660/project/1210540875949204/task/1213868590256377)
      `RW-1525`  ·  High  ·  In Progress
- [ ] [Rumble - investigate and solve ERR_WALLET_BALANCE_FAILURE_CCY error in staging](https://app.asana.com/1/45238840754660/project/1210540875949204/task/1214094490463459)
      `RW-1625`  ·  Medium

### To Triage

- [ ] [Rumble - BE - stop push notifications when received amount <$0.1 for tip or normal receive](https://app.asana.com/1/45238840754660/project/1210540875949204/task/1213139196226601)
      `RW-886`  ·  Medium
- [ ] [[Assets] Only 1 dot is displayed for filter 7D and 1M](https://app.asana.com/1/45238840754660/project/1212521145936484/task/1213823149664564)
      `RW-1486`  ·  Medium
- [ ] [[Push Notifications] Amount mismatch between “Transfer Initiated” and “Transfer Successful” notifications](https://app.asana.com/1/45238840754660/project/1212521145936484/task/1213989533989558)
      `RW-1598`  ·  Medium
- [ ] [BE to persist failed transactions](https://app.asana.com/1/45238840754660/project/1212521145936484/task/1213139196226597)
      `RW-885`

### Completed

- [ ] [[Analytics] Xaxis is incorrect on Asset trend chart](https://app.asana.com/1/45238840754660/project/1212521145936484/task/1213244394019831)
      `RW-955`  ·  Medium

### In-Progress

- [ ] [[Backend - Transactions] Received BTC transaction doesn't display ](https://app.asana.com/1/45238840754660/project/1212521145936484/task/1213704628745111)
      `RW-1428`  ·  High  ·  local: `_tasks/20-apr-26-1-received-btc-transaction-doesnt-display/`
- [ ] [[Backend] Migration Reconciliation Job](https://app.asana.com/1/45238840754660/project/1212521145936484/task/1213680013630981)
      `RW-1409`  ·  High
- [ ] [[Bckend - Tip jar] Tip button doesn't appear on the Rumble and Send Tip button is inactive after following the channel, user](https://app.asana.com/1/45238840754660/project/1212521145936484/task/1213391745549211)
      `RW-1120`  ·  High  ·  local: `_tasks/20-apr-26-2-tip-button-inactive-after-follow/`


## WDK Indexer and Wallet Backends

### DEV IN PROGRESS

- [ ] [Rumble - Silence the remaining Sentry False Positives - (#3)](https://app.asana.com/1/45238840754660/project/1210540875949204/task/1213662485884824)
      High

### PR OPEN - IN REVIEW

- [ ] [Rumble: Reduce the amount of queryTransfersByAddress in the job config](https://app.asana.com/1/45238840754660/project/1210540875949204/task/1212717092938062)
      High
- [ ] [Rumble - [Send] BTC transactions are logged with incorrect amounts](https://app.asana.com/1/45238840754660/project/1210540875949204/task/1212744757896562)

### TO DO

- [ ] [Rumble - Add blockchain specific retryCount/retryDelay for tx webhook](https://app.asana.com/1/45238840754660/project/1210540875949204/task/1213868590256377)
      `RW-1525`  ·  High  ·  In Progress
- [ ] [Rumble - Refactor wdk-* Repos to Remove Rumble-Specific Logic (Move to Rumble Child Repo)](https://app.asana.com/1/45238840754660/project/1210540875949204/task/1213303070214495)
      High
- [ ] [Rumble - Security - Fix Tron Indexer High Vulnerabilities](https://app.asana.com/1/45238840754660/project/1210540875949204/task/1213478780310237)
      High
- [ ] [Rumble - Update Fastify plug ins](https://app.asana.com/1/45238840754660/project/1210540875949204/task/1213226894059885)
      High
- [ ] [Push notifications: format token amounts server-side (fix decimal/precision artifacts)](https://app.asana.com/1/45238840754660/project/1210540875949204/task/1214119276348483)

### TO DO - Medium + Low Prio

- [ ] [Rumble - BE - stop push notifications when received amount <$0.1 for tip or normal receive](https://app.asana.com/1/45238840754660/project/1210540875949204/task/1213139196226601)
      `RW-886`  ·  Medium
- [ ] [Rumble - Implement an endpoint to return the list of transactions based on wallet signature](https://app.asana.com/1/45238840754660/project/1210540875949204/task/1213663338730898)
      Medium
- [ ] [Rumble - investigate and solve ERR_WALLET_BALANCE_FAILURE_CCY error in staging](https://app.asana.com/1/45238840754660/project/1210540875949204/task/1214094490463459)
      `RW-1625`  ·  Medium

### PR MERGED + DEPLOYED TO DEV

- [ ] [Rumble - Bug - Security - Fix Mongo Deprecation Warning - Prod DB Password in Logs](https://app.asana.com/1/45238840754660/project/1210540875949204/task/1213549645575555)
      High  ·  local: `_tasks/20-apr-26-3-fix-mongo-deprecation-prod-db-password-leak/`
- [ ] [Fix ork discovery empty-list failure after restart (Jan 5 prod issue) - handle ERR_TOPIC_LOOKUP_EMPTY](https://app.asana.com/1/45238840754660/project/1210540875949204/task/1212700198741856)
      Medium


## [RW] V1 Bugs Tracking

### Blocked

- [ ] [Rumble - [Send] BTC transactions are logged with incorrect amounts](https://app.asana.com/1/45238840754660/project/1210540875949204/task/1212744757896562)


## Placeholder / onboarding tasks

These look like auto-generated demo tasks. Safe to ignore or complete in Asana.

- [ ] [Task 1](https://app.asana.com/1/45238840754660/task/1211860486771104)  ·  due 2025-11-06
- [ ] [Task 2](https://app.asana.com/1/45238840754660/task/1211860486771106)  ·  due 2025-11-07
- [ ] [Task 3](https://app.asana.com/1/45238840754660/task/1211860486771108)  ·  due 2025-11-10
