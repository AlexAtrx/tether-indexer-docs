# Commit trace - WDK-1196 / RW-1683 channel split

Date: 2026-06-19. All branches cut from current `dev`, one commit each, local only
(not pushed). Repos live under `/Users/alexa/Documents/repos/_tether/_INDEXER/`.

## Card 1 - data-shard

| Repo | Branch | Commit | Base (dev) |
|------|--------|--------|------------|
| wdk-data-shard-wrk | `refactor/WDK-1196-remove-channel-wallet-ownership` | `22ed36dac9aef5f9f19fe4798c337300d5056dbe` | `f1dac14` |
| rumble-data-shard-wrk | `feat/WDK-1196-channel-wallet-ownership` | `4f3164a65a17f82110524daffc86a0d716abea22` | `e7b348a` |

## Card 2 - ork

| Repo | Branch | Commit | Base (dev) |
|------|--------|--------|------------|
| wdk-ork-wrk | `refactor/WDK-1196-remove-channel-shard-routing` | `c6a544fd13bb85d13f5296064134f29cfa7c7822` | `d69f0d1` |
| rumble-ork-wrk | `feat/WDK-1196-channel-shard-routing` | `37543e302540f2c1384db7d5c54c5160ad506862` | `152aca0` |

## Card 3 - app / API / docs

| Repo | Branch | Commit | Base (dev) |
|------|--------|--------|------------|
| wdk-app-node | `refactor/WDK-1196-remove-channel-wallet-api` | `26054bf02b3b0081c8a977d06065242d66075f0c` | `dee3ea0` |
| rumble-app-node | `feat/WDK-1196-channel-wallet-api` | `9a48eecad20dbe1235af3d04a485d87c2f183e10` | `2436835` |

## Split-out (not part of the channel split)

| Repo | Branch | Commit | Base (dev) |
|------|--------|--------|------------|
| rumble-data-shard-wrk | `fix/balance-request-timeout-budget` | `e867c8d92ec83ebf7644b3d18824c57fb97a8adb` | `e7b348a` |

## Files changed per commit

### wdk-data-shard-wrk `22ed36d` (remove)
- tests/api.shard.data.wrk.intg.test.js
- tests/proc.shard.data.wrk.intg.test.js
- tests/unit/api.shard.data.wrk.unit.test.js
- tests/unit/proc.shard.data.wrk.unit.test.js
- workers/api.shard.data.wrk.js
- workers/lib/blockchain.svc.js
- workers/lib/db/base/repositories/wallets.js
- workers/lib/db/hyperdb/repositories/wallets.js
- workers/lib/db/mongodb/repositories/wallets.js
- workers/proc.shard.data.wrk.js

### rumble-data-shard-wrk `4f3164a` (own)
- tests/api.shard.data.wrk.unit.test.js
- tests/proc.shard.data.wrk.unit.test.js
- workers/api.shard.data.wrk.js
- workers/lib/db/hyperdb/repositories/wallets.js
- workers/lib/db/mongodb/repositories/wallets.js
- workers/proc.shard.data.wrk.js

### wdk-ork-wrk `c6a544f` (remove)
- tests/api.ork.wrk.intg.test.js
- tests/autobase.manager.intg.test.js
- tests/data.shard.util.unit.test.js
- workers/api.ork.wrk.js
- workers/lib/constants.js
- workers/lib/data.shard.util.js

### rumble-ork-wrk `37543e3` (own)
- tests/unit/channel-wallet-name.unit.test.js
- tests/unit/data.shard.util.unit.test.js (new)
- workers/api.ork.wrk.js
- workers/lib/data.shard.util.js (new)

### wdk-app-node `26054bf` (remove)
- config/common.json.example
- workers/lib/middlewares/response.validator.js
- workers/lib/schemas/common.js
- workers/lib/server.js
- workers/lib/services/ork.js
- workers/lib/utils/errorsCodes.js

### rumble-app-node `9a48eec` (own)
- tests/channel-wallet-schemas.unit.test.js (new)
- workers/http.node.wrk.js
- workers/lib/server.js
- workers/lib/services/ork.js
- workers/lib/utils/errorsCodes.js

### rumble-data-shard-wrk `e867c8d` (balance budget, split-out)
- workers/api.shard.data.wrk.js
