# WDK-1438 — wdk-app-node fastify v5 security fix — RESULT (2026-05-26)

## Confirmed blocker (now resolved)
`svc-facs-httpd` PR #8 "Update fastify to v5" — **merged 2026-05-26 12:54 UTC**, cut as
tag **`v2.0.0`** (commit `b8a5e62`), bumping `fastify ^4.21.0 → ^5.7.2` and
`@fastify/static ^6 → ^9`. The three app-nodes get Fastify *transitively* through
`@tetherto/svc-facs-httpd`, so they could not clear the `fastify`/`fast-uri` advisories
until svc-facs-httpd went to v5 first. That gate is now open.

## Branch
`wdk-1438-fastify-v5-security` off `upstream/dev` (`a51131d`). **Not pushed.**

## Changes
- `package.json`
  - `@tetherto/svc-facs-httpd` `#v1.1.0 → #v2.0.0`
  - `@fastify/formbody` `^7.4.0 → ^8.0.0`
  - `@fastify/rate-limit` `^7.6.0 → ^10.0.0`
  - `@fastify/sensible` `^5.6.0 → ^6.0.0`
- `workers/lib/middlewares/rate.limit.js` — `req.routerPath` (removed in Fastify v5) →
  `req.routeOptions?.url`
- Test mocks updated to match: `tests/unit/middlewares/rate.limit.test.js` (×3),
  `tests/test-lib/auth.js`
- `package-lock.json` regenerated

## Verification
- Resolved: `@tetherto/svc-facs-httpd@2.0.0` (b8a5e62), `fastify@5.8.5`, `fast-uri@3.1.2`
- `npm audit`: **0 vulnerabilities** (was 3 high: fastify GHSA-jx2c-rxcm-jvmq + fast-uri
  GHSA-q3j6-qgpj-74h6 / GHSA-v39h-62p7-jpjc)
- `npm run lint`: clean
- Unit tests: 66/67. The single failure (`jwt.guard.test.js` "noAuth delegates to testMode
  handler") **also fails on clean `upstream/dev`** — pre-existing, unrelated to this change.

## npm gotcha (for whoever finalizes/pushes)
Plain `npm install` does **not** re-resolve a git dep whose tag changed (`#v1.1.0 → #v2.0.0`)
if the lockfile already pins a commit. Force it once:
```
npm install "@tetherto/svc-facs-httpd@git+https://github.com/tetherto/svc-facs-httpd.git#v2.0.0"
```
then restore the canonical `git+https://...#v2.0.0` spec (npm rewrites it to the `github:`
shorthand) and `npm install` to sync.

## To push (when ready)
Push `wdk-1438-fastify-v5-security` to `origin` (AlexAtrx fork) → PR into `tetherto:dev`.
Independent of WDK-1444. **rumble-app-node (WDK-1442) depends on this merging** — it pins a
wdk-app-node commit.
