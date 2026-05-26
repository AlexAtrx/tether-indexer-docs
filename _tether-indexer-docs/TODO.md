# Asana TODO — assigned to Alex (Tether Indexer)

Generated: 2026-05-20 15:00 UTC
Source: Asana `users/me` task list (incomplete only)
Refresh: ask Claude to "refresh my Asana TODOs".

**Summary:** 32 assigned tasks (29 real + 3 placeholder) across 2 active
projects. 6 in flight (PR OPEN / DEV IN PROGRESS / In-Progress / Ready for
QA), 13 high priority.

---

## Top priorities — stand-up focus

### 1. Check why Sentry Rumble is not receiving data
[WDK-1462](https://app.asana.com/1/45238840754660/project/1210540875949204/task/1214842519965679) · WDK Backends:PR OPEN · High · Sprint 2
> Root cause: the `shouldHandleError` filter on the rumble-app-node Sentry
> integration was silently dropping every error matching `RPC client closed`
> or containing `CHANNEL_CLOSED`, so the dashboard looked empty even though
> Sentry was accepting 417k transactions per 14d. PR #212 opened against
> rumble-app-node:dev to demote those messages to `level=warning` via
> beforeSend and remove the unreachable drops. Now waiting on review.
local: `_tasks/26-20-may-26-WDK-1462-check-why-sentry-rumble-is-not-receiving-data/`

### 2. Rumble DEV: address environment slow restart
[WDK-1229 / RW-1730](https://app.asana.com/1/45238840754660/project/1210540875949204/task/1213475123348181) · WDK Backends:DEV IN PROGRESS · High · Sprint 2
> Sequential PM2 restart of the wdk fleet takes about a minute because every
> worker is forced to wait the full 300s kill-timeout when a SIGINT handler
> early-returns on `hnd.active === 0`, and the base `lockProcessing` poll in
> stop() has no timeout. Investigation and timings are written up in the
> local task folder. Next: open PRs against bfx-svc-boot-js and
> bfx-wrk-base, or work around at the wdk-be-deploy layer.
local: `_tasks/24-20-may-26-WDK-1229-rumble-dev-address-environment-slow-restart/`

### 3. Refactoring: move JWT userId request-param fallback to rumble layer
[WDK-1408](https://app.asana.com/1/45238840754660/project/1210540875949204/task/1214564483403277) · WDK Backends:DEV IN PROGRESS · Medium · Sprint 2
> Move the userId-from-JWT fallback out of the wdk-app-node base and into
> the rumble-app-node overlay so the wallet API stays generic. Francesco
> handed off testing and finalisation of the open PRs to andrey.gilyov; once
> his pass is done, the change can go through merge.
local: `_tasks/25-20-may-26-WDK-1408-refactoring-move-jwt-userid-request-param-fallback-to-rumble-layer/`

### 4. Backend Transactions: received BTC transaction doesn't display
[RW-1428](https://app.asana.com/1/45238840754660/project/1212521145936484/task/1213704628745111) · Rumble Wallet:In-Progress · High · Sprint 1+2
> Received BTC transactions occasionally don't show up in the wallet's
> transaction list even though the balance updates. QA on staging hasn't
> been able to repro from their own account; andrey.gilyov offered creds to
> try the repro under his account. Next step: pick up where the BTC indexer
> hands off to rumble-data-shard, since the balance path works but the
> transactions-list path does not.

### 5. Backend Transactions: BTC received transactions appear with delay
[RW-1720](https://app.asana.com/1/45238840754660/project/1212521145936484/task/1214638250128106) · Rumble Wallet:In-Progress · Medium · Sprint 2
> Same shape as RW-1428 but framed as "delay" rather than "missing".
> Mohamed flagged that this overlaps with RW-1428 / the BTC-from-staging
> ticket and the three should probably be merged. Pending Alex's call on
> whether to dedupe before continuing the investigation.

---

## In progress / In review
- [ ] [[Send] '8e-7 XAUT' transfer amount displays in the notification for '< $0.01 Plasma' transfer](https://app.asana.com/1/45238840754660/project/1212521145936484/task/1214269983129054) — `RW-1670` · Bug · Rumble Wallet:Ready for QA
      local: `_tasks/22-15-may-26-RW-1670-send-8e-7-xaut-transfer-amount-displays-in-the-notification-for-0-01-plasma-transfer/`
- [ ] [Fix ork discovery empty-list failure after restart (Jan 5 prod issue): handle ERR_TOPIC_LOOKUP_EMPTY](https://app.asana.com/1/45238840754660/project/1210540875949204/task/1212700198741856) — `WDK-1012` · WDK Backends:PR MERGED + TESTED ON DEV

## High priority — To Do
- [ ] [Rumble: Testing: Create cross-service E2E integration test suite](https://app.asana.com/1/45238840754660/project/1210540875949204/task/1212919215237588) — `WDK-1085 / RW-1729` · Task · WDK Backends:TO DO · Sprint 2
- [ ] [wdk-indexer-wrk-btc: Security: Fix High/Critical Vulnerabilities](https://app.asana.com/1/45238840754660/project/1210540875949204/task/1214716566892701) — `WDK-1446` · WDK Backends:TO DO · Sprint 2
- [ ] [wdk-indexer-wrk-spark: Security: Fix High/Critical Vulnerabilities](https://app.asana.com/1/45238840754660/project/1210540875949204/task/1214716470029391) — `WDK-1445` · WDK Backends:TO DO · Sprint 2
- [ ] [wdk-indexer-app-node: Security: Fix High/Critical Vulnerabilities](https://app.asana.com/1/45238840754660/project/1210540875949204/task/1214716462372233) — `WDK-1444` · WDK Backends:TO DO · Sprint 2
- [ ] [wdk-indexer-wrk-evm: Security: Fix High/Critical Vulnerabilities](https://app.asana.com/1/45238840754660/project/1210540875949204/task/1214716589484670) — `WDK-1443` · WDK Backends:TO DO · Sprint 2
- [ ] [rumble-app-node: Security: Fix High/Critical Vulnerabilities](https://app.asana.com/1/45238840754660/project/1210540875949204/task/1214716461893028) — `WDK-1442 / RW-1732` · Task · WDK Backends:TO DO · Sprint 2
- [ ] [rumble-promo-wrk: Security: Fix High/Critical Vulnerabilities](https://app.asana.com/1/45238840754660/project/1210540875949204/task/1214716439993136) — `WDK-1441` · WDK Backends:TO DO · Sprint 2
      local: `_tasks/18-13-may-26-WDK-1441-rumble-promo-wrk-security-fix-high-critical-vulnerabilities/`
- [ ] [wdk-app-node: Security: Fix High/Critical Vulnerabilities](https://app.asana.com/1/45238840754660/project/1210540875949204/task/1214716566376368) — `WDK-1438` · WDK Backends:TO DO · Sprint 2
- [ ] [Campaign BE work](https://app.asana.com/1/45238840754660/project/1212521145936484/task/1214395948381748) — `RW-1691` · Task · Rumble Wallet:To Triage · Sprint 1
      local: `_tasks/17-13-may-26-RW-1691-campaign-be-work/`
- [ ] [[Backend Transactions] After sending BTC on-chain from staging build to production build, transaction is not reflected in history but balance is updated](https://app.asana.com/1/45238840754660/project/1212521145936484/task/1214077903141396) — `RW-1622` · Bug · Rumble Wallet:To Triage · Sprint 1
- [ ] [[Balance: Backend] Investigate why BTC balances not updating for users buying from MoonPay](https://app.asana.com/1/45238840754660/project/1212521145936484/task/1214097552937526) — `RW-1632` · Task · Rumble Wallet:To Triage · Sprint 1
- [ ] [Rumble: Update Fastify plug ins](https://app.asana.com/1/45238840754660/project/1210540875949204/task/1213226894059885) — `WDK-1168 / RW-1680` · Task · WDK Backends:TO DO · Sprint 2
      local: `_tasks/16-12-may-26-WDK-1168-rumble-update-fastify-plug-ins/`
- [ ] [[Bckend: Tip jar] Tip button doesn't appear on Rumble and Send Tip button is inactive after following the channel](https://app.asana.com/1/45238840754660/project/1212521145936484/task/1213391745549211) — `RW-1120` · Bug · Rumble Wallet:Completed · Sprint 1

## Medium / Low — To Do
- [ ] [Implement: Rumble App Node API + Promo Worker refactor for configurable multi-campaign reusable code](https://app.asana.com/1/45238840754660/project/1210540875949204/task/1214776932455068) — `WDK-1454` · WDK Backends:TO DO · Sprint 2
      local: `_tasks/21-13-may-26-WDK-1454-implement-rumble-app-node-api-promo-worker-refactor-for-configurable-multi-campaign-reusable-code/`
- [ ] [Plan: adapt Rumble Promo Worker to reusable code and integrate with Rumble Backend API](https://app.asana.com/1/45238840754660/project/1210540875949204/task/1214776665413533) — `WDK-1453` · WDK Backends:TO DO · Sprint 2
      local: `_tasks/20-13-may-26-WDK-1453-plan-adapt-rumble-promo-worker-to-reusable-code-and-integrate-with-rumble-backend-api/`
- [ ] [Onboarding drop-off metric: daily first-time shard assignments vs wallets created](https://app.asana.com/1/45238840754660/project/1210540875949204/task/1214756103889646) — `WDK-1450` · Medium · WDK Backends:TO DO
- [ ] [Rumble: Remove Autobase layer](https://app.asana.com/1/45238840754660/project/1210540875949204/task/1214563205562819) — `WDK-1407 / RW-1731` · Medium · Task · WDK Backends:TO DO: lower prio
- [ ] [Rumble: Push notifications: format token amounts server-side (fix decimal/precision artifacts)](https://app.asana.com/1/45238840754660/project/1210540875949204/task/1214119276348483) — `WDK-1353` · Medium · WDK Backends:TO DO: lower prio
- [ ] [Rumble: investigate and solve ERR_WALLET_BALANCE_FAILURE_CCY error in staging](https://app.asana.com/1/45238840754660/project/1210540875949204/task/1214094490463459) — `WDK-1352 / RW-1625` · Medium · Task · Rumble Wallet:ToDo: Dev
- [ ] [[Push Notifications] Amount mismatch between "Transfer Initiated" and "Transfer Successful" notifications](https://app.asana.com/1/45238840754660/project/1212521145936484/task/1213989533989558) — `RW-1598` · Medium · Bug · Rumble Wallet:To Triage
- [ ] [[Analytics] Xaxis is incorrect on Asset trend chart](https://app.asana.com/1/45238840754660/project/1212521145936484/task/1213244394019831) — `WDK-1346 / RW-955` · Medium · Bug · Done · Rumble Wallet:Completed
- [ ] [[Assets] Only 1 dot is displayed for filter 7D and 1M](https://app.asana.com/1/45238840754660/project/1212521145936484/task/1213823149664564) — `RW-1486` · Medium · Bug · Rumble Wallet:To Triage
- [ ] [Rumble: Implement an endpoint to return the list of transactions based on wallet signature](https://app.asana.com/1/45238840754660/project/1210540875949204/task/1213663338730898) — `WDK-1283` · Medium · WDK Backends:TO DO: lower prio
- [ ] [Rumble: BE: stop push notifications when received amount <$0.1 for tip or normal receive](https://app.asana.com/1/45238840754660/project/1210540875949204/task/1213139196226601) — `WDK-1197 / RW-886` · Medium · Task · WDK Backends:TO DO: lower prio
- [ ] [BE to persist failed transactions](https://app.asana.com/1/45238840754660/project/1212521145936484/task/1213139196226597) — `RW-885` · Task · Rumble Wallet:To Triage

## Placeholder / onboarding
- [ ] [Task 1](https://app.asana.com/1/45238840754660/task/1211860486771104) · due 2025-11-06 **OVERDUE**
- [ ] [Task 2](https://app.asana.com/1/45238840754660/task/1211860486771106) · due 2025-11-07 **OVERDUE**
- [ ] [Task 3](https://app.asana.com/1/45238840754660/task/1211860486771108) · due 2025-11-10 **OVERDUE**

---

## Flags worth knowing
- `WDK-1462` was just moved to **PR OPEN** (the status update Alex just made in Asana); local PR is tetherto/rumble-app-node#212.
- Two tickets are sitting in **Completed** sections but are still marked
  incomplete in Asana: `RW-1120` (Tip jar) and `WDK-1346 / RW-955`
  (Analytics Xaxis). If the work really is done, close them in Asana.
- `WDK-1012` is in **PR MERGED + TESTED ON DEV** but still open. Same
  cleanup: close if the merge has stuck.
- 8 Sprint 2 Security tickets are all High priority and all sit in `TO DO`.
  Likely a single batch of work; consider tackling them together rather
  than serially.
- `RW-1428` and `RW-1720` are likely duplicates of the same BTC-receive
  bug (Mohamed flagged this on RW-1720). Decide which one is canonical
  before sinking more time into either.
