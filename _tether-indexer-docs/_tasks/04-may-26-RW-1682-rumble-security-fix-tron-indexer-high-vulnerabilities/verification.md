# Verification on `wdk-indexer-wrk-tron@main`

Repo: `tetherto/wdk-indexer-wrk-tron`, branch `main`, commit
`6e02432cc28c6c55c95106878f4397c2cb9894a8` ("promote dev to main #107",
2026-05-03 18:46 +0200). Shallow clone, `npm audit --package-lock-only`
(node v22.11.0 / npm 10.9.0).

## Lockfile versions of previously-flagged packages

| Pkg              | In lock      | First patched (per Dependabot) | OK |
|------------------|--------------|--------------------------------|----|
| axios            | 1.15.2       | 1.13.5 / 1.15.0                | ✓  |
| minimatch        | 3.1.5        | 3.1.3 / 3.1.4                  | ✓  |
| lodash           | 4.18.1       | 4.18.0                         | ✓  |
| flatted          | 3.4.2        | 3.4.2                          | ✓  |
| picomatch        | 4.0.4        | 4.0.4                          | ✓  |
| follow-redirects | 1.16.0       | 1.16.0                         | ✓  |
| brace-expansion  | 1.1.14       | 1.1.13                         | ✓  |
| bn.js            | 5.2.3, 4.12.3| 5.2.3 / 4.12.3                 | ✓  |
| ajv              | 6.15.0       | 6.14.0                         | ✓  |
| diff             | 8.0.4        | 8.0.3                          | ✓  |
| tether-wrk-base  | (absent)     | — (alert #22 critical)         | ✓ (removed) |
| elliptic         | 6.6.1        | — (no upstream patch)          | open |

Specifically for the two alerts referenced in the ticket:

- **Alert #7 — minimatch (High):** lockfile has `minimatch 3.1.5`, ≥ `3.1.4` (patched).
- **Alert #3 — axios (High):** lockfile has `axios 1.15.2`, ≥ `1.13.5` (patched).

## `npm audit --package-lock-only` summary

```
{"info":0,"low":10,"moderate":0,"high":0,"critical":0,"total":10}
```

All 10 lows resolve to the single open Dependabot alert (#1, `elliptic <= 6.6.1`,
no upstream patch), propagating through:

```
elliptic
  └ @ethersproject/signing-key
      └ @ethersproject/transactions
          └ @ethersproject/abstract-provider
              └ @ethersproject/abstract-signer
                  └ @ethersproject/hash
                      └ @ethersproject/abi
                          └ tronweb (5.3.0–5.3.4 || 6.0.0-beta.0–6.0.0-beta.4)
                              ├ @tetherto/wdk-wallet-tron
                              └ @tetherto/wdk-wallet-tron-gasfree
```

Two of the chain entries report `fixAvailable: true` (`@tetherto/wdk-wallet-tron`
and `tronweb`), but those upgrades just bump the version of the same vulnerable
`elliptic` chain — they don't drop the elliptic dep, they just move forward to a
newer `tronweb`/wdk-wallet-tron that still depends on the same advisory chain.
Effective root cause is upstream `elliptic`.

## Conclusion

The literal ask in the ticket — "fix the high vulnerabilities behind alerts #3
and #7 on `wdk-indexer-wrk-tron`" — is done on `main`. The ticket can be moved
to `Done` / closed once Alex confirms (or kept open as a parent for the broader
"Rumble + dependents" sweep that the description also requested).

The remaining 10 lows are a separate decision (dismiss with risk note vs. wait
for an upstream `elliptic` patch vs. swap `tronweb`-flavoured deps). Not what
this ticket was filed for.
