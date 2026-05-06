# Asana TODO — assigned to Alex (Tether Indexer)

Generated: 2026-05-06 12:28 UTC
Source: Asana `users/me` task list (incomplete only)
Refresh: ask Claude to "refresh my Asana TODOs".

**Summary:** 25 assigned tasks (22 real + 3 placeholder) across 3 projects.
2 actively in progress, 3 in PR review or deployed-to-dev, 8 high or critical
priority, 1 deferred, 2 sitting in a "Completed" board section but still open
in Asana (flagged below).

---

## Top priorities — stand-up focus

> Up to 5 items. These are what Alex talks through in the next stand-up.

### 1. Provide commands to delete a transaction that is not on the mempool anymore
[RW-1699](https://app.asana.com/1/45238840754660/project/1210540875949204/task/1214518529430430) · WDK Indexer / Rumble Wallet · Critical · DEV IN PROGRESS
> Andrei is seeing a stream of `ERR_GET_TX_FROM_CHAIN_FAILED` on the same hash that has dropped out of the mempool, likely underpriced. Need to ship a runbook command to mark such transactions failed and stop the polling loop. Alex has asked Francesco three clarifying questions before writing the script: whether the tx already flipped to `failed` on its own via the existing shard-wrk safety net, and whether Andrei wants a manual override on top.

### 2. Received BTC transaction doesn't display
[RW-1428](https://app.asana.com/1/45238840754660/project/1212521145936484/task/1213704628745111) · Rumble Wallet · High · In-Progress
local: `_tasks/28-apr-26-2-received-btc-transaction-doesnt-display/`
> User reports an inbound BTC tx that never showed up in the app. Backend has no trace of the receiving address `bc1qgm7k...`, so Alex pushed back asking how the user obtained that address. Tester offered staging credentials to reproduce; ticket has been quiet since early April but is still flagged In-Progress on the Rumble board, so worth confirming whether to keep chasing or close.

### 3. Rumble - [Send] BTC transactions are logged with incorrect amounts
[1212744757896562](https://app.asana.com/1/45238840754660/project/1210540875949204/task/1212744757896562) · WDK Indexer · Medium · PR OPEN - IN REVIEW (also Blocked on the V1 Bugs board)
> Sender side records the wrong BTC amount in transaction history while the receiver side is correct. PR is open against the indexer; cross-listed in the V1 Bugs Tracking project as Blocked, so worth a quick check on what the blocker is and whether the open PR can land independently.

### 4. Rumble - Silence the remaining Sentry False Positives (#3)
[1213662485884824](https://app.asana.com/1/45238840754660/project/1210540875949204/task/1213662485884824) · WDK Indexer · High · PR MERGED + DEPLOYED TO DEV
> [PR #198](https://github.com/tetherto/rumble-app-node/pull/198) is merged and deployed to dev: it adds `FST_ERR_VALIDATION`, RPC client closed, and `CHANNEL_CLOSED` to the server-side Sentry filter. All 22 issues from the ticket are resolved (20 filtered, 2 timeouts had zero events in the last 30 days). Next step is closing the ticket once it has soaked in dev.

### 5. Move #192 code to Rumble Data Shard
[1214430872139370](https://app.asana.com/1/45238840754660/project/1210540875949204/task/1214430872139370) · WDK Indexer · High · TO DO · Sprint 1
> Port [wdk-data-shard-wrk PR #192](https://github.com/tetherto/wdk-data-shard-wrk/pull/192) into rumble-data-shard-wrk. Alex has not started yet because PR #192 was reverted on the WDK side without explanation; he has pinged the original author asking what broke, so he doesn't reintroduce the same regression in Rumble.

---

## In progress / In review
- [ ] [Provide commands to delete a transaction that is not on the mempool anymore](https://app.asana.com/1/45238840754660/project/1210540875949204/task/1214518529430430) · `RW-1699` · Critical · WDK Indexer:DEV IN PROGRESS
- [ ] [[Backend - Transactions] Received BTC transaction doesn't display](https://app.asana.com/1/45238840754660/project/1212521145936484/task/1213704628745111) · `RW-1428` · High · Rumble Wallet:In-Progress
      local: `_tasks/28-apr-26-2-received-btc-transaction-doesnt-display/`
- [ ] [Rumble - [Send] BTC transactions are logged with incorrect amounts](https://app.asana.com/1/45238840754660/project/1210540875949204/task/1212744757896562) · Medium · Sprint 1 · WDK Indexer:PR OPEN - IN REVIEW (also V1 Bugs Tracking:Blocked)
- [ ] [Rumble - Silence the remaining Sentry False Positives - (#3)](https://app.asana.com/1/45238840754660/project/1210540875949204/task/1213662485884824) · High · Sprint 1 · WDK Indexer:PR MERGED + DEPLOYED TO DEV
- [ ] [Fix ork discovery empty-list failure after restart (Jan 5 prod issue)](https://app.asana.com/1/45238840754660/project/1210540875949204/task/1212700198741856) · Medium · WDK Indexer:PR MERGED + DEPLOYED TO DEV

## High priority — To Do
- [ ] [Move #192 code to Rumble Data Shard](https://app.asana.com/1/45238840754660/project/1210540875949204/task/1214430872139370) · Sprint 1 · WDK Indexer:TO DO
- [ ] [Shared - Bugfix - purgeUserData doesn't reset deletedAt](https://app.asana.com/1/45238840754660/project/1210540875949204/task/1213882531683489) · Sprint 2 · WDK Indexer:TO DO
- [ ] [Campaign BE work](https://app.asana.com/1/45238840754660/project/1212521145936484/task/1214395948381748) · `RW-1691` · BE · Sprint 1 · Rumble Wallet:To Triage
- [ ] [[Backend Transactions] After sending BTC on-chain from the staging build to the prod build...](https://app.asana.com/1/45238840754660/project/1212521145936484/task/1214077903141396) · `RW-1622` · BE · Sprint 1 · Rumble Wallet:To Triage
- [ ] [[Balance - Backend] Investigate why BTC balances not updating for users buying from staging](https://app.asana.com/1/45238840754660/project/1212521145936484/task/1214097552937526) · `RW-1632` · BE · Sprint 1 · Rumble Wallet:To Triage

## Medium / Low — To Do
- [ ] [Rumble - Push notifications: format token amounts server-side (fix decimal/precision)](https://app.asana.com/1/45238840754660/project/1210540875949204/task/1214119276348483) · Medium · WDK Indexer:TO DO - Medium + Low Prio
- [ ] [Rumble - investigate and solve ERR_WALLET_BALANCE_FAILURE_CCY error in staging](https://app.asana.com/1/45238840754660/project/1210540875949204/task/1214094490463459) · `RW-1625` · Medium · Rumble Wallet:ToDo - Dev / WDK Indexer:TO DO - Medium + Low Prio
- [ ] [[Push Notifications] Amount mismatch between "Transfer Initiated" and "Transfer Completed"](https://app.asana.com/1/45238840754660/project/1212521145936484/task/1213989533989558) · `RW-1598` · Medium · FE · Rumble Wallet:To Triage
      local: `_tasks/16-apr-26-1-The-amount-in-the-push-looks-with-incorrect-decimals/`
- [ ] [[Assets] Only 1 dot is displayed for filter 7D and 1M](https://app.asana.com/1/45238840754660/project/1212521145936484/task/1213823149664564) · `RW-1486` · Medium · BE · Rumble Wallet:To Triage
- [ ] [Rumble - Security - Fix Tron Indexer High Vulnerabilities](https://app.asana.com/1/45238840754660/project/1210540875949204/task/1213478780310237) · `RW-1682` · Sprint 1 · WDK Indexer:TO DO / Rumble Wallet:To Triage
- [ ] [Rumble - Implement an endpoint to return the list of transactions based on wallet](https://app.asana.com/1/45238840754660/project/1210540875949204/task/1213663338730898) · Medium · WDK Indexer:TO DO - Medium + Low Prio
- [ ] [Rumble - BE - stop push notifications when received amount <$0.1 for tip or normal tx](https://app.asana.com/1/45238840754660/project/1210540875949204/task/1213139196226601) · `RW-886` · Medium · BE · WDK Indexer:TO DO - Medium + Low Prio / Rumble Wallet:To Triage
- [ ] [BE to persist failed transactions](https://app.asana.com/1/45238840754660/project/1212521145936484/task/1213139196226597) · `RW-885` · BE · Rumble Wallet:To Triage
- [ ] [Rumble - Update Fastify plug ins](https://app.asana.com/1/45238840754660/project/1210540875949204/task/1213226894059885) · `RW-1680` · WDK Indexer:TO DO / Rumble Wallet:To Triage

## Blocked / Deferred
- [ ] [Remove the initiated transfer notification](https://app.asana.com/1/45238840754660/project/1212521145936484/task/1213287908612993) · `RW-977` · High · BE · Rumble Wallet:Next steps · due 2026-02-19 **OVERDUE** · Task Progress: Deferred

## Marked Completed but still open in Asana (flag)
- [ ] [[Bckend - Tip jar] Tip button doesn't appear on the Rumble and Send Tip button is missing](https://app.asana.com/1/45238840754660/project/1212521145936484/task/1213391745549211) · `RW-1120` · High · BE · Sprint 1 · Rumble Wallet:**Completed** (still incomplete in Asana)
- [ ] [[Analytics] Xaxis is incorrect on Asset trend chart](https://app.asana.com/1/45238840754660/project/1212521145936484/task/1213244394019831) · `RW-955` · Medium · Bug · Rumble Wallet:**Completed** · Task Progress: Done (still incomplete in Asana)
      local: `_tasks/15-apr-26-Xaxis-is-incorrect/`

## Placeholder / onboarding
- [ ] [Task 1](https://app.asana.com/1/45238840754660/task/1211860486771104) · due 2025-11-06 **OVERDUE**
- [ ] [Task 2](https://app.asana.com/1/45238840754660/task/1211860486771106) · due 2025-11-07 **OVERDUE**
- [ ] [Task 3](https://app.asana.com/1/45238840754660/task/1211860486771108) · due 2025-11-10 **OVERDUE**
