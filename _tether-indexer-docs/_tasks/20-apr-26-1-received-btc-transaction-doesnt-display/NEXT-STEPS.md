# Next steps for "Received BTC transaction doesn't display"

**Ticket:** https://app.asana.com/1/45238840754660/project/1212521145936484/task/1213704628745111

## Latest status (2026-04-20)

- **2026-04-20 10:24 / 10:37** — Alex posted the log findings on the Asana ticket and asked the FE side (via Eddy WM) to run the two in-repo investigations (trace `[QRCodeDisplay]` upstream; grep for `bc1q` / `p2wpkh` / segwit derivation).
- **2026-04-20 11:05** — Eddy WM replied **without running the investigation**. His assumption: *"this wallet might have been created long time ago, and possibly a very old in the address generation on wdk side since nobody else has been able to reproduce this issue in another (new) wallet."*
- **What that means:** Eddy is implicitly redirecting the fix away from a current FE code change and toward a legacy / migration framing — which dovetails with the linked RW-1409 reconciliation ticket but does NOT answer the decisive question (where the FE currently sources `bc1qgm7k56…` from).
- **Ticket is still in In-Progress; priority still High; assignee still Alex.**

## What to do next — ranked

1. **Test Eddy's theory before accepting or rejecting it** — this is cheap and unblocks the decision:
   - Pull `createdAt` for wallet `95f4b950-3601-4ebc-9387-225377d72a28` (the `unrelated` wallet for `pagZrxLHnhU`). Usman's 2026-03-19 12:47 payload shows `createdAt: 1767985547939` → **2026-01-10 06:25 UTC**. That *is* several weeks old by WDK standards but not necessarily "legacy".
   - Cross-check against `wdk-lib-bitcoin` git history for when BTC derivation moved from bip84 / segwit (`bc1q…`) to bip86 / taproot (`bc1p…`). If the switch post-dates `2026-01-10`, Eddy's theory is plausible; if it pre-dates it, the theory is wrong and we're back to a live FE bug.
   - Also compare to the `5 local vs 4 backend` delta in the log — the 5th wallet (the one holding the segwit address) must have a creation timestamp somewhere in local storage.

2. **Reply to Eddy with the outcome of (1)**, not with another ask. Two possible replies:
   - **If theory holds** (BTC derivation switched after this wallet was created): acknowledge it, redirect the fix path to RW-1409 / migration, and escalate via Alex's previously-floated fallback on the FE side — "display only addresses that are registered with the backend" — as a belt-and-braces guard for other stale wallets. Close this ticket once RW-1409 lands.
   - **If theory fails** (derivation was already taproot when this wallet was created): push back — this is an active FE bug, the in-repo investigation is still owed, and the ticket stays on the FE side.

3. **Regardless of (1) outcome**, the FE-side guard ("only render receive addresses present in the `/wallets` response") is worth doing — it's the cleanest way to prevent repeat reports while reconciliation catches up. That's Alex's original Slack fallback. Consider proposing it as a separate small FE ticket rather than bundling it here.

