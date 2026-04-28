# Asana TODO — assigned to Alex (Tether Indexer)

Generated: 2026-04-28 14:08 UTC
Source: Asana `users/me` task list (incomplete only)
Refresh: ask Claude to "refresh my Asana TODOs".

**Summary:** 25 assigned tasks (22 real + 3 placeholder) across 3 projects.
9 in progress / in review, 9 high priority, 1 deferred.

---

## Top priorities — stand-up focus

> Up to 5 items. These are what Alex talks through in the next stand-up.

### 1. Rumble - Add blockchain specific retryCount/retryDelay for tx webhook
[RW-1525 / WDK-1344](https://app.asana.com/0/0/1213868590256377) · WDK Indexer / PR OPEN - IN REVIEW · High · In Progress
> Tx-hash webhooks retry forever in the data-shard-wrk because the discard logic only covers userOp-hash webhooks. PR #199 is open against `rumble-data-shard-wrk` adding per-chain retryCount/retryDelay (posted 2026-04-28). Next: chase review and merge.
local: `_tasks/28-apr-26-1-rumble-tx-webhook-retry-count-delay/`

### 2. [Bckend - Tip jar] Tip button doesn't appear on the Rumble and Send Tip button is inactive after following the channel
[RW-1120](https://app.asana.com/0/0/1213391745549211) · Rumble Wallet V3 / In-Progress · High
> After a user follows a new channel, the tip button stays inactive for ~10 min and a pull-to-refresh doesn't help. Patricio narrowed it down to `-wallet/v1/address-book` returning a stale `tipping_enabled`, so it's a backend freshness issue, not a Rumble-side one. Next: trace why `tipping_enabled` is cached and force a refresh on follow.
local: `_tasks/20-apr-26-2-tip-button-inactive-after-follow/`

### 3. [Backend - Transactions] Received BTC transaction doesn't display
[RW-1428](https://app.asana.com/0/0/1213704628745111) · Rumble Wallet V3 / In-Progress · High
> Test user on staging received BTC at address `bc1qgm7k56y...m9ph2`, but the backend has no record of that address (Usman's wallets dump shows none of the involved addresses). Alex posted Slack analysis on 2026-04-02 and asked Andrey for provenance; Andrey offered his staging credentials on 2026-04-06. Next: log in with Andrey's creds, trace where the address came from (wrong env, missing wallet entry, or migration leftover).
local: `_tasks/28-apr-26-2-received-btc-transaction-doesnt-display/`

### 4. [Backend] Migration Reconciliation Job
[RW-1409](https://app.asana.com/0/0/1213680013630981) · Rumble Wallet V3 / In-Progress · High
> Build a backend job that compares wallet addresses the FE recreates after migration against addresses already stored in BE, flags mismatches, and pulls EVM/BTC balances on mismatched users so we can size the at-risk cohort. Phase 1 (report-generation PR) is shared with the team on Slack and waiting on review. Next: drive Phase 1 to land, then start Phase 2 (the actual reconciliation pass).

### 5. Rumble - Silence the remaining Sentry False Positives (#3)
[WDK-1282](https://app.asana.com/0/0/1213662485884824) · WDK Indexer / DEV IN PROGRESS · High
> Verify the Sentry prod errors Francesco listed (issues 7229, 11240-11242, 7167, etc.) are filtered out as false positives. Blocked on the #2 ticket landing first per the description. No comments yet, so nothing has moved on Alex's side. Next: confirm #2 is in, then walk the listed Sentry issue ids and silence each.

---

## In progress / In review

- [ ] [Rumble: Reduce the amount of queryTransfersByAddress in the job config](https://app.asana.com/0/0/1212717092938062) · `WDK-1023` · High · WDK Indexer / PR OPEN - IN REVIEW
- [ ] [Rumble - [Send] BTC transactions are logged with incorrect amounts](https://app.asana.com/0/0/1212744757896562) · `WDK-1098` · Medium · WDK Indexer / PR OPEN - IN REVIEW (also in `[RW] V1 Bugs Tracking / Blocked`)
- [ ] [Fix ork discovery empty-list failure after restart (Jan 5 prod issue) - handle ERR_TOPIC_LOOKUP_EMPTY](https://app.asana.com/0/0/1212700198741856) · `WDK-1012` · Medium · WDK Indexer / PR MERGED + DEPLOYED TO DEV
- [ ] [[Analytics] Xaxis is incorrect on Asset trend chart](https://app.asana.com/0/0/1213244394019831) · `RW-955 / WDK-1346` · Medium · Rumble Wallet V3 / Completed (Task Progress = Done) · *flag: in Completed section + Done but task still incomplete in Asana*
  local: `_tasks/15-apr-26-Xaxis-is-incorrect/`

## High priority — To Do

- [ ] [[Backend Transactions] After sending BTC on-chain from staging build to production build, the transaction is not reflected in the transaction history, but the balance is updated](https://app.asana.com/0/0/1214077903141396) · `RW-1622` · Rumble Wallet V3 / To Triage
- [ ] [[Balance - Backend] Investigate why BTC balances not updating for users buying from MoonPay](https://app.asana.com/0/0/1214097552937526) · `RW-1632` · Rumble Wallet V3 / To Triage

## Medium / Low — To Do

- [ ] [Rumble - Push notifications: format token amounts server-side (fix decimal/precision artifacts)](https://app.asana.com/0/0/1214119276348483) · `WDK-1353` · Medium · WDK Indexer / TO DO - Medium + Low Prio
  local: `_tasks/16-apr-26-1-The-amount-in-the-push-looks-with-incorrect-decimals/`
- [ ] [Rumble - investigate and solve ERR_WALLET_BALANCE_FAILURE_CCY error in staging](https://app.asana.com/0/0/1214094490463459) · `WDK-1352 / RW-1625` · Medium · Rumble Wallet V3 / ToDo - Dev
- [ ] [[Push Notifications] Amount mismatch between "Transfer Initiated" and "Transfer Successful" notifications](https://app.asana.com/0/0/1213989533989558) · `RW-1598` · Medium · Rumble Wallet V3 / To Triage
- [ ] [[Assets] Only 1 dot is displayed for filter 7D and 1M](https://app.asana.com/0/0/1213823149664564) · `RW-1486` · Medium · Rumble Wallet V3 / To Triage
- [ ] [Rumble - Implement an endpoint to return the list of transactions based on wallet signature](https://app.asana.com/0/0/1213663338730898) · `WDK-1283` · Medium · WDK Indexer / TO DO - Medium + Low Prio
- [ ] [Rumble - BE - stop push notifications when received amount <$0.1 for tip or normal receive](https://app.asana.com/0/0/1213139196226601) · `WDK-1197 / RW-886` · Medium · WDK Indexer / TO DO - Medium + Low Prio
- [ ] [Rumble - Refactor wdk-* Repos to Remove Rumble-Specific Logic (Move to Rumble Child Repo)](https://app.asana.com/0/0/1213303070214495) · `WDK-1196 / RW-1683` · WDK Indexer / TO DO
- [ ] [Rumble - Security - Fix Tron Indexer High Vulnerabilities](https://app.asana.com/0/0/1213478780310237) · `WDK-1237 / RW-1682` · WDK Indexer / TO DO
- [ ] [Rumble - Update Fastify plug ins](https://app.asana.com/0/0/1213226894059885) · `WDK-1168 / RW-1680` · WDK Indexer / TO DO
- [ ] [BE to persist failed transactions](https://app.asana.com/0/0/1213139196226597) · `RW-885` · Rumble Wallet V3 / To Triage

## Blocked / Deferred

- [ ] [Remove the initiated transfer notification](https://app.asana.com/0/0/1213287908612993) · `RW-977` · High · Task Progress = Deferred · Rumble Wallet V3 / Next steps · due 2026-02-19 **OVERDUE**

## Placeholder / onboarding

- [ ] [Task 1](https://app.asana.com/0/0/1211860486771104) · due 2025-11-06 **OVERDUE**
- [ ] [Task 2](https://app.asana.com/0/0/1211860486771106) · due 2025-11-07 **OVERDUE**
- [ ] [Task 3](https://app.asana.com/0/0/1211860486771108) · due 2025-11-10 **OVERDUE**
