# Handling — WDK-1442 rumble-app-node security fix (close-out, 2026-06-10)

## Type
Refactor (security dependency bump). Continuation of the 2026-05-26 session
recorded in [`RESULT.md`](RESULT.md).

## State found today (2026-06-10)
- 3 of the 4 original alerts (`fastify` GHSA-jx2c-rxcm-jvmq, `fast-uri`
  GHSA-v39h-62p7-jpjc + GHSA-q3j6-qgpj-74h6) are **closed**. The fastify-v5
  work landed on both `dev` and `main`: `main` resolves `fastify@5.8.5`,
  `fast-uri@3.1.2`, `@fastify/swagger@9.7.0`, `@fastify/swagger-ui@5.2.6`
  via the wdk-app-node pin bump (WDK-1438 chain). Verified in the live
  lockfile and via `gh api .../dependabot/alerts?state=open`.
- **1 alert remains open:** #1, `SonarSource/sonarqube-scan-action` `>=4 <6`,
  GHSA-5xq9-5g24-4g6f (argument injection). Fixed in `6.0.0`.
  `.github/workflows/build.yml:18` is on `@v5` on both `main` (default
  branch, drives the alert) and `dev`.

## Change
One line, applied to the local clone on `dev` (uncommitted):
- `rumble-app-node/.github/workflows/build.yml:18`
  `SonarSource/sonarqube-scan-action@v5` → `@v6`

## Existing Dependabot PR
- **PR #213** (`chore(deps): bump SonarSource/sonarqube-scan-action from 5
  to 6`) is open against `main` with the byte-identical diff.
- Its CI is red for an environmental reason only: Dependabot-actor runs get
  no repo credentials, so `npm ci` fails cloning the private
  `tetherto/wdk-app-node` git dependency ("Authentication failed") before
  lint/tests run. The workflow one-liner cannot affect those jobs.
- Caveat: merging #213 fixes `main` only. `main` is synced from `dev`
  (e.g. open PR #236 "Sync/main"), and `dev` is still on `@v5`, so the fix
  must land on `dev` too or a later sync reintroduces `@v5`.

## Recommended path (Alex's call, both are GitHub writes)
1. Commit/push the local one-liner from `dev` via the normal flow (PR into
   `tetherto:dev`), then either merge #213 as well or close it once the
   sync carries the fix to `main`.
2. Or merge #213 into `main` directly (red CI is environmental) AND still
   land the `dev` one-liner so the next sync does not revert it.

## Repos touched
- `rumble-app-node` — `.github/workflows/build.yml` one-line action bump
  (local working tree on `dev`, uncommitted per skill rules).

## Layering / idempotency / separation notes
CI workflow file only; no runtime code, no HTTP/HRPC paths, no schemas.

## Tests
Not applicable: the change touches no JS code path. The repo's lint
(`standard`) does not cover workflow YAML. Prior session's verification of
the fastify-v5 stack is in `RESULT.md` (unit tests 9/9, audit clean).

## Stale branch note
Local + origin branch `wdk-1442-fastify-v5-security` is superseded: its
swagger/pin changes are already on `dev`, and `dev` has since moved past it.
Safe to delete (origin delete is a GitHub write, so left to Alex).

## Assumptions / open points
- None blocking. The only remaining action is merging/landing the one-liner,
  which is a GitHub write and stays with Alex.
