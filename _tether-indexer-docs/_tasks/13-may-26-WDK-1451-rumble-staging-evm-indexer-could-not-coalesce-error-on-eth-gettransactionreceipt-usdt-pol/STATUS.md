# Status — 2026-05-13

Root cause investigated, fix landed locally, two draft PRs opened.

## Pull requests

- `rumble-data-shard-wrk` — https://github.com/tetherto/rumble-data-shard-wrk/pull/217
- `rumble-ork-wrk` — https://github.com/tetherto/rumble-ork-wrk/pull/150

Both target `dev`, branch `WDK-1451-validate-tx-webhook-hash-and-fix-retry`. Currently in draft.

## What landed

### rumble-data-shard-wrk
- `workers/proc.shard.data.wrk.js`
  - `storeTxWebhook` validates `transactionHash` per chain; rejects empty `transactionHash` even when `isTransactionReceipt` is set.
  - `_processTxWebhooksJob` wraps `_isTxCompleted` in try/catch; thrown chain errors now fall through to the retry policy instead of aborting the for-await.
- `workers/lib/utils/tx-hash.util.js` (new) — `isValidTxHash(blockchain, hash)` covering EVM, hex64, base58, TON.
- `migrations/mongodb/2026-05-13_drain-invalid-tx-webhooks.js` (new) — marks PENDING records with invalid hash as FAILED, supports `--dry-run`.
- Unit tests: new `tests/tx-hash.util.unit.test.js` plus added cases in `tests/proc.shard.data.wrk.unit.test.js` (throw → retry, placeholder rejection, empty receipt id rejection, gasless receipt id accept).

### rumble-ork-wrk
- `workers/api.ork.wrk.js` — new `_assertValidWebhookTxHash(payload, isTransactionReceipt)` called before every `_addTxWebhook` site in `sendNotification` and `sendNotificationV2`.
- `workers/lib/tx-hash.util.js` (new) — duplicate of the shard helper; both repos are independent.
- Updated test fixtures in `tests/unit/api.ork.wrk.unit.js` to use proper 0x+64hex hashes for webhook-creating tests.
- `tests/unit/api.ork.wrk.tx-hash-validation.unit.test.js` (new) — RANT/TIP rejection, valid-hash accept, receipt-id accept.

## Backing-store question — resolved

`tx-webhook` records live in MongoDB, not HyperDB. Rumble's `rumble-data-shard-wrk/config/common.json` sets `"dbEngine": "mongodb"`; the live collection is `wdk_data_shard_tx_webhooks` (see `workers/lib/db/mongodb/repositories/txwebhook.js`). The drain migration is correctly placed under `migrations/mongodb/`.

## What's left

1. Get reviews on both PRs and merge them in this order: ork first (closes the door), then shard (handles the queue side).
2. On staging, after both merges deploy, run:
   - `npm run migration -- 2026-05-13_drain-invalid-tx-webhooks --dry-run` to confirm only the 4 placeholders are flagged
   - `npm run migration -- 2026-05-13_drain-invalid-tx-webhooks` to mark them FAILED
3. Watch the Grafana panel for ~30 min to confirm the "could not coalesce error" rate drops to zero.
4. Optional: run the same Loki query against `env=prod` once for a sanity check that no `debug-*` hashes exist there.

## Open questions for Alex (not blocking)

- The four placeholder hashes were minted by something running on 2026-05-06 15:40 to 16:27 UTC. Nothing in this codebase emits `debug-<Date.now()>`, so the producer is in the rumble-server monolith. Worth a heads-up to whoever owns that repo so they stop using a string that looks like a tx hash for test webhooks.
- Sprint mismatch (description says Sprint 1, Asana custom field says Sprint 2) — minor.
