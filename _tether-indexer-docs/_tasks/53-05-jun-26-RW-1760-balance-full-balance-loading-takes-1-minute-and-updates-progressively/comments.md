# Comments — RW-1760

Chronological (oldest first). System stories included only where they carry triage signal.

---

**[system] 2026-05-19 17:02 — Gocha Gafrindashvili** (attachment_added)
Attached `Full balance load takes about ~1min.MOV` (in `attachments/`).

---

**[system] 2026-05-19 17:05 — Gocha Gafrindashvili** (assigned)
Assigned to Francesco Canessa. (Priority set High, Stack BE - Backend, Task Type Bug, Sprint 2.)

---

**[comment] 2026-05-27 12:37 — Francesco Canessa**

> @Alex Atrash can you check if this is fixed? thanks

---

**[comment] 2026-05-27 12:40 — Alex Atrash**

> @Francesco my best guess this should be postponed until trx history V2 is out. But I'll double check.

---

**[comment] 2026-05-27 15:10 — Alex Atrash**

> @Francesco Canessa
> Update: V2 is irrelevant for this ticket.

---

**[comment] 2026-05-27 15:29 — Alex Atrash**

> @Francesco Canessa @Eddy WM
>
> **This is a mobile balance-fetch orchestration bug, not an indexer backend issue and not Rumble blocked.**
>
> In mobile, home screen balances are driven by root-mounted WDK balance probes that fetch all configured assets per accountIndex, then `useAggregatedBalances` renders progressively as each probe lands. **That explains the video behavior where total balance climbs in stages.**
>
> The sharp bug is pull-to-refresh invalidates the wrong React Query keys.
>
> Active probes/readers use SDK keys based on `activeWalletId` + `accountIndex`, but `useHomeCallbacks` invalidates/refetches keys based on `wallet.identifier` + `accountIndex`, so refresh often does **not** touch the queries the Home balance actually reads.
>
> Ref:
> - Probe owner: https://github.com/tetherto/rumble-wallet-app-mobile/blob/885d6a699da1740e15bdf52c9ca7521aeab45baa/hooks/useRumbleBalanceProbes.tsx#L25
> - Aggregation reader: https://github.com/tetherto/rumble-wallet-app-mobile/blob/885d6a699da1740e15bdf52c9ca7521aeab45baa/hooks/useAggregatedBalances.ts#L66
> - Wrong refresh key: https://github.com/tetherto/rumble-wallet-app-mobile/blob/885d6a699da1740e15bdf52c9ca7521aeab45baa/hooks/useFlowSelection.ts#L136
> - No-op 5s options: https://github.com/tetherto/rumble-wallet-app-mobile/blob/885d6a699da1740e15bdf52c9ca7521aeab45baa/hooks/useBalanceFetcher.ts#L19
>
> To fix: centralize the balance-probe query key helper and make pull-to-refresh refetch the same activeWalletId/accountIndex keys used by the probes. Then decide whether home screen should wait for all tracked account indexes before showing a final-looking total, or explicitly show a partial/cached state while probes are still settling.

---

**[system] 2026-05-28 09:08 — Alex Atrash** (assigned)
Assigned to Eddy WM.

---

**[comment] 2026-05-28 15:46 — Eddy WM**

> @anton.kurdo@innowise.com take time to investigate if this issue core cause is client side and see how we can resolve this.
> Check the reshkey, probes,...

(also added anton.kurdo@innowise.com as collaborator)

---

**[comment] 2026-06-01 09:11 — anton.kurdo@innowise.com**

