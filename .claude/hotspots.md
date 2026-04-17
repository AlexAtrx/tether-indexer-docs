# Known hotspots & weak points

Snapshot from `___TRUTH.md` (last updated 2026-04-16). If you're about to change code near any of these areas, read the linked sources first.

## RW-1526 — `sparkDepositAddress` pollutes BTC history (open, 2026-04-15)

- Ork registers `wallet.meta.spark.sparkDepositAddress` into the address lookup on wallet create/update:
  `wdk-ork-wrk/workers/api.ork.wrk.js:440-444`
- Shard `getUserTransfers` includes `sparkDepositAddress` in the per-wallet address match set:
  `wdk-data-shard-wrk/workers/api.shard.data.wrk.js:345-347`
- Effect: MoonPay→Spark deposits appear as BTC transfers in `/api/v1/users/{userId}/token-transfers`, but on-chain BTC balance excludes them. Structural mismatch between history and balance for every user who used MoonPay-to-Spark.
- Mobile app applies no `token=btc` filter.

## RW-1601 — push notification decimal precision (open, 2026-04-16)

- `rumble-app-node/workers/lib/server.js:220` (v1) and `:304` (v2) declare `amount: { type: 'number' }`.
- Imprecise floats (e.g. `0.026882800000000002`) are interpolated raw into templates in
  `rumble-data-shard-wrk/workers/lib/utils/notification.util.js:87-126` (`${amount}`).
- Affected templates: `TOKEN_TRANSFER`, `TOKEN_TRANSFER_RANT`, `TOKEN_TRANSFER_TIP`, `SWAP_STARTED`, `TOPUP_STARTED`, `CASHOUT_STARTED`, plus the `*_COMPLETED` topup/cashout variants.
- Fix surface: caller schema + `/api/v2/notifications` schema + template defensiveness.
- Indexer-sourced `TOKEN_TRANSFER_COMPLETED` escapes the bug only because the indexer provides a pre-formatted decimal string.

## `/api/v1/balance/trend` returns empty for real users (open, 2026-04-15)

Root cause is five interacting failures in `syncBalancesJob` at
`wdk-data-shard-wrk/workers/proc.shard.data.wrk.js`:

1. RPC call fan-out: `users × wallets × chains × ccys` (~14 ccy slots) per run.
2. `_processUserBalanceIfMissing` skips the user entirely when `bal.balance === null`, even if individual `tokenBalances` succeeded. A single transient RPC failure on e.g. `spark:btc` voids the whole snapshot. (`:662`)
3. On abort (`getSignal()?.aborted`) the job returns before flushing the tail pipe (~499 buffered entries). (`:784`)
4. `_saveBalanceBatch` catches errors by clearing the pipe (`pipe = []`), silently dropping up to 500 snapshots. (`:800-804`)
5. `range=all` falls back to `new Date(0)`, producing 10 buckets from 1970 to 2026, all null.

Full analysis: `_tether-indexer-docs/_tasks/15-apr-26-Xaxis-is-incorrect/analysis.md`.

Usman's PR `wdk-data-shard-wrk#186` fixed cursor lifetime + abort plumbing only; the five above remain.

## Dual ingestion path ambiguity

Shard polling (`syncWalletTransfers`) and the indexer → processor → shard Redis-stream path both run. Freshness bugs are hard to attribute. The 2026-02-27 staging lag (fresh transfers in indexer, stale in shard/app) was most likely a processor/propagation fault, not an indexer fault.

## Legacy transfer APIs are flat rows

Runtime returns wallet-transfer rows, not one logical transaction per on-chain action. There is no `tx-history v2` / grouped pipeline in runtime code (no `processTransferGroup`, no `underlyingTransfers`, no `wallet_transfers_processed`, no `totalAmount`, no `feeToken`).

## BTC-specific

- Sender-side history is weak: indexer parses one row per output; shard wallet-transfer schema has no fee/change/input fields.
- Direction derived from wallet ownership of `from`; user-level merge does **not** dedupe self-transfers across wallets.
- Balance path is fragile: `scantxoutset` on bitcoind; busy scans map to `ERR_SCANTXOUTSET_BUSY`. March/April reports of zero/missing BTC balances still open.
- `metadata.inputs` is persisted by the BTC indexer (see `wdk-indexer-wrk-btc/workers/lib/providers/rpc.provider.js:79,86-89`).

## Solana

`sync-tx` is intentionally removed at proc startup:
`wdk-indexer-wrk-solana/workers/proc.indexer.solana.wrk.js:28`.

## Notifications / idempotency

Notification dedupe and manual-notification idempotency are memory-only. Restart loses state. Move to durable storage when touching this area.

## MoonPay

- Missing `externalCustomerId`: warn-and-skip (no longer 500s).
  `rumble-app-node/workers/lib/services/moonpay.utils.js:92-93,126-127,153-154`
- `SWAP_COMPLETED` still unimplemented; throws `SWAP_COMPLETED_NOT_SUPPORTED_PAYLOAD_MISSING`.

## Security / deployment risks

- API keys in `wdk-indexer-app-node` are generated plaintext, HMAC-hashed at rest (`utils.hashApiKey`), and emailed in plaintext body.
- `rumble-app-node` docs basic auth falls back to `admin` / `password` if `docsAuth` config is missing. (`workers/lib/services/auth.js:64-82`)
- `noAuth=true` is rejected when `ctx.env === 'production'`, but still a high-risk deployment setting.
- Sentry is config-gated (`conf.sentry.enabled`), not environment-gated.
- Service-to-service trust is shared-secret only (topic capability + crypto key); no mTLS or service identity.

## Docs / setup drift

- `_wdk_docker_network_v2/README.md` says `make up`; Makefile `up` only runs Mongo + Redis. `up-all` is the full stack.
- Public indexer chain whitelist is broader than the set of chain worker repos in the workspace.

## Open TODOs (from TRUTH §8)

- Separate main-BTC-address transfers from `sparkDepositAddress` transfers (RW-1526).
- Save balance snapshots on partial success (persist `tokenBalances` even when aggregated balance is null).
- Flush pipe on `syncBalancesJob` abort; retry/persist failed batches.
- Tighten `/api/v2/notifications` schema to require a decimal string; make templates defensive (RW-1601).
- Resolve BTC zero-balance carry-over from March.
- Decide canonical ingestion path (stream vs polling); document + monitor.
- Ship or retire tx-history v2.
- Carry BTC change/input/fee context into shard history.
- Durable notification/transfer dedupe.
- Re-enable Solana `sync-tx` or document as unsupported.
- Implement or retire MoonPay `SWAP_COMPLETED`.
- Separate migration snapshot + reconciliation path (if migration remains active).
- Align docs / example config / docker with runnable stack.
- Harden docs auth defaults.
