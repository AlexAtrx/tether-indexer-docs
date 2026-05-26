# Live Dependabot analysis — security batch (WDK-1438 / 1441-1446)

Snapshot taken **2026-05-20** via `gh api repos/tetherto/<repo>/dependabot/alerts?state=open --paginate`.

Parent task: https://app.asana.com/1/45238840754660/project/1210540875949204/task/1213478780310237

## Per-repo live counts (high + critical only)

| Repo | Ticket | Critical | High | Total h/c | Asana snapshot (2026-05-11) |
|------|--------|----------|------|-----------|-----------------------------|
| `wdk-app-node` | WDK-1438 | 0 | 3 | 3 | 3 |
| `rumble-promo-wrk` | WDK-1441 | 1 | 10 | 11 | 11 |
| `rumble-app-node` | WDK-1442 | 0 | 4 | 4 | 4 |
| `wdk-indexer-wrk-evm` | WDK-1443 | 0 | 9 | 9 | 9 |
| `wdk-indexer-app-node` | WDK-1444 | 0 | 3 | 3 | 3 |
| `wdk-indexer-wrk-spark` | WDK-1445 | 0 | 10 | 10 | 10 |
| `wdk-indexer-wrk-btc` | WDK-1446 | 0 | 6 | 6 | 6 |

Live counts have drifted up by 1-3 since the 2026-05-11 ticket snapshot (Asana column).

## Critical / urgent

### `tether-wrk-base` GHSA-wvh9-3hgj-7f22 — "Malware in tether-wrk-base"

- **Affected:** `rumble-promo-wrk` only (`package-lock.json`, runtime, direct).
- **Severity:** critical. No fixed version.
- **Cause:** rumble-promo-wrk's `package.json` lists
  `"tether-wrk-base": "git+https://github.com/tetherto/tether-wrk-base.git"` — install is
  pulled directly from the internal GitHub repo, NOT from public npm. A squatter published
  a malicious package under the unscoped name `tether-wrk-base` on public npm, and
  Dependabot matches by package name and flags it as malware. **Almost certainly a false
  positive for the actual install path.**
- **Recommendation:**
  1. Confirm the lockfile resolves to the git URL, not the npm tarball:
     ```bash
     gh api repos/tetherto/rumble-promo-wrk/contents/package-lock.json --jq .content | base64 -d \
       | jq '.packages | with_entries(select(.key | test("tether-wrk-base")))'
     ```
  2. If confirmed git-only, dismiss the alert with `tolerable_risk` + comment explaining
     the name collision, OR rename the internal package to a scoped name like
     `@tetherto/wrk-base` (longer-term fix that also closes the squatting risk).
  3. Do NOT just `npm i` blindly — that may resolve to the malicious npm tarball if the
     git URL ever fails to fetch. Pin/lock the git SHA.

## Shared advisories (close multiple tickets with one upgrade)

Listed by reach (how many repos one fix covers):

### `flatted` — development, affects 4 repos

- **Recommended bump:** `>= 3.4.2` (closes all listed advisories for this package).

