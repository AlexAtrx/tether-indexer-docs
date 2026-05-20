# Next steps for WDK-1408 — Move JWT userId fallback to rumble layer

**Ticket:** https://app.asana.com/1/45238840754660/project/1210540875949204/task/1214564483403277

## What we know
- The WDK layer currently contains rumble-specific code in the userId / JWT check path. The goal is to relocate that logic into the rumble layer so wdk-app-node stays generic and is open-sourceable.
- Francesco opened both ends of the refactor: rumble-app-node PR #181 (adds the logic on the rumble side) and wdk-app-node PR #91 (removes it on the WDK side).
- Originally assigned to Francesco; on 2026-05-13 he reassigned to Alex "to take over testing and finalization of the prs".
- Moved to Sprint 2 on 2026-05-13; priority Medium; section "DEV IN PROGRESS".

## Evidence captured here
- 0 images analysed in `image-analysis.md`
- 0 non-image attachments under `attachments/`
- 1 real comment (plus 4 system stories) in `comments.md`
- Both PR diffs and a written-up analysis under `prs/` (see `prs/PR-ANALYSIS.md`)

## PR state (as of 2026-05-20)
- **rumble-app-node#181** — open, single commit `f5d596f` from 2026-04-03. Adds `RumbleJwtGuard` that keeps the `userId` fallback for rumble. Needs rebase: `http.node.wrk.js` on rumble dev already switched `JwtGuard` to the options-object constructor; PR uses the old positional form.
- **wdk-app-node#91** — open, single commit `709b799` from 2026-04-03. Removes the fallback from base `_parsePayload`. Three PRs (#100, #105, #107) have touched `jwt.guard.js` since — rebase likely small but the auth tests added by #100 must be re-run against the rebased branch.

## Real headline (not in the Asana title)
Per Francesco's commit body on wdk-app-node#91, the fallback was a **JWT impersonation vector**: any signed token without a `userId` claim could become an arbitrary user by passing `?userId=victim` (or in params/body). This isn't just cleanup-for-open-sourcing; it's a security fix being decoupled so the rumble side can ship a transitional shim. Worth confirming the framing with Francesco before merging.

## Open questions for Alex / Francesco
1. **Merge order:** PR 181 must land before PR 91. Confirm rumble is deployed off the new rumble-app-node version before any service pulls in the updated `@tetherto/wdk-app-node`, else mobile clients without `userId` in the token break instantly.
2. **Shim lifetime:** `RumbleJwtGuard` preserves the impersonation surface for rumble. Is there a deletion target / tracking ticket? Add a TODO + ticket link in `rumble.jwt.guard.js` if not.
3. **Telemetry before deletion:** consider logging a warning in the rumble guard when the fallback path is taken, so we can measure rather than guess when it's safe to remove the shim.
4. **Test coverage:** is there an integration test in rumble that exercises a userId-less JWT through the fallback? If not, add one with the PR.

## Before starting work
Rebase both PRs onto their current upstream `dev` branches before doing anything else (`pr-181` and `pr-91` are already in the local clones for inspection). Then run the wdk-app-node auth test suite (added by #100) against the rebased PR 91. Ping Francesco with the four questions above so the merge sequencing is agreed before pushing rebased branches.
