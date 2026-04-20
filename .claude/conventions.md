# Conventions & rules

## HyperDB schemas are append-only

**Never insert a field in the middle of an existing schema.** Always append at the end.

```js
// ❌ WRONG - breaks HyperDB
schema.field('id')
schema.field('newField')     // inserted in middle
schema.field('address')

// ✅ CORRECT
schema.field('id')
schema.field('address')
schema.field('newField')     // appended
```

Rebuild via `npm run db:build` in `wdk-indexer-wrk-base/`.

## Version-bump policy

Any schema / shared-lib change requires:

1. Bump `version` in `package.json`.
2. Update dependent repos:
   - Change in `wdk-indexer-wrk-base` → update every `wdk-indexer-wrk-*` chain repo.
   - Change in `wdk-data-shard-wrk` → update `rumble-data-shard-wrk`.
   - Change in `wdk-app-node` → update `wdk-indexer-app-node` and `rumble-app-node`.
   - Change in `wdk-ork-wrk` → update `rumble-ork-wrk`.
3. Re-run `npm install` in each dependent repo.
4. Breaking changes ⇒ ship a migration script.

## Rumble mirroring

Any change to `wdk-*` base repos must be manually mirrored into the matching `rumble-*` overlay. There is no automated sync.

## Shared Hyperswarm secrets

`config/common.json` `topicConf.capability` and `topicConf.crypto.key` **must be identical across every service** in a deployment. Mismatch = silent discovery failure.

## Linting & testing

- Lint: standard.js (`npm run lint`, `npm run lint:fix`).
- Tests: `npm test`, `npm run test:coverage`. Where available: `test:unit`, `test:integration`, `test:e2e`.
- Migrations: `npm run db:migration` (EVM indexer has this; pattern may exist in others).

## Worker CLI surface

Consistent across workers:

```
node worker.js --wtype <type> --env <env> --rack <rack> [--chain <chain>] [--proc-rpc <KEY>] [--port <n>]
```

- `--wtype`: worker type, e.g. `wrk-data-shard-proc`, `wrk-ork-api`, `wrk-evm-indexer-proc`, `wrk-erc20-indexer-proc`.
- `--rack`: free-form rack identifier (affects logging and sometimes storage path).
- `--proc-rpc`: required on any API worker.

## Configs live in `config/`

- `common.json` — shared secrets (topic, capability, crypto key).
- `facs/db-mongo.config.json` — Mongo replica-set URL.
- `<chain>.json` (indexers only) — RPC URLs, batch size, sync cron.

Recommended sync settings per chain (block-time tuned):
- Ethereum (12s blocks): `txBatchSize: 20`, `syncTx: */30 * * * * *`
- Arbitrum (0.3s blocks): `txBatchSize: 40`, `syncTx: */5 * * * * *`
- Polygon (2s blocks): `txBatchSize: 30`, `syncTx: */15 * * * * *`

## External-output formatting (user rule)

Never use em dashes in anything that gets posted externally: GitHub PRs/issues/comments, git commit messages, Slack, webhooks. Use commas, semicolons, parentheses, or separate sentences. Em dashes are fine in conversation with the user inside Claude Code.

## Ork has no auth

The ork layer has no authentication. Keep it on internal networks only.
