Bug: seed.recovery worker assumes `blockchains` config is a flat array, but the config shape changed to an object/map — causing a prod error.

## Root cause

`workers/lib/services/seed.recovery.js:45` checks:

    ctx.conf.blockchains?.includes(chain)

This assumes `blockchains` is a flat array, e.g.:

    "blockchains": [
      "ethereum",
      "arbitrum",
      ...
    ]

But the blockchain config changed shape and is now an object keyed by chain name:

    "blockchains": {
      "ethereum": { ... },
      ...
    }

`.includes()` does not exist on a plain object, so the check breaks.

## References

- Offending code: https://github.com/tetherto/rumble-app-node/blob/a4fbcccaf698ee79cc09879b94837f10c81bb3b7/workers/lib/services/seed.recovery.js#L45
- New config shape: https://github.com/tetherto/wdk-app-node/blob/0a59b79d1d78db9e30f1c399e2576b83cc6a480f/config/common.json.example#L28

## Prod error (2026-05-28T17:52:48)

    {"level":50,"time":1779990768775,"pid":918258,"hostname":"walletprd3","name":"wrk-node-http-3000-10147b65-b966-4aaa-bd02-added8634274","traceId":"mob:276854334:b43b9873-9324-4217-a10b-39e138efb1d4","err":{"type":"Error","message":"RPC client closed","stack":"Error: RPC client closed\n    at cleanRpcError (/srv/data/production/rumble-app-node/workers/lib/services/promo.js:42:10)\n    at Object.claimCode (/srv/data/production/rumble-app-node/workers/lib/services/promo.js:65:11)\n    at async Object.handler (/srv/data/production/rumble-app-node/workers/lib/server.js:552:16)"},"errorCode":"ERR_ROUTE_UNHANDLED","msg":"Unhandled route error"}

Grafana: http://rwg.rmbl.ws:3000/goto/qgkOEl1vR?orgId=1

## Fix

Update the `blockchains` membership check to handle the new object shape (e.g. `chain in ctx.conf.blockchains` or `Object.keys(ctx.conf.blockchains).includes(chain)`), and audit other call sites that still treat `blockchains` as an array.
