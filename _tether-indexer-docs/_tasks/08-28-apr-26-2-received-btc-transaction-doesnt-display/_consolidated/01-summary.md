# Summary — RW-1428

## Ticket metadata

| Field | Value |
|---|---|
| Title | [Backend - Transactions] Received BTC transaction doesn't display |
| URL | https://app.asana.com/1/45238840754660/project/1212521145936484/task/1213704628745111 |
| Asana GID | 1213704628745111 |
| RW ID | RW-1428 |
| Project | Rumble Wallet V3 |
| Section | In-Progress |
| Priority | High *(was Critical until 2026-04-16)* |
| Severity | Critical |
| Stack | BE - Backend *(was FE - frontend until 2026-04-15)* |
| Rumble Area | Transactions |
| Sprint | Sprint 1 *(added 2026-04-28)* |
| Task Type | Bug |
| Support Type | Bug |
| Fix Version (FE) | RW 2.0.3 |
| Fix Version (BE) | — |
| Environment | Pixel 10 Android 16 |
| Assignee | Alex Atrash |
| Created | 2026-03-18 |
| Last Asana modification | 2026-04-28 |

## The bug in one paragraph

Staging user `klemensqwerty` (userId `pagZrxLHnhU`) received 0.00021337 BTC ($15.82) in tx `f0fcd10294218e84b06e457e3fd740ca70188d84944e45e4aba43a59c2b10d95` on 2026-03-18 11:10 UTC — confirmed on-chain. The Rumble Wallet app shows the **balance** correctly on the BTC holdings screen, so the backend has indexed the UTXO. But **no transaction entry** appears in either the BTC holdings "Latest transactions" feed or the global Transactions list. Reproducible on app v2.0.3 as late as 2026-04-06.

## Why the transaction doesn't display — proven

1. The funds arrived on **segwit** address `bc1qgm7k56yqdzzn30vzzxrjnle6nkdn2wgt0m9ph2`.
2. The user's `/wallets` BE response contains only **taproot** `bc1p…` addresses (verified in two snapshots from Usman 2026-03-19 and again in the 2026-04-06 client log) — neither matches the segwit address.
3. The transaction-history call `GET /api/v1/users/:userId/token-transfers?token=btc&…` filters server-side on `/wallets` BTC addresses. Since the receive address isn't there, the response is `{"transfers":[]}`. Confirmed in the FE log at 17:21:18.
4. The 2026-04-06 FE log confirms the segwit address is never returned by *any* backend endpoint during the session — it is sourced from **client-local state**.
5. The same log shows `walletSync: {"localWalletCount":5, "backendWalletCount":4}` — there is one local wallet the BE doesn't know about. That extra local wallet is the prime suspect for where `bc1qgm7k56…` lives.

## Why Eddy's "very old WDK address generation" theory is wrong

Verified by reading `tetherto/wdk-wallet-btc` (the actual WDK BTC repo — there is no `wdk-lib-bitcoin`):

- Repo description on GitHub: *"WDK module to manage BIP-84 (SegWit) wallets for the Bitcoin blockchain."*
- `src/wallet-account-btc.js` whitelists `bip ∈ {44, 84}`, throws otherwise; default is `bip = 84`. Addresses are derived via `payments.p2pkh` or `payments.p2wpkh`.
- `git log --all -S` for `p2tr` / `bip86` / `taproot` returns **zero** functional hits across every branch and every commit since the initial commit on 2025-05-01.
- bip84/44 support landed 2025-09-04 (`92dd31a`).

So `wdk-wallet-btc` has only ever produced segwit. The `bc1qgm7k56…` segwit address is **not** a legacy artefact — it's exactly what the lib outputs today on `main`. The puzzle inverts: it's the **taproot** addresses in `/wallets` that *cannot* have come from `wdk-wallet-btc`. They must come from a different derivation path on the BE.

## Where things stand right now

- The ticket is on you (Alex). Last substantive exchange was Eddy's 2026-04-20 11:05 deflection ("might have been created long time ago, very old in the address generation on wdk side").
- 2026-04-28: Eddy added the ticket to Sprint 1 — no comment, no other field changes.
- The two in-repo investigations Alex asked for on 2026-04-20 (trace `[QRCodeDisplay]` upstream; grep for `bc1q` / `p2wpkh` / segwit derivation) are still owed.
- Ranked next moves: see `tasks/`.

## Cross-references

- Related ticket: **RW-1409 [Backend] Migration Reconciliation Job** (`https://app.asana.com/1/45238840754660/project/1212521145936484/task/1213680013630981`). Summary in `04-related-context.md`. The reconciliation job as currently scoped (PR #192) does **not** flag this user — see `04-related-context.md` for why.
- Slack analysis thread (Alex's own write-up, 2026-04-02): `https://tether-to.slack.com/archives/C0A5DFYRNBB/p1775069742706779`. Contents not yet captured here.
- Second related ticket Alex mentioned on 2026-04-09: still unnamed.
