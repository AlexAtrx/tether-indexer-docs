Support setting multiple user_data keys in a single request.

Today the user_data key/value endpoints only operate on ONE key per request:

- POST   /api/v1/user-data  -> body { key, value } -> service.ork.setUserData -> shard rpc "setUserData" (validates single key, value size <= valueMaxSize)
- GET    /api/v1/user-data  -> querystring { key } -> getUserData -> { value }

No need to have a multi-delete endpoint


A client that needs to persist several keys must make multiple sequential POSTs, each its own shard rpc round-trip.

Proposal:
Add one new endpoint that accepts a batch of key/value entries and sets them in a single call
(one batch get and one batch post)


Scope / tasks:
- Decide between a new batch endpoint vs. extending POST /api/v1/user-data (lean toward extending, keeping single-key backward compatibility).
- Define + validate the multi-key request schema in server.js; enforce per-key validation (keyMaxLength, valueMaxSize) and the maxKeysPerUser limit across the batch.
- Wire through service.ork to a batched shard rpc
- Update swagger schema/docs and add tests.

details:

(tether-wallet-app-node/workers/lib/server.js, "User data" routes ~L758-854; data-shard worker tether-wallet-data-shard-wrk/workers/api.shard.data.wrk.js setUserData/getUserData/deleteUserData ~L208-231; validation/limits in lib/utils/userDataKeys.util.js — keyMaxLength, valueMaxSize, maxKeysPerUser, keyPrefix.)
