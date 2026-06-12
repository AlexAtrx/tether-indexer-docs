# Asana TODO — assigned to Alex (Tether Indexer)

Generated: 2026-05-26 12:57 UTC
Source: Asana `users/me` task list (incomplete only)
Refresh: ask Claude to "refresh my Asana TODOs".

**Summary:** 33 assigned tasks (30 real + 3 placeholder) across 2 projects
(Rumble Wallet, WDK Backends). 3 in progress, 15 high priority, 2 blocked,
3 likely-done-but-still-open.

---

## Top priorities — stand-up focus

> Up to 5 items. These are what Alex talks through in the next stand-up.

### 1. [Backend - Transactions] Received BTC transaction doesn't display
[RW-1428](https://app.asana.com/1/45238840754660/project/1212521145936484/task/1213704628745111) · Rumble Wallet:In-Progress · High · Severity Critical
> Received BTC tx shows balance but not the transaction in history. Long investigation: the BTC address that received the funds (bc1qgm7k...) has no trace in the backend wallet set, so token-transfers never returns it. Open question is how the user obtained that address. Still in progress.
local: `_tasks/08-28-apr-26-2-received-btc-transaction-doesnt-display/`

### 2. Rumble DEV - Address environment slow restart
[RW-1730 / WDK-1229](https://app.asana.com/1/45238840754660/project/1210540875949204/task/1213475123348181) · WDK Backends:DEV IN PROGRESS · High
> Feb 2026 prod symptom (30 min restart) no longer reproduces: a full sequential pm2 restart of all 51 wdk processes on rumble-dev now finishes in 52 seconds. Root cause still in code: hardcoded `--kill-timeout 300000` per process plus a SIGINT handler in bfx-svc-boot-js that silently returns if SIGINT lands during startup, so a wedged process can burn 5 min. Next is fixing the mechanism, not just the symptom.
local: `_tasks/24-20-may-26-WDK-1229-rumble-dev-address-environment-slow-restart/`

### 3. Campaign BE work
[RW-1691](https://app.asana.com/1/45238840754660/project/1212521145936484/task/1214395948381748) · Rumble Wallet:To Triage · High · Sprint 1
> Backend for the next promo campaign (configurable multi-campaign reusable code). Was waiting on FE to lock the interface and final specs. Initial PR drafts are posted in Slack; phase-2 work folder already started locally and a live PR review pass exists.
local: `_tasks/17-13-may-26-RW-1691-campaign-be-work/` (+ `-phase-2/`)

### 4. [Transactions] BTC received transactions appear in transaction list with delay
[RW-1720](https://app.asana.com/1/45238840754660/project/1212521145936484/task/1214638250128106) · Rumble Wallet:In-Progress · Medium
> BTC received transactions land in the list but with a delay. Flagged as a likely duplicate of RW task 1214576130837779 and needs merging/confirming before BE work. Closely related to the RW-1428 BTC-display investigation above.

### 5. Security hardening batch (7 repos)
[WDK-1438 …1446](https://app.asana.com/1/45238840754660/project/1210540875949204/task/1214716566376368) · WDK Backends:TO DO · High · Sprint 2
> Fix High/Critical npm vulnerabilities across 7 backend repos (wdk-app-node, rumble-app-node, rumble-promo-wrk, wdk-indexer-app-node, wdk-indexer-wrk-evm/spark/btc). All 7 local work folders were created May 20. See the dedicated section below for per-repo links.

---

## Security hardening — High (Sprint 2, 7 repos)
- [ ] [wdk-app-node - Security - Fix High/Critical Vulnerabilities](https://app.asana.com/1/45238840754660/project/1210540875949204/task/1214716566376368) — `WDK-1438` · WDK Backends:TO DO
      local: `_tasks/27-20-may-26-WDK-1438-wdk-app-node-security-fix-high-critical-vulnerabilities/`
- [ ] [rumble-promo-wrk - Security - Fix High/Critical Vulnerabilities](https://app.asana.com/1/45238840754660/project/1210540875949204/task/1214716439993136) — `WDK-1441` · WDK Backends:TO DO
      local: `_tasks/28-20-may-26-WDK-1441-rumble-promo-wrk-security-fix-high-critical-vulnerabilities/`
- [ ] [rumble-app-node - Security - Fix High/Critical Vulnerabilities](https://app.asana.com/1/45238840754660/project/1210540875949204/task/1214716461893028) — `WDK-1442` / `RW-1732` · WDK Backends:TO DO
      local: `_tasks/29-20-may-26-WDK-1442-rumble-app-node-security-fix-high-critical-vulnerabilities/`
- [ ] [wdk-indexer-wrk-evm - Security - Fix High/Critical Vulnerabilities](https://app.asana.com/1/45238840754660/project/1210540875949204/task/1214716589484670) — `WDK-1443` · WDK Backends:TO DO
      local: `_tasks/30-20-may-26-WDK-1443-wdk-indexer-wrk-evm-security-fix-high-critical-vulnerabilities/`
- [ ] [wdk-indexer-app-node - Security - Fix High/Critical Vulnerabilities](https://app.asana.com/1/45238840754660/project/1210540875949204/task/1214716462372233) — `WDK-1444` · WDK Backends:TO DO
      local: `_tasks/31-20-may-26-WDK-1444-wdk-indexer-app-node-security-fix-high-critical-vulnerabilities/`
- [ ] [wdk-indexer-wrk-spark - Security - Fix High/Critical Vulnerabilities](https://app.asana.com/1/45238840754660/project/1210540875949204/task/1214716470029391) — `WDK-1445` · WDK Backends:TO DO
      local: `_tasks/32-20-may-26-WDK-1445-wdk-indexer-wrk-spark-security-fix-high-critical-vulnerabilities/`
- [ ] [wdk-indexer-wrk-btc - Security - Fix High/Critical Vulnerabilities](https://app.asana.com/1/45238840754660/project/1210540875949204/task/1214716566892701) — `WDK-1446` · WDK Backends:TO DO
      local: `_tasks/33-20-may-26-WDK-1446-wdk-indexer-wrk-btc-security-fix-high-critical-vulnerabilities/`

## High priority — To Do
- [ ] [[Backend Transactions] After sending BTC on-chain from the staging build to the production build, the transaction is not reflected in the transaction history, but the balance is updated](https://app.asana.com/1/45238840754660/project/1212521145936484/task/1214077903141396) — `RW-1622` · Rumble Wallet:To Triage · due —
- [ ] [[Balance - Backend] Investigate why BTC balances not updating for users buying from MoonPay](https://app.asana.com/1/45238840754660/project/1212521145936484/task/1214097552937526) — `RW-1632` · Rumble Wallet:To Triage · due —
- [ ] [Rumble - Testing - Create cross-service E2E integration test suite](https://app.asana.com/1/45238840754660/project/1210540875949204/task/1212919215237588) — `WDK-1085` / `RW-1729` · WDK Backends:TO DO · due —

## Medium / Low — To Do
- [ ] [[Send] '8e-7 XAUT' transfer amount displays in the notification for '< $0.01 Plasma' transfer](https://app.asana.com/1/45238840754660/project/1212521145936484/task/1214269983129054) — `RW-1670` · Medium · Rumble Wallet:Ready for QA
      local: `_tasks/22-15-may-26-RW-1670-send-8e-7-xaut-transfer-amount-displays-in-the-notification-for-0-01-plasma-transfer/`
- [ ] [Onboarding drop-off metric: daily first-time shard assignments vs wallets created](https://app.asana.com/1/45238840754660/project/1210540875949204/task/1214756103889646) — `WDK-1450` · Medium · WDK Backends:TO DO
- [ ] [Rumble - Remove Autobase layer](https://app.asana.com/1/45238840754660/project/1210540875949204/task/1214563205562819) — `WDK-1407` / `RW-1731` · Medium · WDK Backends:TO DO - lower prio
- [ ] [Rumble - Push notifications: format token amounts server-side (fix decimal/precision artifacts)](https://app.asana.com/1/45238840754660/project/1210540875949204/task/1214119276348483) — `WDK-1353` · Medium · WDK Backends:TO DO - lower prio
- [ ] [Rumble - investigate and solve ERR_WALLET_BALANCE_FAILURE_CCY error in staging](https://app.asana.com/1/45238840754660/project/1210540875949204/task/1214094490463459) — `WDK-1352` / `RW-1625` · Medium · Rumble Wallet:ToDo - Dev
- [ ] [[Push Notifications] Amount mismatch between "Transfer Initiated" and "Transfer Successful" notifications](https://app.asana.com/1/45238840754660/project/1212521145936484/task/1213989533989558) — `RW-1598` · Medium · FE · Rumble Wallet:To Triage
- [ ] [[Assets] Only 1 dot is displayed for filter 7D and 1M](https://app.asana.com/1/45238840754660/project/1212521145936484/task/1213823149664564) — `RW-1486` · Medium · Rumble Wallet:To Triage
- [ ] [Rumble - Implement an endpoint to return the list of transactions based on wallet signature](https://app.asana.com/1/45238840754660/project/1210540875949204/task/1213663338730898) — `WDK-1283` · Medium · WDK Backends:TO DO - lower prio
- [ ] [Rumble - BE - stop push notifications when received amount <$0.1 for tip or normal receive](https://app.asana.com/1/45238840754660/project/1210540875949204/task/1213139196226601) — `WDK-1197` / `RW-886` · Medium · Rumble Wallet:To Triage
- [ ] [Plan: adapt Rumble Promo Worker to reusable code and integrate with Rumble Backend API](https://app.asana.com/1/45238840754660/project/1210540875949204/task/1214776665413533) — `WDK-1453` · WDK Backends:TO DO · Sprint 2
      local: `_tasks/20-13-may-26-WDK-1453-plan-adapt-rumble-promo-worker-to-reusable-code-and-integrate-with-rumble-backend-api/`
- [ ] [BE to persist failed transactions](https://app.asana.com/1/45238840754660/project/1212521145936484/task/1213139196226597) — `RW-885` · Rumble Wallet:To Triage

## Blocked / Deferred
- [ ] [Implement: Rumble App Node API + Promo Worker refactor for configurable multi-campaign reusable code](https://app.asana.com/1/45238840754660/project/1210540875949204/task/1214776932455068) — `WDK-1454` · BLOCKED · WDK Backends:TO DO · Sprint 2
      local: `_tasks/21-13-may-26-WDK-1454-implement-rumble-app-node-api-promo-worker-refactor-for-configurable-multi-campaign-reusable-code/`
- [ ] [Rumble - Update Fastify plug ins](https://app.asana.com/1/45238840754660/project/1210540875949204/task/1213226894059885) — `WDK-1168` / `RW-1680` · BLOCKED · High · WDK Backends:TO DO
      local: `_tasks/16-12-may-26-WDK-1168-rumble-update-fastify-plug-ins/`

## Likely done — still open in Asana (verify + close)
- [ ] [[Bckend - Tip jar] Tip button doesn't appear on the Rumble and Send Tip button is inactive after following the channel, user](https://app.asana.com/1/45238840754660/project/1212521145936484/task/1213391745549211) — `RW-1120` · sits in Rumble Wallet:Completed (Fix Version RW 2.0.4) but still marked incomplete
- [ ] [[Analytics] Xaxis is incorrect on Asset trend chart](https://app.asana.com/1/45238840754660/project/1212521145936484/task/1213244394019831) — `RW-955` / `WDK-1346` · Task Progress = Done, in Completed section, still incomplete
      local: `_tasks/02-15-apr-26-Xaxis-is-incorrect/`
- [ ] [Fix ork discovery empty-list failure after restart (Jan 5 prod issue) - handle ERR_TOPIC_LOOKUP_EMPTY](https://app.asana.com/1/45238840754660/project/1210540875949204/task/1212700198741856) — `WDK-1012` · in PR MERGED + TESTED ON DEV since Jan, still open

## Placeholder / onboarding
- [ ] [Task 1](https://app.asana.com/1/45238840754660/task/1211860486771104) · due 2025-11-06 **OVERDUE**
- [ ] [Task 2](https://app.asana.com/1/45238840754660/task/1211860486771106) · due 2025-11-07 **OVERDUE**
- [ ] [Task 3](https://app.asana.com/1/45238840754660/task/1211860486771108) · due 2025-11-10 **OVERDUE**
