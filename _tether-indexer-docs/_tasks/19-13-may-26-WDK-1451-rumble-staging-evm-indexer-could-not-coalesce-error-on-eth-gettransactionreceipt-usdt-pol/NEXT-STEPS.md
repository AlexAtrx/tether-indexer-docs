# Next steps for WDK-1451 — EVM indexer "could not coalesce error" on eth_getTransactionReceipt

**Ticket:** https://app.asana.com/1/45238840754660/project/1210540875949204/task/1214766982648102

## What we know
- Staging service `wrk-erc20-indexer-api` for USDT POL on host `walletstg1` (provider: luganodes) is calling `eth_getTransactionReceipt` with the literal string `"debug-1778084251656"` instead of a 0x-prefixed hash.
- The RPC rightly rejects it with code `-32602` ("invalid argument 0: json: cannot unmarshal hex string without 0x prefix into Go value of type common.Hash").
- The ethers error bubbles up as "could not coalesce error" from `makeError`/`JsonRpcProvider.getRpcError`.
- The `1778084251656` is a unix-ms timestamp ≈ 2026-04-13T01:37Z, so something prefixed `debug-` + `Date.now()` and put it on the receipt-fetch path.
- No user comments yet; only Francesco Canessa created the ticket today and assigned it to Alex.

## Evidence captured here
- 0 images
- 0 user comments (3 system events recorded in `comments.md`)
- `description.md`: ticket text with RPC error, ethers stack snippet, and Grafana link.
- `logs-summary.md`: aggregated findings over 1000 Loki entries (1.68h slice) — full export at `Explore-logs-2026-05-13 20_48_02.json`.

## What the logs confirm (new)
- **Exactly 4 stuck placeholder hashes**, all minted on **2026-05-06 15:40–16:27 UTC** (~46 min batch), retrying ever since.
- USDT-POL-only, luganodes-only, walletstg1-only, both shard workers w-0-0 and w-0-1 affected.
- ~10 errors/min in the slice → ~600/hour cumulative across the 4 hashes.
- User-code frame is not in the captured stack — only ethers internals. Producer is not visible in logs; must be found in source.
- Service install path: `/srv/data/staging/wdk-indexer-wrk-evm/`, ethers v6.14.4.

## What's still missing (from `missing-context.md`)
- Code origin of `debug-<timestamp>` (grep job in `rumble-*` / `wdk-*` repos).
- Backing store of the receipt-fetch queue (so the 4 stuck records can be inspected and drained).
- Drain plan for staging — Rumble runbook or just kill-and-redeploy.
- Prod sanity check (same Loki query against `env="prod"`).
- Sprint mismatch (description says Sprint 1, custom field says Sprint 2).

## Before starting work
1. Grep `rumble-*` (Rumble-only, per repo split rule) and `wdk-*` repos for `` `debug-${Date.now()}` `` / `'debug-' +` / `"debug-"` prefixes — and for anything that calls `enqueue` / `pushReceipt` / equivalent with a freshly generated tx hash. Producer is whoever ran on 2026-05-06 15:40–16:27 UTC and enqueued exactly 4 jobs.
2. Add a hash-format guard (`/^0x[0-9a-fA-F]{64}$/`) at the EVM indexer's receipt-fetch entry point so future bad inputs are rejected before reaching luganodes.
3. Find where the 4 stuck items live (HyperDB? worker state on walletstg1?) and propose a drain step.
4. Ask Alex about the open items in `missing-context.md` only after the code grep — most of them are answerable in code.
