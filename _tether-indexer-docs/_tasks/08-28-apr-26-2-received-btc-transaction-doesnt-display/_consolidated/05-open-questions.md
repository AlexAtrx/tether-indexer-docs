# Open questions — RW-1428

Stuff that is still unknown after refresh on 2026-04-28. Each item flags whether we need new info from Alex or from the codebase.

## Need from Alex

- [ ] **Slack analysis thread** `https://tether-to.slack.com/archives/C0A5DFYRNBB/p1775069742706779` — Alex's own 2026-04-02 root-cause write-up for THIS ticket. Likely the most concentrated source of context. Contents not captured here.
- [ ] **Second related ticket URL** — Alex mentioned "two other tickets" on 2026-04-09 11:15 but only named RW-1409. Need the second.
- [ ] **/wallets eventual consistency?** — Usman pulled two contradictory wallet inventories for the same `pagZrxLHnhU` 5 hours apart on 2026-03-19 (Snapshot A: 1 wallet with segwit BTC; Snapshot B: 2 wallets with taproot BTC, completely different IDs). Was there a re-provisioning between 07:29 and 12:47 UTC, or is `/wallets` eventually-consistent?
- [ ] **Decision on reconciliation path vs. FE-constraint fallback** — both still open per Alex's Slack ask on RW-1409.
- [ ] **RW-1409 Slack threads** — the 2026-03-17 analysis (`p1773779479524349`) and the 2026-03-20 PR review thread (`p1774015635649839`) — neither captured here.

## Need from the codebase

- [ ] **Where does the FE source the receive address `bc1qgm7k56…`?** Concretely: in the mobile FE repo, find the component behind `[QRCodeDisplay]` and trace which store / hook / selector supplies the `bitcoin` address it renders. Strong candidates from the log: `walletSync`, `offlineWalletAccessService`, `hooks/useResyncWalletsLackingAddresses`. *(This is the in-repo investigation Alex asked Eddy for on 2026-04-20.)*
- [ ] **What is the 5th local wallet?** The 2026-04-06 log shows `localWalletCount=5, backendWalletCount=4`. Identify the storage location (MMKV key / AsyncStorage key / secure keychain slot) and the entry. That entry is the bug.
- [ ] **What produces the taproot `addresses.bitcoin` returned by `/wallets`?** It cannot be `wdk-wallet-btc` (which only does bip44 + bip84). Likely BE-side derivation in `wdk-indexer-wrk-btc`, `rumble-wallet-backend`, `wdk-data-shard-wrk`, or something in the spark-deposit pipeline. Identifying this is the key to understanding the FE/BE format split.
- [ ] **Segwit-vs-taproot derivation paths in the FE repo** — grep for `bc1q` / `p2wpkh` / `bip84` / segwit derivation. Confirm the FE has a code path that produces segwit addresses; if so, that path is the bug. *(Second of the two investigations Alex asked Eddy for on 2026-04-20.)*

## Considered and dismissed

- ~~"Cross-check `wdk-lib-bitcoin` git history for when BTC derivation switched from bip84 → bip86."~~ Done 2026-04-28: the actual repo is `tetherto/wdk-wallet-btc`; it has only ever supported bip44 + bip84; there is no taproot code path on any branch. Eddy's "very old WDK derivation" theory is falsified. See `03-investigation.md` Part 3.

- ~~"Where exactly is the BTC tx-history endpoint defined?"~~ Pinned in the FE log: `GET /api/v1/users/:userId/token-transfers?token=btc`. Not blocking.

- ~~"How did the user acquire the `bc1qgm7k56…` address?"~~ Resolved by video Frame 6 — the app served it via the standard Receive flow.

- ~~"Is the screen recording's address character-sequence ambiguous?"~~ Use andrey's quoted form `bc1qgm7k56yqdzzn30vzzxrjnle6nkdn2wgt0m9ph2`. The on-chain txid resolves to that address on mempool.space.
