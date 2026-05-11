# Asana TODO — assigned to Alex (Tether Indexer)

Generated: 2026-05-11 (manual update — security sweep spinoffs added)
Source: Asana `users/me` task list (incomplete only)
Refresh: ask Claude to "refresh my Asana TODOs".

**Summary:** 35 assigned tasks (32 real + 3 placeholder) across 3 projects. 7 in flight. 19 High priority (1 Critical), 8 Medium, 5 unset. The 11 new items are per-repo follow-ups to RW-1682 (Tron security ticket), one per backend repo with open high/critical Dependabot alerts.

---

## Top priorities — stand-up focus

> Up to 5 items. These are what Alex talks through in the next stand-up.

### 1. Provide commands to delete a transaction that is not on the mempool anymore
[RW-1699](https://app.asana.com/1/45238840754660/project/1210540875949204/task/1214518529430430) · WDK Indexer:DEV IN PROGRESS · Critical · in flight
> Andrei is hitting `ERR_GET_TX_FROM_CHAIN_FAILED` for a BTC tx that fell out of the mempool (likely underpriced). Need a runbook plus a safe delete command. Posted three blocking questions back to Andrei: did the watcher already auto-flip the tx to `failed` (line 259 in proc.shard.data.wrk.js), which shard holds the record, and what did Andrei already try. Waiting on his reply before writing the command.

### 2. Move #192 code to Rumble Data Shard
[1214430872139370](https://app.asana.com/1/45238840754660/project/1210540875949204/task/1214430872139370) · WDK Indexer:DEV IN PROGRESS · Sprint 1 · High · in flight
> wdk-data-shard-wrk PR #192 (migration-reporting script) was reverted in #211 with an empty body, so before porting it to rumble-data-shard-wrk I asked the original author whether the revert was a real bug, a perf issue, or just landed in the wrong repo, and whether the migration has already run on Rumble (in which case the task is obsolete). Waiting on context.
> local: `_tasks/04-may-26-WDK-1389-move-192-code-to-rumble-data-shard/`

### 3. [Backend - Transactions] Received BTC transaction doesn't display
[RW-1428](https://app.asana.com/1/45238840754660/project/1212521145936484/task/1213704628745111) · Rumble Wallet:In-Progress · Sprint 1 · High · in flight
> User Andrey reports a received BTC tx that does not show up in history; backend has no trace of the address `bc1qgm7k56...`. Asked QA how the user obtained that address since it does not match anything we have indexed. Picking back up after they replied with credentials to repro on staging.
> local: `_tasks/28-apr-26-2-received-btc-transaction-doesnt-display/`

### 4. Rumble - Security - Fix Tron Indexer High Vulnerabilities
[RW-1682](https://app.asana.com/1/45238840754660/project/1210540875949204/task/1213478780310237) · WDK Indexer:DEV IN PROGRESS · Sprint 1 · in flight
> Narrow Tron scope is done (Dependabot #3, #7 closed; main is clean for high/critical). 11 per-repo follow-ups created in Sprint 1 for the broader sweep (see "Security sweep follow-ups" section). Fastify upgrade (RW-1680) is the prerequisite for the app-node items. Pending Francesco's sign-off on scope; once that lands this ticket can be closed.
> local: `_tasks/04-may-26-RW-1682-rumble-security-fix-tron-indexer-high-vulnerabilities/`

### 5. Rumble - Silence the remaining Sentry False Positives - (#3)
[1213662485884824](https://app.asana.com/1/45238840754660/project/1210540875949204/task/1213662485884824) · WDK Indexer:PR MERGED + DEPLOYED TO DEV · Sprint 1 · High · soaking on dev
> rumble-app-node PR #198 added FST_ERR_VALIDATION, RPC client closed, and CHANNEL_CLOSED filters on top of the existing status-code/HRPC filter. Resolved all 22 Sentry issues from this ticket; the two `/balance` and `/wallets/balances` timeouts had zero events in 30 days so closed those too. Just monitoring on dev now; will close once it bakes for a release cycle.

---

## In progress / In review
- [ ] [Provide commands to delete a transaction that is not on the mempool anymore](https://app.asana.com/1/45238840754660/project/1210540875949204/task/1214518529430430) — `RW-1699` · Critical · WDK Indexer:DEV IN PROGRESS
- [ ] [Move #192 code to Rumble Data Shard](https://app.asana.com/1/45238840754660/project/1210540875949204/task/1214430872139370) · High · Sprint 1 · WDK Indexer:DEV IN PROGRESS
      local: `_tasks/04-may-26-WDK-1389-move-192-code-to-rumble-data-shard/`
- [ ] [\[Backend - Transactions\] Received BTC transaction doesn't display](https://app.asana.com/1/45238840754660/project/1212521145936484/task/1213704628745111) — `RW-1428` · High · Sprint 1 · Rumble Wallet:In-Progress
      local: `_tasks/28-apr-26-2-received-btc-transaction-doesnt-display/`
- [ ] [Rumble - Security - Fix Tron Indexer High Vulnerabilities](https://app.asana.com/1/45238840754660/project/1210540875949204/task/1213478780310237) — `RW-1682` · Sprint 1 · WDK Indexer:DEV IN PROGRESS
      local: `_tasks/04-may-26-RW-1682-rumble-security-fix-tron-indexer-high-vulnerabilities/`
- [ ] [Rumble - Silence the remaining Sentry False Positives - (#3)](https://app.asana.com/1/45238840754660/project/1210540875949204/task/1213662485884824) · High · Sprint 1 · WDK Indexer:PR MERGED + DEPLOYED TO DEV
- [ ] [Rumble - \[Send\] BTC transactions are logged with incorrect amounts](https://app.asana.com/1/45238840754660/project/1210540875949204/task/1212744757896562) · Medium · Sprint 1 · WDK Indexer:PR OPEN - IN REVIEW (V1 Bugs:Blocked)
- [ ] [Fix ork discovery empty-list failure after restart (Jan 5 prod issue) - handle ERR_TOPIC_LOOKUP_EMPTY](https://app.asana.com/1/45238840754660/project/1210540875949204/task/1212700198741856) · Medium · WDK Indexer:PR MERGED + DEPLOYED TO DEV

## High priority — To Do
- [ ] [Shared - Bugfix - purgeUserData doesn't reset deletedAt](https://app.asana.com/1/45238840754660/project/1210540875949204/task/1213882531683489) · High · Sprint 2 · WDK Indexer:TO DO
- [ ] [Campaign BE work](https://app.asana.com/1/45238840754660/project/1212521145936484/task/1214395948381748) — `RW-1691` · High · Sprint 1 · Rumble Wallet:To Triage
- [ ] [\[Backend Transactions\] After sending BTC on-chain from staging to prod, tx is not reflected in history but balance updates](https://app.asana.com/1/45238840754660/project/1212521145936484/task/1214077903141396) — `RW-1622` · High · Sprint 1 · Rumble Wallet:To Triage
- [ ] [\[Balance - Backend\] Investigate why BTC balances not updating for users buying from MoonPay](https://app.asana.com/1/45238840754660/project/1212521145936484/task/1214097552937526) — `RW-1632` · High · Sprint 1 · Rumble Wallet:To Triage
- [ ] [\[Bckend - Tip jar\] Tip button doesn't appear and Send Tip is inactive after following the channel](https://app.asana.com/1/45238840754660/project/1212521145936484/task/1213391745549211) — `RW-1120` · High · Sprint 1 · Rumble Wallet:Completed *(flagged: section says Completed but still incomplete in Asana)*

## Security sweep follow-ups (Sprint 1)

Per-repo follow-ups to [RW-1682](https://app.asana.com/1/45238840754660/project/1210540875949204/task/1213478780310237). All assigned to Alex, High priority, Sprint 1, Area=Rumble, in WDK Backends. Counts are open high/critical Dependabot alerts at 2026-05-11. Fastify upgrade (RW-1680) is the prerequisite for the app-node items.

- [ ] [rumble-promo-wrk - Security - Fix High/Critical Vulnerabilities](https://app.asana.com/1/45238840754660/project/1210540875949204/task/1214716439993136) · 11 alerts · High · Sprint 1
- [ ] [wdk-indexer-wrk-spark - Security - Fix High/Critical Vulnerabilities](https://app.asana.com/1/45238840754660/project/1210540875949204/task/1214716470029391) · 10 alerts · High · Sprint 1
- [ ] [wdk-indexer-wrk-evm - Security - Fix High/Critical Vulnerabilities](https://app.asana.com/1/45238840754660/project/1210540875949204/task/1214716589484670) · 9 alerts · High · Sprint 1
- [ ] [wdk-indexer-wrk-btc - Security - Fix High/Critical Vulnerabilities](https://app.asana.com/1/45238840754660/project/1210540875949204/task/1214716566892701) · 6 alerts · High · Sprint 1
- [ ] [rumble-app-node - Security - Fix High/Critical Vulnerabilities](https://app.asana.com/1/45238840754660/project/1210540875949204/task/1214716461893028) · 4 alerts · High · Sprint 1 · waits on RW-1680
- [ ] [wdk-app-node - Security - Fix High/Critical Vulnerabilities](https://app.asana.com/1/45238840754660/project/1210540875949204/task/1214716566376368) · 3 alerts · High · Sprint 1 · waits on RW-1680
- [ ] [wdk-indexer-app-node - Security - Fix High/Critical Vulnerabilities](https://app.asana.com/1/45238840754660/project/1210540875949204/task/1214716462372233) · 3 alerts · High · Sprint 1 · waits on RW-1680
- [ ] [rumble-data-shard-wrk - Security - Fix High/Critical Vulnerabilities](https://app.asana.com/1/45238840754660/project/1210540875949204/task/1214716566857326) · 2 alerts · High · Sprint 1
- [ ] [rumble-ork-wrk - Security - Fix High/Critical Vulnerabilities](https://app.asana.com/1/45238840754660/project/1210540875949204/task/1214716555228120) · 1 alert · High · Sprint 1
- [ ] [wdk-ork-wrk - Security - Fix High/Critical Vulnerabilities](https://app.asana.com/1/45238840754660/project/1210540875949204/task/1214716491270754) · 1 alert · High · Sprint 1
- [ ] [wdk-data-shard-wrk - Security - Fix High/Critical Vulnerabilities](https://app.asana.com/1/45238840754660/project/1210540875949204/task/1214716439793573) · 1 alert · High · Sprint 1

Repos with 0 open high/critical alerts (no ticket needed): rumble-wallet-lib-passkey, wdk-indexer-wrk-{base,solana,ton}, wdk-indexer-processor-wrk, wdk, wdk-wallet, wdk-wallet-{btc,evm,solana,spark,ton,tron,tron-gasfree}, wdk-react-native-core, wdk-protocol-fiat-moonpay, wdk-protocol-swap-velora-evm.

## Medium / Low — To Do
- [ ] [Rumble - Push notifications: format token amounts server-side (fix decimal/precision artifacts)](https://app.asana.com/1/45238840754660/project/1210540875949204/task/1214119276348483) · Medium · WDK Indexer:TO DO - Medium + Low Prio
- [ ] [Rumble - investigate and solve ERR_WALLET_BALANCE_FAILURE_CCY error in staging](https://app.asana.com/1/45238840754660/project/1210540875949204/task/1214094490463459) — `RW-1625` · Medium · WDK Indexer:TO DO - Medium + Low Prio (RW:ToDo - Dev)
- [ ] [\[Push Notifications\] Amount mismatch between "Transfer Initiated" and "Transfer Successful" notifications](https://app.asana.com/1/45238840754660/project/1212521145936484/task/1213989533989558) — `RW-1598` · Medium · Rumble Wallet:To Triage
- [ ] [\[Assets\] Only 1 dot is displayed for filter 7D and 1M](https://app.asana.com/1/45238840754660/project/1212521145936484/task/1213823149664564) — `RW-1486` · Medium · Rumble Wallet:To Triage
- [ ] [Rumble - Implement an endpoint to return the list of transactions based on wallet signature](https://app.asana.com/1/45238840754660/project/1210540875949204/task/1213663338730898) · Medium · WDK Indexer:TO DO - Medium + Low Prio
- [ ] [Rumble - BE - stop push notifications when received amount <$0.1 for tip or normal receive](https://app.asana.com/1/45238840754660/project/1210540875949204/task/1213139196226601) — `RW-886` · Medium · WDK Indexer:TO DO - Medium + Low Prio (RW:To Triage)
- [ ] [BE to persist failed transactions](https://app.asana.com/1/45238840754660/project/1212521145936484/task/1213139196226597) — `RW-885` · Rumble Wallet:To Triage
- [ ] [Rumble - Update Fastify plug ins](https://app.asana.com/1/45238840754660/project/1210540875949204/task/1213226894059885) — `RW-1680` · WDK Indexer:TO DO (RW:To Triage)
      local: `_tasks/06-may-26-RW-1680-rumble-update-fastify-plug-ins/`
- [ ] [\[Analytics\] Xaxis is incorrect on Asset trend chart](https://app.asana.com/1/45238840754660/project/1212521145936484/task/1213244394019831) — `RW-955` · Medium · Task Progress: Done · Rumble Wallet:Completed *(flagged: Task Progress=Done but Asana still flags incomplete)*

## Placeholder / onboarding
- [ ] [Task 1](https://app.asana.com/1/45238840754660/task/1211860486771104) · due 2025-11-06 **OVERDUE**
- [ ] [Task 2](https://app.asana.com/1/45238840754660/task/1211860486771106) · due 2025-11-07 **OVERDUE**
- [ ] [Task 3](https://app.asana.com/1/45238840754660/task/1211860486771108) · due 2025-11-10 **OVERDUE**
