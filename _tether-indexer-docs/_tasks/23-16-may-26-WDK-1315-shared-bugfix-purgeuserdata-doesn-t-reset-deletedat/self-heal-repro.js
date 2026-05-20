'use strict'

// Standalone repro of the self-heal logic added to _validateWalletExistence.
// Boots the AutobaseLookupStorage directly (no worker / workspace deps) and
// simulates the validation path before & after the patch.

const path = require('path')
const fs = require('fs')
const os = require('os')
const Corestore = require('corestore')
const AutobaseLookupStorage = require('../workers/lib/db/autobase/lookup.storage')
const { LOOKUP_TYPES } = require('../workers/lib/constants')

const TMP = fs.mkdtempSync(path.join(os.tmpdir(), 'self-heal-repro-'))

// Replicates the relevant logic from api.ork.wrk.js#_validateWalletExistence
// for a single address. Two flavors: pre-patch and post-patch.
async function preValidate (storage, address, excludeWalletId = null) {
  const existing = await storage.getWalletIdByAddress(address)
  if (existing && existing !== excludeWalletId) {
    throw new Error('ERR_ADDRESS_ALREADY_EXISTS')
  }
}

async function postValidate (storage, address, excludeWalletId = null) {
  const existing = await storage.getWalletIdByAddress(address)
  if (!existing || existing === excludeWalletId) return
  const walletLookup = await storage.getLookup(LOOKUP_TYPES.WALLETS, existing)
  if (!walletLookup) {
    await storage.delWalletIdLookup(existing)
    return
  }
  throw new Error('ERR_ADDRESS_ALREADY_EXISTS')
}

function record (results, label, ok, detail = '') {
  results.push({ label, ok, detail })
  console.log(`  ${ok ? 'PASS' : 'FAIL'} ${label}${detail ? ' — ' + detail : ''}`)
}

async function main () {
  const store = new Corestore(TMP)
  await store.ready()
  const storage = new AutobaseLookupStorage({ store })
  await storage.ready()
  await storage.waitWriteReady(10000)

  const results = []

  console.log('\n=== Scenario 1: live mapping (real wallet exists) ===')
  {
    const userId = 'u1'
    const walletId = 'w1'
    const addr = '0x1'
    await storage.saveLookup(LOOKUP_TYPES.WALLETS, walletId, 'shard1', userId)
    await storage.saveWalletIdLookup(addr, walletId)

    let preThrew = false
    try { await preValidate(storage, addr) } catch (e) { preThrew = e.message === 'ERR_ADDRESS_ALREADY_EXISTS' }
    record(results, 'pre-patch throws for live mapping', preThrew)

    let postThrew = false
    try { await postValidate(storage, addr) } catch (e) { postThrew = e.message === 'ERR_ADDRESS_ALREADY_EXISTS' }
    record(results, 'post-patch still throws for live mapping', postThrew)

    record(results,
      'live mapping not collateral-damaged',
      (await storage.getWalletIdByAddress(addr)) === walletId,
      `addr → ${await storage.getWalletIdByAddress(addr)}`
    )
  }

  console.log('\n=== Scenario 2: orphaned mapping (no WALLETS lookup) ===')
  {
    const orphanWalletId = 'w-orphan'
    const addr = '0x-orphan'

    // Seed the orphan: address mapping exists, but no (WALLETS, walletId) row.
    await storage.saveWalletIdLookup(addr, orphanWalletId)

    record(results,
      'orphan present before validation',
      (await storage.getWalletIdByAddress(addr)) === orphanWalletId,
      `addr → ${await storage.getWalletIdByAddress(addr)}`
    )

    let preThrew = false
    try { await preValidate(storage, addr) } catch (e) { preThrew = e.message === 'ERR_ADDRESS_ALREADY_EXISTS' }
    record(results, 'pre-patch INCORRECTLY throws on orphan (reproduces the bug)', preThrew)

    let postThrew = false
    try { await postValidate(storage, addr) } catch (e) { postThrew = e.message === 'ERR_ADDRESS_ALREADY_EXISTS' }
    record(results, 'post-patch does NOT throw on orphan', !postThrew)

    await storage.base.update()
    record(results,
      'post-patch cleared the orphan',
      (await storage.getWalletIdByAddress(addr)) === null,
      `addr → ${await storage.getWalletIdByAddress(addr)}`
    )
  }

  console.log('\n=== Scenario 3: excludeWalletId (update flow) ===')
  {
    const userId = 'u3'
    const walletId = 'w3'
    const addr = '0x3'
    await storage.saveLookup(LOOKUP_TYPES.WALLETS, walletId, 'shard1', userId)
    await storage.saveWalletIdLookup(addr, walletId)

    let preThrew = false
    try { await preValidate(storage, addr, walletId) } catch (e) { preThrew = true }
    record(results, 'pre-patch passes when address matches excludeWalletId', !preThrew)

    let postThrew = false
    try { await postValidate(storage, addr, walletId) } catch (e) { postThrew = true }
    record(results, 'post-patch passes when address matches excludeWalletId', !postThrew)
  }

  console.log('\n=== Scenario 4: post-heal, a fresh wallet can claim the same address ===')
  {
    const orphanWalletId = 'w-orphan-2'
    const newUserId = 'u-fresh'
    const newWalletId = 'w-fresh'
    const addr = '0x-formerly-orphaned'

    await storage.saveWalletIdLookup(addr, orphanWalletId)
    await postValidate(storage, addr) // self-heal step
    await storage.base.update()

    // Simulate the post-validate flow: shard creates wallet, ork stores WALLETS
    // lookup, ork inserts the address mapping for the new walletId.
    await storage.saveLookup(LOOKUP_TYPES.WALLETS, newWalletId, 'shard1', newUserId)
    await storage.saveWalletIdLookup(addr, newWalletId)

    record(results,
      'fresh wallet successfully claims the previously orphaned address',
      (await storage.getWalletIdByAddress(addr)) === newWalletId,
      `addr → ${await storage.getWalletIdByAddress(addr)}`
    )

    // And re-running validation with this new live mapping should throw again.
    let postThrew = false
    try { await postValidate(storage, addr) } catch (e) { postThrew = e.message === 'ERR_ADDRESS_ALREADY_EXISTS' }
    record(results, 'post-patch throws again now that the address is a live mapping', postThrew)
  }

  console.log('\n=== SUMMARY ===')
  const passed = results.filter(r => r.ok).length
  const failed = results.length - passed
  console.log(`${passed}/${results.length} checks passed${failed ? ` — ${failed} FAILED` : ''}`)

  await storage.close()
  fs.rmSync(TMP, { recursive: true, force: true })
  process.exit(failed ? 1 : 0)
}

main().catch(err => {
  console.error('test crashed:', err)
  fs.rmSync(TMP, { recursive: true, force: true })
  process.exit(1)
})
