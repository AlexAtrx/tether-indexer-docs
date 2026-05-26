# Live Dependabot — `tetherto/wdk-indexer-wrk-spark`

Snapshot taken **2026-05-20** via `gh api repos/tetherto/wdk-indexer-wrk-spark/dependabot/alerts?state=open --paginate`.

See [`shared-dependabot-analysis.md`](../27-20-may-26-WDK-1438-wdk-app-node-security-fix-high-critical-vulnerabilities/shared-dependabot-analysis.md) for the cross-repo grouping and the suggested fix sequence.

## Open high/critical advisories on this repo

| # | Sev | Package | Scope | Vulnerable | Fixed | GHSA | Summary |
|---|-----|---------|-------|-----------|-------|------|---------|
| 29 | high | `axios` | runtime | `>= 1.0.0, < 1.15.1` | `1.15.1` | [GHSA-pf86-5x62-jrwf](https://github.com/advisories/GHSA-pf86-5x62-jrwf) | Axios: Prototype Pollution Gadgets - Response Tampering, Data Exfiltra... |
| 28 | high | `axios` | runtime | `>= 1.0.0, < 1.15.1` | `1.15.1` | [GHSA-6chq-wfr3-2hj9](https://github.com/advisories/GHSA-6chq-wfr3-2hj9) | Axios: Header Injection via Prototype Pollution |
| 25 | high | `axios` | runtime | `>= 1.0.0, < 1.15.1` | `1.15.1` | [GHSA-pmwg-cvhr-8vh7](https://github.com/advisories/GHSA-pmwg-cvhr-8vh7) | Axios: Incomplete Fix for CVE-2025-62718 — NO_PROXY Protection Bypasse... |
| 23 | high | `axios` | runtime | `>= 1.0.0, < 1.15.2` | `1.15.2` | [GHSA-q8qp-cvcw-x6jj](https://github.com/advisories/GHSA-q8qp-cvcw-x6jj) | Axios has prototype pollution read-side gadgets in HTTP adapter that a... |
| 10 | high | `picomatch` | development | `>= 4.0.0, < 4.0.4` | `4.0.4` | [GHSA-c2c7-rcm5-vvqj](https://github.com/advisories/GHSA-c2c7-rcm5-vvqj) | Picomatch has a ReDoS vulnerability via extglob quantifiers |
| 9 | high | `flatted` | development | `<= 3.4.1` | `3.4.2` | [GHSA-rf6f-7fwh-wjgh](https://github.com/advisories/GHSA-rf6f-7fwh-wjgh) | Prototype Pollution via parse() in NodeJS flatted |
| 8 | high | `flatted` | development | `< 3.4.0` | `3.4.0` | [GHSA-25h7-pfq9-p65f](https://github.com/advisories/GHSA-25h7-pfq9-p65f) | flatted vulnerable to unbounded recursion DoS in parse() revive phase |
| 7 | high | `minimatch` | development | `< 3.1.3` | `3.1.3` | [GHSA-7r86-cg39-jmmj](https://github.com/advisories/GHSA-7r86-cg39-jmmj) | minimatch has ReDoS: matchOne() combinatorial backtracking via multipl... |
| 6 | high | `minimatch` | development | `< 3.1.4` | `3.1.4` | [GHSA-23c5-xmqv-rm74](https://github.com/advisories/GHSA-23c5-xmqv-rm74) | minimatch ReDoS: nested *() extglobs generate catastrophically backtra... |
| 5 | high | `minimatch` | development | `< 3.1.3` | `3.1.3` | [GHSA-3ppc-4f35-3m26](https://github.com/advisories/GHSA-3ppc-4f35-3m26) | minimatch has a ReDoS via repeated wildcards with non-matching literal... |
