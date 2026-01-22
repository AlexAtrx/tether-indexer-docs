'use strict'

const test = require('brittle')
const path = require('path')
const { createWorker } = require('tether-svc-test-helper/lib/worker')
const createClient = require('tether-svc-test-helper/lib/client')
const { ConfigUtils, CleanupUtils, getTestAddress, isProviderConfigured } = require('../utils')

let procWorker = null
let apiWorker = null

// Helper to make RPC calls using test helper client
async function makeRpcCall (workerInstance, method, payload = {}) {
  const client = createClient(workerInstance)

  try {
    await client.start()
    const response = await client.request(method, payload)
    return response
  } finally {
    await client.stop().catch(() => {})
  }
}

// Setup test config - verify at least one provider is working
async function setupConfig () {
  const testConfig = ConfigUtils.loadTestConfig()

  // Verify at least one provider is configured and working
  const mainRpc = testConfig.wrk.mainRpc
  const secondaryRpcs = testConfig.wrk.secondaryRpcs || []

  // Test mainRpc first
  const isMainWorking = await isProviderConfigured(mainRpc)
  if (isMainWorking) {
    console.log('✅ Main RPC is working')
    await CleanupUtils.cleanupPreviousRun()
    return
  }

  // Try secondary RPCs
  console.log('⚠️  Main RPC not working, checking secondary RPCs...')
  for (const secondaryRpc of secondaryRpcs) {
    if (secondaryRpc && secondaryRpc.uri) {
      const isSecondaryWorking = await isProviderConfigured(secondaryRpc)
      if (isSecondaryWorking) {
        console.log(`✅ Found working secondary RPC: ${secondaryRpc.type || 'rpc'}`)
        await CleanupUtils.cleanupPreviousRun()
        return
      }
    }
  }

  throw new Error(
    'ERR_PROVIDER_NOT_CONFIGURED: No working RPC provider found. ' +
    'Please update config/test.bitcoin.json with a valid provider URI.'
  )
}

// Cleanup
async function cleanup () {
  // Stop workers
  if (apiWorker) {
    await apiWorker.stop().catch(() => {})
  }
  if (procWorker) {
    await procWorker.stop().catch(() => {})
  }
}

test('E2E: Bitcoin Indexer Workers Integration', { timeout: 300000 }, async (t) => {
  await setupConfig()
  t.teardown(cleanup)

  // Start processing worker
  procWorker = createWorker({
    wtype: 'wrk-btc-indexer-proc',
    env: 'test',
    rack: 'btc-proc-e2e',
    chain: 'bitcoin',
    serviceRoot: path.join(__dirname, '../..')
  })

  await procWorker.start()
  t.ok(procWorker.worker, 'Processing worker should start')

  const procKey = procWorker.worker.getRpcKey()
  t.ok(procKey, 'Processing worker should have RPC key')

  // Wait for processing worker to sync blocks
  console.log('⏳ Waiting for processing worker to sync blocks (20s)...')
  await new Promise(resolve => setTimeout(resolve, 20000))

  t.ok(procWorker.worker && !procWorker.worker.killed, 'Processing worker should still be running')

  // Start API worker with processing worker's RPC key
  apiWorker = createWorker({
    wtype: 'wrk-btc-indexer-api',
    env: 'test',
    rack: 'btc-api-e2e',
    chain: 'bitcoin',
    procRpc: procKey,
    serviceRoot: path.join(__dirname, '../..')
  })

  await apiWorker.start()
  t.ok(apiWorker.worker, 'API worker should start')

  const apiKey = apiWorker.worker.getRpcKey()
  t.ok(apiKey, 'API worker should have RPC key')

  console.log('⏳ Waiting for API worker to finish loading database and announce on DHT (5s)...')
  await new Promise(resolve => setTimeout(resolve, 5000))

  // Verify both workers are running
  t.ok(procWorker.worker && !procWorker.worker.killed, 'Processing worker should still be running')
  t.ok(apiWorker.worker && !apiWorker.worker.killed, 'API worker should still be running')
})

test('E2E: Data synchronization between workers', { timeout: 300000 }, async (t) => {
  await setupConfig()
  t.teardown(cleanup)

  // Start processing worker
  procWorker = createWorker({
    wtype: 'wrk-btc-indexer-proc',
    env: 'test',
    rack: 'btc-proc-e2e',
    chain: 'bitcoin',
    serviceRoot: path.join(__dirname, '../..')
  })

  await procWorker.start()
  const procKey = procWorker.worker.getRpcKey()

  // Start API worker
  apiWorker = createWorker({
    wtype: 'wrk-btc-indexer-api',
    env: 'test',
    rack: 'btc-api-e2e',
    chain: 'bitcoin',
    procRpc: procKey,
    serviceRoot: path.join(__dirname, '../..')
  })

  await apiWorker.start()
  const apiKey = apiWorker.worker.getRpcKey()
  t.ok(apiKey, 'API worker should have RPC key')

  // Wait for API worker to be ready for RPC calls
  console.log('⏳ Waiting for API worker to be ready (2s)...')
  await new Promise(resolve => setTimeout(resolve, 2000))

  // Test: API worker can query balance (verifies workers are communicating)
  const testAddress = getTestAddress()
  t.ok(testAddress, 'Should have test address')

  const balance = await makeRpcCall(
    apiWorker,
    'getBalance',
    {
      address: testAddress
    }
  )

  t.ok(typeof balance === 'string', 'API worker should return balance as string')
  t.ok(parseFloat(balance) > 0, 'Balance should be greater than zero')
})