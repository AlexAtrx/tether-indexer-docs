Update the caching of endpoints to use bfx-facs-redis as opposed to lru cache

We've noticed issues with balance fluctuations due to the usage of lru cache. The problem is discussed in this thread:

Get a sense of how Redis is used in another service (wdk-indexer-app-node):
```
'use strict'

const TetherWrkBase = require('tether-wrk-base/workers/base.wrk.tether')
const async = require('async')
const pino = require('pino')
const { camelize } = require('@bitfinexcom/lib-js-util-base')
const libServer = require('./lib/server')
const utils = require('./lib/utils')
const service = require('./lib/services')
const AutobaseManager = require('./lib/autobase.manager')
const auth = require('./lib/middlewares/auth')
const { configureAuth } = require('./lib/middlewares')
const SendGridEmailService = require('./lib/services/sendgrid-email')

class WdkServerHttpBase extends TetherWrkBase {
  constructor (conf, ctx) {
    super(conf, ctx)

    if (!ctx.port) {
      throw new Error('ERR_HTTP_PORT_INVALID')
    }

    this.prefix = `${this.wtype}-${ctx.port}`
    this.ctx.rack = ctx.port // fix for wrk base store

    this.init()
    this.start()
  }

  init () {
    super.init()

    this.logger = pino({
      name: `wrk:http:${this.ctx.wtype}:${process.pid}`,
      level: this.conf.debug || this.ctx.debug ? 'debug' : 'info'
    })

    this.allUniqueBlockchains = [...new Set(Object.keys(this.conf.blockchains))]
    this.allUniqueCcys = [...new Set(Object.values(this.conf.blockchains).flatMap(b => b.ccys))]

    // Job schedules
    this.jobSchedules = {}
    this.jobSchedules.revokeInactiveKeys = this.conf.revokeInactiveKeysInterval || '0 2 * * *' // Daily at 2 AM

    this.setInitFacs([
      ['fac', 'bfx-facs-redis', 'r0', 'r0', {}, 2],
      ['fac', 'bfx-facs-http', 'h0', 'h0', { timeout: 30000, debug: false }, 0],
      ['fac', 'svc-facs-httpd', 'h0', 'h0', {
        staticRootPath: require('path').join(__dirname, 'public'),
        staticPrefix: '/static/',
        port: this.ctx.port,
        logger: this.ctx.logging ?? true,
        addDefaultRoutes: true,
        trustProxy: true
      }, 1],
      ['fac', 'bfx-facs-scheduler', '0', '0', {}, 0]
    ])

    this.routes = new Map()
  }

  async _runJob (flag, func) {
    if (this[flag]) {
      return
    }

    try {
      this[flag] = true
      await func()
    } catch (err) {
      this.logger.error({ err }, 'ERR_JOB_FAILED')
    } finally {
      this[flag] = false
    }
  }

  _start (cb) {
    async.series([
      next => { super._start(next) },
      async () => {
        this.autobaseManager = new AutobaseManager(this)

        // Initialize SendGrid email service
        this.emailService = new SendGridEmailService(this)
        this.logger.info('SendGrid email service initialized')

        const ctxKey = 'autobase'
        const camelizedKey = camelize(ctxKey)
        await this.net_r0.startSwarm()
        await this._startAutobase(camelizedKey)

        this.net_r0.swarm.on('connection', (connection) => this.store_s0.store.replicate(connection))
        this.swarmDiscovery = this.net_r0.swarm.join(this.autobaseManager.getDiscoveryKey())

        await this.autobaseManager.waitWriteReady(0)
        this.logger.info('autobase became writable')

        await this._setupServer()
        await this.httpd_h0.startServer()

        const shouldRunRemoveKeysJob = !this.ctx[camelizedKey]

        if (shouldRunRemoveKeysJob) {
          this.scheduler_0.add(
            'revoke-inactive-keys',
            this._runJob.bind(this, 'revokeInactiveKeys', this._revokeInactiveKeysJob.bind(this)),
            this.jobSchedules.revokeInactiveKeys
          )
        }
      }
    ], cb)
  }

  async _startAutobase (ctxKey) {
    const bootstrap = this.ctx[ctxKey] ? Buffer.from(this.ctx[ctxKey], 'hex') : null
    await this.autobaseManager.start(bootstrap)
    this.status.autobase = {
      writer: this.autobaseManager.getWriterKey().toString('hex'),
      bootstrap: this.autobaseManager.getBootstrapKey().toString('hex')
    }
    this.saveStatus()

    this.logger.info(`autobase writer key: ${this.status.autobase.writer}`)
    this.logger.info(`autobase bootstrap key: ${this.status.autobase.bootstrap}`)
    this.logger.info('waiting for autobase to become writable')
  }

  _registerRoute (r) {
    this.routes.set(`${r.method}:${r.url}`, r)
  }

  _setupRoutes () {
    libServer.routes(this).forEach((r) => this._registerRoute(r))
  }

  _getTopicConf () {
    const conf = this.conf.topicConf ?? {}
    if (conf.capability && !Buffer.isBuffer(conf.capability)) {
      conf.capability = Buffer.from(conf.capability, 'utf-8')
    }
    return conf
  }

  async getBootstrapKey () {
    return this.autobaseManager.getBootstrapKey().toString('hex')
  }

  async registerAutobaseWriter (req) {
    const { key } = req
    await this.autobaseManager.addWriter(key)
    return 1
  }

  async removeAutobaseWriter (req) {
    const { key } = req
    await this.autobaseManager.removeWriter(key)
    return 1
  }

  async _setupServer () {
    configureAuth(auth.ApiKeyGuard.name, new auth.ApiKeyGuard(this.conf.apiKeySecret))

    const httpd = this.httpd_h0
    httpd.addPlugin([require('@fastify/sensible')])

    httpd.addPlugin([
      require('@fastify/rate-limit'),
      {
        global: false,
        redis: this.redis_r0?.cli_rw,
        // remove rate limit headers
        addHeadersOnExceeding: {
          'x-ratelimit-limit': this.conf.rateLimitHeaders ?? false,
          'x-ratelimit-remaining': this.conf.rateLimitHeaders ?? false,
          'x-ratelimit-reset': this.conf.rateLimitHeaders ?? false
        },
        addHeaders: {
          'x-ratelimit-limit': this.conf.rateLimitHeaders ?? false,
          'x-ratelimit-remaining': this.conf.rateLimitHeaders ?? false,
          'x-ratelimit-reset': this.conf.rateLimitHeaders ?? false,
          'retry-after': this.conf.rateLimitHeaders ?? false
        }
      }
    ])

    httpd.addPlugin([require('@fastify/swagger'), {
      openapi: {
        openapi: '3.0.0',
        info: {
          title: 'WDK Indexer API',
          description: 'API for blockchain token transfers and balances',
          version: '1.0.0'
        }
      }
    }])

    httpd.addPlugin([require('@fastify/swagger-ui'), {
      routePrefix: '/docs'
    }])

    this._setupRoutes()
    for (const r of this.routes.values()) {
      httpd.addRoute(r)
    }

    const rpcServer = this.net_r0.rpcServer
    const rpcActions = [
      'getBootstrapKey',
      'createApiKey',
      'getApiKeyDetails',
      'deleteApiKeysForOwner',
      'registerAutobaseWriter',
      'removeAutobaseWriter',
      'revokeApiKey',
      'blockUser',
      'unblockUser'
    ]

    for (const action of rpcActions) {
      rpcServer.respond(action, async (req) => {
        return await this.net_r0.handleReply(action, req)
      })
    }

    const topicConf = this._getTopicConf()
    this.net_r0.startLookup(topicConf)
  }

  async createApiKey (req) {
    const { owner, ttl = 0, label } = req
    if (!owner) {
      throw new Error('ERR_OWNER_REQUIRED')
    }
    if (!label || typeof label !== 'string') {
      throw new Error('ERR_LABEL_REQUIRED')
    }

    return await service.apiKey.requestApiKey(this, {
      owner,
      ttl,
      label,
      sendEmail: false
    })
  }

  async getApiKeyDetails (req) {
    const { key } = req

    if (!key) {
      throw new Error('ERR_API_KEY_REQUIRED')
    }

    const hashedKey = utils.hashApiKey(key, this.conf.apiKeySecret)
    const apiKeyEntry = await this.autobaseManager.getApiKey(hashedKey)

    if (!apiKeyEntry) {
      throw new Error('ERR_API_KEY_NOT_FOUND')
    }

    return {
      owner: apiKeyEntry.owner,
      ttl: apiKeyEntry.ttl,
      label: apiKeyEntry.label,
      createdAt: apiKeyEntry.createdAt,
      lastActive: apiKeyEntry.lastActive || 0
    }
  }

  async deleteApiKeysForOwner (req) {
    const { owner } = req

    if (!owner) {
      throw new Error('ERR_OWNER_REQUIRED')
    }

    const normalizedOwner = utils.normalizeEmail(owner)

    await this.autobaseManager.delApiKeysForOwner(normalizedOwner)
    this.logger.info(`API keys deleted for owner: ${owner}`)

    return { success: true }
  }

  /**
   * Check if an API key already exists for the given email
   * @param {string} email - Email address
   * @returns {Promise<boolean>}
   */
  async hasApiKeyForEmail (email) {
    const normalized = utils.normalizeEmail(email)
    return await this.autobaseManager.hasApiKeyForOwner(normalized)
  }

  /**
   * Scheduled job for revoking inactive keys
   * Runs daily at 2 AM (configurable via jobSchedules.revokeInactiveKeys)
   */
  async _revokeInactiveKeysJob () {
    try {
      this.logger.info('Starting scheduled inactive keys cleanup...')
      const thresholdDays = this.conf.inactivityThresholdDays || 30
      const thresholdMs = thresholdDays * 24 * 60 * 60 * 1000
      const revoked = await this.autobaseManager.sweepInactiveKeys(thresholdMs)
      this.logger.info(`Scheduled cleanup completed. Revoked ${revoked} inactive keys.`)
    } catch (error) {
      this.logger.error(`Scheduled cleanup failed: ${error.message}`)
    }
  }

  /**
   * Admin: revoke a specific API key
   */
  async revokeApiKey (req) {
    const { key } = req
    if (!key) throw new Error('ERR_API_KEY_REQUIRED')
    const hashedKey = utils.hashApiKey(key, this.conf.apiKeySecret)
    await this.autobaseManager.deleteApiKey(hashedKey)
    return { success: true }
  }

  /**
   * Admin: block a user
   */
  async blockUser (req) {
    const { owner } = req
    const reason = 'Blocked by admin'
    if (!owner) throw new Error('ERR_OWNER_REQUIRED')
    const normalizedOwner = utils.normalizeEmail(owner)

    await this.autobaseManager.setOwnerBlocked(normalizedOwner, reason)
    await this.autobaseManager.delApiKeysForOwner(normalizedOwner)
    return { success: true }
  }

  /**
   * Admin: unblock a user
   */
  async unblockUser (req) {
    const { owner } = req
    if (!owner) throw new Error('ERR_OWNER_REQUIRED')
    const normalizedOwner = utils.normalizeEmail(owner)
    await this.autobaseManager.unsetOwnerBlocked(normalizedOwner)
    return { success: true }
  }

  async _stop (cb) {
    try {
      await this.autobaseManager?.close()
      this.logger.info('AutobaseManager closed successfully')
    } catch (error) {
      this.logger.error('Failed to close AutobaseManager:', error)
    }

    super._stop(cb)
  }
}

module.exports = WdkServerHttpBase
```
