'use strict'

const { test } = require('brittle')
const sinon = require('sinon')
const RumbleDataShardUtil = require('../../workers/lib/data.shard.util')

function makeCtx () {
  return {
    status: {},
    lru_lookup: { get: sinon.stub(), set: sinon.stub() },
    lookupStorage: {
      saveLookup: sinon.stub(),
      getLookup: sinon.stub()
    }
  }
}

test('storeChannelShard saves a channels lookup', async t => {
  const util = new RumbleDataShardUtil(makeCtx())
  sinon.stub(util, 'resolveRpc').resolves('rpc-1')

  await util.storeChannelShard('c1', 'shard-1', 'user-1')

  t.ok(util.ctx.lookupStorage.saveLookup.calledOnceWithExactly('channels', 'c1', 'shard-1', 'user-1'))
})

test('resolveChannelShard: cache hit, miss, and error', async t => {
  const ctx = makeCtx()
  ctx.lru_lookup.get.withArgs('channel-shard:c').returns({ id: 'shard-1', rpcKey: 'rpc-1' })
  let util = new RumbleDataShardUtil(ctx)

  // cache hit
  const hit = await util.resolveChannelShard('c')
  t.is(hit.id, 'shard-1')
  t.is(hit.rpcKey, 'rpc-1')

  // miss -> resolve from lookup storage + rpc
  ctx.lru_lookup.get.returns(undefined)
  ctx.lookupStorage.getLookup.resolves('shard-1')
  util = new RumbleDataShardUtil(ctx)
  sinon.stub(util, 'resolveRpc').resolves('rpc-1')
  const miss = await util.resolveChannelShard('c2')
  t.is(miss.id, 'shard-1')
  t.is(miss.rpcKey, 'rpc-1')

  // empty lookup -> error
  ctx.lookupStorage.getLookup.resolves(undefined)
  await t.exception(() => util.resolveChannelShard('c3'), /ERR_DATA_SHARD_LOOKUP_EMPTY/)
})
