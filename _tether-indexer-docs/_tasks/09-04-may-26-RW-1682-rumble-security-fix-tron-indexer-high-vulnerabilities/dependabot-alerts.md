# Dependabot alerts referenced in the ticket

Source: `gh api repos/tetherto/wdk-indexer-wrk-tron/dependabot/alerts/{3,7}`. Raw
JSON in `_raw/dependabot-alert-3.json` and `_raw/dependabot-alert-7.json`. Full
list in `_raw/dependabot-alerts-all.json`.

## Headline

**Both alerts the ticket asks to fix are already in `state: fixed`.** Fixed at
2026-04-26 (the ticket was last modified 2026-04-30 with no comment about the
fix landing). Across the whole repo, every High/Critical/Medium alert is fixed.
The only open alert is #1 (elliptic, low severity, no patched version available
upstream).

## Alert #7 — minimatch (High, FIXED)

- Package: `minimatch` (npm, transitive, dev scope, in `package-lock.json`)
- Advisory: GHSA-3ppc-4f35-3m26 / CVE-2026-26996
- Issue: ReDoS via repeated `*` wildcards followed by a non-matching literal.
  Each `*` compiles to `[^/]*?`, V8 backtracks O(4^N).
- Vulnerable range (this repo's instance): `< 3.1.3`. First patched: `3.1.3`.
- State: `fixed` at 2026-04-26T10:41:44Z.

## Alert #3 — axios (High, FIXED)

- Package: `axios` (npm, transitive, runtime scope, in `package-lock.json`)
- Advisory: GHSA-43fc-jf86-j433 / CVE-2026-25639
- Issue: DoS in `mergeConfig` when a config object has `__proto__` as an own
  property (from `JSON.parse`). Throws `TypeError: merge is not a function`.
- Vulnerable range (this repo's instance): `>= 1.0.0, <= 1.13.4`. First patched: `1.13.5`.
- State: `fixed` at 2026-04-26T10:41:43Z.

## Full alert table for `wdk-indexer-wrk-tron`

| #  | Pkg              | Severity | Range                       | Fix    | State  |
|----|------------------|----------|-----------------------------|--------|--------|
| 23 | axios            | medium   | >=1.0.0, <1.15.0            | 1.15.0 | fixed  |
| 22 | tether-wrk-base  | critical | >= 0                        | —      | fixed  |
| 21 | axios            | medium   | >=1.0.0, <1.15.0            | 1.15.0 | fixed  |
| 20 | follow-redirects | medium   | <=1.15.11                   | 1.16.0 | fixed  |
| 19 | brace-expansion  | medium   | <1.1.13                     | 1.1.13 | fixed  |
| 15 | lodash           | medium   | <=4.17.23                   | 4.18.0 | fixed  |
| 14 | lodash           | high     | >=4.0.0, <=4.17.23          | 4.18.0 | fixed  |
| 13 | picomatch        | medium   | >=4.0.0, <4.0.4             | 4.0.4  | fixed  |
| 12 | picomatch        | high     | >=4.0.0, <4.0.4             | 4.0.4  | fixed  |
| 11 | flatted          | high     | <=3.4.1                     | 3.4.2  | fixed  |
| 10 | flatted          | high     | <3.4.0                      | 3.4.0  | fixed  |
| 9  | minimatch        | high     | <3.1.3                      | 3.1.3  | fixed  |
| 8  | minimatch        | high     | <3.1.4                      | 3.1.4  | fixed  |
| 7  | minimatch        | high     | <3.1.3                      | 3.1.3  | fixed  |
| 6  | bn.js            | medium   | >=5.0.0, <5.2.3             | 5.2.3  | fixed  |
| 5  | bn.js            | medium   | <4.12.3                     | 4.12.3 | fixed  |
| 4  | ajv              | medium   | <6.14.0                     | 6.14.0 | fixed  |
| 3  | axios            | high     | >=1.0.0, <=1.13.4           | 1.13.5 | fixed  |
| 2  | diff             | low      | >=6.0.0, <8.0.3             | 8.0.3  | fixed  |
| 1  | elliptic         | low      | <=6.6.1                     | —      | open   |

## So what?

- The literal ask in the ticket ("upgrade npm to fix high vulnerabilities" for
  alerts #3 and #7) appears to be **already done in the repo**. Verify by
  checking out `wdk-indexer-wrk-tron` and running `npm audit` — if it's clean
  for High+, the ticket can move to verification rather than implementation.
- The remaining open alert (#1, `elliptic <= 6.6.1`) has no patched version
  upstream. Decision needed: dismiss with risk note, or pin to a fork. This
  isn't what the ticket asked for, but it's the only thing left.
- The broader sweep ("npm audit across rumble and dependent packages") is still
  open. That work needs scoping with Alex.
