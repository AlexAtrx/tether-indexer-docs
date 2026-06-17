    },

    {
      method: 'GET',
      url: '/api/v1/wallets/:id',
      schema: {
        description: 'Get a single wallet by ID. Returns wallet with UMA (username, uma) when present. Requires Bearer token.',
        tags: ['Wallets'],
        summary: 'Get wallet by ID',
        security: [{ bearerAuth: [] }],
        params: {
          type: 'object',
          additionalProperties: false,
          properties: { id: { type: 'string', minLength: 1 } },
          required: ['id']
        },
        response: {
          200: { description: 'Wallet object', ...walletObjectSchema },
          404: { description: 'Wallet not found', ...errorResponseSchema }
        }
      },
      preHandler: async (req, rep) => {
        await middleware.auth.guard(ctx, req)
      },
      handler: async (req, rep) => {
        const res = await service.ork.getWallet(ctx, req)
        return send200(rep, res)
      }
    },
    {
      method: 'GET',
      url: '/api/v1/wallets',
      schema: {
        description: 'List wallets for the authenticated user. Each wallet may include UMA (username, uma). Requires Bearer token.',
        tags: ['Wallets'],
        summary: 'List wallets',
        security: [{ bearerAuth: [] }],
        response: {
          200: {
            description: 'Wallets list',
            type: 'object',
            properties: { wallets: { type: 'array', items: walletObjectSchema } },
            required: ['wallets']
          }
        }
      },
      preHandler: async (req, rep) => {
        await middleware.auth.guard(ctx, req)
      },
      handler: async (req, rep) => {
        const res = await service.ork.getUserWallets(ctx, req)
        return send200(rep, res)
      }
    },
    {
      method: 'POST',
      url: '/api/v1/wallets',
      schema: {
        description: `Create one or more user wallets. Each wallet may include UMA username.

**Username validation rules:**
- Length: 4-15 characters
- Must contain at least 1 letter (a-z)
- Must contain at least 1 digit (0-9)
- Allowed characters: lowercase letters (a-z), digits (0-9) only (no special characters)
- Uppercase letters are auto-normalized to lowercase`,
        tags: ['Wallets'],
        summary: 'Create wallets',
        security: [{ bearerAuth: [] }],
        body: postWalletsBodySchema,
        response: {
          200: {
            description: 'Created wallet(s). Tether: one wallet per user.',
            type: 'array',
            items: walletObjectSchema
          },
          400: {
            description: 'Validation error. Error codes: ERR_USERNAME_REQUIRED, ERR_USERNAME_LENGTH, ERR_USERNAME_INVALID_CHARS, ERR_USERNAME_MIN_DIGITS, ERR_USERNAME_MIN_LETTERS',
            ...errorResponseSchema
          },
          422: { description: 'Schema validation failed', ...errorResponseSchema },
          429: { description: 'Rate limit exceeded', ...errorResponseSchema }
        }
      },
      preHandler: async (req, rep) => {
        await middleware.auth.guard(ctx, req)
        await rateLimitMiddleware(ctx, req, rep, {
          max: ctx.conf?.rateLimit?.wallets?.max || 100,
          timeWindow: ctx.conf?.rateLimit?.wallets?.timeWindow || 24 * 60 * 60 * 1000
        })
      },
      handler: async (req, rep) => {
        const body = (req.body || []).map(w => ({ ...w, type: 'user' }))
        for (const w of body) {
          if (w.username != null && String(w.username).trim() !== '') {
            const format = validateUsernameFormat(w.username)
            if (!format.valid) {
              const err = createAppError(format.reason, 400)
              err.code = format.code
              throw err
            }
            w.username = format.normalized
          }
        }
        const res = await service.ork.addWallet(ctx, { ...req, body })
        return rep.status(200).send(res)
      }
    },
    {
      method: 'PATCH',
      url: '/api/v1/wallets/:id',
      schema: {
        description: 'Update a wallet by ID. Body: addresses?, meta?. Requires Bearer token.',
        tags: ['Wallets'],
        summary: 'Update wallet',
        security: [{ bearerAuth: [] }],
        params: {
          type: 'object',
          additionalProperties: false,
          properties: {
            id: { type: 'string' }
          },
          required: ['id']
        },
        body: patchWalletsBodySchema,
        response: {
          200: {
            description: 'Wallet(s) updated.',
            ...walletObjectSchema
          },
          400: {
            description: 'Validation error',
            ...errorResponseSchema
          },
          422: { description: 'Schema validation failed', ...errorResponseSchema },
          429: { description: 'Rate limit exceeded', ...errorResponseSchema }
        }
      },
      preHandler: async (req, rep) => {
        await middleware.auth.guard(ctx, req)
      },
      handler: async (req, rep) => {
        const res = await wdkService.ork.updateWallet(ctx, req)
        return rep.status(200).send(res)
      }
    },
    {
      method: 'POST',
      url: '/api/v1/username/suggest',
      config: {
        rateLimit: {
          max: ctx.conf.rateLimit?.umaSuggest?.max || 30,
          timeWindow: ctx.conf.rateLimit?.umaSuggest?.timeWindow || 60000
        }
      },
      schema: {
        description: 'Suggest an available UMA username from email. Username rules: 4-15 characters, at least 1 letter, at least 1 digit, letters and digits only (no special characters).',
        tags: ['UMA'],
        summary: 'Suggest username',
        security: [{ bearerAuth: [] }],
        body: {
          type: 'object',
          properties: { email: { type: 'string', format: 'email' } },
          required: ['email'],
          additionalProperties: false
        },
        response: {
          200: {
            type: 'object',
            properties: { username: { type: 'string' } }
          },
          400: {
            description: 'Invalid request',
            ...errorResponseSchema
          },
          409: {
            description: 'Could not suggest available username',
            ...errorResponseSchema
          }
        }
      },
      preHandler: async (req, rep) => {
        await middleware.auth.guard(ctx, req)
      },
      handler: createHandler(ctx, (req) => service.uma.suggest(ctx, req))
    },
    {
      method: 'POST',
      url: '/api/v1/username/check',
      config: {
        rateLimit: {
          max: ctx.conf.rateLimit?.umaCheck?.max || 30,
          timeWindow: ctx.conf.rateLimit?.umaCheck?.timeWindow || 60000
        }
      },
      schema: {
        description: `Check if UMA username is available and valid.

**Username validation rules:**
- Length: 4-15 characters
- Must contain at least 1 letter (a-z)
- Must contain at least 1 digit (0-9)
- Allowed characters: lowercase letters (a-z), digits (0-9) only (no special characters)
- Uppercase letters are auto-normalized to lowercase`,
        tags: ['UMA'],
        summary: 'Check username availability',
        security: [{ bearerAuth: [] }],
        body: {
          type: 'object',
          properties: {
            username: { type: 'string', description: 'Username to check (4-15 chars, letters and digits only, no special characters)' }
          },
          required: ['username'],
          additionalProperties: false
        },
        response: {
          200: {
            type: 'object',
            properties: {
              available: { type: 'boolean', description: 'True if username is available and valid' },
              reason: { type: 'string', description: 'Error message if not available (validation failed or taken)' },
              code: { type: 'string', description: 'Error code: ERR_USERNAME_LENGTH, ERR_USERNAME_INVALID_CHARS, ERR_USERNAME_MIN_DIGITS, ERR_USERNAME_MIN_LETTERS' }
            }
          }
        }
      },
      preHandler: async (req, rep) => {
        await middleware.auth.guard(ctx, req)
      },
      handler: createHandler(ctx, (req) => service.uma.check(ctx, req))
    },
    {
      method: 'GET',
      url: '/.well-known/lnurlp/:username',
      config: {
        rateLimit: {
          max: ctx.conf.rateLimit?.lnurlpLookup?.max || 30,
          timeWindow: ctx.conf.rateLimit?.lnurlpLookup?.timeWindow || 60000
        }
      },
      schema: {
        description: `LNURL-P endpoint for UMA/Lightning payments. Supports two modes:
- **Lookup** (no query params): Returns payment capabilities including supported currencies, settlement options, and callback URL
- **Pay** (with amount): Returns payment address (EVM) or proxies to Lightning indexer for invoice creation

Settlement layers: lightning, ln, spark (Lightning Network), ethereum, polygon, arbitrum, plasma (EVM chains), tron`,
        tags: ['UMA'],
        summary: 'LNURL-P lookup or pay request',
        security: [],
        params: {
          type: 'object',
          properties: {
            username: { type: 'string', description: 'UMA username (e.g. alice123)' }
          },
          required: ['username']
        },
        querystring: {
          type: 'object',
          properties: {
            amount: { type: 'string', description: 'Amount in smallest unit of the currency (required for pay request)' },
            settlementLayer: { type: 'string', enum: getUmaChainsConfig(ctx.conf).settlementLayerEnum, description: 'Settlement layer: lightning, ln, spark, ethereum, polygon, arbitrum, plasma, tron' },
            settlementAsset: { type: 'string', enum: getUmaChainsConfig(ctx.conf).supportedCurrencies, description: 'Asset identifier: btc, sat, usdt, xaut' }
          }
        },
        response: {
          200: {
            description: 'Lookup response (no amount) or Pay response (with amount)',
            oneOf: [
              {
                type: 'object',
                description: 'Lookup response - payment capabilities',
                properties: {
                  tag: { type: 'string', enum: ['payRequest'], description: 'Always "payRequest" for LNURL-P' },
                  callback: { type: 'string', description: 'URL for pay request (e.g. /api/lnurl/payreq/:sparkIdentityKey)' },
                  minSendable: { type: 'integer', description: 'Minimum sendable amount in millisatoshis' },
                  maxSendable: { type: 'integer', description: 'Maximum sendable amount in millisatoshis' },
                  metadata: { type: 'string', description: 'JSON-encoded metadata array with text/plain and text/identifier' },
                  commentAllowed: { type: 'integer', description: 'Max comment length (default 255)' },
                  currencies: {
                    type: 'array',
                    description: 'Supported currencies for conversion',
                    items: {
                      type: 'object',
                      properties: {
                        code: { type: 'string', description: 'Currency code (btc, sat, usdt, xaut)' },
                        name: { type: 'string', description: 'Currency display name' },
                        symbol: { type: 'string', description: 'Currency symbol' },
                        decimals: { type: 'integer', description: 'Decimal places' },
                        convertible: {
                          type: 'object',
                          properties: {
                            min: { type: 'integer', description: 'Minimum convertible amount' },
                            max: { type: 'integer', description: 'Maximum convertible amount' }
                          }
                        },
                        multiplier: { type: 'number', description: 'Conversion multiplier' }
                      }
                    }
                  },
                  payerData: {
                    type: 'object',
                    description: 'Required payer data fields',
                    properties: {
                      name: { type: 'object', properties: { mandatory: { type: 'boolean' } } },
                      email: { type: 'object', properties: { mandatory: { type: 'boolean' } } },
                      identifier: { type: 'object', properties: { mandatory: { type: 'boolean' } } },
                      compliance: { type: 'object', properties: { mandatory: { type: 'boolean' } } }
                    }
                  },
                  umaVersion: { type: 'string', description: 'UMA protocol version (1.0)' },
                  defaultSettlementLayer: { type: 'string', description: 'Default settlement layer (lightning)' },
                  defaultAssetIdentifier: { type: 'string', description: 'Default asset (sat)' },
                  settlementOptions: {
                    type: 'array',
                    description: 'Available settlement options based on wallet addresses',
                    items: {
                      type: 'object',
                      properties: {
                        settlementLayer: { type: 'string', description: 'Layer name (ethereum, polygon, lightning, etc.)' },
                        assets: {
                          type: 'array',
                          items: {
                            type: 'object',
                            properties: {
                              identifier: { type: 'string', description: 'Asset identifier (usdt, xaut, btc)' },
                              multipliers: { type: 'object', description: 'Currency multipliers' }
                            }
                          }
                        }
                      }
                    }
                  }
                },
                additionalProperties: true
              },
              {
                type: 'object',
                description: 'Pay response - Lightning invoice or EVM address',
                properties: {
                  pr: { type: 'string', description: 'BOLT11 invoice (Lightning) or wallet address (EVM chains like 0x...)' },
                  routes: { type: 'array', items: { type: 'object' }, description: 'Route hints (usually empty)' },
                  successAction: {
                    type: 'object',
                    description: 'Action to show on payment success',
                    properties: {
                      tag: { type: 'string', description: 'Action type (message)' },
                      message: { type: 'string', description: 'Success message' }
                    }
                  },
                  payeeData: {
                    type: 'object',
                    description: 'Receiver information',
                    properties: {
                      identifier: { type: 'string', description: 'UMA identifier ($username@domain)' }
                    }
                  }
                },
                additionalProperties: true
              },
              {
                type: 'null',
                description: 'Null when wallet address not found for the requested layer/asset'
              }
            ]
          },
          400: {
            type: 'object',
            description: 'Bad request - invalid parameters',
            properties: {
              statusCode: { type: 'integer' },
              error: { type: 'string' },
              message: { type: 'string', description: 'Error codes: ERR_UMA_AMOUNT_INVALID, ERR_UMA_SETTLEMENT_LAYER_INVALID, ERR_UMA_SETTLEMENT_ASSET_INVALID' }
            }
          },
          404: {
            type: 'object',
            description: 'User not found',
            properties: {
              statusCode: { type: 'integer' },
              error: { type: 'string' },
              message: { type: 'string', description: 'ERR_UMA_USER_NOT_FOUND' }
            }
          }
        }
      },
      handler: async (req, rep) => {
        const { username } = req.params
        const query = req.query || {}
        const protocol = req.headers['x-forwarded-proto'] || req.protocol || 'https'
        const host = req.headers['x-forwarded-host'] || req.hostname || 'localhost'
        const baseUrl = `${protocol}://${host}`.replace(/\/$/, '')
        const fakeReq = { _info: {} }
        try {
          const data = await service.uma.lnurlp(ctx, fakeReq, username, query, baseUrl)
          return send200(rep, data)
        } catch (err) {
          throw ctx.httpd_h0.server.httpErrors.createError(err.statusCode ?? statusFromMessage(err.message) ?? 500, err.message)
        }
      }
    },

    {
      method: 'GET',
      url: '/api/lnurl/payreq/:uuid',
      config: {
        rateLimit: {
          max: ctx.conf.rateLimit?.lnurlPayreq?.max || 30,
          timeWindow: ctx.conf.rateLimit?.lnurlPayreq?.timeWindow || 60000
        }
      },
      schema: {
        description: `LNURL-P pay request endpoint for Lightning Network (Spark). Proxies requests to the Spark indexer service (wdk-indexer-wrk-spark) which handles:
- UMA protocol signature verification
- Lightning invoice creation via Spark wallet
- UMA-compliant response generation

This endpoint is the callback URL returned in the LNURL-P lookup response for Lightning settlements.`,
        tags: ['UMA'],
        summary: 'LNURL-P pay request (Lightning/Spark)',
        security: [],
        params: {
          type: 'object',
          properties: {
            uuid: { type: 'string', description: 'Spark identity public key (hex-encoded)' }
          },
          required: ['uuid']
        },
        querystring: {
          type: 'object',
          additionalProperties: true,
          properties: {
            amount: { type: 'string', description: 'Amount in millisatoshis (required)' },
            receivingCurrencyCode: { type: 'string', description: 'Receiving currency code (SAT, BTC)' },
            sendingAmountCurrencyCode: { type: 'string', description: 'Sending currency code' },
            comment: { type: 'string', description: 'Optional payment comment (max 255 chars)' }
          }
        },
        response: {
          200: {
            type: 'object',
            additionalProperties: true,
            description: 'UMA PayReqResponse with Lightning invoice',
            properties: {
              pr: { type: 'string', description: 'BOLT11 Lightning invoice for payment' },
              routes: {
                type: 'array',
                items: { type: 'object', additionalProperties: true },
                description: 'Route hints (usually empty, included in BOLT11)'
              },
              disposable: { type: 'boolean', description: 'If false, LNURL link can be reused' },
              successAction: {
                type: 'object',
                additionalProperties: true,
                description: 'Action shown on payment success (LUD-09)',
                properties: {
                  tag: { type: 'string', description: 'Action type (message)' },
                  message: { type: 'string', description: 'Success message' }
                }
              },
              payeeData: {
                type: 'object',
                additionalProperties: true,
                description: 'Receiver information',
                properties: {
                  identifier: { type: 'string', description: 'UMA identifier' },
                  name: { type: 'string', description: 'Receiver name' },
                  email: { type: 'string', description: 'Receiver email' }
                }
              },
              converted: {
                type: 'object',
                additionalProperties: true,
                description: 'Currency conversion details',
                properties: {
                  amount: { type: 'integer', description: 'Amount in receiving currency smallest unit' },
                  currencyCode: { type: 'string', description: 'Currency code (SAT)' },
                  decimals: { type: 'integer', description: 'Decimal places' },
                  fee: { type: 'integer', description: 'Fee amount' },
                  multiplier: { type: 'number', description: 'Exchange rate multiplier' }
                }
              }
            }
          },
          400: {
            type: 'object',
            description: 'Bad request - missing or invalid parameters',
            properties: {
              status: { type: 'string', enum: ['ERROR'] },
              reason: { type: 'string', description: 'Error message (e.g. amount required)' }
            }
          },
          500: {
            type: 'object',
            description: 'Internal server error',
            properties: {
              status: { type: 'string', enum: ['ERROR'] },
              reason: { type: 'string', description: 'Error message' }
            }
          }
        }
      },
      handler: async (req, rep) => {
        const uuid = req.params.uuid
        const protocol = req.headers['x-forwarded-proto'] || req.protocol || 'https'
        const host = req.headers['x-forwarded-host'] || req.hostname || 'localhost'
        const baseUrl = `${protocol}://${host}`.replace(/\/$/, '')
        const fullUrl = `${baseUrl}${req.url}`
        try {
          const response = await service.indexer.handleLnurlPayreq(ctx, uuid, fullUrl)
          return rep.status(response.httpStatus || 200).send(response.data)
        } catch (err) {
          const code = err.statusCode ?? statusFromMessage(err.message) ?? 500
          const reason = err.message ?? 'Internal server error'
          return rep.status(code).send({ status: 'ERROR', reason })
        }
      }
    },

    {
      method: 'POST',
      url: '/api/uma/payreq/:uuid',
      config: {
        rateLimit: {
          max: ctx.conf.rateLimit?.umaPayreq?.max || 30,
          timeWindow: ctx.conf.rateLimit?.umaPayreq?.timeWindow || 60000
        }
      },
      schema: {
        description: `UMA protocol pay request endpoint (POST). Handles the second step of UMA payment flow:

**For EVM and Tron chains** (ethereum, polygon, arbitrum, plasma):
- Returns the wallet address directly from the user's wallet
- No Lightning invoice creation needed

**For Lightning** (lightning, ln, spark):
- Proxies request to Spark indexer service
- Indexer handles UMA signature verification and invoice creation

This endpoint is called by sending VASPs after the initial LNURL-P lookup.`,
        tags: ['UMA'],
        summary: 'UMA pay request (POST)',
        security: [],
        params: {
          type: 'object',
          properties: {
            uuid: { type: 'string', description: 'User ID or username for lookup' }
          },
          required: ['uuid']
        },
        body: {
          type: 'object',
          additionalProperties: true,
          description: 'UMA PayRequest object from sending VASP',
          properties: {
            receivingCurrencyCode: {
              type: 'string',
              description: 'Settlement layer/currency: SAT, BTC (Lightning), polygon, ethereum, arbitrum, plasma (EVM), tron'
            },
            amount: { type: 'integer', description: 'Amount in smallest unit (millisatoshis for Lightning)' },
            sendingAmountCurrencyCode: { type: 'string', description: 'Currency code of sending amount' },
            payerData: {
              type: 'object',
              additionalProperties: true,
              description: 'Information about the payer',
              properties: {
                identifier: { type: 'string', description: 'UMA address of payer ($alice@vasp.com)' },
                name: { type: 'string', description: 'Payer name' },
                email: { type: 'string', description: 'Payer email' },
                compliance: {
                  type: 'object',
                  additionalProperties: true,
                  description: 'Compliance data (signature, signatureNonce, etc.)'
                }
              }
            },
            requestedPayeeData: {
              type: 'object',
              additionalProperties: true,
              description: 'Data requested about the payee'
            },
            comment: { type: 'string', description: 'Optional payment comment (max 255 chars)' }
          }
        },
        response: {
          200: {
            type: 'object',
            additionalProperties: true,
            description: 'PayReqResponse - varies by settlement layer',
            properties: {
              pr: { type: 'string', description: 'BOLT11 invoice (Lightning) or EVM wallet address (0x...)' },
              routes: { type: 'array', items: { type: 'object' }, description: 'Route hints (empty for EVM)' },
              successAction: {
                type: 'object',
                additionalProperties: true,
                description: 'Action shown on success',
                properties: {
                  tag: { type: 'string' },
                  message: { type: 'string' }
                }
              },
              payeeData: {
                type: 'object',
                additionalProperties: true,
                description: 'Receiver information',
                properties: {
                  identifier: { type: 'string', description: 'UMA identifier ($username@domain)' }
                }
              },
              converted: {
                type: 'object',
                additionalProperties: true,
                description: 'Currency conversion details (Lightning only)',
                properties: {
                  amount: { type: 'integer' },
                  currencyCode: { type: 'string' },
                  decimals: { type: 'integer' },
                  fee: { type: 'integer' },
                  multiplier: { type: 'number' }
                }
              }
            }
          },
          400: {
            type: 'object',
            description: 'Bad request',
            properties: {
              status: { type: 'string', enum: ['ERROR'] },
              reason: { type: 'string', description: 'ERR_UMA_SPARK_IDENTITY_KEY_NOT_FOUND, ERR_UMA_WALLET_ADDRESS_NOT_FOUND' }
            }
          },
          401: {
            type: 'object',
            description: 'Unauthorized - signature verification failed',
            properties: {
              status: { type: 'string', enum: ['ERROR'] },
              reason: { type: 'string' }
            }
          },
          404: {
            type: 'object',
            description: 'User not found',
            properties: {
              status: { type: 'string', enum: ['ERROR'] },
              reason: { type: 'string', description: 'ERR_UMA_USER_NOT_FOUND' }
            }
          },
          500: {
            type: 'object',
            description: 'Internal server error',
            properties: {
              status: { type: 'string', enum: ['ERROR'] },
              reason: { type: 'string' }
            }
          }
        }
      },
      handler: async (req, rep) => {
        const uuid = req.params.uuid
        const protocol = req.headers['x-forwarded-proto'] || req.protocol || 'https'
        const host = req.headers['x-forwarded-host'] || req.hostname || 'localhost'
        const baseUrl = `${protocol}://${host}`.replace(/\/$/, '')
        const fullUrl = `${baseUrl}${req.url}`
        try {
          const response = await service.uma.handleUmaPayreq(ctx, req, uuid, fullUrl, req.body)
          return rep.status(response.httpStatus || 200).send(response.data)
        } catch (err) {
          const code = err.statusCode ?? statusFromMessage(err.message) ?? 500
          const reason = err.message ?? 'Internal server error'
          return rep.status(code).send({ status: 'ERROR', reason })
        }
      }
    },

    {
      method: 'POST',
      url: '/api/v1/logs',
      bodyLimit: ctx.conf.logs?.validation?.maxBodyBytes || 524288,
      config: {
        rateLimit: {
          max: ctx.conf.logs?.rateLimit?.maxRequestsPerMinute || 120,
          timeWindow: 60000,
          keyGenerator: (req) => {
            const authHeader = req.headers.authorization
            if (authHeader && authHeader.startsWith('Bearer ')) {
              return `logs:auth:${authHeader.substring(7, 50)}`
            }
