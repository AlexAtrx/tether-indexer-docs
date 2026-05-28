# WDK-1168 / RW-1680 — Rumble: Update Fastify plug-ins — RESULT (2026-05-28)

**Done locally, NOT committed** (per instruction). Branch left as-is so it can be
folded into the existing rumble fastify branch or a fresh WDK-1168 branch when pushed.

## TL;DR

The whole-estate Fastify v4 → v5 plugin upgrade is now complete across **all four**
fastify-bearing repos. Three were already merged via the security batch; this session
finished the **only** remaining one — `rumble-app-node` — and verified the entire estate
is v4-free.

| Repo | Where fastify comes from | State going in | State now |
|---|---|---|---|
| `svc-facs-httpd` | direct (`fastify ^5.7.2`) | ✅ released **v2.0.0** on `main` | unchanged — v5, 0 vuln |
| `wdk-app-node` | transitive via svc-facs-httpd | ✅ **WDK-1438 merged** to `dev` (#112) | unchanged — `fastify@5.8.5`, 0 vuln |
| `wdk-indexer-app-node` | transitive via svc-facs-httpd | ✅ **WDK-1444 merged** to `dev` (#82) | unchanged — `fastify@5.8.5`, 0 vuln |
| `rumble-app-node` | transitive via wdk-app-node | ⏳ pin pre-v5; lockfile stale | ✅ **completed here** — `fastify@5.8.5`, 0 vuln |

No other repo in the workspace declares `fastify` or any `@fastify/*` plugin
(verified by scanning every top-level `package.json`). The umbrella ticket's
"check the repos, both internal and rumble" scope is therefore fully covered by
these four.

## What changed in `rumble-app-node` (working tree, uncommitted)

Branch: `wdk-1442-fastify-v5-security` (the prior session's branch; its swagger bumps
were already staged here — this session added the operative pin bump + lockfile regen).

- `package.json`
  - `@tetherto/wdk-app-node` pin `#1031258475af… → #b678ef2cb1bf277c9c33d9c87f01029efd2c2c56`
    — the current `tetherto:dev` HEAD that carries the merged WDK-1438 Fastify-v5 fix.
    The old pin is an **ancestor** of dev HEAD, so this advance pulls in only the
    WDK-1438 fastify upgrade + a one-commit WDK-1408 jwt-test alignment — no unrelated drift.
    **This is the operative fix:** it's what flips rumble's transitive `fastify@4.29.1 → v5`.
  - `@fastify/swagger` `^8.15.0 → ^9.0.0` (rumble's own direct plugin; v5-compatible major)
  - `@fastify/swagger-ui` `^4.1.0 → ^5.0.0` (ditto)
  - (these two swagger bumps were already present from the WDK-1442 session)
- `package-lock.json` — **regenerated** (see npm gotcha below).
- `.github/workflows/build.yml` — `SonarSource/sonarqube-scan-action @v5 → @v6`.
  ⚠️ This is a **WDK-1442 security** change (argument-injection advisory GHSA-5xq9-5g24-4g6f),
  *not* a fastify-plugin change. It was already in the working tree before this session.
  Keep it with the WDK-1442 PR, or split it out — it's out of WDK-1168's strict scope.

No rumble **source** edits were needed: `workers/http.node.wrk.js` already registers
swagger with the v5 `openapi:` option shape and `routePrefix` on `@fastify/swagger-ui`
(its v5 home), so the source was already v5-ready.

## npm gotcha hit + resolved (important for whoever pushes)

A plain `npm install` after the pin bump moved the **top-level** `wdk-app-node` ref but
left the **nested git-dep-in-git-dep** stale: the lockfile still resolved
`@tetherto/svc-facs-httpd#b11b1bac` (v1.0.0, `fastify ^4.21.0`, `@fastify/static ^6`)
even though `wdk-app-node@b678ef2` now requires `svc-facs-httpd#v2.0.0`. Result: an
**internally inconsistent lockfile** and `fastify@4.29.1` still resolved (5 high vulns
re-appeared: `fast-uri <=3.1.1` via the v4 `@fastify/ajv-compiler@3` chain).

Fix that worked: **clean regen** —
```
rm -rf node_modules package-lock.json && npm install
```
This forces npm to re-expand the full git-dep tree from `package.json`
(`wdk-app-node@b678ef2 → svc-facs-httpd#v2.0.0 → fastify ^5`).

## Verification (rumble, after clean regen)

- `@tetherto/wdk-app-node` resolves `#b678ef2…`; `@tetherto/svc-facs-httpd` resolves
  **`#b8a5e62` (v2.0.0)** — v4 v1.x chain gone.
- Top-level **`fastify@5.8.5`**. Lockfile scan: **zero** `fastify-4.x` tarballs and
  **zero** `"fastify": "^4…"` constraints anywhere (top-level or nested).
- `fast-uri@3.1.2` (advisory-fixed); `@fastify/ajv-compiler@4.0.5` (v5-era, was v3).
- All `@fastify/*` at v5-compatible majors: swagger **9.7.0**, swagger-ui **5.2.6**,
  static **9.1.3**, formbody **8.0.2**, rate-limit **10.3.0**, sensible **6.0.4**.
- `npm audit`: **0 vulnerabilities** (was 5 high + 2 low on the stale v4 tree).
- `npm run lint` (`standard`): **clean**.
- Unit tests `tx-hash-schema.unit.test.js`: **9/9 pass**.
- Integration `http.node.wrk.intg.test.js`: the **v5 server boots and serves** — swagger
  v9 + swagger-ui v5 register with **no** `FST_ERR`/`AVV_`/plugin errors, and the
  POST/PATCH/validation route tests pass. The lone failure is the
  `GET /wallets/:id/balance` assertion, which needs a live Redis/Mongo/RPC backend
  (absent in this sandbox): the handler returns no `tokenBalances`, the response schema's
  `fast-json-stringify` rejects it, and the test then dereferences `data.token_balances.usdt`
  (undefined). **Backend-dependent, not a v5 regression** — consistent with the negative
  control documented in WDK-1442's RESULT.md (the same test fails identically on the v4 pin).

## Cross-repo verification (the 3 already-merged repos)

Read-only re-audit + adversarial verification this session (no changes made):

- `wdk-indexer-app-node` (dev): single `fastify@5.8.5`, no nested v4, all plugins v5,
  zero v4 API patterns in source. **DONE.**
- `svc-facs-httpd` (main, v2.0.0): single `fastify@5.8.5`, `@fastify/static@9.1.3`,
  v5-shaped `index.js`. **DONE.**
- `wdk-app-node` (dev): single `fastify@5.8.5`, all plugins v5, 0 vuln. **DONE** —
  with one cosmetic nit below.

## Optional follow-up (NOT done — out of WDK-1168 plugin scope, and in a clean merged repo)

`wdk-app-node/workers/lib/middlewares/response.validator.js:69` still references
`request.routerPath` as a **third** fallback:
```js
const routeKey = `${request.method}:${request.routeOptions?.url || request.routerPath || request.url}`
```
`request.routerPath` was removed in Fastify v5 so it always evaluates `undefined`;
it's dead-but-misleading code chained **after** the v5-canonical `request.routeOptions?.url`,
so it runs correctly on v5. Worth dropping the `|| request.routerPath` in a future
wdk-app-node touch, but it's not a plugin change and not a runtime issue — left untouched
to avoid uncommitted drift in an already-merged, clean repo.

## To push (when ready — not done, per "no commit")

1. Decide branch: keep on `wdk-1442-fastify-v5-security` (folds rumble's fastify-v5 work
   into the existing security PR) **or** cut a dedicated `wdk-1168-rumble-fastify-plugins`
   off `tetherto:dev`.
2. If splitting tickets: move the `build.yml` sonar bump to the WDK-1442 PR.
3. Commit `package.json` + `package-lock.json` (the v4-free lockfile), push to `origin`
   (AlexAtrx fork) → PR into `tetherto:dev`.
4. The wdk-app-node pin (`#b678ef2`) is current dev HEAD; re-point to a newer dev SHA if
   dev has advanced by push time.
