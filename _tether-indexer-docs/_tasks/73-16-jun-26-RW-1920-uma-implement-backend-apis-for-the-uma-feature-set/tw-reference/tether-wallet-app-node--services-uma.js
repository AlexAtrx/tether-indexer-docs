'use strict'

const orkService = require('./ork')
const indexerService = require('./indexer')
const accountDeletion = require('./accountDeletion')
const { createAppError } = require('../utils/appError')
const {
  getUmaChainsConfig,
  getSupportedChain,
  getChainAssetIdentifiers
} = require('../utils/uma')
const {
  LAYER_TO_CHAIN,
  UMA_PAYER_DATA,
  DEFAULT_CURRENCIES_CONFIG
} = require('../constants/uma-chains')
const {
  validateUsernameFormat,
  validateLnurlpPayParams,
  suggestCandidatesFromEmail
} = require('../utils/uma')
const { applyUmaDefaults } = require('../utils/uma-defaults')

const suggest = async (ctx, req) => {
  const { email } = req.body || {}
  if (!email || typeof email !== 'string' || !email.trim()) {
    throw createAppError('ERR_UMA_EMAIL_REQUIRED')
  }
  const normalizedEmail = email.trim().toLowerCase()
  const candidates = suggestCandidatesFromEmail(normalizedEmail, 10)
  const fakeReq = { _info: {} }
  for (const username of candidates) {
    const { userId } = await orkService.lookupUmaUsername(ctx, fakeReq, username)
    if (!userId) {
      return { username }
    }
  }
  throw createAppError('ERR_UMA_SUGGEST_FAILED')
}

const check = async (ctx, req) => {
  const { username } = req.body || {}
  if (!username || typeof username !== 'string' || !username.trim()) {
    throw createAppError('ERR_UMA_USERNAME_REQUIRED')
  }
  const format = validateUsernameFormat(username)
  if (!format.valid) {
    return { available: false, reason: format.reason, code: format.code }
  }
  const fakeReq = { _info: {} }
  const { userId } = await orkService.lookupUmaUsername(ctx, fakeReq, format.normalized)
  return { available: !userId }
}

const buildSettlementOptionsFromWallet = (wallet, layerToChain = LAYER_TO_CHAIN) => {
  if (!wallet?.addresses) return []

  const options = []
  const addresses = wallet.addresses

  for (const chainKey in addresses) {
    const addr = addresses[chainKey]
    if (typeof addr !== 'string' || !addr) continue

    const chain = getSupportedChain(chainKey, layerToChain)
    if (!chain || chain.layer === 'lightning' || chain.layer === 'ln') continue

    const assetIds = getChainAssetIdentifiers(chain)
    options.push({
      settlementLayer: chain.layer,
      assets: assetIds.map((identifier) => ({ identifier, multipliers: {} }))
    })
  }

  if (wallet?.meta?.spark?.sparkIdentityKey) {
    const lightningOption = {
      settlementLayer: 'lightning',
      assets: [{ identifier: 'sat', multipliers: {} }]
    }

    options.push(lightningOption)

    options.push({
      ...lightningOption,
      settlementLayer: 'ln'
    })
  }

  return options
}

const buildCurrenciesForLookup = (ctx, uma) => {
  const minSendable = Number(uma.minSendable) || 1000
  const maxSendable = Number(uma.maxSendable) || Number.MAX_SAFE_INTEGER
  const list = ctx.conf?.uma?.currencies || DEFAULT_CURRENCIES_CONFIG
  const multiplierConf = ctx.conf?.uma?.currencyMultipliers || {}
  return list.map((c) => ({
    code: c.code,
    name: c.name || c.code,
    symbol: c.symbol || c.code,
    decimals: c.decimals != null ? c.decimals : 2,
    convertible: { min: minSendable, max: maxSendable },
    multiplier: multiplierConf[c.code] != null ? Number(multiplierConf[c.code]) : 1
  }))
}

const buildMetadata = (uma) => {
  return JSON.stringify([
    ['text/plain', `Pay to ${uma.username}${uma.domain ? `@${uma.domain}` : ''}`],
    ['text/identifier', `${uma.username}${uma.domain ? `@${uma.domain}` : ''}`]
  ])
}

