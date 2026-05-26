# Live Dependabot — `tetherto/wdk-indexer-wrk-btc`

Snapshot taken **2026-05-20** via `gh api repos/tetherto/wdk-indexer-wrk-btc/dependabot/alerts?state=open --paginate`.

See [`shared-dependabot-analysis.md`](../27-20-may-26-WDK-1438-wdk-app-node-security-fix-high-critical-vulnerabilities/shared-dependabot-analysis.md) for the cross-repo grouping and the suggested fix sequence.

## Open high/critical advisories on this repo

| # | Sev | Package | Scope | Vulnerable | Fixed | GHSA | Summary |
|---|-----|---------|-------|-----------|-------|------|---------|
| 9 | high | `picomatch` | development | `>= 4.0.0, < 4.0.4` | `4.0.4` | [GHSA-c2c7-rcm5-vvqj](https://github.com/advisories/GHSA-c2c7-rcm5-vvqj) | Picomatch has a ReDoS vulnerability via extglob quantifiers |
| 8 | high | `flatted` | development | `<= 3.4.1` | `3.4.2` | [GHSA-rf6f-7fwh-wjgh](https://github.com/advisories/GHSA-rf6f-7fwh-wjgh) | Prototype Pollution via parse() in NodeJS flatted |
| 7 | high | `flatted` | development | `< 3.4.0` | `3.4.0` | [GHSA-25h7-pfq9-p65f](https://github.com/advisories/GHSA-25h7-pfq9-p65f) | flatted vulnerable to unbounded recursion DoS in parse() revive phase |
| 5 | high | `minimatch` | development | `< 3.1.3` | `3.1.3` | [GHSA-7r86-cg39-jmmj](https://github.com/advisories/GHSA-7r86-cg39-jmmj) | minimatch has ReDoS: matchOne() combinatorial backtracking via multipl... |
| 4 | high | `minimatch` | development | `< 3.1.4` | `3.1.4` | [GHSA-23c5-xmqv-rm74](https://github.com/advisories/GHSA-23c5-xmqv-rm74) | minimatch ReDoS: nested *() extglobs generate catastrophically backtra... |
| 3 | high | `minimatch` | development | `< 3.1.3` | `3.1.3` | [GHSA-3ppc-4f35-3m26](https://github.com/advisories/GHSA-3ppc-4f35-3m26) | minimatch has a ReDoS via repeated wildcards with non-matching literal... |
