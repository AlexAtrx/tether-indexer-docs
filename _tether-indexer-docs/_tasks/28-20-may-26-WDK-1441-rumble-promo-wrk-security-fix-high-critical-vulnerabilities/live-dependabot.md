# Live Dependabot — `tetherto/rumble-promo-wrk`

Snapshot taken **2026-05-20** via `gh api repos/tetherto/rumble-promo-wrk/dependabot/alerts?state=open --paginate`.

See [`shared-dependabot-analysis.md`](../27-20-may-26-WDK-1438-wdk-app-node-security-fix-high-critical-vulnerabilities/shared-dependabot-analysis.md) for the cross-repo grouping and the suggested fix sequence.

## Open high/critical advisories on this repo

| # | Sev | Package | Scope | Vulnerable | Fixed | GHSA | Summary |
|---|-----|---------|-------|-----------|-------|------|---------|
| 16 | critical | `tether-wrk-base` | runtime | `>= 0` | `—` | [GHSA-wvh9-3hgj-7f22](https://github.com/advisories/GHSA-wvh9-3hgj-7f22) | Malware in tether-wrk-base |
| 13 | high | `lodash` | runtime | `>= 4.0.0, <= 4.17.23` | `4.18.0` | [GHSA-r5fr-rjxr-66jc](https://github.com/advisories/GHSA-r5fr-rjxr-66jc) | lodash vulnerable to Code Injection via `_.template` imports key names |
| 11 | high | `picomatch` | development | `>= 4.0.0, < 4.0.4` | `4.0.4` | [GHSA-c2c7-rcm5-vvqj](https://github.com/advisories/GHSA-c2c7-rcm5-vvqj) | Picomatch has a ReDoS vulnerability via extglob quantifiers |
| 10 | high | `flatted` | development | `<= 3.4.1` | `3.4.2` | [GHSA-rf6f-7fwh-wjgh](https://github.com/advisories/GHSA-rf6f-7fwh-wjgh) | Prototype Pollution via parse() in NodeJS flatted |
| 9 | high | `flatted` | development | `< 3.4.0` | `3.4.0` | [GHSA-25h7-pfq9-p65f](https://github.com/advisories/GHSA-25h7-pfq9-p65f) | flatted vulnerable to unbounded recursion DoS in parse() revive phase |
| 8 | high | `tar` | runtime | `<= 7.5.10` | `7.5.11` | [GHSA-9ppj-qmqm-q256](https://github.com/advisories/GHSA-9ppj-qmqm-q256) | node-tar Symlink Path Traversal via Drive-Relative Linkpath |
| 7 | high | `tar` | runtime | `<= 7.5.9` | `7.5.10` | [GHSA-qffp-2rhf-9h96](https://github.com/advisories/GHSA-qffp-2rhf-9h96) | tar has Hardlink Path Traversal via Drive-Relative Linkpath |
| 5 | high | `tar` | runtime | `< 7.5.8` | `7.5.8` | [GHSA-83g3-92jg-28cx](https://github.com/advisories/GHSA-83g3-92jg-28cx) | Arbitrary File Read/Write via Hardlink Target Escape Through Symlink C... |
| 4 | high | `tar` | runtime | `< 7.5.7` | `7.5.7` | [GHSA-34x7-hfp2-rc4v](https://github.com/advisories/GHSA-34x7-hfp2-rc4v) | node-tar Vulnerable to Arbitrary File Creation/Overwrite via Hardlink ... |
| 3 | high | `tar` | runtime | `<= 7.5.3` | `7.5.4` | [GHSA-r6q2-hw4h-h46w](https://github.com/advisories/GHSA-r6q2-hw4h-h46w) | Race Condition in node-tar Path Reservations via Unicode Ligature Coll... |
| 1 | high | `tar` | runtime | `<= 7.5.2` | `7.5.3` | [GHSA-8qq5-rm4j-mr97](https://github.com/advisories/GHSA-8qq5-rm4j-mr97) | node-tar is Vulnerable to Arbitrary File Overwrite and Symlink Poisoni... |
