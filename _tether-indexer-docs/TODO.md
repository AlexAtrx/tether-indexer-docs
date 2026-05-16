# Asana TODO — assigned to Alex (Tether Indexer)

Generated: 2026-05-15 14:14 UTC
Source: Asana `users/me` task list (incomplete only)
Refresh: ask Claude to "refresh my Asana TODOs".

**Summary:** 37 assigned tasks (34 real, 3 placeholder) across 2 projects. 5 in progress, 15 high priority, 2 blocked.

> Tasks that live in both WDK Backends and Rumble Wallet projects are shown with both ids, e.g. `WDK-1168 / RW-1680`.

---

## Top priorities — stand-up focus

> Up to 5 items. These are what Alex talks through in the next stand-up.

### 1. [Backend - Transactions] Received BTC transaction doesn't display
`RW-1428` · [Asana](https://app.asana.com/1/45238840754660/project/1212521145936484/task/1213704628745111) · Rumble Wallet:In-Progress · High · In Progress
> Received BTC tx on staging never showed up in the user's history but balance did; user-side repro never landed and the task has been quiet since early April. Likely needs a nudge or close as not-reproducible.

### 2. [Send] Latest transactions are displayed after several minutes after confirmation
`RW-1706` · [Asana](https://app.asana.com/1/45238840754660/project/1212521145936484/task/1214576130837779) · Rumble Wallet:In-Progress · High · In Progress
> User-reported lag between confirmation and the tx showing in the list. Innowise explained that the backend indexer pipeline (chain event then index then expose) is what delays it; QA was asked to verify on prod. Priority was dropped in the meantime so this is now low-effort triage.

### 3. [Send] '8e-7 XAUT' transfer amount displays in the notification for '< $0.01 Plasma' transfer
`RW-1670` · [Asana](https://app.asana.com/1/45238840754660/project/1212521145936484/task/1214269983129054) · Rumble Wallet:In-Progress · Medium · In Progress
> Push notification renders tiny XAUT amounts in scientific form (8e-7) instead of a normal decimal. Reproduced again last week on BTC Spark too. This is the server-side amount formatting fix tracked alongside WDK-1353.

### 4. [Transactions] BTC received transactions appear in transaction list with delay
`RW-1720` · [Asana](https://app.asana.com/1/45238840754660/project/1212521145936484/task/1214638250128106) · Rumble Wallet:In-Progress · Medium · In Progress
> BTC received tx lags in the list while balance updates immediately. Innowise flagged this as a duplicate of RW-1706 and Mo agreed; we asked Eddy on May 13 to confirm so we can merge or close.

### 5. Refactoring - Move JWT userId request param fallback to rumble layer
`WDK-1408` · [Asana](https://app.asana.com/1/45238840754660/project/1210540875949204/task/1214564483403277) · WDK Backends:DEV IN PROGRESS · Medium · In Progress
> Refactor to move JWT userId fallback from WDK into the Rumble layer (so WDK can be open-sourced cleanly). PRs are open at rumble-app-node#181 and wdk-app-node#91; Francesco reassigned testing and finalisation to Alex on May 13.

---

## In progress / In review

- [ ] [[Analytics] Xaxis is incorrect on Asset trend chart](https://app.asana.com/1/45238840754660/project/1212521145936484/task/1213244394019831) · `WDK-1346` / `RW-955` · Medium · Rumble Wallet:Completed
      progress: Done
      note: sits in a Completed/Done Asana section but is still marked incomplete
- [ ] [Fix ork discovery empty-list failure after restart (Jan 5 prod issue) - handle ERR_TOPIC_LOOKUP_EMPTY](https://app.asana.com/1/45238840754660/project/1210540875949204/task/1212700198741856) · `WDK-1012` · Medium · WDK Backends:PR MERGED + TESTED ON DEV
      note: sits in a Completed/Done Asana section but is still marked incomplete
- [ ] [[Bckend - Tip jar] Tip button doesn't appear on the Rumble and Send Tip button is inactive after following the channel, user](https://app.asana.com/1/45238840754660/project/1212521145936484/task/1213391745549211) · `RW-1120` · High · Rumble Wallet:Completed
      note: sits in a Completed/Done Asana section but is still marked incomplete

## High priority — To Do

- [ ] [wdk-app-node - Security - Fix High/Critical Vulnerabilities](https://app.asana.com/1/45238840754660/project/1210540875949204/task/1214716566376368) · `WDK-1438` · WDK Backends:TO DO · due —
- [ ] [wdk-indexer-wrk-btc - Security - Fix High/Critical Vulnerabilities](https://app.asana.com/1/45238840754660/project/1210540875949204/task/1214716566892701) · `WDK-1446` · WDK Backends:TO DO · due —
- [ ] [wdk-indexer-wrk-evm - Security - Fix High/Critical Vulnerabilities](https://app.asana.com/1/45238840754660/project/1210540875949204/task/1214716589484670) · `WDK-1443` · WDK Backends:TO DO · due —
- [ ] [wdk-indexer-wrk-spark - Security - Fix High/Critical Vulnerabilities](https://app.asana.com/1/45238840754660/project/1210540875949204/task/1214716470029391) · `WDK-1445` · WDK Backends:TO DO · due —
- [ ] [Shared - Bugfix - purgeUserData doesn't reset deletedAt](https://app.asana.com/1/45238840754660/project/1210540875949204/task/1213882531683489) · `WDK-1315` · WDK Backends:TO DO · due —
      local: `_tasks/15-may-26-WDK-1315-shared-bugfix-purgeuserdata-doesn-t-reset-deletedat/`
- [ ] [[Balance - Backend] Investigate why BTC balances not updating for users buying from MoonPay](https://app.asana.com/1/45238840754660/project/1212521145936484/task/1214097552937526) · `RW-1632` · Rumble Wallet:To Triage · due —
- [ ] [[Backend Transactions]After sending BTC on-chain from the staging build to the production build, the transaction is not reflected in the transaction history, but the balance is updated](https://app.asana.com/1/45238840754660/project/1212521145936484/task/1214077903141396) · `RW-1622` · Rumble Wallet:To Triage · due —
- [ ] [Rumble - Testing - Create cross-service E2E integration test suite](https://app.asana.com/1/45238840754660/project/1210540875949204/task/1212919215237588) · `WDK-1085` / `RW-1729` · WDK Backends:TO DO · due —
- [ ] [Campaign BE work](https://app.asana.com/1/45238840754660/project/1212521145936484/task/1214395948381748) · `RW-1691` · Rumble Wallet:To Triage · due —
      local: `_tasks/13-may-26-RW-1691-campaign-be-work/`
- [ ] [Check why Sentry Rumble is not receiving data](https://app.asana.com/1/45238840754660/project/1210540875949204/task/1214842519965679) · `WDK-1462` · WDK Backends:TO DO · due —
- [ ] [rumble-promo-wrk - Security - Fix High/Critical Vulnerabilities](https://app.asana.com/1/45238840754660/project/1210540875949204/task/1214716439993136) · `WDK-1441` · WDK Backends:TO DO · due —
      local: `_tasks/13-may-26-WDK-1441-rumble-promo-wrk-security-fix-high-critical-vulnerabilities/`
- [ ] [wdk-indexer-app-node - Security - Fix High/Critical Vulnerabilities](https://app.asana.com/1/45238840754660/project/1210540875949204/task/1214716462372233) · `WDK-1444` · WDK Backends:TO DO · due —

## Medium / Low — To Do

- [ ] [Onboarding drop-off metric: daily first-time shard assignments vs wallets created](https://app.asana.com/1/45238840754660/project/1210540875949204/task/1214756103889646) · `WDK-1450` · Medium · WDK Backends:TO DO
- [ ] [Rumble - BE - stop push notifications when received amount <$0.1 for tip or normal receive](https://app.asana.com/1/45238840754660/project/1210540875949204/task/1213139196226601) · `WDK-1197` / `RW-886` · Medium · Rumble Wallet:To Triage
- [ ] [Rumble - Push notifications: format token amounts server-side (fix decimal/precision artifacts)](https://app.asana.com/1/45238840754660/project/1210540875949204/task/1214119276348483) · `WDK-1353` · Medium · WDK Backends:TO DO - lower prio
- [ ] [[Assets] Only 1 dot is displayed for filter 7D and 1M](https://app.asana.com/1/45238840754660/project/1212521145936484/task/1213823149664564) · `RW-1486` · Medium · Rumble Wallet:To Triage
- [ ] [Rumble - Remove Autobase layer](https://app.asana.com/1/45238840754660/project/1210540875949204/task/1214563205562819) · `WDK-1407` / `RW-1731` · WDK Backends:TO DO - lower prio
- [ ] [rumble-app-node - Security - Fix High/Critical Vulnerabilities](https://app.asana.com/1/45238840754660/project/1210540875949204/task/1214716461893028) · `WDK-1442` / `RW-1732` · WDK Backends:TO DO
- [ ] [Rumble DEV - Address environment slow restart](https://app.asana.com/1/45238840754660/project/1210540875949204/task/1213475123348181) · `WDK-1229` / `RW-1730` · WDK Backends:TO DO
- [ ] [[Push Notifications] Amount mismatch between “Transfer Initiated” and “Transfer Successful” notifications](https://app.asana.com/1/45238840754660/project/1212521145936484/task/1213989533989558) · `RW-1598` · Medium · Rumble Wallet:To Triage
- [ ] [Rumble - investigate and solve ERR_WALLET_BALANCE_FAILURE_CCY error in staging](https://app.asana.com/1/45238840754660/project/1210540875949204/task/1214094490463459) · `WDK-1352` / `RW-1625` · Medium · Rumble Wallet:ToDo - Dev
- [ ] [BE to persist failed transactions](https://app.asana.com/1/45238840754660/project/1212521145936484/task/1213139196226597) · `RW-885` · Rumble Wallet:To Triage
- [ ] [Plan: adapt Rumble Promo Worker to reusable code and integrate with Rumble Backend API](https://app.asana.com/1/45238840754660/project/1210540875949204/task/1214776665413533) · `WDK-1453` · WDK Backends:TO DO
      local: `_tasks/13-may-26-WDK-1453-plan-adapt-rumble-promo-worker-to-reusable-code-and-integrate-with-rumble-backend-api/`
- [ ] [Rumble - Implement an endpoint to return the list of transactions based on wallet signature](https://app.asana.com/1/45238840754660/project/1210540875949204/task/1213663338730898) · `WDK-1283` · Medium · WDK Backends:TO DO - lower prio

## Blocked / Deferred

- [ ] [Rumble - Update Fastify plug ins](https://app.asana.com/1/45238840754660/project/1210540875949204/task/1213226894059885) · `WDK-1168` / `RW-1680` · WDK Backends:TO DO
      local: `_tasks/12-may-26-WDK-1168-rumble-update-fastify-plug-ins/`
      reason: flagged Blocked
- [ ] [Implement: Rumble App Node API + Promo Worker refactor for configurable multi-campaign reusable code](https://app.asana.com/1/45238840754660/project/1210540875949204/task/1214776932455068) · `WDK-1454` · WDK Backends:TO DO
      local: `_tasks/13-may-26-WDK-1454-implement-rumble-app-node-api-promo-worker-refactor-for-configurable-multi-campaign-reusable-code/`
      reason: flagged Blocked

## Placeholder / onboarding

- [ ] [Task 1](https://app.asana.com/1/45238840754660/task/1211860486771104) · due 2025-11-06
- [ ] [Task 2](https://app.asana.com/1/45238840754660/task/1211860486771106) · due 2025-11-07
- [ ] [Task 3](https://app.asana.com/1/45238840754660/task/1211860486771108) · due 2025-11-10
