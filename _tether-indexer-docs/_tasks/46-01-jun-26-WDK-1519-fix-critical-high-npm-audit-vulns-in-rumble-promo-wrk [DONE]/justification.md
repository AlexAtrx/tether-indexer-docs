# rumble-promo-wrk npm audit: triage and justification

Prepared for Andrei's Rumble team. Covers the `npm audit` findings on
`@tetherto/rumble-promo-wrk` (branch `dev` @ `083869e`, node v22.13.0, npm 10.9.2).

Totals: 16 advisories (1 critical, 6 high, 5 moderate, 4 low).

Bottom line: every CRITICAL and HIGH advisory has **no upstream fix available**,
and on inspection none represents a real risk to this service. One is a
false positive (name collision with a malicious public-npm package), and the
six HIGH advisories are a single build-time toolchain that never processes
attacker-controlled input. Detail below.

## CRITICAL

### tether-wrk-base — "Malware in tether-wrk-base" (GHSA-wvh9-3hgj-7f22)

**Not applicable to us. This is a false positive.**

- Our dependency resolves from our own private GitHub repo, not from public npm:
  `package-lock.json` shows
  `git+ssh://git@github.com/tetherto/tether-wrk-base.git#7aba3e02b342344aa8d0e78050e94f205f33d5a9`
  (`tether-wrk-base@0.1.0`).
- The advisory is for a package that an attacker published under the same name
  `tether-wrk-base` on the public npm registry (a name-squat / dependency-confusion
  attempt). `npm audit` matches advisories by package name only, with an affected
  range of `>=0` and a CVSS score of 0, so it flags every package named
  `tether-wrk-base` regardless of where it was actually installed from.
- Because we pin the dependency to our git source by commit SHA, npm never pulls
  the malicious registry package. There is nothing to "fix": no version bump can
  clear a `>=0` name-based advisory, and changing the source would only mean
  pointing at the same trusted repo.

Recommended follow-up (defensive, optional): keep this dependency pinned to a git
SHA (already the case), and consider publishing a benign placeholder under the
`tether-wrk-base` name on npm, or scoping it (`@tetherto/...`), to remove the
name-squat vector entirely. That is a Tether-org decision, not a promo-wrk change.

## HIGH (6 advisories, one root cause)

All six HIGH advisories are the native-build toolchain for the `sqlite3` addon.
They chain from a single direct dependency:

```
@bitfinex/bfx-facs-db-sqlite (direct, git dep)
└─ sqlite3 5.x
   └─ node-gyp <=10.3.1            (build tool, runs at npm install)
      ├─ make-fetch-happen          (node-gyp's HTTPS fetch of node headers)
      │  └─ cacache                 (node-gyp's on-disk fetch cache)
      └─ tar <=7.5.10  ← the actual CVEs
```

Advisories: the `tar` package carries six advisories (GHSA-34x7-hfp2-rc4v,
GHSA-8qq5-rm4j-mr97, GHSA-83g3-92jg-28cx, GHSA-qffp-2rhf-9h96,
GHSA-9ppj-qmqm-q256, GHSA-r6q2-hw4h-h46w) for arbitrary file create/overwrite and
symlink/hardlink path traversal during archive extraction, plus an APFS race
condition. `node-gyp`, `make-fetch-happen`, `cacache`, `sqlite3`, and
`@bitfinex/bfx-facs-db-sqlite` are flagged only because they depend on that `tar`.

**Why this is not high/critical for us:**

1. **No fix exists.** npm reports "No fix available" for every package in this
   chain, including the latest `tar` 7.x. There is no non-vulnerable version to
   upgrade to, so an override or bump cannot resolve it.