const getSendableLimits = (uma) => {
  const minSendable = Number(uma.minSendable) || 1000
  const maxSendable = Number(uma.maxSendable) || Number.MAX_SAFE_INTEGER
  return { minSendable, maxSendable }
}

const getEvmAddressResponse = (addr, uma) => {
  return {
    pr: addr,
    routes: [],
    successAction: { tag: 'message', message: 'Payment received. Thank you.' },
    payeeData: {
      identifier: `$${uma.username}@${uma.domain || 'localhost'}`
    }
  }
}

const resolveEvmAddress = (wallet, layer, settlementLayer, chainsConfig) => {
  const chain = chainsConfig.layerToChain[layer]
  if (!chain) return { error: 'ERR_UMA_CHAIN_NOT_FOUND' }
  if (!wallet || !wallet.addresses) return { error: 'ERR_UMA_WALLET_NOT_FOUND' }
  const addr = wallet.addresses[layer] || wallet.addresses[settlementLayer]
  if (!addr || typeof addr !== 'string') return { error: 'ERR_UMA_WALLET_ADDRESS_NOT_FOUND' }
  return { address: addr, chain }
}

const isLightningLayer = (layer) => {
  return layer === 'ln' || layer === 'lightning' || layer === 'spark'
}

const getLnurlpCallback = (baseUrl, identifier) => {
  return `${baseUrl}/api/lnurl/payreq/${encodeURIComponent(identifier)}`
}

const lnurlpLookup = async (ctx, req, username, baseUrl) => {
  const chainsConfig = getUmaChainsConfig(ctx.conf)
  let uma = await orkService.getUmaByUsername(ctx, req, username)

  if (!uma) throw createAppError('ERR_UMA_USER_NOT_FOUND', 404)

  if (await accountDeletion.isUserAccountBlocked(ctx, uma?.userId)) {
    throw createAppError('ERR_ACCOUNT_BLOCKED', 403)
  }
  uma = applyUmaDefaults(uma, ctx)
  const wallet = await orkService.getWalletById(ctx, req, uma.walletId)

  const { minSendable, maxSendable } = getSendableLimits(uma)
  const metadata = buildMetadata(uma)
  const settlementOptions = buildSettlementOptionsFromWallet(wallet, chainsConfig.layerToChain)
  const currencies = buildCurrenciesForLookup(ctx, uma)
  const commentAllowed = ctx.conf?.uma?.commentAllowed ?? 255
  const sparkIdentityKey = wallet?.meta?.spark?.sparkIdentityKey
  const userId = uma.userId || uma.id

  let callback = `${baseUrl}/.well-known/lnurlp/${encodeURIComponent(username)}`
  if (sparkIdentityKey) {
    callback = getLnurlpCallback(baseUrl, sparkIdentityKey)
  } else if (userId) {
    callback = getLnurlpCallback(baseUrl, userId)
  }

  return {
    tag: 'payRequest',
    callback,
    minSendable,
    maxSendable,
    metadata,
    commentAllowed,
    currencies,
    payerData: UMA_PAYER_DATA,
    umaVersion: '1.0',
    defaultSettlementLayer: uma.defaultSettlementLayer || chainsConfig.defaultSettlementLayer,
    defaultAssetIdentifier: chainsConfig.defaultAssetIdentifier,
    ...(settlementOptions.length > 0 && { settlementOptions })
  }
}

