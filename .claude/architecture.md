# Architecture

## Request paths

**Wallet/user (authenticated):**
```
user → wdk-app-node (HTTP)
     → wdk-ork-wrk (routing)
     → wdk-data-shard-wrk (business logic / canonical storage)
     → wdk-indexer-wrk-{chain} (per-chain indexer RPC)
     → chain RPC / Mongo
```

**Public indexer (API-key):**
```
client → wdk-indexer-app-node (HTTP)
       → chain indexer topic RPC (`{blockchain}:{token}`)
```

## Proc / API split

Every service has two worker types:

- **Proc worker** — writer. Runs sync jobs, owns mutations, prints a unique `Proc RPC Key` at boot.
- **API worker** — reader. Takes queries. Requires the matching Proc's RPC key via `--proc-rpc <KEY>`.

Handshake is: Proc prints the key → operator feeds it to API on start. That is how API authenticates back to its Proc.

## Hyperswarm transport

P2P RPC over Hyperswarm. All services **must share**:

- `topicConf.capability` — handshake secret
- `topicConf.crypto.key` — encryption key

Mismatch ⇒ services start successfully but never discover each other (silent failure). Topic names you will see: `@wdk/data-shard`, `@wdk/ork`, `{blockchain}:{token}` for per-chain indexers.

## Transfer ingestion (two paths, ambiguous)

**Path A — shard polling:** `syncWalletTransfers` job pulls from indexers.
- Code-default cron: `*/5 * * * *`, timeout 10 min.
- Example override: `*/30 * * * * *`.

**Path B — Redis streams:**
1. `wdk-indexer-wrk-base/workers/proc.indexer.wrk.js` `pipe.xadd` → `@wdk/transactions:{chain}:{token}` (default `publishBatchSize = 100`).
2. `wdk-indexer-processor-wrk` consumes that and writes → `@wdk/transactions:shard-{shardGroup}`.
3. `wdk-data-shard-wrk/workers/proc.shard.data.wrk.js` consumes shard stream (consumer group, blocking reads, claim pending, trim old).

Payload is CSV `raw` (not JSON). `TRANSACTION_MSG_TYPES.NEW_TRANSACTION = 'new_transaction'`.

No canonical path is enforced. Freshness bugs are hard to reason about because both run.

## Storage choices (configurable per service)

- Chain indexers + shards: `dbEngine: hyperdb | mongodb`.
- Ork + processor lookup: `lookupEngine: autobase | mongodb`.

## Schema layering

- `@tetherto/wdk-indexer-wrk-base` → all chain indexer repos import this.
- `@tetherto/wdk-app-node` → extended by `wdk-indexer-app-node` and `rumble-app-node`.
- `@tetherto/wdk-data-shard-wrk` → overlaid by `rumble-data-shard-wrk` (adds notifications/webhooks).
- `@tetherto/wdk-ork-wrk` → overlaid by `rumble-ork-wrk` (adds LRU idempotency for swap/topup/cashout).

## Jobs & schedules (code defaults)

| Job | Repo | Cron | Timeout |
|---|---|---|---|
| `syncBalances` | `wdk-data-shard-wrk` | `0 */6 * * *` | 1_200_000 ms (20 min) |
| `syncWalletTransfers` | `wdk-data-shard-wrk` | `*/5 * * * *` | 600_000 ms (10 min) |
| `revokeInactiveKeysInterval` | `wdk-indexer-app-node` | `0 2 * * *` | (inactivity threshold 30d) |
| tx-webhook | `rumble-data-shard-wrk` | `*/10 * * * * *` (every 10s) | — |

Example overrides in `proc.shard.data.json.example`: `syncBalances 0 0 * * *`, `syncWalletTransfers */30 * * * * *`.

## Whitelisted chains (public indexer)

`ethereum, sepolia, plasma, avalanche, arbitrum, polygon, tron, ton, solana, bitcoin, spark`.
Note: this list is broader than the set of chain worker repos checked in.

## Diagrams on disk

- `_tether-indexer-docs/app-structure-and-diagrams/wdk-indexer-local-diagram.mmd`
- `_tether-indexer-docs/analysis-2026-01-14/wdk-indexer-architecture-2026-01-14.{mmd,svg}`
- `_tether-indexer-docs/analysis-2026-01-14/wdk-data-flow-2026-01-14.{mmd,svg}`
- `_tether-indexer-docs/analysis-2026-01-14/wdk-component-dependencies-2026-01-14.{mmd,svg}`
- `_tether-indexer-docs/analysis-2026-01-14/architecture-viewer.html`
