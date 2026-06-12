# Local code audit - WDK-1196 / RW-1683

Audit date: 2026-06-09.

Local repo baseline:

- `wdk-app-node`: `fix/tip-jar-first-toggle-rpc-client-closed-RW-1832` at `ecb5368`
- `rumble-app-node`: `fix/rant-transfers-not-displayed-in-chat` at `884746f`
- `wdk-data-shard-wrk`: `dev` at `49e4444`
- `rumble-data-shard-wrk`: `fix/transfer-notification-copy` at `88dfb4a`
- `wdk-ork-wrk`: `fix/rant-transfers-not-displayed-in-chat` at `facd751`
- `rumble-ork-wrk`: `fix/rant-transfers-not-displayed-in-chat` at `c287ff3`

## App layer

- `wdk-app-node/workers/lib/schemas/common.js:89` has `walletEnum = ['user', 'channel', 'unrelated']`; `:99-105` defines `walletTypes` from that enum.
- `wdk-app-node/workers/lib/server.js:471-507` lets `POST /api/v1/wallets` accept `channelId` and requires it when `type = channel`.
- `wdk-app-node/workers/lib/server.js:603-621`, `:693-721`, `:741-767`, and `:823-848` expose `walletTypes` on user balance/transfer routes.
- `wdk-app-node/workers/lib/services/ork.js:192-199` forwards `walletTypes` to ork.
- `wdk-app-node/workers/lib/middlewares/response.validator.js:121-134` includes `channelId` in wallet responses.
- `wdk-app-node/workers/lib/utils/errorsCodes.js:13-14` owns `ERR_USER_TIP_JAR_NOT_FOUND` and `ERR_CHANNEL_TIP_JAR_NOT_FOUND`.
- `wdk-app-node/config/common.json.example:3` contains Rumble UI `staticRootPath`.
- `rumble-app-node/workers/http.node.wrk.js:50-61` calls `super._setupRoutes()` and then adds Rumble routes; it only overrides the `POST /api/v1/wallets` pre-handler for channel ownership.
- `rumble-app-node/workers/lib/server.js:51-85` owns GET user/channel tip-jar routes; `:835-862` owns channel tip-jar rename.
- `rumble-app-node/workers/lib/services/ork.js:47-67` forwards tip-jar and rename RPCs.

Interpretation: Rumble already owns tip-jar endpoints, but still inherits the
base wallet creation/balance/transfer schema surface from WDK.

## Data-shard layer

- `wdk-data-shard-wrk/workers/proc.shard.data.wrk.js:226-392` creates wallets. It has channel duplicate rules at `:243-247`, missing `channelId` validation at `:258-263`, and persists `channelId` at `:379`.
- `wdk-data-shard-wrk/workers/api.shard.data.wrk.js:214-218`, `:315-351`, `:515-548`, and `:661-683` implement `walletTypes` filtering for balance and transfer reads.
- `wdk-data-shard-wrk/workers/lib/blockchain.svc.js:358-365` filters balance wallets by `walletTypes`.
- `wdk-data-shard-wrk/workers/lib/db/base/repositories/wallets.js:12` and `:80-86` define `channelId` and `getActiveChannelWallet`.
- `wdk-data-shard-wrk/workers/lib/db/mongodb/repositories/wallets.js:47-50` creates the channel index; `:197-207` queries by channel.
- `wdk-data-shard-wrk/workers/lib/db/hyperdb/build.js:18` adds optional `channelId`; `:210-218` adds `active-wallets-by-channel-id`.
- `wdk-data-shard-wrk/workers/lib/db/hyperdb/helpers.js:8-10` maps the channel index.
- `rumble-data-shard-wrk/workers/api.shard.data.wrk.js:41-67` owns user/channel tip-jar reads and channel rename forwarding.
- `rumble-data-shard-wrk/workers/proc.shard.data.wrk.js:201-225` syncs Rumble jars after wallet create; `:227-240` syncs jars after wallet update; `:246-260` updates channel wallet name by `channelId`.
- `rumble-data-shard-wrk/workers/lib/db/mongodb/repositories/wallets.js:3-17` and `workers/lib/db/hyperdb/repositories/wallets.js:3-10` extend WDK wallet repositories but only add created/updated indexes.
- `rumble-data-shard-wrk/workers/proc.shard.data.wrk.js:490-493` and `workers/lib/utils/rumble.server.util.js:51-63` show rant webhook behavior is already Rumble-only.

Interpretation: the hardest migration is making Rumble data-shard own channel
wallet storage/query semantics before WDK removes them.

## Ork layer

- `wdk-ork-wrk/workers/lib/constants.js:3-7` defines `LOOKUP_TYPES.CHANNELS`.
- `wdk-ork-wrk/workers/lib/data.shard.util.js:167-192` implements `storeChannelShard` and `resolveChannelShard`.
- `wdk-ork-wrk/workers/api.ork.wrk.js:431-452` stores wallet shard lookups and stores a channel shard lookup when a created wallet has `channelId`.
- `rumble-ork-wrk/workers/api.ork.wrk.js:41-53` owns Rumble tip-jar RPC methods, but uses inherited `resolveChannelShard` for channel tip-jar and channel wallet rename routing.
- `rumble-ork-wrk/workers/api.ork.wrk.js:465-476` registers Rumble RPC actions including `getUserTipJar`, `getChannelTipJar`, and `updateChannelWalletName`.
- `rumble-ork-wrk/workers/api.ork.wrk.js:419-450` and `workers/lib/constants.js:6-22` show Rumble-only notification rant/tip webhook handling.

Interpretation: channel lookup helpers must move into `rumble-ork-wrk` before
WDK removes them.