4. Lower-priority, only if (1) doesn't settle it:
   - Run the `/wallets` eventually-consistency check (Usman's 1-wallet vs 2-wallet snapshot mystery from 2026-03-19).
   - Still-missing: the 2026-04-02 Slack analysis thread and the second unnamed related ticket (see `missing-context.md`).

---


## What we know
- Staging user `klemensqwerty` (userId `pagZrxLHnhU`, email klemens.andrew@gmail.com) received 0.00021337 BTC ($15.82) in tx `f0fcd10294218e84b06e457e3fd740ca70188d84944e45e4aba43a59c2b10d95` on 2026-03-18 11:10 UTC — confirmed on-chain (mempool.space).
- The **balance** shows correctly on the BTC holdings screen, so the backend has indexed the UTXO — but **no transaction entry** appears in either the BTC holdings "Latest transactions" feed or the global Transactions list.
- FE already ruled itself out (Ahsan, 2026-03-18): `token-transfers?token=BTC` for this user returns empty from BE.
- The receive address `bc1qgm7k56yqdzzn30vzzxrjnle6nkdn2wgt0m9ph2` is **not** present in either `/wallets` snapshot the BE returned — neither in Usman's 1-wallet view (2026-03-19 07:29) nor his later 2-wallet view (2026-03-19 12:47). Open mystery: how did the user receive funds on an address the backend doesn't know about?
- Stack was re-classified from FE to BE on 2026-04-15; Priority dropped Critical → High on 2026-04-16 with Eddy's rationale: "mainly a backend related item that affects only one user, and can be fixed on the backend without any change on the app."
- Alex linked this to another Asana ticket in-progress: `.../task/1213680013630981` (plus a second unnamed related ticket).
- An analysis was posted by Alex in Slack on 2026-04-02 (channel C0A5DFYRNBB, thread p1775069742706779) — contents not captured here.

## Evidence captured here
- 2 images from the ticket description + 7 frame-screenshots extracted from the 2026-04-06 screen recording, all analysed in `image-analysis.md`.
- Video screenshots under `attachments/video-file-screenshots/` (7 PNGs from `screen-20260406-172125-1775485270371.mp4`) — **Frame 6 shows the app serving `bc1qgm7k56yqdzzn30vzzxrjnle6nkdn2wgt0m9ph2` as the user's BTC ON-CHAIN receive address**. App version confirmed as v2.0.3. On 2026-04-06 the ON-CHAIN balance had dropped from 21337 sats to 630 sats, but the transactions list was still empty — bug still reproducible.
- Client log `rumble-wallet-2026-04-06.log` (2.0 MB, 1,810 lines, spans 11:16–17:21 device time) — **fully analysed in `log-analysis.md`**. Covers the exact moment in the video (QRCodeDisplay copy event at 17:21:22 = Frame 7). See next section for the headline findings.
- `screen-20260406-172125-1775485270371.mp4` (2.9 MB) — represented by the 7 screenshots.
- 28 stories captured in `comments.md` (comments + relevant system events).

## Headline findings from the log (see `log-analysis.md`)

1. **The segwit receive address `bc1qgm7k56…` is never returned by any backend call during the session** — not by `/api/v1/wallets`, not by `token-transfers`, not by any other endpoint in the log. It is sourced from **client-local state**, not from BE.
2. **The tx-history call is now pinned**: `GET /api/v1/users/pagZrxLHnhU/token-transfers?token=btc&walletTypes=user&walletTypes=channel&walletTypes=unrelated` → `200 {"transfers":[]}`. The server-side filter is keyed off the user's BTC wallet addresses as stored in `/wallets`, which are **taproot** (`bc1p…`); since the funds arrived on a **segwit** (`bc1q…`) address the server doesn't know about, zero transfers are returned.
3. **Smoking-gun marker:** the `walletSync` log at 17:21:13 reports `localWalletCount=5, backendWalletCount=4` — the client has one wallet the backend doesn't know about. That extra local wallet is the likely source of `bc1qgm7k56…`.
4. **Format split is real:** all `/wallets` BTC entries are taproot; both the received-on address and two other `bc1q…` segwit addresses appear elsewhere in the log. The FE still has segwit-address code paths alive even though the BE only stores taproot.
5. The `[QRCodeDisplay]` component rendered the segwit address from this local state — Alex's Slack fallback ("FE only displays BE-registered addresses") therefore maps to an actual FE code change on the Receive flow, not a server-side filter.

## What's missing (from `missing-context.md`)
- The 2026-04-02 Slack analysis thread Alex linked on THIS ticket (`C0A5DFYRNBB p1775069742706779`).
- The second of the "two other tickets" Alex mentioned as related (one is captured under `related-ticket-1213680013630981-migration-reconciliation-job/`; the second is still unnamed).
- Clarification on which service owns the `token-transfers` endpoint and how we replay the BTC call locally.
- Which BE endpoint actually serves the BTC receive address to the FE (since it's clearly not `/wallets`), and whether the `/wallets` vs. receive-address desync has its own ticket.
- Whether `/wallets` is eventually-consistent (to explain Usman's single- vs two-wallet snapshot).

_(The 2026-04-06 screen recording is no longer missing — 7 frame-screenshots cover it, see above.)_

## Related context fetched here

`related-ticket-1213680013630981-migration-reconciliation-job/` — captures the "[Backend] Migration Reconciliation Job" ticket (RW-1409) that Alex linked as directly relevant, plus the Slack PR-review thread for its initial-phase script.

Two findings from that subfolder that matter for the parent ticket:

1. **The initial-phase reconciliation PR** ([`tetherto/wdk-data-shard-wrk#192`](https://github.com/tetherto/wdk-data-shard-wrk/pull/192)) is narrower than the Asana requirements — it only checks two `accountIndex` anomalies (`unrelated != 0`, `user == 100`). It does **not** compare addresses, so running it on staging will **not** flag `pagZrxLHnhU` (the user in this ticket), because their wallets have `accountIndex` 0 and 1. The reconciliation job as built today will not identify this bug on its own.

2. **Alex has already floated a fallback plan** in Slack: instead of full reconciliation, have the app team display only addresses that are registered with the backend. If adopted, that would close this parent ticket symptomatically — the FE would stop serving `bc1qgm7k56…` as a receive address when `/wallets` doesn't contain it.

See `related-ticket-.../missing-context.md` for the still-open items around PR #192 (merge/run status, output location, the 2026-03-17 analysis Slack thread, migration scope, BTC coverage, remediation policy, and the reconciliation-vs-FE-constraint decision).

## Before starting work — recommended next step

The log analysis has shifted the investigation **from "which BE endpoint serves the address" to "where in the FE repo the Receive flow sources the address"**. The next concrete step is an in-repo code investigation, not more data gathering:

1. In the FE repo, locate the `[QRCodeDisplay]` component and trace upstream to find which store / hook / selector supplies the `bitcoin` address passed to it. Strong candidates based on log module names: `walletSync`, `offlineWalletAccessService`, `hooks/useResyncWalletsLackingAddresses`.
2. Grep the FE repo for segwit-vs-taproot derivation (`p2wpkh` / `bech32` / `bc1q` / `bip84` vs `bip86` / `taproot`). The BE serves taproot; some FE code path still has segwit addresses alive. That path is the bug.
3. Answer the `localWalletCount=5 vs backendWalletCount=4` delta: which local wallet is the 5th one, and how did it get there? That is the concrete artefact the parent bug hangs on.

## Still worth asking Alex (but lower priority now)
1. Summary / key findings from the 2026-04-02 Slack analysis thread — to confirm the root cause matches what the log already implies.
2. The second related Asana ticket URL.
3. Decision on reconciliation path vs. FE-constraint fallback (see `related-ticket-.../NEXT-STEPS.md`).