| GHSA | Sev | Vulnerable range | Fixed | Summary |
|------|-----|------------------|-------|---------|
| [GHSA-25h7-pfq9-p65f](https://github.com/advisories/GHSA-25h7-pfq9-p65f) | high | `< 3.4.0` | `3.4.0` | flatted vulnerable to unbounded recursion DoS in parse() revive phase |
| [GHSA-rf6f-7fwh-wjgh](https://github.com/advisories/GHSA-rf6f-7fwh-wjgh) | high | `<= 3.4.1` | `3.4.2` | Prototype Pollution via parse() in NodeJS flatted |

**Affected repos:** `rumble-promo-wrk` (WDK-1441), `wdk-indexer-wrk-btc` (WDK-1446), `wdk-indexer-wrk-evm` (WDK-1443), `wdk-indexer-wrk-spark` (WDK-1445)

### `picomatch` — development, affects 4 repos

- **Recommended bump:** `>= 4.0.4` (closes all listed advisories for this package).

| GHSA | Sev | Vulnerable range | Fixed | Summary |
|------|-----|------------------|-------|---------|
| [GHSA-c2c7-rcm5-vvqj](https://github.com/advisories/GHSA-c2c7-rcm5-vvqj) | high | `>= 4.0.0, < 4.0.4` | `4.0.4` | Picomatch has a ReDoS vulnerability via extglob quantifiers |

**Affected repos:** `rumble-promo-wrk` (WDK-1441), `wdk-indexer-wrk-btc` (WDK-1446), `wdk-indexer-wrk-evm` (WDK-1443), `wdk-indexer-wrk-spark` (WDK-1445)

### `fast-uri` — runtime, affects 3 repos

- **Recommended bump:** `>= 3.1.2` (closes all listed advisories for this package).

| GHSA | Sev | Vulnerable range | Fixed | Summary |
|------|-----|------------------|-------|---------|
| [GHSA-q3j6-qgpj-74h6](https://github.com/advisories/GHSA-q3j6-qgpj-74h6) | high | `<= 3.1.0` | `3.1.1` | fast-uri vulnerable to path traversal via percent-encoded dot segments |
| [GHSA-v39h-62p7-jpjc](https://github.com/advisories/GHSA-v39h-62p7-jpjc) | high | `<= 3.1.1` | `3.1.2` | fast-uri vulnerable to host confusion via percent-encoded authority delimiters |

**Affected repos:** `rumble-app-node` (WDK-1442), `wdk-app-node` (WDK-1438), `wdk-indexer-app-node` (WDK-1444)

### `fastify` — runtime, affects 3 repos

- **Recommended bump:** `>= 5.7.2` (closes all listed advisories for this package).

| GHSA | Sev | Vulnerable range | Fixed | Summary |
|------|-----|------------------|-------|---------|
| [GHSA-jx2c-rxcm-jvmq](https://github.com/advisories/GHSA-jx2c-rxcm-jvmq) | high | `< 5.7.2` | `5.7.2` | Fastify's Content-Type header tab character allows body validation bypass |

**Affected repos:** `rumble-app-node` (WDK-1442), `wdk-app-node` (WDK-1438), `wdk-indexer-app-node` (WDK-1444)

### `minimatch` — development, affects 3 repos

- **Recommended bump:** `>= 3.1.4` (closes all listed advisories for this package).

| GHSA | Sev | Vulnerable range | Fixed | Summary |
|------|-----|------------------|-------|---------|
| [GHSA-7r86-cg39-jmmj](https://github.com/advisories/GHSA-7r86-cg39-jmmj) | high | `< 3.1.3` | `3.1.3` | minimatch has ReDoS: matchOne() combinatorial backtracking via multiple non-adjacent GLOBS... |
| [GHSA-3ppc-4f35-3m26](https://github.com/advisories/GHSA-3ppc-4f35-3m26) | high | `< 3.1.3` | `3.1.3` | minimatch has a ReDoS via repeated wildcards with non-matching literal in pattern |
| [GHSA-23c5-xmqv-rm74](https://github.com/advisories/GHSA-23c5-xmqv-rm74) | high | `< 3.1.4` | `3.1.4` | minimatch ReDoS: nested *() extglobs generate catastrophically backtracking regular expres... |

**Affected repos:** `wdk-indexer-wrk-btc` (WDK-1446), `wdk-indexer-wrk-evm` (WDK-1443), `wdk-indexer-wrk-spark` (WDK-1445)

## Per-repo deltas (advisories not shared)

### `wdk-app-node` (WDK-1438) — 0 repo-unique advisories

All h/c advisories on this repo are covered by the shared clusters above.

### `rumble-promo-wrk` (WDK-1441) — 8 repo-unique advisories

| GHSA | Sev | Package | Vulnerable | Fixed | Scope | Manifest |
|------|-----|---------|-----------|-------|-------|----------|
| [GHSA-wvh9-3hgj-7f22](https://github.com/advisories/GHSA-wvh9-3hgj-7f22) | critical | `tether-wrk-base` | `>= 0` | `—` | runtime | `package-lock.json` |
| [GHSA-r5fr-rjxr-66jc](https://github.com/advisories/GHSA-r5fr-rjxr-66jc) | high | `lodash` | `>= 4.0.0, <= 4.17.23` | `4.18.0` | runtime | `package-lock.json` |
| [GHSA-9ppj-qmqm-q256](https://github.com/advisories/GHSA-9ppj-qmqm-q256) | high | `tar` | `<= 7.5.10` | `7.5.11` | runtime | `package-lock.json` |
| [GHSA-qffp-2rhf-9h96](https://github.com/advisories/GHSA-qffp-2rhf-9h96) | high | `tar` | `<= 7.5.9` | `7.5.10` | runtime | `package-lock.json` |
| [GHSA-83g3-92jg-28cx](https://github.com/advisories/GHSA-83g3-92jg-28cx) | high | `tar` | `< 7.5.8` | `7.5.8` | runtime | `package-lock.json` |
| [GHSA-34x7-hfp2-rc4v](https://github.com/advisories/GHSA-34x7-hfp2-rc4v) | high | `tar` | `< 7.5.7` | `7.5.7` | runtime | `package-lock.json` |
| [GHSA-r6q2-hw4h-h46w](https://github.com/advisories/GHSA-r6q2-hw4h-h46w) | high | `tar` | `<= 7.5.3` | `7.5.4` | runtime | `package-lock.json` |
| [GHSA-8qq5-rm4j-mr97](https://github.com/advisories/GHSA-8qq5-rm4j-mr97) | high | `tar` | `<= 7.5.2` | `7.5.3` | runtime | `package-lock.json` |

### `rumble-app-node` (WDK-1442) — 1 repo-unique advisory

| GHSA | Sev | Package | Vulnerable | Fixed | Scope | Manifest |
|------|-----|---------|-----------|-------|-------|----------|
| [GHSA-5xq9-5g24-4g6f](https://github.com/advisories/GHSA-5xq9-5g24-4g6f) | high | `SonarSource/sonarqube-scan-action` | `>= 4.0.0, < 6.0.0` | `6.0.0` | runtime | `.github/workflows/build.yml` |

### `wdk-indexer-wrk-evm` (WDK-1443) — 3 repo-unique advisories

| GHSA | Sev | Package | Vulnerable | Fixed | Scope | Manifest |
|------|-----|---------|-----------|-------|-------|----------|
| [GHSA-vrm6-8vpv-qv8q](https://github.com/advisories/GHSA-vrm6-8vpv-qv8q) | high | `undici` | `< 6.24.0` | `6.24.0` | development | `package-lock.json` |
| [GHSA-v9p9-hfj2-hcw8](https://github.com/advisories/GHSA-v9p9-hfj2-hcw8) | high | `undici` | `< 6.24.0` | `6.24.0` | development | `package-lock.json` |
| [GHSA-f269-vfmq-vjvj](https://github.com/advisories/GHSA-f269-vfmq-vjvj) | high | `undici` | `>= 6.0.0, < 6.24.0` | `6.24.0` | development | `package-lock.json` |

### `wdk-indexer-app-node` (WDK-1444) — 0 repo-unique advisories

All h/c advisories on this repo are covered by the shared clusters above.

### `wdk-indexer-wrk-spark` (WDK-1445) — 4 repo-unique advisories

| GHSA | Sev | Package | Vulnerable | Fixed | Scope | Manifest |
|------|-----|---------|-----------|-------|-------|----------|
| [GHSA-pf86-5x62-jrwf](https://github.com/advisories/GHSA-pf86-5x62-jrwf) | high | `axios` | `>= 1.0.0, < 1.15.1` | `1.15.1` | runtime | `package-lock.json` |
| [GHSA-6chq-wfr3-2hj9](https://github.com/advisories/GHSA-6chq-wfr3-2hj9) | high | `axios` | `>= 1.0.0, < 1.15.1` | `1.15.1` | runtime | `package-lock.json` |
| [GHSA-pmwg-cvhr-8vh7](https://github.com/advisories/GHSA-pmwg-cvhr-8vh7) | high | `axios` | `>= 1.0.0, < 1.15.1` | `1.15.1` | runtime | `package-lock.json` |
| [GHSA-q8qp-cvcw-x6jj](https://github.com/advisories/GHSA-q8qp-cvcw-x6jj) | high | `axios` | `>= 1.0.0, < 1.15.2` | `1.15.2` | runtime | `package-lock.json` |

### `wdk-indexer-wrk-btc` (WDK-1446) — 0 repo-unique advisories

All h/c advisories on this repo are covered by the shared clusters above.

## Suggested fix sequence

Most advisories are in `package-lock.json` only (transitive devDependencies via standard /
brittle / husky / sinon). For npm runtime+dev sets, a single `npm update` + commit usually
resolves all transitive-only entries (flatted, picomatch, minimatch, undici). Runtime
direct deps (fastify, fast-uri, axios, tar, lodash) need an explicit version bump in
`package.json`.

1. **Across all 7 repos — transitive cleanup (one PR per repo):**
   ```bash
   npm update                      # bumps within ^/~ ranges
   npm dedupe                      # collapse duplicate trees
   npm audit fix                   # patches with no breaking-change risk
   # then verify no advisories remain at high/critical:
   npm audit --omit=dev --audit-level=high
   ```
   Expected to close: all `flatted`, `picomatch`, `minimatch`, `undici` advisories (devDeps).

2. **`wdk-app-node` / `rumble-app-node` / `wdk-indexer-app-node` — bump fastify family:**
   ```bash
   npm i fastify@^5.7.2 fast-uri@^3.1.2
   ```
   Closes GHSA-jx2c-rxcm-jvmq + the two `fast-uri` advisories. `fast-uri` is transitive via
   fastify but pinning explicitly forces resolution.

3. **`wdk-indexer-wrk-spark` — bump axios:**
   ```bash
   npm i axios@^1.15.2
   ```
   Closes all 4 axios advisories in one shot.

4. **`rumble-promo-wrk` — special-case package:**
   - Bump `tar` (direct or hoist its parent) to `^7.5.11` — closes 6 tar advisories.
   - Bump `lodash` to `^4.18.0`.
   - Address `tether-wrk-base` malware false-positive as described above.

5. **`rumble-app-node` — workflow file:**
   ```yaml
   # .github/workflows/build.yml
   - uses: SonarSource/sonarqube-scan-action@v6  # was v4/v5
   ```

## Verification after each PR

```bash
# Triple-check the alert closed (Dependabot can lag a few hours after merge)
gh api repos/tetherto/<repo>/dependabot/alerts --paginate \
  -q '[.[] | select(.state=="open") | select(.security_advisory.severity=="high" or .security_advisory.severity=="critical") | {number, sev:.security_advisory.severity, pkg:.dependency.package.name, ghsa:.security_advisory.ghsa_id}]'
```
