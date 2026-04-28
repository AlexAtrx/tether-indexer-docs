# Investigation — RW-1428

Combined analysis of the FE log, screenshots/video, and the WDK BTC library. The conclusion is that the bug is a **format split**: the FE is presenting a segwit (`bc1q…`) receive address from a local wallet that the backend doesn't know about, while the backend's `/wallets` and `token-transfers?token=btc` endpoints only know about taproot (`bc1p…`) addresses.

---

## Part 1 — FE log dissection

`evidence/rumble-wallet-2026-04-06.log` — 1,810-line client log captured during the 2026-04-06 reproduction session, spanning 11:16:07 → 17:21:53 device-local time.

### Headline finding: the receive address is not from the backend

```
$ grep -c "bc1qgm7k56" rumble-wallet-2026-04-06.log
0
$ grep -c "f0fcd10294" rumble-wallet-2026-04-06.log
0
```

The mystery receive address `bc1qgm7k56yqdzzn30vzzxrjnle6nkdn2wgt0m9ph2` does not appear anywhere in the log — not in any `WalletAPI` response, `RumbleAPI` response, or other event. Yet video Frame 6 (17:21:10 device-time) shows the app rendering exactly that address in the Receive QR code, and `[QRCodeDisplay] Address copied to clipboard` fires at 17:21:22 to confirm the user copied it.

**Conclusion:** no backend endpoint serves this address to the FE during the session. The Receive flow sources it from client-local state.

### What the BE calls during the Receive tap

#### tx-history call (the call that produces the empty feed)

At 17:21:18, two back-to-back calls:

```
GET https://wallet-8s4anfsr6it9.rmbl.ws/api/v1/users/pagZrxLHnhU/token-transfers
    ?token=btc&limit=100&sort=desc
    &walletTypes=user&walletTypes=channel&walletTypes=unrelated
→ 200 {"transfers":[]}
```

For comparison, at 17:21:48 the same endpoint *without* `token=btc` returns **48 transfers** (the USD₮ / USA₮ / scudos entries visible in the global Transactions screen).

The server-side query filters transfers by the user's BTC wallet addresses as stored in `/wallets` — and since the funds arrived on `bc1qgm7k56…` (which isn't in `/wallets`), zero results.

#### /wallets call

At 17:21:50:

```
GET /api/v1/wallets → 200 {"wallets":[…4 wallets…]}
```

Returns the same 4-wallet set from Usman's 2026-03-19 12:47 snapshot — BTC addresses are both taproot. Neither matches the segwit receive address.

### Client-local state modules with FE-only addresses

The FE has several modules that can hold addresses without a network round-trip:

- `[walletSync]` — maintains a local wallet-keys store with per-account entries `{"key":"***","accountIndex":N,"type":"…","identifier":"…"}`. **Five local wallets observed (accountIndex 0-4)**, four of which match the `/wallets` response (sync log: *"All backend wallets already exist locally – no sync needed"*) — meaning there is one **extra local wallet** the backend doesn't know about. Strongest candidate for where `bc1qgm7k56…` lives.
- `[legacyKeychainRecovery]` — ran once at 13:01:38 with result `{"completed":false,"hasAll":false,"hasSalt":false,"hasEntropy":false}`. Wired up but no legacy material on this device. Doesn't rule out legacy material on the original reporter's device.
- `[offlineWalletAccessService]`, `[backupService]`, `[cloudBackup]`, `[hooks/useResyncWalletsLackingAddresses]`, `[hooks/useBackendWalletResetCheck]`, `[hooks/useWalletBackendSync]`, `[hooks/useWalletValidation]` — all present. The migration / sync / recovery surface area where an FE-only address can persist.
- `[QRCodeDisplay]` — the component that renders the receive QR code. Only logged the copy event, not the address it rendered.

The walletSync log at 17:21:13 is the smoking gun:

```
[walletSync] All backend wallets already exist locally – no sync needed
             {"backendWalletCount":4,"localWalletCount":5}
```

### Timestamp map: log ↔ video