> @Eddy WM @George Javakhidze
> Investigated this — confirmed **client-side**, reproduces on **cold start** (matches the video). Not a backend/indexer issue.
> The behavior is mostly a side effect of our balance-fetch architecture: on `READY`, `RumbleBalanceProbes` mounts one probe per `accountIndex`, each running a full `useBalancesForWallet` across all networks/tokens. `useAggregatedBalances` merges results as each probe settles, so the total climbs in stages. On the account in the video there are many wallets, which makes it worse — more probes, more independent fetches through the worklet bridge, longer wall-clock time and more intermediate states.
>
> Worth noting this isn't a single scenario — cold start can hit different flows, and the fix should account for that:
> 1. **Fresh install / first login** — No MMKV, no React Query cache. Probes are the only source. Partial probe data goes straight to the UI → progressive jumping from the first settled probe. Here there's nothing to show instantly; the fix is **when** we expose data (atomic gate), not cache-first.
> 2. **Returning user (app restart, same account)** — MMKV has last-good totals and raw balances from the previous session. We partially use this (`getCachedBalance`, `getCachedRawBalances`), but fallback only applies when balance is `0`. As soon as the first probe returns partial fresh data, cache is bypassed and the UI starts climbing again.
> 3. **User switch / re-auth after logout** — Caches are cleared (`shouldClearBalanceCachesForUser`), so behavior is closer to fresh install.
> 4. **Heavy vs light accounts** — Same architecture, but wallet count scales linearly — the video account is the worst case.
>
> **Proposed fixes (flow-aware):**
> - **All cold-start flows — atomic aggregator gate (P0):** Don't emit partial aggregated snapshots while the cold-start batch is in progress. Show loading/skeleton until all relevant probes have settled, then one final snapshot.
> - **Fresh install / no cache (P1) — tiered fetch:** Don't probe all account indexes at once. Fetch user wallet first, defer tip jars/channels to background.
> - **Heavy accounts (P2) — concurrency cap on cold start:** Queue probe fetches (e.g. max 2–3 parallel) instead of firing all at once.
> - **Returning user only (P2, optional) — stable MMKV display:** While the batch is fetching, keep showing MMKV total instead of replacing it with partial fresh data. Only swap once the batch is fully settled.
> - **Separate issue — pull-to-refresh key mismatch:** Probes cache under `activeWalletId`, refresh invalidates `wallet.identifier`. Worth fixing, but not what's shown in the video (cold start, not manual refresh).

---

**[system] 2026-06-01 09:12 — Eddy WM** (assigned)
Assigned to anton.kurdo@innowise.com.

---

**[comment] 2026-06-01 09:14 — Eddy WM**

> @anton.kurdo@innowise.com You should proceed and fix this,
> @Aliaksei Shaltykou collaborate on this with anton.kurdo@innowise.com since you recently made some changes around this area.
> Let's have a definitive fix on this issue fellas.

---

**[comment] 2026-06-01 10:31 — George Javakhidze**

> Thanks for the very detailed summary, @anton.kurdo@innowise.com
> BE already has an endpoint which can return total balance per token and wallet. My proposal would be to use BE for fresh install / no cache (for instant result), the rest as you propose.

---

**[comment] 2026-06-05 07:47 — anton.kurdo@innowise.com**

> ## Investigation Summary
> **Scope:** The issue only affects accounts with a large number of wallets, and it does not reproduce consistently — roughly **6 out of 10** attempts.
>
> **Steps to reproduce:**
> 1. Fresh start the app
> 2. Log in with **Account A** (an account with many wallets)
> 3. Log out
> 4. Log in with **any other Account B**
> 5. Log out
> 6. Log in with **Account A** again
>
> The bug appears at step 6.
>
> **Notable behavior:** If you repeat the same flow again after step 6 (logout → Account B → logout → Account A), the issue **no longer occurs**. So the problem appears only on the **second login to Account A** after switching from another account — not on subsequent cycles of the same steps.
>
> I tested @George Javakhidze suggestion, but it didn't work because the backend endpoint returns an incorrect balance that doesn't match the actual balance.
> cc @Mohamed Elsabry @Eddy WM

---

**[comment] 2026-06-05 08:39 — George Javakhidze**

> @anton.kurdo@innowise.com can you share an example of the wallet where BE returned incorrect balance?

---

**[comment] 2026-06-05 08:41 — anton.kurdo@innowise.com**

> **kartofili / 123qweASD! / collect sphere asset adult split write fatigue twelve predict width another crew**
> But I've tested several wallets and get the same behavior.

---

**[system] 2026-06-05 09:51 — anton.kurdo@innowise.com** (section_changed)
Moved this task from "In-Progress" back to "To Triage".
