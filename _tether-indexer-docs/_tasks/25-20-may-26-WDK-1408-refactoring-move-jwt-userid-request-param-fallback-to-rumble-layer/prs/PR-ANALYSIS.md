# PR analysis — WDK-1408

Both PRs authored by Francesco Canessa on 2026-04-03. Neither is merged as of 2026-05-20.

## tetherto/wdk-app-node#91 — `fix: remove request param fallback from JWT _parsePayload`

- **Head:** `709b799` (single commit)
- **Base when branched:** `0195abd` (Merge PR #87 — chore/update-hp-svc-facs-net-cache-fix)
- **Diff:** 1 file, 2/-2 lines — `workers/lib/middlewares/auth/jwt.guard.js`
- **State on upstream:** not merged into `dev`. Still present on dev with the old vulnerable signature.

### The change
```diff
- _parsePayload (payload, req) {
-   return { id: payload.userId || req.params?.userId || req.query?.userId || req.body?.userId }
+ _parsePayload (payload) {
+   return { id: payload.userId }
```

### What the commit message reveals (worth re-reading carefully)

> If a JWT passed signature verification but had no userId claim, _parsePayload silently read userId from URL params, query string, or request body. This allowed any valid token without userId to impersonate arbitrary users by injecting userId in the request.

This is **not a cosmetic refactor**. It is a security fix: any signed-but-userId-less JWT could become any user by passing `?userId=victim` (or a body field). The Asana ticket framed it as "make WDK cleaner for open-sourcing" but the underlying motivation in the commit body is impersonation prevention. Worth confirming with Francesco/Alex which framing should land in the merged commit — the security framing matters for changelog / disclosure decisions.

### Rebase risk

Since PR 91 was branched, three other PRs have touched `jwt.guard.js`:

- `b1c2d5f` test: add missing auth coverage for WDK app node (#100)
- `515c4be` feature: custom jwt auth header (#105)
- `583ddc8` Feature/jwt custom header (#107)

The `JwtGuard` constructor changed shape (now takes `{ secret, header, options }` instead of a positional secret). The `_parsePayload` method itself has the same signature on dev, so the diff should still apply, **but** the surrounding `guard()` method now reads `req.headers[this.header.key]` instead of a hardcoded header. **Action:** rebase pr-91 onto current `upstream/dev`; expect either a trivial conflict or a clean rebase on `_parsePayload`, but re-run the auth test suite added by #100 since it post-dates the PR.

## tetherto/rumble-app-node#181 — `fix: move JWT userId request param fallback to rumble layer`

- **Head:** `f5d596f` (single commit)
- **Base when branched:** `afee23c` (promote dev to dev, #180)
- **Diff:** 2 files, 14/-2 lines
  - `workers/http.node.wrk.js` — swap `JwtGuard` for new `RumbleJwtGuard`
  - `workers/lib/middlewares/rumble.jwt.guard.js` — new subclass with the fallback restored
- **State on upstream:** not merged into `dev`.

### The change
New file `rumble.jwt.guard.js`:
```js
const { JwtGuard } = require('@tetherto/wdk-app-node/workers/lib/middlewares/auth')
class RumbleJwtGuard extends JwtGuard {
  _parsePayload (payload, req) {
    return { id: payload.userId || req.params?.userId || req.query?.userId || req.body?.userId }
  }
}
module.exports = RumbleJwtGuard
```

`http.node.wrk.js` swaps `new JwtGuard(this.conf.jwtSecret)` → `new RumbleJwtGuard(this.conf.jwtSecret)`.

### Rebase risk — bigger than PR 91

Rumble's `upstream/dev` has already moved past PR 181's wiring. Current `http.node.wrk.js` on dev contains:

```js
const { DefaultGuard, JwtGuard } = require('@tetherto/wdk-app-node/workers/lib/middlewares/auth')
...
middlewares.configureAuth('secret', new JwtGuard({
  secret: this.conf.jwtSecret,
  header: { key: 'x-secret-token' }
}))
```

i.e. the new options-object constructor is already adopted. PR 181's diff still uses the positional `new JwtGuard(this.conf.jwtSecret)` form. After rebase:

1. The `RumbleJwtGuard` subclass needs no change (it just overrides `_parsePayload`); the new constructor is inherited from the parent unchanged.
2. The `http.node.wrk.js` change must be re-applied as:
   ```js
   middlewares.configureAuth('secret', new RumbleJwtGuard({
     secret: this.conf.jwtSecret,
     header: { key: 'x-secret-token' }
   }))
   ```
3. The import line stays: drop `JwtGuard` from the destructure, add `const RumbleJwtGuard = require('./lib/middlewares/rumble.jwt.guard')`.

### Behavioural concern — backwards compatibility

The new `RumbleJwtGuard` **preserves the impersonation surface** for rumble traffic. Commit body says:
> preserves the fallback behavior for backwards compatibility with existing mobile clients, until we can verify all tokens include userId in the payload.

So as written, merging both PRs closes the hole on WDK callers but leaves it open on Rumble. Two questions before finalising:

1. Is there a tracking ticket / timeline to delete `RumbleJwtGuard` once mobile clients all emit `userId`? If not, this is the kind of "temporary" shim that lives forever — worth at minimum a TODO with a date and an Asana link in the new file.
2. Could rumble-app-node enforce a transitional check instead — e.g. log a warning when the fallback is hit so we can measure whether any clients still rely on it? That would let us delete the fallback faster and intentionally rather than guessing.

## Merge order

Rumble PR 181 **must merge first**, then WDK PR 91. If wdk-app-node#91 lands before rumble-app-node#181 is updated for the dependency, any rumble deployment pulling in the new wdk-app-node will silently start rejecting JWTs that previously worked via the fallback path — i.e. immediate prod auth breakage for mobile clients that don't include `userId` in the token.

After both are merged, bump the `@tetherto/wdk-app-node` version pinned by rumble-app-node and verify a rumble integration test that exercises `_parsePayload` with a userId-less token actually returns the param fallback id.