| Log time | Event | Video frame |
|---|---|---|
| 17:21:13 | walletSync reports 5 local vs 4 backend | just before Frame 1 |
| 17:21:18 | Two empty `token-transfers?token=btc` responses | around Frame 5 (BTC wallet view) |
| 17:21:22 | `[QRCodeDisplay] Address copied to clipboard` | Frame 7 (copy toast) |
| 17:21:48-50 | Unfiltered `token-transfers` returns 48 non-BTC rows; `/wallets` returns taproot set | after the video ends |

### Implications for the fix (from log analysis alone)

1. The tx-history call is correctly identified (`/api/v1/users/:userId/token-transfers?token=btc`). Fixing the empty-feed symptom needs either (a) the endpoint to consider addresses the user actually received funds on, not just `/wallets` entries, or (b) the user's `/wallets` entry to contain the segwit receive address.
2. The receive address is FE-local, not BE-served. So Alex's Slack fallback ("app team only displays addresses that are registered with the backend") is a *real* FE code change on the Receive flow, not just a server-side filter flip.
3. The `localWalletCount=5 vs backendWalletCount=4` split is a durable observable marker of the bug class. Whatever fix gets picked, it should drive that delta to zero for migrated users.

---

## Part 2 — Image / video walk-through

`evidence/ticket-screenshot-1-balance.png` — 2026-03-18 11:28 device-time. Original ticket attachment. BTC holdings screen showing $15.82 / 0.00021337 BTC balance, ON CHAIN address row populated, **"No transactions yet"** in the latest-transactions area. Proves balance is indexed by the BE; tx feed isn't.

`evidence/ticket-screenshot-2-tx-list.png` — 2026-03-18 11:29 device-time. Original ticket attachment. Global Transactions feed showing USD₮ / USA₮ / scudos entries from 2026-03-10 → 2026-03-18, but the 2026-03-18 11:10 BTC receive is missing. Isolates the bug to BTC token-transfers, not a global filter.

`evidence/video-frame-05-btc-wallet.png` — 2026-04-06 17:21 device-time. Same BTC wallet screen as the 03-18 screenshot, 19 days later. Balance now $0.44 / 0.0000063 BTC (630 sats — drained from 21337 sats). Latest transactions still empty. **Bug still reproducible** on app v2.0.3.

`evidence/video-frame-06-receive-flow.png` — 2026-04-06 17:21 device-time. **CRITICAL evidence.** The Receive bottom sheet is open over the BTC wallet. Header reads "BTC · ON CHAIN Address — Receive BTC using the ON CHAIN network". The QR code and address text below show **`bc1qgm7k56yqdz…kdn2wgt0m9ph2`** — the same segwit address the funds arrived on. **This proves the app itself presents `bc1qgm7k56…` as the user's BTC receive address.** Combined with the log finding that no backend response contains this address, the FE must be sourcing it from client-local state.

`evidence/video-frame-07-copy-toast.png` — 2026-04-06 17:21 device-time. "Address copied to clipboard" toast confirms the user copied the address from inside the app, closing the loop on "how did the user acquire this address — from the app's own Receive flow".

App version confirmed v2.0.3 (Profile screen frame, not in evidence/).

---

## Part 3 — WDK BTC derivation check (falsifies Eddy's theory)

Eddy's 2026-04-20 11:05 comment:

> My assumption here is this wallet might have been created long time ago, and possibly a very old in the address generation on wdk side since nobody else has been able to reproduce this issue in another (new) wallet

This requires `wdk-wallet-btc` (the WDK Bitcoin module — there is no `wdk-lib-bitcoin`) to have changed its derivation at some point, with old wallets still on the old format. Verified against `tetherto/wdk-wallet-btc`:

- **Repo:** https://github.com/tetherto/wdk-wallet-btc (public)
- **GitHub description:** *"WDK module to manage BIP-84 (SegWit) wallets for the Bitcoin blockchain."*
- **Source:** `src/wallet-account-btc.js:111-126`:

