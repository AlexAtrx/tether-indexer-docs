# PR diffs — the fix

Both PRs are the same change: re-pin `@bitfinex/bfx-facs-db-mongo` from the default branch (master, commit `90db1de`, `mongodb ^3.7.3`) to the `feature/mongodb-v6-driver` branch (commit `3a3e1358`, `mongodb ^6.21.0`). The leak came from the v3 driver — Node's `[DEP0170] DeprecationWarning: The URL mongodb://...` is emitted by the v3 connection-string parser path and prints the URL verbatim. The v6 driver doesn't go through that path.

## tetherto/wdk-ork-wrk PR #115

- Title: `fix: upgrade bfx-facs-db-mongo to mongodb v6 driver (WDK-1255)`
- Merged: 2026-04-14T11:25:08Z
- Files: `package.json` (+1/-1), `package-lock.json` (+102/-144)

`package.json` change:

```diff
   "dependencies": {
-    "@bitfinex/bfx-facs-db-mongo": "git+https://github.com/bitfinexcom/bfx-facs-db-mongo.git",
+    "@bitfinex/bfx-facs-db-mongo": "github:bitfinexcom/bfx-facs-db-mongo#feature/mongodb-v6-driver",
```

## tetherto/wdk-indexer-wrk-base PR #104

- Title: `fix: upgrade bfx-facs-db-mongo to mongodb v6 driver (WDK-1255)`
- Merged: 2026-04-14T11:25:36Z
- Files: `package.json` (+1/-1), `package-lock.json` (+103/-153)

`package.json` change (identical to #115):

```diff
   "dependencies": {
-    "@bitfinex/bfx-facs-db-mongo": "git+https://github.com/bitfinexcom/bfx-facs-db-mongo.git",
+    "@bitfinex/bfx-facs-db-mongo": "github:bitfinexcom/bfx-facs-db-mongo#feature/mongodb-v6-driver",
```

PR #104 also incidentally drops `test-tmp` from devDependencies — unrelated cleanup.

## What the lock-file change implies (for the data-shard mirror)

Going from v3 to v6 of the `mongodb` driver is a major bump and carries some real API differences (return shapes from `insertOne`/`updateOne`, removed `useNewUrlParser`/`useUnifiedTopology` options, `Cursor` API changes, etc.). For the indexer/ork PRs it was apparently a no-op at the call site — `bfx-facs-db-mongo` absorbs the change behind its facade. For the data shard, **before merging the package.json bump, grep for any direct `mongodb` API usage** (`require('mongodb')`, `MongoClient`, raw cursor methods) — if there's none and everything goes through `bfx-facs-db-mongo`, it's a clean mirror. If anything calls `mongodb` directly, those call sites likely need a v6 audit.

## Mirror recipe for `wdk-data-shard-wrk` (and any other consumer)

1. In the repo root, edit `package.json` exactly as above.
2. `rm -rf node_modules package-lock.json && npm install` to regenerate the lock cleanly.
3. Boot locally and confirm `[DEP0170]` no longer appears.
4. (Optional, repo-wide audit): `grep -r "require('mongodb')" .` — should return nothing if the facade is the only consumer.
