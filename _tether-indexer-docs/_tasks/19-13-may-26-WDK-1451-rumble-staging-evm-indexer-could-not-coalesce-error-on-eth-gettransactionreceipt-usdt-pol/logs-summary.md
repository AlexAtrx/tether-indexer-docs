# Logs summary — `Explore-logs-2026-05-13 20_48_02.json`

Loki export from the Grafana link in the description. 1000 entries, exported 2026-05-13 ~20:48 local.

## Window
- min: **2026-05-12T22:42:53.176Z**
- max: **2026-05-13T00:23:40.845Z**
- span: **6047.7s** (~1h41m) → ~10 errors / minute

## What's identical across all 1000 entries
- `msg`: `failed to get transaction receipt, Provider: luganodes`
- `err.shortMessage`: `could not coalesce error`
- `err.error.code`: `-32602`
- `err.error.message`: `invalid argument 0: json: cannot unmarshal hex string without 0x prefix into Go value of type common.Hash`
- `err.payload.method`: `eth_getTransactionReceipt`
- `fields.env`: `staging`
- `fields.host` / `hostname`: `walletstg1`
- Provider: **luganodes only** — no other RPC provider seen
- Token / chain: **USDT POL only** — no other indexer worker seen in this slice

## Stuck hashes (exactly 4)
All 4 are `debug-<unix-ms-timestamp>`, minted in a **46-minute burst on 2026-05-06**:

| Hash | Count in slice | Encoded timestamp |
|---|---:|---|
| `debug-1778082053217` | 253 | 2026-05-06T15:40:53Z |
| `debug-1778082230306` | 249 | 2026-05-06T15:43:50Z |
| `debug-1778084251656` | 237 | 2026-05-06T16:17:31Z |
| `debug-1778084846161` | 261 | 2026-05-06T16:27:26Z |

→ Looks like a one-off batch of 4 placeholder hashes that got enqueued on 2026-05-06 and have been retrying continuously for **~7 days** by the time the ticket was filed.

## Workers
Both indexer-api workers are pulling these same 4 items:

| Worker (`name`) | service_name | pm2_app | Count |
|---|---|---|---:|
| `wrk-erc20-indexer-api-w-0-0-usdt-pol-e0fd08a7-c0ac-4b9b-a3f5-e51b6dbd7374` | idx-usdt-pol-api-w-0-0 | idx-usdt-pol-api-w-0-0 | 622 |
| `wrk-erc20-indexer-api-w-0-1-usdt-pol-521c6a0c-1781-4367-9c08-467307038475` | idx-usdt-pol-api-w-0-1 | idx-usdt-pol-api-w-0-1 | 378 |

Two workers, same backlog → shared retry queue (consistent with the shard model).

## Trace IDs
Diverse — top traceIds only have 5–6 hits each across 1000 entries. So each error log line is a **separate retry attempt**, not a tight in-process loop. Re-enqueue / re-scheduling.

## Stack origin
Stack top frame from every entry:
```
at makeError (/srv/data/staging/wdk-indexer-wrk-evm/node_modules/ethers/lib.commonjs/utils/errors.js:137:21)
at JsonRpcProvider.getRpcError (/srv/data/staging/wdk-indexer-wrk-evm/node_modules/ethers/lib.commonjs/providers/provider-jsonrpc.js:749:41)
at /srv/data/staging/wdk-indexer-wrk-evm/node_modules/ethers/lib.commonjs/providers/provider-jsonrpc.js:302:45
at process.processTicksAndRejections (node:internal/process/task_queues:95:5)
```
- Service install path: `/srv/data/staging/wdk-indexer-wrk-evm/`
- Ethers version: **6.14.4**
- The user-code frame is not in the stack — ethers swallowed it. We can't tell from this stack which call site invoked `getTransactionReceipt`. We'll need to find that in the source.

## What this changes vs. the original description
- Confirms the bug is **not a single-call glitch**: it's a persistent 4-item backlog churning since 2026-05-06.
- Confirms it's USDT-POL-only / luganodes-only / staging-only in this window (the Loki filter didn't narrow it; the data did).
- Confirms both shard workers are affected, not just one.
- Narrows the producer hunt to whatever code ran ~2026-05-06 15:40–16:27 UTC and enqueued exactly 4 receipt-fetch jobs with placeholder hashes.
