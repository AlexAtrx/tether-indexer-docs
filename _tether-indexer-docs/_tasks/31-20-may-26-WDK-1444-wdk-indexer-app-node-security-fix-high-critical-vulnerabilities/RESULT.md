# WDK-1444 — wdk-indexer-app-node fastify v5 security fix — RESULT (2026-05-26)

## Confirmed blocker (now resolved)
Same root cause as WDK-1438/1442: gated on `svc-facs-httpd` PR #8 "Update fastify to v5",
**merged 2026-05-26**, tag **`v2.0.0`** (commit `b8a5e62`). Fastify is transitive via
`@tetherto/svc-facs-httpd`. See the wdk-app-node RESULT.md for the full PR detail.

## Branch
`wdk-1444-fastify-v5-security` off `origin/dev` (`41b3a93`). **Not pushed.**
Note: in this repo `origin` = `tetherto`, the AlexAtrx fork remote is `per`.

## Changes
- `package.json`
  - `@tetherto/svc-facs-httpd` `#v1.0.0 → #v2.0.0`
  - `@fastify/rate-limit` `^9.1.0 → ^10.0.0`
  - `@fastify/sensible` `^5.6.0 → ^6.0.0`
  - `@fastify/swagger` `^8.15.0 → ^9.0.0`
  - `@fastify/swagger-ui` `^4.2.0 → ^5.0.0`
  - (`@fastify/static ^9.0.0` already v5-era — unchanged)
- `workers/lib/middlewares/rate.limit.js` — `req.routerPath → req.routeOptions?.url`
- Test mock: `tests/unit/middlewares.unit.test.js`
- `package-lock.json` regenerated

## Verification
- Resolved: `svc-facs-httpd@2.0.0` (b8a5e62), `fastify@5.8.5`, `fast-uri@3.1.2`,
  `@fastify/swagger@9.7.0`, `@fastify/swagger-ui@5.2.6`
- `npm audit`: base `origin/dev` had **5 high + 1 low + 1 moderate**; this branch now has
  **0 high/critical**. One moderate remains — `brace-expansion` GHSA-jxxr-4gwj-5jf2, a
  transitive dev dep — which **pre-existed on dev** and is below this ticket's high/critical
  scope. (`npm audit fix` would clear it if desired.)
- `npm run lint`: clean
- Unit tests: **69/69 pass** (incl. the rate-limit middleware test).

## npm gotcha
Same stale-git-tag re-resolution issue as WDK-1438 — had to force
`npm install "@tetherto/svc-facs-httpd@git+...#v2.0.0"`. See wdk-app-node RESULT.md.

## To push (when ready)
Push `wdk-1444-fastify-v5-security` to `per` (AlexAtrx fork) → PR into `tetherto:dev`
(remote `origin`). Independent of the other two — can go in parallel.
