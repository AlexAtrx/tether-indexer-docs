# Asana TODO — assigned to Alex (Tether Indexer)

Generated: 2026-04-28 12:59 UTC
Source: Asana `users/me` task list (incomplete only)
Refresh: ask Claude to "refresh my Asana TODOs".

**Summary:** 25 assigned tasks (22 real + 3 placeholder) across 2 projects.
1 marked Task Progress = In Progress, 8 active in In-Progress / PR / Dev
sections, 8 with Priority = High, 1 deferred. One quirk to flag: RW-955 sits
in the "Completed" section with Task Progress = Done but Asana still has it
open.

---

## Top priorities — stand-up focus

> Five items. These are what to talk through in the next stand-up.

### 1. Add blockchain-specific retryCount / retryDelay for tx webhook
[RW-1525](https://app.asana.com/1/45238840754660/project/1212521145936484/task/1213868590256377) · WDK Indexer / Rumble Wallet V3 · High · In Progress
> Backend retries user-operation tx webhooks indefinitely because there is no per-chain cap, while user-hash flows already have one. Need to add chain-aware retryCount and retryDelay so failed webhooks get discarded; Francesco linked the GitHub PR-179 thread plus a Slack thread with the full repro on 2026-04-15.

### 2. Received BTC transaction doesn't display
[RW-1428](https://app.asana.com/1/45238840754660/project/1212521145936484/task/1213704628745111) · Rumble Wallet V3 · High · In-Progress section
> Andrey's staging account received a BTC tx (hash f0fcd102...) that never appeared in the wallet. Backend has no trace of address bc1qgm7k5..., so the question is where the user got that address. Last comment was Andrey offering staging creds so we can repro and trace the missing address through the indexer.
local: `_tasks/20-apr-26-1-received-btc-transaction-doesnt-display/`

### 3. Tip button doesn't appear, Send Tip inactive after follow
[RW-1120](https://app.asana.com/1/45238840754660/project/1212521145936484/task/1213391745549211) · Rumble Wallet V3 · High · In-Progress section
> When a freshly created user starts following a channel, `tipping_enabled` returned by `/wallet/v1/address-book` is stale until relogin, so the Tip button stays inactive. Patricio confirmed it is an API issue (not the FE); fix lives in the address-book endpoint to return the up-to-date flag.
local: `_tasks/20-apr-26-2-tip-button-inactive-after-follow/`

### 4. Migration Reconciliation Job
[RW-1409](https://app.asana.com/1/45238840754660/project/1212521145936484/task/1213680013630981) · Rumble Wallet V3 · High · In-Progress section
> Job to reconcile wallet addresses recreated by the FE during migration against what the BE already stored, so we can measure migration accuracy. Analysis and proposed fix were shared in Slack on 2026-03-17; an initial PR to generate the discrepancy report (phase 1) was posted on 2026-03-20. Next is wiring the reconciliation pass once the report is approved.

### 5. Reduce queryTransfersByAddress in the job config
[1212717092938062](https://app.asana.com/1/45238840754660/project/1210540875949204/task/1212717092938062) · WDK Indexer · High · PR OPEN - IN REVIEW
> `syncWalletTransfersJob` was firing ~120 times/sec in prod, hammering the DB with ~2k queryTransfersByAddress calls/sec. Vigan's quick fix (lower `syncTransfersExec` timer + restart) is in flight; the PR is open and waiting on review.

---

## In progress / In review
- [ ] [Rumble - Silence the remaining Sentry False Positives - (#3)](https://app.asana.com/1/45238840754660/project/1210540875949204/task/1213662485884824) · High · WDK Indexer:DEV IN PROGRESS
- [ ] [Rumble - [Send] BTC transactions are logged with incorrect amounts](https://app.asana.com/1/45238840754660/project/1210540875949204/task/1212744757896562) · Medium · WDK Indexer:PR OPEN - IN REVIEW (also flagged Blocked in [RW] V1 Bugs Tracking)
- [ ] [Fix ork discovery empty-list failure after restart (Jan 5 prod issue) - handle ERR_TOPIC_LOOKUP_EMPTY](https://app.asana.com/1/45238840754660/project/1210540875949204/task/1212700198741856) · Medium · WDK Indexer:PR MERGED + DEPLOYED TO DEV

## High priority — To Do
- [ ] [[Backend Transactions]After sending BTC on-chain from the staging build to the production build, the transaction is not reflected in the transaction history, but the balance is updated](https://app.asana.com/1/45238840754660/project/1212521145936484/task/1214077903141396) · `RW-1622` · Rumble Wallet V3:To Triage
- [ ] [[Balance - Backend] Investigate why BTC balances not updating for users buying from MoonPay](https://app.asana.com/1/45238840754660/project/1212521145936484/task/1214097552937526) · `RW-1632` · Rumble Wallet V3:To Triage

## Medium / Low — To Do
- [ ] [Rumble - Push notifications: format token amounts server-side (fix decimal/precision artifacts)](https://app.asana.com/1/45238840754660/project/1210540875949204/task/1214119276348483) · Medium · WDK Indexer:TO DO - Medium + Low Prio
      local: `_tasks/17-apr-26-decimals-issue/`
- [ ] [Rumble - investigate and solve ERR_WALLET_BALANCE_FAILURE_CCY error in staging](https://app.asana.com/1/45238840754660/project/1210540875949204/task/1214094490463459) · `RW-1625` · Medium · Rumble Wallet V3:ToDo - Dev / WDK Indexer:TO DO - Medium + Low Prio
- [ ] [[Push Notifications] Amount mismatch between "Transfer Initiated" and "Transfer Successful" notifications](https://app.asana.com/1/45238840754660/project/1212521145936484/task/1213989533989558) · `RW-1598` · Medium · Rumble Wallet V3:To Triage
      local: `_tasks/16-apr-26-1-The-amount-in-the-push-looks-with-incorrect-decimals/`
- [ ] [[Analytics] Xaxis is incorrect on Asset trend chart](https://app.asana.com/1/45238840754660/project/1212521145936484/task/1213244394019831) · `RW-955` · Medium · Rumble Wallet V3:Completed (marked Done but still open in Asana)
      local: `_tasks/15-apr-26-Xaxis-is-incorrect/`
- [ ] [[Assets] Only 1 dot is displayed for filter 7D and 1M](https://app.asana.com/1/45238840754660/project/1212521145936484/task/1213823149664564) · `RW-1486` · Medium · Rumble Wallet V3:To Triage
- [ ] [Rumble - Implement an endpoint to return the list of transactions based on wallet signature](https://app.asana.com/1/45238840754660/project/1210540875949204/task/1213663338730898) · Medium · WDK Indexer:TO DO - Medium + Low Prio
- [ ] [Rumble - BE - stop push notifications when received amount <$0.1 for tip or normal receive](https://app.asana.com/1/45238840754660/project/1210540875949204/task/1213139196226601) · `RW-886` · Medium · WDK Indexer:TO DO - Medium + Low Prio
- [ ] [BE to persist failed transactions](https://app.asana.com/1/45238840754660/project/1212521145936484/task/1213139196226597) · `RW-885` · Rumble Wallet V3:To Triage
- [ ] [Rumble - Update Fastify plug ins](https://app.asana.com/1/45238840754660/project/1210540875949204/task/1213226894059885) · `RW-1680` · WDK Indexer:TO DO
- [ ] [Rumble - Security - Fix Tron Indexer High Vulnerabilities](https://app.asana.com/1/45238840754660/project/1210540875949204/task/1213478780310237) · `RW-1682` · Sprint 1 · WDK Indexer:TO DO
- [ ] [Rumble - Refactor wdk-* Repos to Remove Rumble-Specific Logic (Move to Rumble Child Repo)](https://app.asana.com/1/45238840754660/project/1210540875949204/task/1213303070214495) · `RW-1683` · Sprint 1 · WDK Indexer:TO DO

## Blocked / Deferred
- [ ] [Remove the initiated transfer notification](https://app.asana.com/1/45238840754660/project/1212521145936484/task/1213287908612993) · `RW-977` · High · Rumble Wallet V3:Next steps · due 2026-02-19 **OVERDUE** (Task Progress = Deferred)

## Placeholder / onboarding
- [ ] [Task 1](https://app.asana.com/1/45238840754660/task/1211860486771104) · due 2025-11-06 **OVERDUE**
- [ ] [Task 2](https://app.asana.com/1/45238840754660/task/1211860486771106) · due 2025-11-07 **OVERDUE**
- [ ] [Task 3](https://app.asana.com/1/45238840754660/task/1211860486771108) · due 2025-11-10 **OVERDUE**
