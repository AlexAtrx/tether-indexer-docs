# Log analysis — `attachments/rumble-wallet-2026-04-06.log`

1,810-line FE client log captured during the 2026-04-06 reproduction session. Spans 11:16:07 → 17:21:53 device-local time. The attached video (`screen-20260406-172125-1775485270371.mp4`) was recorded during this same session — the `[QRCodeDisplay] Address copied to clipboard` entry at **17:21:22** is literally the toast shown in video Frame 7.

## Headline finding — the Receive address is not from the backend

Grep for the mystery receive address across the entire log:

```
$ grep -c "bc1qgm7k56" rumble-wallet-2026-04-06.log
0
$ grep -c "bc1qh7e"   rumble-wallet-2026-04-06.log   # Usman's earlier BTC address
0
$ grep -c "bc1qqfr"   rumble-wallet-2026-04-06.log   # the sender address
0
$ grep -c "f0fcd10294" rumble-wallet-2026-04-06.log  # the tx hash
0
```

`bc1qgm7k56yqdzzn30vzzxrjnle6nkdn2wgt0m9ph2` **does not appear anywhere in the log** — not in any `WalletAPI` response, not in any `RumbleAPI` response, not in any log event. Yet the video (Frame 6, 17:21:10 device time) shows the app rendering exactly that address in the Receive QR code, and the `[QRCodeDisplay]` event fires at 17:21:22 to confirm the user copied it.

Conclusion: **no backend endpoint serves this address to the FE during the session.** The Receive flow sources it from client-local state, not from a network call.

## What backend calls DID happen around the Receive tap

### Transaction history call (the call that produces the empty feed)

At 17:21:18 — two back-to-back calls:

```
GET https://wallet-8s4anfsr6it9.rmbl.ws/api/v1/users/pagZrxLHnhU/token-transfers
    ?token=btc&limit=100&sort=desc
    &walletTypes=user&walletTypes=channel&walletTypes=unrelated
→ 200 {"transfers":[]}
```

So the endpoint behind the "No transactions yet" UI is identified: `GET /api/v1/users/:userId/token-transfers?token=btc&…`. It returns an empty array. For comparison, at 17:21:48 the same endpoint *without* `token=btc` returns **48 transfers** (the USD₮ / USA₮ / scudos entries visible in the global Transactions screen).

Interpretation: the server-side query filters transfers by the user's BTC wallet addresses as stored in `/wallets` — and since the funds arrived on `bc1qgm7k56…` (which isn't in `/wallets`), zero results.

### Wallets call

At 17:21:50:

```
GET https://wallet-8s4anfsr6it9.rmbl.ws/api/v1/wallets
→ 200 {"wallets":[…4 wallets…]}
```

Returns the same 4-wallet set Usman pulled — BTC addresses `bc1pu036lhtmx7ny9ztzcj5twg4sehaxgxsnjj3hgcg5zl9p95zn7wusygetkd` (unrelated) and `bc1p9phkf0wwgjaja5yumfscpd5krqhj5wc9q4e5lldv3qcxc09lakzsvjm4ax` (user), **both taproot (`bc1p…`)**. Neither matches the segwit receive address.

### Unique BTC addresses observed anywhere in the log

Taproot (`bc1p…`, from `/wallets` + spark deposit addresses):
- `bc1pu036lhtmx7ny9ztzcj5twg4sehaxgxsnjj3hgcg5zl9p95zn7wusygetkd`
- `bc1p9phkf0wwgjaja5yumfscpd5krqhj5wc9q4e5lldv3qcxc09lakzsvjm4ax`
- `bc1parpw4p487ea33gq2n7fqz27agw7xt9f4dgf6r2hq8lkkvsd90sls522s9q`
- `bc1p22zsl9wjpt4ruumy37g0jrqg2dd3e8sy380d48l5pzre5e8q26msvz8esz`
- `bc1p7rx5lsnyxxxgpxsruyudyhznx9n2vw7zyz46nzn3emh9228uj7tsnxp2u8`
- `bc1pre8l9lchz8wenm9fzm49q87ln8c7qpmywr4gnwmg08xglczm2uvs6v7tru`

