# Repo inventory

All paths are relative to the workspace root. All repos are clones of
`github.com/tetherto/<name>` (private org; user has access via `gh`).

## Gateway / HTTP surfaces

| Repo | Role |
|---|---|
| `wdk-indexer-app-node` | Public API-key HTTP surface for direct address-based indexer queries. Register + `/api/v1/request-api-key`, direct + batch `/token-transfers` and `/token-balances`, Swagger at `/docs`. |
| `wdk-app-node` | Authenticated wallet/user HTTP surface. Routes under `/api/v1/wallets/...`, `/api/v1/users/...`, `/api/v1/balance/trend`. |
| `rumble-app-node` | Rumble extension of `wdk-app-node`: device, MoonPay, notifications, swaps, logs, admin transfer routes. |

## Gateway / RPC mesh

| Repo | Role |
|---|---|
| `wdk-ork-wrk` | Gateway/router. Resolves user/wallet/address → shard lookups via Autobase or Mongo. |
| `rumble-ork-wrk` | Rumble extension: LRU idempotency for `SWAP_STARTED`, `TOPUP_STARTED`, `CASHOUT_STARTED`. |

## Data shards (canonical wallet/balance/transfer storage)

| Repo | Role |
|---|---|
| `wdk-data-shard-wrk` | Canonical wallet, balance, user-data, wallet-transfer storage. Proc/API split. Supports polling sync and Redis shard-stream. |
| `rumble-data-shard-wrk` | Rumble overlay on shard: notifications/webhooks, LRU transfer dedupe, tx-webhook cron. |

## Indexer processor (bridge)

| Repo | Role |
|---|---|
| `wdk-indexer-processor-wrk` | Consumes `@wdk/transactions:{chain}:{token}` and emits `@wdk/transactions:shard-{shardGroup}`. (Present on disk; older docs still reference it as external.) |

## Chain indexers

All extend `@tetherto/wdk-indexer-wrk-base` (shared scaffold, Hyperswarm plumbing, HyperDB codecs).

| Repo | Chain |
|---|---|
| `wdk-indexer-wrk-base` | Base lib. Circuit breaker (failureThreshold 3, resetTimeout 30000, successThreshold 2), deterministic provider selection, optional Prometheus hooks. |
| `wdk-indexer-wrk-btc` | Bitcoin. Persists `metadata.inputs`. Balance via `scantxoutset` (maps busy → `ERR_SCANTXOUTSET_BUSY`). |
| `wdk-indexer-wrk-evm` | Ethereum, Arbitrum, Polygon, Avalanche, Sepolia, Plasma + ERC-20 tokens. |
| `wdk-indexer-wrk-solana` | Solana + SPL. Proc deletes `sync-tx` on startup (intentionally disabled). |
| `wdk-indexer-wrk-ton` | TON. |
| `wdk-indexer-wrk-tron` | Tron. |
| `wdk-indexer-wrk-spark` | Spark. |

## Wallet libraries (SDK side, not indexer runtime)

| Repo | Purpose |
|---|---|
| `wdk` | Multi-wallet manager (registers different blockchain wallets dynamically). |
| `wdk-wallet` | Base BIP-32 wallet manager. |
| `wdk-wallet-btc`, `-evm`, `-solana`, `-spark`, `-ton`, `-tron`, `-tron-gasfree` | Per-chain BIP-32 wallets. |
| `wdk-react-native-core` | Core for React Native wallets: wallet management, balance fetching, worklet ops. |
| `wdk-protocol-fiat-moonpay` | MoonPay protocol adapter for `@tetherto/wdk-wallet` accounts. |
| `wdk-protocol-swap-velora-evm` | Velora swap protocol for EVM + ERC-4337. |

## Other / misc

| Repo | Purpose |
|---|---|
| `qvac` | qvac runtime/bundle (no package.json at root). |
| `qvac-registry-vcpkg` | qvac vcpkg registry. |
| `rumble-promo-wrk` | Rumble promo codes worker. |
| `rumble-wallet-lib-passkey` | React Native passkey. |
| `rumble-docs`, `wdk-docs` | Public docs. |

## Docs

`_tether-indexer-docs/` holds engineering truth, tasks, diagrams.
- `___TRUTH.md` is the authoritative running summary.
- `_tasks/` is organised by date prefix (e.g. `17-apr-26-decimals-issue`).
- `analysis-2026-01-14/` has architecture / data-flow / component-dependencies mermaid + SVG.
- `app_setup/` has quick-start and local-run procedures.
