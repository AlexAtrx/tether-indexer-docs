# Handling — RW-1940 downgrade ERR_EXISTING_ADDRESS_SPARK_DATA_UPDATE_FORBIDDEN (stop Sentry error)

## Type
bug (error-classification bug surfaced as Sentry noise)

## What was wrong / wanted
`PATCH /api/v1/wallets/:id` raises `ERR_EXISTING_ADDRESS_SPARK_DATA_UPDATE_FORBIDDEN`
when a client tries to alter already-set Spark wallet data. This is an expected,
benign client-side rejection, but it was reaching Sentry as a production Error
(issue 132843, RUMBLE-WALLET-BACKEND-2K). It should not create Sentry error issues.

## Root cause
The error is thrown in `wdk-data-shard-wrk/workers/proc.shard.data.wrk.js:497`
(`updateWallet`) and propagates back over HRPC to the app-node HTTP boundary.

The app-node maps ork/shard error strings to HTTP status via
`wdk-app-node/workers/lib/utils/errorsCodes.js`. The non-Spark sibling
`ERR_EXISTING_ADDRESS_UPDATE_FORBIDDEN` is mapped to `403`, but the Spark variant
`ERR_EXISTING_ADDRESS_SPARK_DATA_UPDATE_FORBIDDEN` was missing from the map.

Consequences of the missing entry (`base.http.server.wdk.js:144-159`):
- The base error handler has no mapping, so it falls through to the 500 branch
  and returns HTTP 500 (wrong; it is a client 4xx, not a server fault).
- Rumble's Sentry handler `shouldHandleError` (`rumble-app-node/workers/http.node.wrk.js:160-167`)
  only skips capture for validation errors, 4xx `statusCode`, or codes that map
  to `< 500`. With no mapping and a 500 status, it returned `true`, so the error
  was captured as a Sentry Error.

The tripled `[HRPC_ERR]=[HRPC_ERR]=[HRPC_ERR]=` prefix seen in Sentry is from the
error crossing shard -> ork -> app-node; both the base handler (`replaceAll`,
line 146) and the Sentry predicate (`replaceAll`) already strip all copies, so
that was never the problem.

## Change
Added one entry to the base error-code map, mirroring its existing sibling:

`wdk-app-node/workers/lib/utils/errorsCodes.js`
```
ERR_EXISTING_ADDRESS_UPDATE_FORBIDDEN: 403,
ERR_EXISTING_ADDRESS_SPARK_DATA_UPDATE_FORBIDDEN: 403,   // added
```

With the mapping present: the base handler now returns HTTP 403 (correct), and
`shouldHandleError` returns false (both the `statusCode < 500` and the mapped
`< 500` checks pass), so Sentry skips the event entirely. This is the same
mechanism the codebase already uses to keep all other 4xx client errors out of
Sentry, and it is strictly stronger than the ticket's "log as warning" ask.

## Repos touched
- `wdk-app-node` — added `ERR_EXISTING_ADDRESS_SPARK_DATA_UPDATE_FORBIDDEN: 403`
  to `workers/lib/utils/errorsCodes.js`; added unit test
  `tests/unit/utils/errorsCodes.test.js`.

Not changed:
- `wdk-data-shard-wrk` — the throw site is correct; only the HTTP-layer
  classification was wrong, so no change there.
- `rumble-app-node` — its `errorsCodes.js` merges on top of the base map, so it
  inherits the new entry automatically. Adding it there too would be a duplicate.

## Layering / idempotency / separation notes
- Layering: HTTP-status and Sentry-capture classification belong at the
  `-app-node` HTTP boundary, which is exactly the error-code map. Spark wallet
  data is WDK-generic (the throw is in the WDK shard, and the sibling code lives
  in the base map), so the fix belongs in base `wdk-app-node`, not the Rumble fork.
- Idempotency: N/A. No request/mutation added or changed; this is pure
  error-to-status mapping data.
- Separation of concerns / HyperDB: untouched.

## Tests
- `wdk-app-node`: `npx brittle tests/unit/utils/errorsCodes.test.js` — 2/2 pass
  (asserts the new code maps to 403 and is `< 500`, the Sentry-skip threshold).
- `wdk-app-node`: `npx brittle tests/unit/utils/*.test.js` — 13/13 pass (no regressions).
- `npx standard` on both changed files — clean.

## Sentry connection note
Sentry MCP auth works (`whoami` = Alex Atrash, org `rumble`). Issue 132843 was
read via `get_sentry_resource`. The query/event tools (`search_issue_events`,
`search_events`) failed with an OpenAI quota error on the Sentry MCP server side
(those endpoints run an embedded LLM to translate queries; its OpenAI key is over
quota). Direct resource fetch and auth are unaffected.

## Assumptions / open points
- The local `wdk-app-node` clone was already on branch `dev` with unrelated
  uncommitted WIP (server.js, ork.js, response.validator.js, schemas, config).
  My change is isolated to `errorsCodes.js` + the new test; I did not touch the WIP.
- To reach Rumble production, `rumble-app-node` consumes `wdk-app-node` as a
  git-pinned dependency, so the pin must be bumped to a commit that includes this
  entry. That bump/commit/release is left to Alex (no commits/pushes were made).
