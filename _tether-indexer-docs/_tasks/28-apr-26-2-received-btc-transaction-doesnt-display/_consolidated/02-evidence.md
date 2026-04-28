# Evidence — RW-1428

All observable data points captured for this ticket. Each item references the artefact in `evidence/`.

## The transaction

- **txid:** `f0fcd10294218e84b06e457e3fd740ca70188d84944e45e4aba43a59c2b10d95`
- **mempool.space:** https://mempool.space/tx/f0fcd10294218e84b06e457e3fd740ca70188d84944e45e4aba43a59c2b10d95
- **Sender address:** `bc1qqfr4t0d9nraxfk7xgk7qd7sg6vq7flsaljk6kp`
- **Recipient address:** `bc1qgm7k56yqdzzn30vzzxrjnle6nkdn2wgt0m9ph2` *(segwit / bc1q…)*
- **Amount:** 0.00021337 BTC ($15.82 at the time)
- **Date / Time:** 2026-03-18 11:10 UTC
- **Status:** confirmed on-chain
- **Source:** andrey.gilyov comment, Asana 2026-03-19 13:41

## The user

- **userId:** `pagZrxLHnhU`
- **email:** klemens.andrew@gmail.com
- **password:** `1234qQ1234!`
- **seed phrase:** `elephant adjust birth still van radio ecology young belt april range enable`
- **Environment:** staging, Pixel 10 Android 16, Rumble Wallet **v2.0.3** (confirmed in video Frame 2)

## /wallets snapshots

The user's wallet inventory as returned by the backend `/api/v1/wallets` endpoint at three different points in time. **Every BTC address returned by the BE is taproot (`bc1p…`).** None of them is the receive address `bc1qgm7k56…`.

### Snapshot A — Usman, 2026-03-19 07:29 UTC (Asana comment)

One wallet returned for `pagZrxLHnhU`:

| Field | Value |
|---|---|
| id | `3efa0461-b62d-4629-bc1c-1346bb204d1e` |
| type | `unrelated` |
| name | `klemensqwerty` |
| accountIndex | 0 |
| addresses.bitcoin | `bc1qh7ehdzkh49lhxt5rz6ysckle76ercevsv2ujwc` *(segwit / bc1q…, not taproot — matches Snapshot A only)* |
| addresses.spark | `spark1pgssxfensumhna2rf3jvxnky9t0mzfaysf2kukhadm85eq54lh993x35cwsluk` |
| meta.spark.sparkDepositAddress | `bc1pct6hc86kpac42kszzykmafjhhlt49g3wwv3x7l4x4rwvy297af0s367e9a` *(taproot)* |
| createdAt | 1773687758473 → **2026-03-16 22:42 UTC** |

### Snapshot B — Usman, 2026-03-19 12:47 UTC (Asana comment), 5 hours later

Two wallets returned for the same `pagZrxLHnhU`. **Note:** the `id`s and BTC addresses are completely different from Snapshot A — same userId, different wallet inventory.

| id | type | accountIndex | createdAt | bitcoin (taproot) |
|---|---|---|---|---|
| `95f4b950-3601-4ebc-9387-225377d72a28` | unrelated | 0 | 1767985547939 → **2026-01-10 06:25 UTC** | `bc1pu036lhtmx7ny9ztzcj5twg4sehaxgxsnjj3hgcg5zl9p95zn7wusygetkd` |
| `4e3f7bb3-b525-44dd-a903-83bd9710e740` | user | 1 | 1768213410518 → **2026-01-12 21:43 UTC** | `bc1p9phkf0wwgjaja5yumfscpd5krqhj5wc9q4e5lldv3qcxc09lakzsvjm4ax` |

### Snapshot C — FE log, 2026-04-06 17:21:50

Same 4-wallet payload as the BE returned during the reproduction session. BTC addresses are again the two taproot addresses from Snapshot B (plus the spark deposit addresses). The exact response is in the log at 17:21:50.

### Open mystery on /wallets

