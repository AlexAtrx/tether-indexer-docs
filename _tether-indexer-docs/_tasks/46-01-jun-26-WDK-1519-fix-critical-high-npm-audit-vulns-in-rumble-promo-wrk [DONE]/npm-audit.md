# npm audit — rumble-promo-wrk

Captured locally on 2026-06-01.

- Repo: `_INDEXER/rumble-promo-wrk` (`@tetherto/rumble-promo-wrk` 0.1.1)
- Branch: `dev` @ `083869e` (Merge PR #47 `chore/security-deps-bump-202605` — a prior deps-bump already landed)
- node v22.13.0 / npm 10.9.2
- Totals: **16 vulnerabilities — 4 low, 5 moderate, 6 high, 1 critical**

Raw output saved at `_raw/npm-audit.txt` and `_raw/npm-audit.json`.

## CRITICAL (1)

| Package | Direct | Fix | Advisory |
|---|---|---|---|
| `tether-wrk-base` (`*`) | yes | **none** | Malware in tether-wrk-base — GHSA-wvh9-3hgj-7f22 |

Top priority. Listed as a direct dependency. Needs: confirm whether we actually pull/use it (vs. a stale/typosquat name), and replace or remove. This is the one true non-build-chain advisory in the set.

## HIGH (6) — all one chain

All six HIGH advisories collapse to a **single root cause: `tar` (<=7.5.10), no fix available**, propagating up the native-build chain for `sqlite3`:

```
@bitfinex/bfx-facs-db-sqlite (*, direct)
└─ sqlite3 (5.0.0-5.1.7)
   └─ node-gyp (<=10.3.1)
      ├─ make-fetch-happen (7.1.1-14.0.0)
      │  └─ cacache (14.0.0-18.0.4)
      └─ tar (<=7.5.10)   ← actual vuln
```

`tar` advisories: GHSA-34x7-hfp2-rc4v, GHSA-8qq5-rm4j-mr97, GHSA-83g3-92jg-28cx, GHSA-qffp-2rhf-9h96, GHSA-9ppj-qmqm-q256, GHSA-r6q2-hw4h-h46w (arbitrary file create/overwrite, symlink/hardlink path traversal, APFS race condition during extraction).

| Package | Direct | Fix |
|---|---|---|
| `@bitfinex/bfx-facs-db-sqlite` (`*`) | yes | none |
| `sqlite3` (5.0.0-5.1.7) | no | none |
| `node-gyp` (<=10.3.1) | no | none |
| `make-fetch-happen` (7.1.1-14.0.0) | no | none |
| `cacache` (14.0.0-18.0.4) | no | none |
| `tar` (<=7.5.10) | no | none |

These are `node-gyp` build-time machinery used to compile the native `sqlite3` addon — `tar` here extracts the prebuilt-binary / build artifacts at install time, not untrusted archives at runtime. Strong justification candidate (build/dev-time, no runtime exposure to attacker-controlled tarballs).

## MODERATE (5)

| Package | Direct | Fix | Advisory |
|---|---|---|---|
| `brace-expansion` (<1.1.13) | no | **`npm audit fix`** | ReDoS / hang — GHSA-f886-m6hf-6m8v |
| `ip-address` (<=10.1.0) | no | **`npm audit fix`** | XSS in Address6 HTML methods — GHSA-v2v4-37r5-5v8g |
| `ws` (8.0.0-8.20.0) | no | none | Uninitialized memory disclosure — GHSA-58qx-3vcg-4xpx |
| `ethers` (>=6.0.0-beta.1) | yes | none | depends on vulnerable `ws` |
| `@tetherto/wdk-wallet-evm` | yes | none | depends on vulnerable `ethers` |

`brace-expansion` + `ip-address` fix cleanly with `npm audit fix` (non-breaking). The `ws`->`ethers`->`wdk-wallet-evm` chain has no published fix and is gated on a `wdk-wallet-evm` / `ethers` bump.

## LOW (4)

| Package | Direct | Fix | Advisory |
|---|---|---|---|
| `@tootallnate/once` (<2.0.1) | no | none | Incorrect control-flow scoping — GHSA-vpq2-c234-7xj6 (via http-proxy-agent -> make-fetch-happen, same node-gyp chain) |
| `http-proxy-agent` (4.0.1) | no | none | depends on vulnerable `@tootallnate/once` |
| `diff` (6.0.0-8.0.2) | no | force (sinon@21) | jsdiff DoS — GHSA-73rr-hh4g-fpgx |
| `sinon` (19.0.0-21.0.0) | yes | force (sinon@21) | depends on vulnerable `diff` (devDependency) |

`diff`/`sinon` is a **devDependency** (test tooling), fixable only via `npm audit fix --force` (installs sinon@21, outside stated range).

## Triage summary for the fix

1. **Quick wins (non-breaking):** `npm audit fix` clears `brace-expansion` + `ip-address`.
2. **CRITICAL `tether-wrk-base`:** investigate whether it is a real dependency / typosquat; remove or replace. No upstream fix.
3. **HIGH tar chain (6 advisories, 1 root cause):** no fix; build-time sqlite native-compile machinery. Candidate for justification (not exposed to untrusted archives at runtime) unless we can drop/replace `@bitfinex/bfx-facs-db-sqlite` or pin a patched `tar`.
4. **MODERATE ws/ethers/wdk-wallet-evm:** gated on a `wdk-wallet-evm` bump; justify or wait for upstream.
5. **LOW diff/sinon:** devDependency; `npm audit fix --force` to sinon@21, or justify as test-only.