Segwit (`bc1q…`):
- `bc1qnkv2gtp437tyxjnc2z2mhw6awq8zhs4exd6v4h`
- `bc1qu5v0rt46x534w9cfd5qj7s08gxzc4pkf2p49qg`

Neither of the segwit addresses is `bc1qgm7k56…`. Both bech32 formats coexist in the log — which itself is suspicious and worth flagging: the BE is serving taproot, but segwit artefacts are still circulating in the FE.

## Client-local state modules present in the log

The FE has several local-state modules that can hold addresses without a network round-trip. The specific source of `bc1qgm7k56…` is one of these (or a code path derived from the seed phrase):

- `[walletSync]` — maintains a local wallet-keys store with per-account entries of the form `{"key":"***","accountIndex":N,"type":"unrelated|user|channel","identifier":"…"}`. Five local wallets observed (accountIndex 0–4), four of which match the `/wallets` response (sync log: *"All backend wallets already exist locally – no sync needed"*) — meaning there's at least one **extra local wallet** the backend doesn't know about. That could be the origin of the segwit address.
- `[legacyKeychainRecovery]` — ran once at 13:01:38/39 with result `{"completed":false,"hasAll":false,"hasSalt":false,"hasEntropy":false}`. So legacy keychain recovery is wired up but did not find legacy material on *this* device. Does not rule out legacy material on the original reporter's device from which the address originated.
- `[offlineWalletAccessService]`, `[backupService]`, `[cloudBackup]`, `[hooks/useResyncWalletsLackingAddresses]`, `[hooks/useBackendWalletResetCheck]`, `[hooks/useWalletBackendSync]`, `[hooks/useWalletValidation]` — all present. Together these implement the migration / sync / recovery surface area where an FE-only address can persist.
- `[QRCodeDisplay]` — the component that renders the receive QR code. It only logged the copy event, not the address it rendered.

The `walletSync` log at 17:21:13 is particularly telling:

```
[walletSync] All backend wallets already exist locally – no sync needed
             {"backendWalletCount":4,"localWalletCount":5}
```

The client has **5 local wallets, the backend has 4**. The extra local wallet is the prime suspect for where `bc1qgm7k56…` lives — it's known to the FE but invisible to the BE, which is exactly the pattern the parent BTC-tx bug predicts.

## Timestamp map to the video

| Log time   | Event                                                              | Video frame |
|------------|--------------------------------------------------------------------|-------------|
| 17:21:13   | `walletSync` reports 5 local vs 4 backend wallets                  | just before Frame 1 |
| 17:21:18   | Two empty `token-transfers?token=btc` responses                    | around Frame 5 (BTC wallet view) |
| 17:21:22   | `[QRCodeDisplay] Address copied to clipboard`                      | Frame 7 (copy toast) |
| 17:21:48–50| App resumes, unfiltered `token-transfers` returns 48 non-BTC rows, `/wallets` returns taproot set | after the video ends |

## Implications for the fix

1. **The tx-history call is correctly identified** (`/api/v1/users/:userId/token-transfers?token=btc`). Fixing the "No transactions yet" symptom means either:
   - Making this endpoint also consider addresses the user actually received funds on (not just `/wallets` entries), or
   - Ensuring the user's `/wallets` entry contains the segwit receive address so the lookup naturally matches.
2. **The receive address is FE-local, not BE-served.** So Alex's Slack fallback — "app team only displays addresses that are registered with the backend" — is a *real* FE code change on the Receive flow, not just a server-side filter flip. The FE needs to sink the extra local-wallet entry and render only what `/wallets` returns.
3. **The `localWalletCount=5 vs backendWalletCount=4` split is a durable, observable marker** of the bug class. Whatever fix gets picked, it should drive that delta to zero for migrated users.

## Open questions the log does NOT answer

- Where exactly is the extra 5th local wallet stored (MMKV key / AsyncStorage key / secure keychain slot)?
- How did it acquire the segwit address — BIP84 derivation from the seed at install time? Carried forward from a pre-migration build? Seeded by an old FE version that derived `bc1q` addresses?
- Is this extra-local-wallet pattern present for many users or only for those who migrated from the old app?
