'use strict'

const DataShardUtil = require('@tetherto/wdk-ork-wrk/workers/lib/data.shard.util')

// Channel -> shard routing is Rumble-specific (channel wallets / tip jars), so
// it lives here rather than in the generic wdk-ork-wrk lookup util.
const CHANNELS = 'channels'

class RumbleDataShardUtil extends DataShardUtil {
  /**
   * Stores the channel -> shard lookup for a created channel wallet.
   * @param {string} channelId
   * @param {string} shardId
   * @param {string} userId
   * @returns {Promise<void>}
   */
  async storeChannelShard (channelId, shardId, userId) {
    await this.resolveRpc(shardId) // ensure rpc key is resolved
    await this.ctx.lookupStorage.saveLookup(CHANNELS, channelId, shardId, userId)
  }

  /**
   * Resolves the data shard that owns a given channelId.
   * @param {string} channelId
   * @returns {Promise<{ id: string, rpcKey: string }>}
   */
  async resolveChannelShard (channelId) {
    const ckey = `channel-shard:${channelId}`
    const cval = this.ctx.lru_lookup.get(ckey)
    if (cval) {
      return cval
    }

    const id = await this.ctx.lookupStorage.getLookup(CHANNELS, channelId)
    if (!id) {
      throw new Error('ERR_DATA_SHARD_LOOKUP_EMPTY')
    }
    const rpcKey = await this.resolveRpc(id)
    const res = { id, rpcKey }
    this.ctx.lru_lookup.set(ckey, res)
    return res
  }
}

module.exports = RumbleDataShardUtil
