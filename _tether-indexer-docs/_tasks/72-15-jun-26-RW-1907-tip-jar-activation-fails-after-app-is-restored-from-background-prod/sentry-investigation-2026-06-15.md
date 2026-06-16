# Sentry investigation - 2026-06-15 retest

Sentry host checked: `https://sentry.rumble.work/`

## Projects / environments

- Org: `rumble`
- `rumble-wallet-backend` environments: `production`, `staging`
- `rumble-wallet-app` environments: `development`, `production`

The mobile app project does not have a `staging` environment tag.

## Backend staging search

Project: `rumble-wallet-backend`

Queries:

- `event.type:error environment:staging`, `2026-06-15T08:00:00Z` to `2026-06-15T08:25:00Z`
- `event.type:error environment:staging`, `2026-06-15T07:00:00Z` to `2026-06-15T09:00:00Z`

Result: `0` events in both windows.

## Matching mobile app events

Project: `rumble-wallet-app`

The events matching the screenshot are tagged `production`, not `staging`:

- Release: `com.rumble.wallet@2.4.0`
- Dist/build: `207`
- OS/device: `iOS 27.0`, `iPhone15,2`
- User id: `Uj6xF1_KCeY`
- API host: `https://wallet-9p1aan4nff.rmbl.ws`

This matches the ticket screenshot (`v2.4.0(207)`, iPhone, same Tip Jar names).

### Device registration failure first

At `2026-06-15T08:13:52Z`-`08:13:53Z`, mobile Sentry recorded:

- Event issues: `RUMBLE-WALLET-APP-EC` / `RUMBLE-WALLET-APP-ED`
- Request: `POST /api/v1/device-ids`
- Status: `500`
- Error body: `{"statusCode":500,"error":"Internal Server Error","message":"[HRPC_ERR]=RPC client closed"}`

### Tip Jar toggle failures

At `2026-06-15T08:13:55Z`:

- Event issue: `RUMBLE-WALLET-APP-F0`
- Request: `PATCH /api/v1/wallets/e56f6b32-b04b-490d-9cf9-0fbee84028c3`
- Status: `500`
- Error body: `{"statusCode":500,"error":"Internal Server Error","message":"[HRPC_ERR]=RPC client closed"}`
- App log context:
  - `tipJarItemName`: `ggaphrindashvili's Tip Jar`
  - `walletId`: `e56f6b32-b04b-490d-9cf9-0fbee84028c3`
  - `enabled`: `true`
  - `channelId`: `user-Uj6xF1_KCeY`

At `2026-06-15T08:13:57Z`:

- Event issue: `RUMBLE-WALLET-APP-F0`
- Request: `PATCH /api/v1/wallets/cde0c56a-b925-46c5-81ec-73195059a8ff`
- Status: `500`
- Error body: `{"statusCode":500,"error":"Internal Server Error","message":"[HRPC_ERR]=RPC client closed"}`
- App log context:
  - `tipJarItemName`: `Cattsssss`
  - `walletId`: `cde0c56a-b925-46c5-81ec-73195059a8ff`
  - `enabled`: `false`
  - `channelId`: `oJ5tZCiyAfw`

These are the two exact Tip Jar names shown in `IMG_0992.jpg`.

## Backend production Sentry cross-check

Project: `rumble-wallet-backend`

Queries:

- `event.type:error environment:production`, `2026-06-15T08:13:40Z` to `2026-06-15T08:14:10Z`
- `event.type:error ("RPC client closed" OR wallet OR device-ids)`, same window

Result: `0` backend Sentry events.

## Conclusion

Staging Sentry is clean for the retest window. The matching mobile events are
production-tagged and show the app did send the Tip Jar toggle requests. Both
requests received backend HTTP `500` responses with `[HRPC_ERR]=RPC client
closed`.

This is not a frontend-only failure. The earlier staging log scan did not see
the failed requests because the matching app events were sent against
`wallet-9p1aan4nff.rmbl.ws` under Sentry `production`, not the staging backend
searched on `walletstg1`.

Next backend evidence to request/check: production logs for
`wallet-9p1aan4nff.rmbl.ws` around `2026-06-15T08:13:52Z`-`08:13:58Z`,
especially `POST /api/v1/device-ids` and the two `PATCH /api/v1/wallets/:id`
requests above.
