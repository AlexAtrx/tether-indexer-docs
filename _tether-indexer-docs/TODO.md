# Asana TODO — assigned to Alex (Tether Indexer)

Generated: 2026-05-04 10:55 UTC
Source: Asana `users/me` task list (incomplete only) + **Sprint** custom field on the WDK Indexer project (gid 1210540875949204)
Refresh: ask Claude to "refresh my Asana TODOs".

**Summary:** 25 assigned tasks (22 real + 3 placeholder) across 4 projects. **6 are in the current sprint (Sprint 1)**; 1 already tagged into the next sprint (Sprint 2). 4 in progress / in review, 11 high priority, 1 deferred.

---

## Current sprint — Sprint 1 — assigned to me (6)

> Captured via the **Sprint** custom field = "Sprint 1" on the WDK Indexer project. This matches the filtered board view at `…/project/1210540875949204/list/1210540715526618`. These take priority for the sprint.

- [ ] [Rumble - Silence the remaining Sentry False Positives (#3)](https://app.asana.com/1/45238840754660/project/1210540875949204/task/1213662485884824) · High · WDK Indexer:**PR OPEN - IN REVIEW**
      > Follow-up to the #2 Sentry pass: Francesco believes the remaining unresolved high/medium issues in the Rumble Sentry project are also false positives. Walk each linked issue, confirm, and add filters so they stop paging.
- [ ] [Rumble - \[Send\] BTC transactions are logged with incorrect amounts](https://app.asana.com/1/45238840754660/project/1211195910521628/task/1212744757896562) · Medium · WDK Indexer:**PR OPEN - IN REVIEW**
      > Sent-BTC entries in the app history show amounts that don't match what was actually sent. PR is open and awaiting review; the V1 Bugs Tracking copy is parked under Blocked until that lands.
- [ ] [Move #192 code to Rumble Data Shard](https://app.asana.com/1/45238840754660/project/1210540875949204/task/1214430872139370) · High · WDK Indexer:TO DO
- [ ] [Rumble - Security - Fix Tron Indexer High Vulnerabilities](https://app.asana.com/1/45238840754660/project/1210540875949204/task/1213478780310237) · High · WDK Indexer:TO DO
- [ ] [Rumble - Refactor wdk-* Repos to Remove Rumble-Specific Logic](https://app.asana.com/1/45238840754660/project/1210540875949204/task/1213303070214495) · High · WDK Indexer:TO DO · **BLOCKED**
- [ ] [Rumble - Update Fastify plug ins](https://app.asana.com/1/45238840754660/project/1210540875949204/task/1213226894059885) · High · WDK Indexer:TO DO · **BLOCKED**

### Next sprint (Sprint 2) — already tagged
- [ ] [Shared - Bugfix - purgeUserData doesn't reset deletedAt](https://app.asana.com/1/45238840754660/project/1210540875949204/task/1213882531683489) · High · WDK Indexer:TO DO

---

## Other top priorities — stand-up focus

> Active items not tagged into the current sprint but still load-bearing.

### 1. [Backend - Transactions] Received BTC transaction doesn't display in transaction history
[1213704628745111](https://app.asana.com/1/45238840754660/project/1212521145936484/task/1213704628745111) · Rumble Wallet:In-Progress · High
> Reported: receiving BTC on staging doesn't surface the tx in history. Latest signal is from Andrey on 2026-04-06 asking to retry with his credentials on staging, so it sits waiting on a fresh repro before any code change.
local: `_tasks/28-apr-26-2-received-btc-transaction-doesnt-display/`

### 2. Fix ork discovery empty-list failure after restart
[1212700198741856](https://app.asana.com/1/45238840754660/project/1210540875949204/task/1212700198741856) · WDK Indexer:PR MERGED + DEPLOYED TO DEV · Medium
> Post-restart bug where new wallet creation failed for ~4.5h because app-node accepted traffic before any ork worker was discoverable. Fix (readiness gate, RoundRobin guard, ERR_TOPIC_LOOKUP_EMPTY handling) is merged to dev; needs verification on staging and a regression test before closing.

---

## High priority — To Do
- [ ] [Campaign BE work](https://app.asana.com/1/45238840754660/project/1212521145936484/task/1214395948381748) · Rumble Wallet:To Triage
- [ ] [\[Backend Transactions\] After sending BTC on-chain from the staging](https://app.asana.com/1/45238840754660/project/1212521145936484/task/1214077903141396) · Rumble Wallet:To Triage
- [ ] [\[Balance - Backend\] Investigate why BTC balances not updating](https://app.asana.com/1/45238840754660/project/1212521145936484/task/1214097552937526) · Rumble Wallet:To Triage
      local: `_tasks/2-march-2026/17-march-26-Balance-fetching/`
- [ ] [\[Bckend - Tip jar\] Tip button doesn't appear on the Rumble app](https://app.asana.com/1/45238840754660/project/1212521145936484/task/1213391745549211) · Rumble Wallet:Completed (still open in Asana, see anomalies)
      local: `_tasks/2-march-2026/17-march-26-tip-button-doesnt-appear/`

## Medium / Low — To Do
- [ ] [Rumble - Push notifications: format token amounts server-side](https://app.asana.com/1/45238840754660/project/1210540875949204/task/1214119276348483) · Medium · WDK Indexer:TO DO - Medium + Low Prio
      local: `_tasks/17-apr-26-decimals-issue/`
- [ ] [Rumble - investigate and solve ERR_WALLET_BALANCE_FAILURE_CC](https://app.asana.com/1/45238840754660/project/1212521145936484/task/1214094490463459) · Medium · Rumble Wallet:ToDo - Dev
- [ ] [\[Push Notifications\] Amount mismatch between "Transfer Initiated" and actual amount](https://app.asana.com/1/45238840754660/project/1212521145936484/task/1213989533989558) · Medium · Rumble Wallet:To Triage
      local: `_tasks/16-apr-26-1-The-amount-in-the-push-looks-with-incorrect-decimals/`
- [ ] [\[Analytics\] Xaxis is incorrect on Asset trend chart](https://app.asana.com/1/45238840754660/project/1212521145936484/task/1213244394019831) · Medium · Rumble Wallet:Completed (Task Progress = Done but still open, see anomalies)
      local: `_tasks/15-apr-26-Xaxis-is-incorrect/`
- [ ] [\[Assets\] Only 1 dot is displayed for filter 7D and 1M](https://app.asana.com/1/45238840754660/project/1212521145936484/task/1213823149664564) · Medium · Rumble Wallet:To Triage
- [ ] [Rumble - Implement an endpoint to return the list of transactions](https://app.asana.com/1/45238840754660/project/1210540875949204/task/1213663338730898) · Medium · WDK Indexer:TO DO - Medium + Low Prio
      local: `_tasks/2-march-2026/23-march-26-1-Rumble-GET-token-transfers/`
- [ ] [Rumble - BE - stop push notifications when received amount is below dust](https://app.asana.com/1/45238840754660/project/1212521145936484/task/1213139196226601) · Medium · Rumble Wallet:To Triage
- [ ] [BE to persist failed transactions](https://app.asana.com/1/45238840754660/project/1212521145936484/task/1213139196226597) · Rumble Wallet:To Triage

## Blocked / Deferred
- [ ] [Remove the initiated transfer notification](https://app.asana.com/1/45238840754660/project/1212521145936484/task/1213287908612993) · High · Rumble Wallet:Next steps · due 2026-02-19 **OVERDUE** · Task Progress = Deferred

## Placeholder / onboarding
- [ ] [Task 1](https://app.asana.com/1/45238840754660/project/1211860486771097/task/1211860486771104) · due 2025-11-06 **OVERDUE**
- [ ] [Task 2](https://app.asana.com/1/45238840754660/project/1211860486771097/task/1211860486771106) · due 2025-11-07 **OVERDUE**
- [ ] [Task 3](https://app.asana.com/1/45238840754660/project/1211860486771097/task/1211860486771108) · due 2025-11-10 **OVERDUE**

---

## Anomalies worth flagging

- **Tip-button task** ([1213391745549211](https://app.asana.com/1/45238840754660/project/1212521145936484/task/1213391745549211)) sits in the "Completed" section on the Rumble Wallet board but is still marked incomplete in Asana. Either close it or move it back to an active section.
- **Xaxis analytics task** ([1213244394019831](https://app.asana.com/1/45238840754660/project/1212521145936484/task/1213244394019831)) has Task Progress = "Done" and is in the Completed section, but the task itself is still open. Same: close it or reset progress.
- **Onboarding placeholders** (Task 1/2/3) have been overdue since November 2025. Probably safe to mark complete or delete.
- **Sprint identification:** the URL (`…/list/1210540715526618`) is a saved board view filtered to **Sprint = Sprint 1**. The REST API doesn't expose saved views by gid, so the captured set was reproduced via the project's `Sprint` custom field — confirmed against the screenshot (Move #192, Tron Indexer security, Update Fastify, Refactor wdk-* in TO DO; Sentry FP #3 and Send-BTC in PR OPEN - IN REVIEW). The purgeUserData ticket is tagged Sprint 2 and is therefore listed as next-sprint, not current.