How can the same userId return totally different wallet inventories 5 hours apart on the same day? Possible explanations:
- Read-after-write inconsistency in `/wallets`.
- Mid-day re-provisioning of the user.
- Mid-day reconciliation operation.

This is *not* the bug we're chasing here, but it overlaps it (RW-1409).

## What the backend `token-transfers` endpoint returns

From the 2026-04-06 FE log:

| Time | URL | Response |
|---|---|---|
| 17:21:18 | `GET /api/v1/users/pagZrxLHnhU/token-transfers?token=btc&limit=100&sort=desc&walletTypes=user&walletTypes=channel&walletTypes=unrelated` | `200 {"transfers":[]}` |
| 17:21:48 | `GET /api/v1/users/pagZrxLHnhU/token-transfers?limit=100&sort=desc&walletTypes=user&walletTypes=channel&walletTypes=unrelated` *(no token filter)* | `200 {"transfers":[…48 entries…]}` |

So the all-currencies endpoint returns 48 entries (USD₮ / USA₮ / scudos visible in Frame 2 of the description screenshot), but the `token=btc` filter zeros it out. The server-side filter is keyed off the user's `/wallets` BTC addresses — which are taproot — so the segwit UTXO never matches.

## All BTC addresses observed in the FE log

**Taproot (`bc1p…`) — from `/wallets` and spark deposit addresses:**
- `bc1pu036lhtmx7ny9ztzcj5twg4sehaxgxsnjj3hgcg5zl9p95zn7wusygetkd`
- `bc1p9phkf0wwgjaja5yumfscpd5krqhj5wc9q4e5lldv3qcxc09lakzsvjm4ax`
- `bc1parpw4p487ea33gq2n7fqz27agw7xt9f4dgf6r2hq8lkkvsd90sls522s9q`
- `bc1p22zsl9wjpt4ruumy37g0jrqg2dd3e8sy380d48l5pzre5e8q26msvz8esz`
- `bc1p7rx5lsnyxxxgpxsruyudyhznx9n2vw7zyz46nzn3emh9228uj7tsnxp2u8`
- `bc1pre8l9lchz8wenm9fzm49q87ln8c7qpmywr4gnwmg08xglczm2uvs6v7tru`

**Segwit (`bc1q…`) — observed in the log but NOT the receive address:**
- `bc1qnkv2gtp437tyxjnc2z2mhw6awq8zhs4exd6v4h`
- `bc1qu5v0rt46x534w9cfd5qj7s08gxzc4pkf2p49qg`

**Conspicuously absent from the log: `bc1qgm7k56yqdzzn30vzzxrjnle6nkdn2wgt0m9ph2`** (the receive address rendered by `[QRCodeDisplay]` and shown in video Frame 6). It comes from client-local state, not any network response. Verified by:

```
$ grep -c "bc1qgm7k56" rumble-wallet-2026-04-06.log
0
```

## walletSync local-vs-backend delta — the smoking gun

At 17:21:13 the `walletSync` module logs:

```
[walletSync] All backend wallets already exist locally – no sync needed
             {"backendWalletCount":4,"localWalletCount":5}
```

Five local wallets, four backend wallets. The 5th local wallet is the one the FE is using as the BTC receive source — known to the FE, invisible to the BE. This is the durable observable marker of the bug.

## Image evidence

