# Handling — WDK-1589 migrate the user-data API to the wdk base layer

## Type
refactor (fold-in of the WDK-1522 batch feature, per Alex's decision 2026-07-02)

## What was done
The full user-data key/value API (single-key set/get/delete plus the WDK-1522 batch
set/get) now lives in the wdk base; both forks were deduplicated down to their genuinely
product-specific overrides. All 9 repos changed locally, nothing committed.

### Base (additive, versions bumped to 0.2.0)

**wdk-data-shard-wrk**
- Repos: `getUserDataMulti` (returns an array on both engines) and `countByKeyPrefix`
  added to the abstract, Mongo (escaped regex + maxTimeMS, TW's safer variant) and
  HyperDB repos. HyperDB count uses an open-ended prefix scan with break-on-first-miss;
  the review caught that Rumble's original `lt: prefix + '￿'` bound misses
  astral-plane keys (quota bypass, reproduced live) and the fix is verified against a
  real hyperdb.
- `workers/lib/utils/user.data.util.js`: `getUserDataLimits(conf)` (kills the 4x
  duplication) + `escapeRegexPrefix`.
- api worker: `_validateUserDataKey`, the 5 public handlers with full validation
  (ERR_INVALID_KEY/PREFIX/KEY_TOO_LONG/VALUE_TOO_LARGE/INVALID_BATCH/BATCH_TOO_LARGE/
  DUPLICATE_KEY), reads on the replica, writes forwarded to proc; registered in
  rpcActions. Hook: `_userDataRepoForKey(key)` (default mutable repo), now used by
  `_getUserData`.
- proc worker: `setUserData`, `deleteUserData`, `setUserDataBatch` (single UoW, one
  commit, idempotent upserts); `storeUserData`/`delUserData` now route through
  `_userDataRepoForKey(key, uowOrDb)`. Hooks: `_countUserDataKeysForLimit` (default
  mutable count) and `_onUserDataMutated` (default no-op, called after successful
  set/batch/delete). Registered in proc rpcActions.
- Config example gets the `userData` block; ported Rumble's hyperdb integration suite
  as `tests/user-data.intg.test.js` (hermetic: `lookupEngine: 'autobase'`, replica reads
  poll instead of fixed sleeps) plus unit tests for handlers, hooks, repos, util.

**wdk-ork-wrk**: five plain `_rpcRequest(req, action)` forwarders (base `_rpcRequest`
already resolves the user shard from `req.userId` — same resolution path the forks used
explicitly) + rpcActions + unit tests.

**wdk-app-node**: the 5 routes with TW's full schemas/swagger metadata (batch `maxItems`
from `conf.userData?.maxKeysPerUser ?? 100`); `services/ork.js` methods (batch GET
normalizes a single `keys` value to an array); `getUserData`/`getUserDataBatch`/
`deleteUserData` added to CORE_RETRYABLE_METHODS (deletes are idempotent staged
deleteOnes); 9 error codes added to `errorsCodes.js`; the shared route errorHandler in
`base.http.server.wdk.js` now maps raw Mongo `E11000`/`duplicate key` messages to 409
(review finding: TW's deleted `createHandler`/`statusFromMessage` used to do this; the
base Map lookup alone would have turned that rare unique-index race into a 500).

### tether-wallet fork (dedup + overrides kept)
- data-shard: deleted duplicated limits/validation/handlers and its repo subclass
  (both methods now in base; contexts/UoW rewired to the base repo class). KEPT:
  `_userDataRepoForKey` immutable routing (api + proc), `delUserData` immutable
  `ERR_METHOD_DISABLED` guard (now a slim pre-check + `super.delUserData`),
  `_countUserDataKeysForLimit` override (mutable + immutable counts, same thresholds),
  `_onUserDataMutated` override (metadata LRU invalidation; now also fires on delete,
  fixing the old staleness bug), `USER_METADATA_CACHE_KEYS` const in constants.js,
  `userDataKeys.util.js` untouched. `_getUserMetadata` adapted to the array-returning
  `getUserDataMulti`.
- ork: deleted the 3 forwarders + registrations.
- app-node: deleted the 3 routes + service methods; `getUserLanguage` now calls
  `baseOrkService.getUserData` (same retry semantics, `getUserData` is core-retryable);
  removed `getUserData`/`deleteUserData` from the fork RETRYABLE set (core now).
  `appError.js` left untouched (its user-data entries are harmless duplicates of the
  base map and `statusFromMessage` still serves other TW routes).
- New `tests/user-data.http.intg.test.js` pins the TW wire contract on a booted worker:
  POST 200 `{success}`, GET 200 `{value}`, DELETE 204 empty, batch shapes, 422 schema,
  400 mappings — byte-identical to before the migration (verified 9/9 locally).

### rumble fork (pure dedup)
- data-shard: deleted duplicated limits/validation/handlers and BOTH `userdata.js` repo
  subclasses (contexts fall back to the base repos, which now carry both methods with
  the regex-escape fix Rumble's Mongo copy lacked).
- ork: deleted the 3 forwarders + registration entries.
- app-node: deleted the 3 routes + service wrappers + the warn-only response-validator
  entries; removed `getUserData` from RUMBLE_EXTRA_RETRYABLE_METHODS. New
  `tests/user-data.http.intg.test.js` pins the approved new wire behavior (8/8 locally).

## Approved behavior changes shipped (Alex, 2026-07-02)
- Rumble DELETE /api/v1/user-data: 200 + body -> 204 empty.
- Rumble shard validation errors: unmapped 500s -> 400 (also de-noises Sentry).
- Rumble gains POST/GET /api/v1/user-data/batch.
- `deleteUserData` becomes ork-retryable everywhere (idempotent).
- TW `deleteUserData` now invalidates the metadata LRU (bug fix).
- TW wire: unchanged, verified byte-identical by review.

## Adversarial review (10-agent workflow) — outcomes
- CONFIRMED + FIXED: hyperdb `countByKeyPrefix` astral-key quota bypass (see above).
- CONFIRMED + FIXED: E11000 -> 409 mapping loss on the migrated TW routes (base
  errorHandler branch added + test).
- CONFIRMED, sequencing (no local fix possible): fork pins are NOT bumped — the new base
  SHAs don't exist until the base PRs merge. **Each fork PR must bump its
  `@tetherto/wdk-*` pin in the same commit that deletes the fork code**, otherwise the
  fork loses its user-data API entirely.
- CONFIRMED, low, operational: the batch endpoints appear on any app-node the moment its
  base pin bumps; against an old ork/shard they fail as protomux `UNKNOWN_METHOD` -> 500.
  Deploy order per family: **data-shard -> ork -> app-node**. The single-key path is
  wire-compatible in every mixed old/new combination (verified).
- CONFIRMED env-limitation: the new base intg suite's replica read-back tests stall on
  this machine (hyperdb swarm replication never converges locally; the untouched wallet
  path stalls identically on clean HEAD, and the pre-existing intg suites can't even
  boot here — Mongo auth). Proc-side/validation tests pass locally. Needs one
  green-infra run; note CI's integration job is non-blocking.

## Tests (local)
- wdk-data-shard-wrk: unit 84/84, lint clean; new hyperdb repo methods additionally
  verified against a real hyperdb store (incl. astral-key regression); intg suite
  proc-side green, replica read-backs env-limited (above).
- wdk-ork-wrk: new tests 5/5; other suites green except one pre-existing crash
  (data.shard.util, reproduced on clean baseline); repo's own `standard` install is
  broken (pre-existing) — linted clean via a sibling repo's standard.
- wdk-app-node: unit 181/182 (pre-existing jwt-guard failure, baseline-verified),
  new integration 14/14, lint clean.
- tether-wallet-data-shard-wrk: unit 300/301 (pre-existing `deletedAt` failure), lint
  clean. tether-wallet-ork-wrk: 46/47 (pre-existing `_setupMongodbLookupEngine`).
  tether-wallet-app-node: unit 332/333 (pre-existing configureAuth, verified against
  pinned base too), new wire-contract intg 9/9, lint clean.
- rumble-data-shard-wrk: unit 95/97 (2 pre-existing rant-webhook failures), changed
  files lint clean (repo has pre-existing lint debt elsewhere). rumble-ork-wrk: 9/9.
  rumble-app-node: 5/5 + new intg 8/8, lint clean.
- The TW/rumble app-node intg suites need generated test config with `noAuth: true`
  (same coupling as the pre-existing intg suites); generated config was removed after
  verification.

## IMPORTANT: node_modules overlays
To run fork tests against the new base before any pin exists, each fork's
`node_modules/@tetherto/wdk-*/workers/` tree was rsync-overlaid with the local base
working tree (all six forks). This simulates the future pin bump. `npm ci`/`npm install`
restores the pinned state (and will break the fork user-data tests until the pins are
bumped to merged base SHAs).

## PR checklist (for /commit and the PR train)
1. DONE 2026-07-02: base PRs opened as drafts, rebased onto tetherto/dev (the merged
   tx-enrich work #257/#165/#136 was resolved into the branches):
   - wdk-data-shard-wrk: https://github.com/tetherto/wdk-data-shard-wrk/pull/269
   - wdk-ork-wrk: https://github.com/tetherto/wdk-ork-wrk/pull/171
   - wdk-app-node: https://github.com/tetherto/wdk-app-node/pull/144
   TW PRs #169/#81/#141 closed with pointers to these (Alex's call).
2. After base merges: bump each fork's base pin to the merged SHA **in the same PR** as
   the dedup, `npm install` (mind the `~/.npmrc` @tetherto registry 404 gotcha:
   `--@tetherto:registry=https://registry.npmjs.org`), re-run suites.
3. State the approved Rumble wire changes + the shard->ork->app-node deploy order in the
   fork PR descriptions.
4. Conflict watch (same files in flight): wdk-ork-wrk #165, wdk-data-shard-wrk #257/#263,
   wdk-app-node #136/#139, tether-wallet-app-node #159.
5. No data migration anywhere: collections, indexes, stored shapes and RPC action names
   are unchanged.
