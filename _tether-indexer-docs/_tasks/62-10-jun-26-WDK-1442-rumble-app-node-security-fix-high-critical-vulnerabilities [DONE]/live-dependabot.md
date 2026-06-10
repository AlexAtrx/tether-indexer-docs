# Live Dependabot — `tetherto/rumble-app-node`

Snapshot taken **2026-05-20** via `gh api repos/tetherto/rumble-app-node/dependabot/alerts?state=open --paginate`.

See [`shared-dependabot-analysis.md`](../27-20-may-26-WDK-1438-wdk-app-node-security-fix-high-critical-vulnerabilities/shared-dependabot-analysis.md) for the cross-repo grouping and the suggested fix sequence.

## Open high/critical advisories on this repo

| # | Sev | Package | Scope | Vulnerable | Fixed | GHSA | Summary |
|---|-----|---------|-------|-----------|-------|------|---------|
| 30 | high | `fast-uri` | runtime | `<= 3.1.1` | `3.1.2` | [GHSA-v39h-62p7-jpjc](https://github.com/advisories/GHSA-v39h-62p7-jpjc) | fast-uri vulnerable to host confusion via percent-encoded authority de... |
| 29 | high | `fast-uri` | runtime | `<= 3.1.0` | `3.1.1` | [GHSA-q3j6-qgpj-74h6](https://github.com/advisories/GHSA-q3j6-qgpj-74h6) | fast-uri vulnerable to path traversal via percent-encoded dot segments |
| 3 | high | `fastify` | runtime | `< 5.7.2` | `5.7.2` | [GHSA-jx2c-rxcm-jvmq](https://github.com/advisories/GHSA-jx2c-rxcm-jvmq) | Fastify's Content-Type header tab character allows body validation byp... |
| 1 | high | `SonarSource/sonarqube-scan-action` | runtime | `>= 4.0.0, < 6.0.0` | `6.0.0` | [GHSA-5xq9-5g24-4g6f](https://github.com/advisories/GHSA-5xq9-5g24-4g6f) | Argument injection vulnerability in SonarQube Scan Action |