| File | When | What it proves |
|---|---|---|
| `evidence/ticket-screenshot-1-balance.png` | 2026-03-18 11:28 device-time | BTC holdings: $15.82 / 0.00021337 BTC visible; "Latest transactions" empty. Balance is indexed by BE; tx feed isn't. |
| `evidence/ticket-screenshot-2-tx-list.png` | 2026-03-18 11:29 device-time | Global Transactions feed: USD₮/USA₮/scudos entries shown; the 2026-03-18 11:10 BTC receive is missing. |
| `evidence/video-frame-05-btc-wallet.png` | 2026-04-06 17:21 device-time | BTC wallet still shows balance (630 sats = $0.44 — drained from 21337 sats) but transaction list still empty. Bug still reproducible. |
| `evidence/video-frame-06-receive-flow.png` | 2026-04-06 17:21 device-time | **CRITICAL.** App is serving `bc1qgm7k56yqdz…kdn2wgt0m9ph2` as the BTC ON-CHAIN receive address inside the Receive bottom sheet. Closes the loop on "where did the user get this address" — from the app itself. |
| `evidence/video-frame-07-copy-toast.png` | 2026-04-06 17:21 device-time | Tap-to-copy toast confirms the user copied the receive address from inside the app. |
| `evidence/screen-recording-20260406.mp4` | 2026-04-06 17:21 | Full ~13s recording from which frames 5-7 are extracted. |
| `evidence/rumble-wallet-2026-04-06.log` | 2026-04-06 11:16 → 17:21 device-time | 1,810-line FE log covering the reproduction session. The log shows every backend call, the empty-tx response, the walletSync delta, and the QRCodeDisplay copy event. |

## Address-character-sequence note

In video Frame 7's share-sheet wrap, the address could read either `…rjnle6nkdn2w…` (as andrey quoted) or `…rjnietnkdn2w…` (visual artefact). The wrap is ambiguous on the screenshot. Use andrey's quoted form `bc1qgm7k56yqdzzn30vzzxrjnle6nkdn2wgt0m9ph2` until disproved by direct video inspection or on-chain verification — the txid resolves to that exact address on mempool.space.

## Timeline (key events)

| Date | Who | What |
|---|---|---|
| 2026-01-10 06:25 UTC | — | `unrelated` taproot wallet `95f4b950-…` createdAt |
| 2026-01-12 21:43 UTC | — | `user` taproot wallet `4e3f7bb3-…` createdAt |
| 2026-03-16 22:42 UTC | — | `unrelated` segwit wallet `3efa0461-…` createdAt *(disappears by next snapshot)* |
| 2026-03-18 11:10 UTC | — | BTC tx received on `bc1qgm7k56…` |
| 2026-03-18 09:25 UTC | andrey.gilyov | Ticket filed |
| 2026-03-18 18:38 UTC | Ahsan Akhtar | FE rules itself out: `token-transfers?token=BTC` returns empty |
| 2026-03-19 07:29 UTC | Usman Khan | Single-wallet `/wallets` snapshot (segwit BTC) |
| 2026-03-19 12:47 UTC | Usman Khan | Two-wallet `/wallets` snapshot (taproot BTC) |
| 2026-03-23 14:22 | Mohamed Elsabry | Fix Version (FE) → RW 2.0.3 |
| 2026-03-24 12:42 | Mohamed Elsabry | Reassigned to Alex |
| 2026-04-01 11:37 | Eddy WM | Moved to "Ready for QA" |
| 2026-04-02 14:27 | Alex | Slack analysis link posted |
| 2026-04-02 15:00 | Alex | "We have no trace of this address in the backend" comment |
| 2026-04-06 14:23 | andrey.gilyov | Posted log + screen recording, moved back to In-Progress |
| 2026-04-09 11:10 | Eddy WM | "It seems like an extreme rare case" / "Is it something that can be resolved on the backend?" |
| 2026-04-09 11:15 | Alex | Linked RW-1409 + a second (still unnamed) ticket |
| 2026-04-15 06:13 | Eddy WM | Stack: FE → BE |
| 2026-04-15 13:34 | Eddy WM | Renamed to "[Backend - Transactions] …" |
| 2026-04-16 13:38 | Eddy WM | Priority: Critical → High |
| 2026-04-20 10:24 | Alex | Posted log findings: "comes from client-local state" |
| 2026-04-20 10:37 | Alex | Asked FE for two in-repo investigations |
| 2026-04-20 11:05 | Eddy WM | "Wallet might have been created long time ago" deflection |
| 2026-04-28 10:28 | Eddy WM | Sprint set to Sprint 1 |
