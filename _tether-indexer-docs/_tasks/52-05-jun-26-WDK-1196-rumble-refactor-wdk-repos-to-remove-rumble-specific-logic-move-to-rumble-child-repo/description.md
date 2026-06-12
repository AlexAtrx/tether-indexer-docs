TO BE SPLIT - Blocked

**TODO: Before starting this card, evaluate the tasks needed and split this card in multiple high prio cards (maybe 3 to 5)**

Refactor all `wdk-*` repositories to remove Rumble-specific functionality and ensure:

- `wdk-*` remains generic and reusable.
- Rumble-specific behavior lives only in the Rumble child repositories:
  - `rumble-app-node`
  - `rumble-data-shard-wrk`
  - `rumble-ork-wrk`

Rumble must retain equivalent functionality after the split.

## Objective

Move the following from `wdk-*` → Rumble child repos:

- Wallet type `"channel"` (including `channelId`, channel–shard lookups)
- Tip jar (user + channel tip jar APIs & error codes)
- Any Rumble-specific config or documentation

# Scope of Changes

## 1️⃣ wdk-app-node

**Remove / Guard**

- `workers/lib/server.js`
  - Remove `channelId` from `POST /api/v1/wallets` body schema
  - Remove `walletTypes` query param from:
    - `GET /api/v1/users/:userId/balance`
    - `GET /api/v1/users/:userId/token-transfers`
- `workers/lib/schemas/common.js`
  - Remove `channel` from `walletEnum`
  - Remove `walletTypes` schema (if only used for channel filtering)
- `workers/lib/services/ork.js`
  - Remove `walletTypes` handling in balance calls
- `workers/lib/middlewares/response.validator.js`
  - Remove `channelId` from response schemas
- `workers/lib/utils/errorsCodes.js`
  - Remove:
    - `ERR_USER_TIP_JAR_NOT_FOUND`
    - `ERR_CHANNEL_TIP_JAR_NOT_FOUND`
- `config/common.json.example`
  - Replace/remove Rumble-specific `staticRootPath` (e.g. rumble-app-ui/build)

## 2️⃣ wdk-data-shard-wrk

**Remove**

- Channel wallet type (`type: 'channel'`)
- `channelId` validation & duplicate checks
- `ERR_CHANNEL_ID_INVALID`
- `getActiveChannelWallet`
- Channel-based filtering (`walletTypes`)
- Channel DB indexes & schema fields
- Channel-related HyperDB structures
- Channel-related tests

**Files Impacted**

- `workers/proc.shard.data.wrk.js`
- `workers/api.shard.data.wrk.js`
- `workers/lib/blockchain.svc.js`
- `workers/lib/db/base/repositories/wallets.js`
- `workers/lib/db/mongodb/repositories/wallets.js`
- `workers/lib/db/hyperdb/...`
- All related test files

## 3️⃣ wdk-ork-wrk

**Remove**

- `storeChannelShard`
- `resolveChannelShard`
- `CHANNELS` from `LOOKUP_TYPES`
- Tip jar RPC registration
- Channel lookup tests

**Files Impacted**

- `workers/api.ork.wrk.js`
- `workers/lib/data.shard.util.js`
- `workers/lib/constants.js`
- Related test files

## 4️⃣ Rumble Child Repos

Implement equivalent functionality in:

- `rumble-app-node`
- `rumble-data-shard-wrk`
- `rumble-ork-wrk`

Must support:

- Channel wallets
- channelId lookups
- Tip jar (user + channel)
- Rants (if applicable)
- Channel shard mapping
- Channel-specific indexes

All Rumble tests must pass independently of `wdk-*`.

## 5️⃣ Documentation Updates

Update API / Swagger / route schemas:

**In wdk:**

- Remove:
  - Wallet type `channel`
  - `channelId`
  - `walletTypes`
  - Tip jar endpoints
- Add note: Channel wallets and tip jar functionality are provided by Rumble child applications.

**In Rumble:**

- Document channel wallets
- Document tip jar APIs
- Document rants API (if applicable)

# Acceptance Criteria

- `wdk-app-node` contains no channel wallet schema, tip jar error codes, or Rumble-specific config.
- `wdk-data-shard-wrk` has no channel wallet type, channelId, channel index, or related DB artifacts.
- `wdk-ork-wrk` has no channel shard storage/resolution or tip jar RPC.
- Rumble child repos fully implement channel wallets + tip jar (and rants if applicable).
- All updated tests pass in both wdk and Rumble.
- API/Swagger docs updated accordingly.

## Risk Level

High – touches schemas, DB indexes, HyperDB specs, and cross-repo integration.
