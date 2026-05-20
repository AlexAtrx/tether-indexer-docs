# Status — 2026-05-15

Root cause investigated, fix split across two repos, draft PRs opened.

## Pull requests

- `rumble-app-node` — https://github.com/tetherto/rumble-app-node/pull/210 — fastify schema validates `transactionHash` and `transactionReceiptId` per chain at the HTTP API boundary. Branch `WDK-1451-validate-tx-hash-in-notifications-schema`.
- `rumble-data-shard-wrk` — https://github.com/tetherto/rumble-data-shard-wrk/pull/217 — cron try/catch around `_isTxCompleted`, defense-in-depth check in `storeTxWebhook`, drain migration. Branch `WDK-1451-validate-tx-webhook-hash-and-fix-retry`.
- `rumble-ork-wrk` — closed (https://github.com/tetherto/rumble-ork-wrk/pull/150). Reviewer pointed out the ork is an internal HRPC service; the HTTP API is rumble-app-node. Moved validation up there. Shard guard still covers the MoonPay internal-RPC path that bypasses the HTTP layer.

Both open PRs target `dev` and are in draft.

## What landed

### rumble-data-shard-wrk
- `workers/proc.shard.data.wrk.js`
  - `storeTxWebhook` validates `transactionHash` per chain; rejects empty `transactionHash` even when `isTransactionReceipt` is set.
  - `_processTxWebhooksJob` wraps `_isTxCompleted` in try/catch; thrown chain errors now fall through to the retry policy instead of aborting the for-await.
- `workers/lib/utils/tx-hash.util.js` (new) — `isValidTxHash(blockchain, hash)` covering EVM, hex64, base58, TON.
- `migrations/mongodb/2026-05-13_drain-invalid-tx-webhooks.js` (new) — marks PENDING records with invalid hash as FAILED, supports `--dry-run`.
- Unit tests: new `tests/tx-hash.util.unit.test.js` plus added cases in `tests/proc.shard.data.wrk.unit.test.js` (throw → retry, placeholder rejection, empty receipt id rejection, gasless receipt id accept).

### rumble-app-node (new)
- `workers/lib/schemas/tx-hash.js` (new) — exports `txHashValidationRules`, a list of JSON-schema `allOf` clauses that apply a per-chain `pattern` to `transactionHash` and `transactionReceiptId` based on the request's `blockchain`. EVM (`0x` + 64 hex), bitcoin/spark/tron (64 hex), solana (base58 43–88), ton (hex or base64).
- `workers/lib/server.js` — spreads `txHashValidationRules` into the existing `allOf` arrays of both `/api/v1/notifications` and `/api/v2/notifications` route schemas.
- `tests/tx-hash-schema.unit.test.js` (new) — AJV-based unit tests confirming per-chain accept/reject behaviour.
- Test fixtures in `tests/http.node.wrk.intg.test.js` updated from `'0xHash'` / `'0xReceiptId'` placeholders to proper 0x+64hex values so the existing happy-path tests still pass under the new patterns.

### rumble-ork-wrk (dropped)
The ork-side validation PR (#150) was closed after reviewer feedback. Reasoning: `api.ork.wrk.js` is an internal HRPC service, not the HTTP API boundary that rumble-server hits. The fastify schema in rumble-app-node is the real API layer, and that's where the format check belongs. The shard guard remains as defense-in-depth for the MoonPay internal-RPC path (`rumble-app-node/workers/lib/services/moonpay.utils.js` calls `sendNotification` on the ork directly, bypassing the HTTP schema).

## Backing-store question — resolved

`tx-webhook` records live in MongoDB, not HyperDB. Rumble's `rumble-data-shard-wrk/config/common.json` sets `"dbEngine": "mongodb"`; the live collection is `wdk_data_shard_tx_webhooks` (see `workers/lib/db/mongodb/repositories/txwebhook.js`). The drain migration is correctly placed under `migrations/mongodb/`.

## What's left

1. Get reviews on both open PRs. Merge order: app-node first (closes the public door), then shard (cron try/catch + drain).
2. On staging, after both merges deploy, run:
   - `npm run migration -- 2026-05-13_drain-invalid-tx-webhooks --dry-run` to confirm only the 4 placeholders are flagged
   - `npm run migration -- 2026-05-13_drain-invalid-tx-webhooks` to mark them FAILED
3. Watch the Grafana panel for ~30 min to confirm the "could not coalesce error" rate drops to zero.
4. Optional: run the same Loki query against `env=prod` once for a sanity check that no `debug-*` hashes exist there.

## Open questions for Alex (not blocking)

- The four placeholder hashes were minted by something running on 2026-05-06 15:40 to 16:27 UTC. Nothing in this codebase emits `debug-<Date.now()>`, so the producer is in the rumble-server monolith. Worth a heads-up to whoever owns that repo so they stop using a string that looks like a tx hash for test webhooks.
- Sprint mismatch (description says Sprint 1, Asana custom field says Sprint 2) — minor.
