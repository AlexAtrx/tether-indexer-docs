# Asana TODO — assigned to Alex (Tether Indexer)

Generated: 2026-05-13 13:37 UTC
Source: Asana `users/me` task list (incomplete only)
Scope: Sprint 2 (active sprint) plus pending Sprint 1 tickets that didn't carry over.
Refresh: ask Claude to "refresh my Asana TODOs".

**Summary:** 17 assigned tasks in scope. 12 in Sprint 2, 1 in both Sprint 1 and Sprint 2, 4 pending from Sprint 1 only. 3 actively in flight (1 PR open, 1 dev in progress, 1 in progress). 11 High priority, 1 Medium, 5 priority unset.

---

## Top priorities — stand-up focus

### 1. Move #192 code to Rumble Data Shard
[Asana](https://app.asana.com/0/1212521145936484/1214430872139370) · `WDK-1389` · WDK Backends:PR OPEN · High · Sprint 2
> Porting the previously reverted wdk-data-shard-wrk PR #192 onto rumble-data-shard-wrk. New PR is open (rumble-data-shard-wrk#216) and Francesco pinged today asking for the merge. Next step: respond to review feedback and land it.
local: `_tasks/04-may-26-WDK-1389-move-192-code-to-rumble-data-shard/`

### 2. Refactoring: move JWT userId request param fallback to rumble layer
[Asana](https://app.asana.com/0/1212521145936484/1214564483403277) · WDK Backends:DEV IN PROGRESS · Medium · Sprint 2
> Pulling Rumble-specific userId/JWT logic out of the WDK layer into the Rumble layer so WDK stays clean for open-sourcing. Francesco handed it over today: take over testing and finalisation of rumble-app-node#181 and wdk-app-node#91.

### 3. [Backend - Transactions] Received BTC transaction doesn't display
[Asana](https://app.asana.com/0/1212521145936484/1213704628745111) · Rumble Wallet:In-Progress · High · Sprint 1 + Sprint 2
> Single-user issue where an inbound BTC tx for a `bc1q...` address isn't shown. Investigation has been stuck on where the FE sources that address, since `/wallets` doesn't return it. Next: chase the mobile team for the in-repo traces I asked for (QRCodeDisplay store binding + bc1q grep), then resume the BE side.
local: `_tasks/28-apr-26-2-received-btc-transaction-doesnt-display/`

### 4. Plan: adapt Rumble Promo Worker to reusable code and integrate with Rumble Backend API
[Asana](https://app.asana.com/0/1212521145936484/1214776665413533) · `WDK-1453` · WDK Backends:TO DO · Sprint 2
> Planning card. Define the refactor approach for turning the promo worker into reusable, multi-campaign code and its integration with the Rumble Backend API. Output is a design doc plus a task breakdown that feeds the implementation card below.
local: `_tasks/13-may-26-WDK-1453-plan-adapt-rumble-promo-worker-to-reusable-code-and-integrate-with-rumble-backend-api/`

### 5. Implement: Rumble App Node API + Promo Worker refactor for multi-campaign reusable code
[Asana](https://app.asana.com/0/1212521145936484/1214776932455068) · `WDK-1454` · WDK Backends:TO DO · Sprint 2
> Implementation card paired with the planning ticket above. Touches both rumble-app-node API and the promo worker so multiple campaigns can be configured against a shared codebase. Blocked on the plan landing first.
local: `_tasks/13-may-26-WDK-1454-implement-rumble-app-node-api-promo-worker-refactor-for-configurable-multi-campaign-reusable-code/`

---

## In progress / In review

- [ ] [Move #192 code to Rumble Data Shard](https://app.asana.com/0/1212521145936484/1214430872139370) · `WDK-1389` · High · WDK Backends:PR OPEN · Sprint 2
      local: `_tasks/04-may-26-WDK-1389-move-192-code-to-rumble-data-shard/`
- [ ] [Refactoring - Move JWT userId request param fallback to rumble layer](https://app.asana.com/0/1212521145936484/1214564483403277) · Medium · WDK Backends:DEV IN PROGRESS · Sprint 2
- [ ] [\[Backend - Transactions\] Received BTC transaction doesn't display](https://app.asana.com/0/1212521145936484/1213704628745111) · High · Rumble Wallet:In-Progress · Sprint 1 + Sprint 2
      local: `_tasks/28-apr-26-2-received-btc-transaction-doesnt-display/`

## High priority — To Do (Sprint 2)

- [ ] [wdk-app-node - Security - Fix High/Critical Vulnerabilities](https://app.asana.com/0/1212521145936484/1214716566376368) · WDK Backends:TO DO · Sprint 2
- [ ] [rumble-promo-wrk - Security - Fix High/Critical Vulnerabilities](https://app.asana.com/0/1212521145936484/1214716439993136) · WDK Backends:TO DO · Sprint 2
      local: `_tasks/13-may-26-WDK-1441-rumble-promo-wrk-security-fix-high-critical-vulnerabilities/`
- [ ] [wdk-indexer-app-node - Security - Fix High/Critical Vulnerabilities](https://app.asana.com/0/1212521145936484/1214716462372233) · WDK Backends:TO DO · Sprint 2
- [ ] [wdk-indexer-wrk-btc - Security - Fix High/Critical Vulnerabilities](https://app.asana.com/0/1212521145936484/1214716566892701) · WDK Backends:TO DO · Sprint 2
- [ ] [wdk-indexer-wrk-evm - Security - Fix High/Critical Vulnerabilities](https://app.asana.com/0/1212521145936484/1214716589484670) · WDK Backends:TO DO · Sprint 2
- [ ] [wdk-indexer-wrk-spark - Security - Fix High/Critical Vulnerabilities](https://app.asana.com/0/1212521145936484/1214716470029391) · WDK Backends:TO DO · Sprint 2
- [ ] [Shared - Bugfix - purgeUserData doesn't reset deletedAt](https://app.asana.com/0/1212521145936484/1213882531683489) · WDK Backends:TO DO · Sprint 2

## To Do (Sprint 2, priority unset)

- [ ] [Rumble staging - EVM indexer: could not coalesce error on eth_getTransactionReceipt](https://app.asana.com/0/1212521145936484/1214766982648102) · WDK Backends:TO DO · Sprint 2
- [ ] [Plan: adapt Rumble Promo Worker to reusable code and integrate with Rumble Backend API](https://app.asana.com/0/1212521145936484/1214776665413533) · `WDK-1453` · WDK Backends:TO DO · Sprint 2
      local: `_tasks/13-may-26-WDK-1453-plan-adapt-rumble-promo-worker-to-reusable-code-and-integrate-with-rumble-backend-api/`
- [ ] [Implement: Rumble App Node API + Promo Worker refactor for configurable multi-campaign reusable code](https://app.asana.com/0/1212521145936484/1214776932455068) · `WDK-1454` · WDK Backends:TO DO · Sprint 2
      local: `_tasks/13-may-26-WDK-1454-implement-rumble-app-node-api-promo-worker-refactor-for-configurable-multi-campaign-reusable-code/`

## Pending from Sprint 1 (not in Sprint 2)

- [ ] [Campaign BE work](https://app.asana.com/0/1212521145936484/1214395948381748) · High · Rumble Wallet:To Triage · Sprint 1
      local: `_tasks/13-may-26-RW-1691-campaign-be-work/`
- [ ] [\[Backend Transactions\] After sending BTC on-chain from the staging build to the prod build, the transaction doesn't display](https://app.asana.com/0/1212521145936484/1214077903141396) · High · Rumble Wallet:To Triage · Sprint 1
- [ ] [\[Balance - Backend\] Investigate why BTC balances not updating for users buying from staging](https://app.asana.com/0/1212521145936484/1214097552937526) · High · Rumble Wallet:To Triage · Sprint 1
- [ ] [\[Bckend - Tip jar\] Tip button doesn't appear on the Rumble and Send Tip button is greyed out](https://app.asana.com/0/1212521145936484/1213391745549211) · High · Rumble Wallet:Completed · Sprint 1
      Flag: sits in the "Completed" section in Asana but is still marked incomplete. Verify with PM whether to close or move out.

---

## Notes from this refresh

- All other tickets (no Sprint assignment) were removed from this file per request. They remain open in Asana — re-pull them if a future sprint claims them.
- The 4 Sprint 1 carry-overs are all in the "To Triage" or "Completed" sections of Rumble Wallet, suggesting they may need a PM pass before re-prioritising into Sprint 2.