```js
const bip = config.bip ?? 84

if (![44, 84].includes(bip)) {
  throw new Error('Invalid bip specification. Supported bips: 44, 84.')
}

const fullPath = `m/${bip}'/${netdp}'/${path}`
…
const { address } = bip === 44
  ? payments.p2pkh({ pubkey: account.publicKey, network })
  : payments.p2wpkh({ pubkey: account.publicKey, network })
```

Default `bip = 84` produces segwit (`bc1q…`); `bip = 44` produces P2PKH (`1…`). Anything else throws. **No bip86 / p2tr / taproot code path exists.**

History check (all branches, all commits):

```
$ git log --all --oneline -S "p2tr"     # no functional matches
$ git log --all --oneline -S "bip86"    # no functional matches
$ git log --all --oneline -S "taproot"  # one match in a 2025-11-09 message-signing commit, unrelated
$ git log --all --pretty='%ci %h %s' -S "p2wpkh" -- 'src/*' 'index.js'
2025-11-09 17:48:00 +0330 9ff4104 add btcjs message signing and verification
2025-09-04 12:57:01 +0330 92dd31a add bip84/44 support
…
2025-05-05 18:18:23 +0200 c7778e6 Transfer project from davi0kprogramsthings/wdk-wallet-btc.
```

**Conclusion:** `wdk-wallet-btc` has never produced taproot. There has been no derivation switch. The segwit `bc1qgm7k56…` is consistent with the current main branch, not a legacy artefact.

### The puzzle inverts

Going through the user's BTC addresses against what `wdk-wallet-btc` *can* produce:

| Wallet `id` | createdAt | BTC format | Source library? |
|---|---|---|---|
| `95f4b950-…` (`unrelated`, idx 0) | 2026-01-10 06:25 UTC | `bc1pu036…` taproot | NOT wdk-wallet-btc |
| `4e3f7bb3-…` (`user`, idx 1) | 2026-01-12 21:43 UTC | `bc1p9phk…` taproot | NOT wdk-wallet-btc |
| `3efa0461-…` (`unrelated`, idx 0, *Snapshot A only*) | 2026-03-16 22:42 UTC | `bc1qh7eh…` segwit | matches wdk-wallet-btc |
| `bc1qgm7k56…` (FE-served receive, source of the bug) | unknown | `bc1q…` segwit | matches wdk-wallet-btc |

The two segwit addresses are consistent with the WDK lib. The two taproot addresses **must come from a different derivation path on the BE.** Likely candidates:
- Spark-related deposit address being copied/aliased into `addresses.bitcoin`. (The `meta.spark.sparkDepositAddress` is also taproot, e.g. `bc1pct6hc86…`, but it's *different* from `addresses.bitcoin` — so this is not a simple alias.)
- A backend-side BTC derivation in `wdk-indexer-wrk-btc`, `rumble-wallet-backend`, `wdk-data-shard-wrk`, or another shard/ork repo.
- A migration-time recreation that produced taproot addresses on the BE while the FE held onto older segwit.

Identifying which is essential to understanding the FE/BE format split — see `tasks/02-find-taproot-source-on-be.md`.

---

## Bottom-line summary of the investigation

1. The bug is a **format split**: FE serves segwit, BE expects taproot.
2. The segwit address is **FE-local** — five local wallets, four backend wallets, the extra one holds the segwit receive address.
3. The segwit address is **not legacy** — `wdk-wallet-btc` produces segwit today on `main`. Eddy's "old WDK derivation" framing is wrong on the facts.
4. The actual mystery to solve next is **where the taproot `bc1p…` addresses in `/wallets` come from**, since they cannot be from `wdk-wallet-btc`. Once that's identified, the FE/BE format split has a name and a fix path.

## Open questions the log/code do NOT answer

- Where exactly is the extra 5th local wallet stored (MMKV key / AsyncStorage key / secure keychain slot)?
- How did it acquire the segwit address — bip84 derivation from the seed at install time? Carried forward from a pre-migration build? Seeded by an old FE version that derived `bc1q` addresses?
- Is this extra-local-wallet pattern present for many users or only for those who migrated from the old app?
- Which BE module produces the taproot `addresses.bitcoin` returned by `/wallets`?
