# WDK-1442 — rumble-app-node fastify v5 security fix — RESULT (2026-05-26)

## Confirmed blocker (now resolved)
Same Fastify-v5 root cause as WDK-1438/1444 — gated on `svc-facs-httpd` PR #8, **merged
2026-05-26**, tag **`v2.0.0`**. rumble gets Fastify *transitively through*
`@tetherto/wdk-app-node` (which uses svc-facs-httpd), so rumble's `fastify`/`fast-uri`
advisories only clear once the **wdk-app-node pin moves to a v5-fixed commit** — i.e. this
ticket depends on **WDK-1438** landing first.

## Branch
`wdk-1442-fastify-v5-security` off `upstream/dev` (`7ea2ab9`). **Not pushed.**
(Started fresh off `dev`, NOT off the `rw-1691-v1-campaign-claims` feature branch.)

## Changes made now (committable, self-contained)
- `package.json`
  - `@fastify/swagger` `^8.15.0 → ^9.0.0`
  - `@fastify/swagger-ui` `^4.1.0 → ^5.0.0`
  (needed for Fastify v5 compatibility — rumble registers both directly in
  `workers/http.node.wrk.js`; configs reviewed, v9/v5-compatible)
- `.github/workflows/build.yml`
  - `SonarSource/sonarqube-scan-action` `@v5 → @v6` — closes the repo-unique advisory
    **GHSA-5xq9-5g24-4g6f** (argument injection)
- No `routerPath` usage in rumble — it inherits the fixed rate-limit middleware from
  wdk-app-node.

## Final step — BLOCKED on WDK-1438 (not done here)
1. Bump `@tetherto/wdk-app-node` pin from `#1031258475af…` to the **merged WDK-1438 commit
   SHA** on `tetherto/wdk-app-node`.
2. Regenerate `package-lock.json` (forcing the wdk-app-node re-resolution, same git-tag
   gotcha — see wdk-app-node RESULT.md).
The lockfile was intentionally **not** regenerated on this branch: against the current
remote wdk-app-node it still resolves `fastify@4.29.1` (advisories unchanged), and against
swagger@9 it would be inconsistent.

## Verification (throwaway copy pointed at the local fixed wdk-app-node)
Confirms the chain clears once the pin moves:
- `fastify@5.8.5` (v4 fully gone), `fast-uri@3.1.2`, `@fastify/swagger@9.7.0`,
  `@fastify/swagger-ui@5.2.6`
- `npm audit`: **0 vulnerabilities**
- `npm run lint`: clean
- Tests: unit `tx-hash-schema.unit.test.js` **9/9 pass**. `http.node.wrk.intg.test.js` is an
  integration test needing the live backend (Redis/Mongo/RPC); under v5 the server boots and
  serves routes — it only fails on a balance-data assertion with no backend present (infra,
  not a v5 regression).
- Negative control: against the **current** remote wdk-app-node pin, rumble still carries
  `fastify@4.29.1` + the fast-uri highs — proving the pin bump is the operative fix.

## To push (when ready, after WDK-1438 merges)
Do the two final-step items above, then push `wdk-1442-fastify-v5-security` to `origin`
(AlexAtrx fork) → PR into `tetherto:dev`.