const lnurlpPay = async (ctx, req, username, amount, settlementLayer, settlementAsset, baseUrl, queryString = '') => {
  const chainsConfig = getUmaChainsConfig(ctx.conf)
  let uma = await orkService.getUmaByUsername(ctx, req, username)
  if (!uma) throw createAppError('ERR_UMA_USER_NOT_FOUND', 404)
  uma = applyUmaDefaults(uma, ctx)
  if (await accountDeletion.isUserAccountBlocked(ctx, uma?.userId)) {
    throw createAppError('ERR_ACCOUNT_BLOCKED', 403)
  }
  const amountNum = parseInt(amount, 10)
  if (Number.isNaN(amountNum) || amountNum <= 0) throw createAppError('ERR_UMA_AMOUNT_INVALID', 400)

  let layer
  let assetIdentifier
  try {
    const validated = validateLnurlpPayParams(settlementLayer, settlementAsset, amountNum, uma, chainsConfig)
    layer = validated.layer
    assetIdentifier = validated.assetIdentifier
  } catch (err) {
    throw createAppError(err.message, 400)
  }

  const wallet = await orkService.getWalletById(ctx, req, uma.walletId)
  if (isLightningLayer(layer)) {
    const sparkIdentityKey = wallet?.meta?.spark?.sparkIdentityKey
    if (!sparkIdentityKey) throw createAppError('ERR_UMA_SPARK_IDENTITY_KEY_NOT_FOUND', 400)
    const payreqUrl = `${baseUrl}/api/lnurl/payreq/${encodeURIComponent(sparkIdentityKey)}${queryString ? (queryString.startsWith('?') ? queryString : `?${queryString}`) : ''}`
    const response = await indexerService.handleLnurlPayreq(ctx, sparkIdentityKey, payreqUrl)
    return response.data
  }

  if (layer) {
    const resolved = resolveEvmAddress(wallet, layer, settlementLayer, chainsConfig)
    if (resolved.error) throw createAppError(resolved.error, 400)

    const assetIds = getChainAssetIdentifiers(resolved.chain)
    if (!assetIds.includes(assetIdentifier)) throw createAppError('ERR_UMA_SETTLEMENT_ASSET_INVALID', 400)

    return getEvmAddressResponse(resolved.address, uma)
  }
}

const handleUmaPayreq = async (ctx, req, userId, requestUrl, requestBody) => {
  const fakeReq = { _info: { user: { id: userId } } }
  let uma = null
  try {
    uma = await orkService.getUmaByUserId(ctx, fakeReq)
  } catch (error) {
    ctx.logger.warn('Error getting UMA by user ID:', error)
  }

  if (!uma) {
    const fakeReq2 = { _info: {} }
    uma = await orkService.getUmaByUsername(ctx, fakeReq2, userId)
  }
  if (!uma) throw createAppError('ERR_UMA_USER_NOT_FOUND', 404)
  const chainsConfig = getUmaChainsConfig(ctx.conf)
  const wallet = await orkService.getWalletById(ctx, fakeReq, uma.walletId)

  const settlementLayer = requestBody?.receivingCurrencyCode?.toLowerCase() || 'lightning'
  const layer = chainsConfig.layerToChain[settlementLayer] ? settlementLayer : 'lightning'

  if (!isLightningLayer(layer)) {
    const resolved = resolveEvmAddress(wallet, layer, settlementLayer, chainsConfig)
    if (resolved.error) throw createAppError(resolved.error, 400)

    return {
      httpStatus: 200,
      data: getEvmAddressResponse(resolved.address, uma)
    }
  }

  const sparkIdentityKey = wallet?.meta?.spark?.sparkIdentityKey
  if (!sparkIdentityKey) {
    throw createAppError('ERR_UMA_SPARK_IDENTITY_KEY_NOT_FOUND', 400)
  }

  const url = typeof requestUrl === 'string' ? new URL(requestUrl) : requestUrl
  const payreqUrl = `${url.origin}/api/lnurl/payreq/${sparkIdentityKey}?amount=${requestBody?.amount || 0}`
  const response = await indexerService.handleLnurlPayreq(ctx, sparkIdentityKey, payreqUrl)
  return response
}

const lnurlp = async (ctx, req, username, query, baseUrl) => {
  const amount = query?.amount
  if (!amount) {
    return lnurlpLookup(ctx, req, username, baseUrl)
  }
  const queryString = Object.keys(query || {}).length ? new URLSearchParams(query).toString() : ''
  return lnurlpPay(ctx, req, username, amount, query?.settlementLayer, query?.settlementAsset, baseUrl, queryString)
}

module.exports = {
  validateUsernameFormat,
  suggest,
  check,
  lnurlpLookup,
  lnurlpPay,
  lnurlp,
  handleUmaPayreq,
  getLnurlpCallback
}