2. **Build-time only, not a runtime dependency.** `node-gyp` (and therefore
   `tar`, `make-fetch-happen`, `cacache`) runs once, at `npm install`, to compile
   the `sqlite3` native addon. At runtime the worker loads the compiled `.node`
   binary directly; it never requires `node-gyp` or `tar`. Confirmed: there is no
   `require('node-gyp' | 'tar' | 'make-fetch-happen' | 'cacache')` anywhere in the
   service source (`worker.js`, `workers/`, `lib/`). `sqlite3` itself is used at
   runtime (`workers/api.promo.wrk.js`, `workers/proc.promo.wrk.js` via
   `@bitfinex/bfx-facs-db-sqlite`), but the runtime sqlite library is not what the
   advisories are about.
3. **The vulnerable code path is never reached with untrusted input.** The `tar`
   CVEs require extracting an attacker-controlled archive. `node-gyp` only uses
   `tar` to extract the official Node.js headers/prebuilt artifacts it fetches
   over HTTPS from `nodejs.org` during a build we control, in our own CI / dev
   environment. The promo worker never extracts user-supplied or network-supplied
   tar archives at runtime.

Net: build-time toolchain, no fixed version published, no exposure to
attacker-controlled archives. Accept with this justification until upstream
`sqlite3` / `node-gyp` ship a patched `tar`.

## MODERATE (5) — 2 fixed, 3 justified

- **brace-expansion (<1.1.13)** and **ip-address (<=10.1.0)** — FIXED via
  `npm audit fix` (transitive, non-breaking): brace-expansion 1.1.12 -> 1.1.15,
  ip-address 10.1.0 -> 10.2.0. Lockfile only; tests green.
- **ws (8.0.0-8.20.0, uninitialized memory disclosure)** via **ethers (>=6)** via
  **@tetherto/wdk-wallet-evm** — kept. The only available fix downgrades `ethers`
  to 5.8.0, a breaking change that `wdk-wallet-evm` cannot take, so we do not apply
  it. Risk is not real for us: `ws` is only present because `ethers` bundles it for
  `WebSocketProvider`, and promo-wrk does not use websockets. `ethers` is used only
  in admin helper scripts (`scripts/utils/wallet.js`, `scripts/pay-eth.js`) for
  pure functions (`parseEther`, `parseUnits`, `isAddress`, `getAddress`) and HD
  wallet signing; there is no `WebSocketProvider` / websocket usage anywhere, so
  the vulnerable code path is never exercised.

## LOW (4) — 1 fixed, justified

- **diff (jsdiff DoS)** via **sinon** — FIXED. Bumped devDependency `sinon`
  21.0.0 -> 21.1.2, which pulls `diff` 8.0.4 (out of the vulnerable range).
  Test-only, not shipped to any runtime; tests green.
- **@tootallnate/once** and **http-proxy-agent** — same build-time `node-gyp`
  toolchain as the HIGH `tar` chain; build-time only, no fix.

Net result of applied fixes: **16 -> 12 advisories** (2 moderate + 2 low cleared).
The remaining 12 (1 critical, 6 high, 3 moderate, 2 low) all have no non-breaking
fix and are covered by the justifications above.

## Summary table

| Severity | Package | Fix | Disposition |
|---|---|---|---|
| critical | tether-wrk-base | none (range `>=0`) | False positive: installed from tetherto git, not the npm malware squat |
| high | tar + node-gyp + make-fetch-happen + cacache + sqlite3 + bfx-facs-db-sqlite | none | Build-time native-compile toolchain; no runtime use; no untrusted archives; accept |
| moderate | brace-expansion, ip-address | `npm audit fix` | FIXED (1.1.15 / 10.2.0); tests green |
| moderate | ws / ethers / wdk-wallet-evm | only via ethers 5 downgrade (breaking) | Kept; websockets unused in promo-wrk, path never reached |
| low | @tootallnate/once, http-proxy-agent | none | Same build-time toolchain as HIGH tar chain |
| low | diff / sinon | bump sinon 21.1.2 | FIXED (diff 8.0.4); devDependency (tests), not shipped |
