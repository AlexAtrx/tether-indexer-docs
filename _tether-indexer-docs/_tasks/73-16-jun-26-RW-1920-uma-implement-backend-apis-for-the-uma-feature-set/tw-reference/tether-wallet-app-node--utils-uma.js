'use strict'

const { SUPPORTED_CHAINS, LAYER_TO_CHAIN, DEFAULT_CURRENCIES_CONFIG } = require('../constants/uma-chains')

/** @param {object} [conf] - app config (e.g. ctx.conf). Returns UMA chains config; defaults when conf.uma not set. */
const getUmaChainsConfig = (conf) => {
  const supportedChains = Array.isArray(conf?.uma?.supportedChains) && conf.uma.supportedChains.length > 0
    ? conf.uma.supportedChains
    : SUPPORTED_CHAINS
  const defaultSettlementLayer = conf?.uma?.defaultSettlementLayer ?? 'lightning'
  const layerToChain = Object.fromEntries(supportedChains.map(c => [c.layer, c]))
  const settlementLayerEnum = supportedChains.map(c => c.layer)
  const defaultChain = layerToChain[defaultSettlementLayer]
  const assetIds = defaultChain?.assetIdentifiers
  const defaultAssetIdentifier = Array.isArray(assetIds) && assetIds.length > 0 ? assetIds[0] : 'sat'
  const supportedCurrencies = (conf?.uma?.currencies ?? DEFAULT_CURRENCIES_CONFIG).map(c => c.code.toLowerCase())
  return {
    supportedChains,
    layerToChain,
    defaultSettlementLayer,
    settlementLayerEnum,
    defaultAssetIdentifier,
    supportedCurrencies
  }
}

/**
 * Get asset identifiers for a chain (multi-asset only).
 * @param {{ assetIdentifiers: string[] }} chain
 * @returns {string[]}
 */
const getChainAssetIdentifiers = (chain) => {
  if (!chain || !Array.isArray(chain.assetIdentifiers) || chain.assetIdentifiers.length === 0) {
    return ['sat']
  }
  return chain.assetIdentifiers
}

const USERNAME_MIN_LENGTH = 4
const USERNAME_MAX_LENGTH = 15
const USERNAME_MIN_DIGITS = 1
const USERNAME_MIN_LETTERS = 1
const USERNAME_PATTERN = /^[a-z0-9]+$/
const USERNAME_ERROR_MESSAGE = 'Your username must be 4–15 characters long, use only letters and numbers, and include at least one number.'

const validateUsernameFormat = (username) => {
  if (!username || typeof username !== 'string') {
    return { valid: false, reason: USERNAME_ERROR_MESSAGE, code: 'ERR_USERNAME_REQUIRED' }
  }
  const s = username.trim().toLowerCase()
  if (s.length === 0) {
    return { valid: false, reason: USERNAME_ERROR_MESSAGE, code: 'ERR_USERNAME_REQUIRED' }
  }
  if (s.length < USERNAME_MIN_LENGTH || s.length > USERNAME_MAX_LENGTH) {
    return { valid: false, reason: USERNAME_ERROR_MESSAGE, code: 'ERR_USERNAME_LENGTH' }
  }
  if (!USERNAME_PATTERN.test(s)) {
    return { valid: false, reason: USERNAME_ERROR_MESSAGE, code: 'ERR_USERNAME_INVALID_CHARS' }
  }
  const digitCount = (s.match(/\d/g) || []).length
  if (digitCount < USERNAME_MIN_DIGITS) {
    return { valid: false, reason: USERNAME_ERROR_MESSAGE, code: 'ERR_USERNAME_MIN_DIGITS' }
  }
  const letterCount = (s.match(/[a-z]/g) || []).length
  if (letterCount < USERNAME_MIN_LETTERS) {
    return { valid: false, reason: USERNAME_ERROR_MESSAGE, code: 'ERR_USERNAME_MIN_LETTERS' }
  }
  return { valid: true, normalized: s }
}

const baseFromEmail = (email) => {
  if (!email || typeof email !== 'string') return 'user'
  const local = email.split('@')[0].toLowerCase().replace(/[^a-z0-9]/g, '') || 'user'
  return local.slice(0, 20)
}

const validateLnurlpPayParams = (settlementLayer, settlementAsset, amountNum, uma, chainsConfig) => {
  if (!chainsConfig.settlementLayerEnum.includes(settlementLayer)) {
    throw new Error('ERR_UMA_SETTLEMENT_LAYER_INVALID')
  }
  if (settlementAsset && !chainsConfig.supportedCurrencies.includes(settlementAsset.toLowerCase())) {
    throw new Error('ERR_UMA_SETTLEMENT_ASSET_INVALID')
  }
  const min = uma?.minSendable
  const max = uma?.maxSendable
  if (min != null && amountNum < min) {
    throw new Error('ERR_UMA_AMOUNT_TOO_SMALL')
  }
  if (max != null && amountNum > max) {
    throw new Error('ERR_UMA_AMOUNT_TOO_LARGE')
  }
  const layer = (settlementLayer || '').toLowerCase()
  return { layer, assetIdentifier: settlementAsset?.toLowerCase() }
}

const suggestCandidatesFromEmail = (email, count = 5) => {
  const base = baseFromEmail(email)
  const candidates = []
  let n = Math.floor(Math.random() * 90) + 10
  for (let i = 0; i < count; i++) {
    let candidate = `${base}${n}`
    if (candidate.length < USERNAME_MIN_LENGTH) {
      candidate = base.padEnd(USERNAME_MIN_LENGTH - String(n).length, 'x') + n
    }
    if (candidate.length > USERNAME_MAX_LENGTH) {
      candidate = base.slice(0, USERNAME_MAX_LENGTH - String(n).length) + n
    }
    candidates.push(candidate)
    n = (n + 1) % 100
    if (n < 10) n = 10
  }
  return [...new Set(candidates)]
}

/**
 * Get settlement option for a chain if supported and wallet has address for it.
 * @param {string} walletAddressKey - key in wallet.addresses (e.g. 'ethereum', 'polygon')
 * @param {Record<string, { layer: string, assetIdentifiers: string[] }>} [layerToChain] - optional override (default: LAYER_TO_CHAIN)
 * @returns {typeof LAYER_TO_CHAIN[string] | null}
 */
const getSupportedChain = (walletAddressKey, layerToChain = LAYER_TO_CHAIN) => {
  if (!walletAddressKey || typeof walletAddressKey !== 'string') return null
  const layer = walletAddressKey.toLowerCase()
  return layerToChain[layer] || null
}

module.exports = {
  getUmaChainsConfig,
  getChainAssetIdentifiers,
  USERNAME_MIN_LENGTH,
  USERNAME_MAX_LENGTH,
  USERNAME_MIN_DIGITS,
  USERNAME_MIN_LETTERS,
  USERNAME_PATTERN,
  USERNAME_ERROR_MESSAGE,
  validateUsernameFormat,
  validateLnurlpPayParams,
  baseFromEmail,
  suggestCandidatesFromEmail,
  getSupportedChain
}
