# Initial finding - RW-1428

## Root cause

This is a wallet membership/registration gap, not a Bitcoin address-format split.

The received BTC address `bc1qgm7k56yqdzzn30vzzxrjnle6nkdn2wgt0m9ph2` is not registered in the backend wallet/address registry for user `pagZrxLHnhU`. The indexer/backend transfer path associates BTC transfers to users only through active backend wallet ids and their registered addresses. Because this exact address has no wallet-id lookup, the transfer is not routed or stored under any wallet id, so `/api/v1/users/pagZrxLHnhU/token-transfers?token=btc...` returns `{"transfers":[]}`.

The app still rendered that address in the Receive flow. The hard fact is: the FE advertised a receive address that the BE had no record of. It may come from FE-local wallet state, but the exact source is not proven from the backend/indexer repos alone.

## Facts from the ticket/logs

- Received transaction: `f0fcd10294218e84b06e457e3fd740ca70188d84944e45e4aba43a59c2b10d95`.
- Receive address shown/copied by the app: `bc1qgm7k56yqdzzn30vzzxrjnle6nkdn2wgt0m9ph2`.
- The FE log's `/api/v1/wallets` response contains 4 backend wallets. None contains the receive address.
- The BE `addresses.bitcoin` values in that response are mixed format:

| accountIndex | type | `addresses.bitcoin` | format |
| --- | --- | --- | --- |
| `0` | unrelated | `bc1pu036lhtmx7ny9ztzcj5twg4sehaxgxsnjj3hgcg5zl9p95zn7wusygetkd` | taproot |
| `1` | user | `bc1p9phkf0wwgjaja5yumfscpd5krqhj5wc9q4e5lldv3qcxc09lakzsvjm4ax` | taproot |
| `2` | channel | `bc1qnkv2gtp437tyxjnc2z2mhw6awq8zhs4exd6v4h` | segwit |
| `3` | channel | `bc1qu5v0rt46x534w9cfd5qj7s08gxzc4pkf2p49qg` | segwit |

- The `bc1p...` values `bc1parpw4p487...`, `bc1p7rx5lsny...`, `bc1pre8l9lch...`, and `bc1p22zsl9w...` are `meta.spark.sparkDepositAddress` values, not `addresses.bitcoin`.
- Any consolidated-doc framing that says every BE BTC address is taproot, or that the bug is "FE segwit vs BE taproot", is wrong on the facts. The BE has registered `bc1q...` channel wallet addresses and would route transfers to any registered `bc1q...` address.
- The receive address does not appear in the captured backend responses. The only proof of it is the UI/video and the QR copy event.
- The existing `localWalletCount=5` signal should be treated carefully: nearby detailed logs show 4 local wallets, while the wallet-sync key list appears to include the same accountIndex `1` user wallet twice. This is suspicious local state/logging, not hard proof of a distinct fifth wallet.

## Code path facts

- `wdk-app-node/workers/lib/server.js` routes `/api/v1/users/:userId/token-transfers` to `service.ork.getUserTransfers`.
- `wdk-ork-wrk/workers/api.ork.wrk.js` proxies wallet and transfer reads to the data shard, and stores address-to-wallet lookups only for addresses present on backend wallet documents.
- `wdk-data-shard-wrk/workers/api.shard.data.wrk.js#getUserTransfers` builds eligible transfer streams from `getActiveUserWallets(userId)`, `wallet.addresses`, and `wallet.meta.spark.sparkDepositAddress`. It does not query arbitrary client/local receive addresses.
- `wdk-data-shard-wrk/workers/proc.shard.data.wrk.js#_walletTransferBatch` syncs transfers only for `Object.entries(wallet.addresses || {})` on active backend wallets.
- `wdk-indexer-processor-wrk/workers/indexer.processor.wrk.js#_handleNewTransfer` resolves incoming transfer `from`/`to` addresses through `lookupStorage.getWalletIdByAddress(address)`. If no lookup exists, the transfer is not forwarded to a wallet shard.
- `wdk-indexer-wrk-btc` supports both `bc1q` and `bc1p` mainnet addresses and indexes outputs by exact address. This does not look like a BTC address parser/indexer format issue.
- The relevant boundary is exact address membership in the BE registry, not whether the address is segwit or taproot.

## What is not proven

- This is not proven to be caused by an old WDK derivation path from the local backend/indexer code. These repos mostly persist supplied wallet addresses; they do not show the source that chose the backend `addresses.bitcoin` values or the UI receive address.
- The taproot-source question is real but separate: something outside the inspected backend/indexer path produced the user/unrelated `bc1p...` `addresses.bitcoin` values, but that is not the cause of this empty `token-transfers` feed.
- Changing the `token=btc` filter would not fix the issue. The missing association is the unregistered receive address, not the token filter.
- The exact FE store/hook that supplied `bc1qgm7k56...` is still unknown because the mobile FE code is not present in this local workspace.

## Actionable next step

Find where the FE sourced `bc1qgm7k56yqdzzn30vzzxrjnle6nkdn2wgt0m9ph2`. Either that wallet/address needs to be registered on the BE, or the FE needs to stop showing receive addresses that are not present in the latest BE wallet registry.
