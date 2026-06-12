# Handling — WDK-1519 Fix critical/high npm audit vulns in rumble-promo-wrk

## Type
Refactor (dependency bumps) + triage/justification.

## What was wanted
Fix all CRITICAL and HIGH `npm audit` vulns in `rumble-promo-wrk`; for anything
unfixable, write a justification to share with Andrei's Rumble team.

## Outcome
Applied every safe available fix (16 -> 12 vulns, suite green) and justified the
rest. None of the CRITICAL/HIGH advisories has an upstream fix, and on inspection
none is a real risk to this service, so those are covered by the share-ready
`justification.md`.

### Fixes applied (verified green)
- `npm audit fix` (non-breaking, lockfile only): `brace-expansion` 1.1.12 -> 1.1.15
  and `ip-address` 10.1.0 -> 10.2.0 (both transitive, moderate).
- Bumped devDependency `sinon` 21.0.0 -> 21.1.2 in `package.json`, which pulls
  `diff` 8.0.4 and clears the low `diff` jsdiff DoS. Test-only dep.
- Result: **16 -> 12 vulnerabilities** (cleared 2 moderate + 2 low). The 12
  remaining are all "No fix available"; the only `--force` option left is the `ws`
  moderate, which would downgrade `ethers` 6 -> 5 (breaking, declined; websockets
  are unused here anyway).
- `npm test`: 15/15 pass, 60/60 asserts. `posttest` `standard` lint: clean.

### Registry note (why the first fix attempt 404'd)
`npm audit fix` initially failed resolving `@tetherto/wdk-wallet-evm@1.0.0-beta.4`
because `~/.npmrc` routes the `@tetherto` scope to `npm.pkg.github.com`, but the
lockfile resolves those packages from **public npm** (`registry.npmjs.org`). The
fixes were applied by overriding the scope for the install:
`npm audit fix --@tetherto:registry=https://registry.npmjs.org`. This is a
machine-local `.npmrc` mismatch, not a missing token and not a server-vs-laptop
difference: the `@tetherto` packages are public on npmjs.org.

### Unfixable, justified (see justification.md)
- **CRITICAL `tether-wrk-base` (GHSA-wvh9-3hgj-7f22): false positive.** Installed
  from `git+ssh://git@github.com/tetherto/tether-wrk-base.git#7aba3e0` (lockfile),
  not the public-npm name-squat malware the advisory targets. Range `>=0` / CVSS 0
  flags the name regardless of source; no bump can clear it.
- **6 HIGH = one build-time toolchain.** `tar <=7.5.10` (six advisories) carried up
  through `node-gyp -> make-fetch-happen / cacache` and `sqlite3 ->
  @bitfinex/bfx-facs-db-sqlite`. No fixed `tar` exists (even latest 7.x is in
  range). node-gyp/tar run only at `npm install` to compile the sqlite3 native
  addon; no runtime `require` of node-gyp/tar/make-fetch-happen/cacache in
  `worker.js`/`workers/`/`lib/`. The tar CVEs need extraction of attacker-controlled
  archives, which never happens (node-gyp extracts trusted nodejs.org headers over
  HTTPS during our own build).
- **3 moderate ws/ethers/wdk-wallet-evm:** no non-breaking fix; promo-wrk uses no
  websockets (`ethers` only in admin `scripts/` helpers), so the `ws` path is
  never reached.
- **2 low @tootallnate/once + http-proxy-agent:** same build-time node-gyp chain.

## Repos touched
- `_INDEXER/rumble-promo-wrk` (branch `dev`):
  - `package.json` — `sinon` 21.0.0 -> 21.1.2 (devDependency).
  - `package-lock.json` — `brace-expansion`, `ip-address`, `sinon`/`diff` bumps.
  - No source code changed.

## Layering / idempotency / separation notes
- N/A. Dependency-version changes only; no runtime code or service contract touched.

## Tests
- `rumble-promo-wrk`: `npm test` (brittle) -> 15/15 pass, 60/60 asserts; `posttest`
  `standard` lint clean. No tests needed changing (no behaviour change).

## Open points for Alex
- These edits are local and uncommitted (skill never commits/pushes). When you
  commit, do it from an env where `@tetherto` resolves to public npm, or use the
  `--@tetherto:registry=https://registry.npmjs.org` override, so a fresh
  `npm install` does not 404.
- Confirm the delivery channel/format Andrei's team expects for the writeup
  (Slack, Asana comment, doc); `justification.md` is written to paste as-is.
- Optional defensive follow-up (Tether-org level): publish a benign/scoped
  placeholder for the `tether-wrk-base` name on npm to kill the squat vector.

## Evidence captured in folder
- `justification.md` — share-ready writeup for Andrei's Rumble team.
- `npm-audit.md` — full per-advisory triage (pre-fix baseline).
- `_raw/npm-audit.txt` / `.json` — pre-fix audit. `_raw/npm-audit-after-fix.txt` /
  `.json` — post-fix audit (12 vulns).
