# Next steps for wdk-indexer-app-node - Security - Fix High/Critical Vulnerabilities

**Ticket:** https://app.asana.com/1/45238840754660/project/1210540875949204/task/1214716462372233

## What we know
- Repo: `tetherto/wdk-indexer-app-node`
- 3 open high/critical Dependabot advisories as of 2026-05-11.
- Sibling tickets in the same sprint cover the other indexer/app-node/wrk repos under one
  parent ("Security - Fix ... High/Critical Vulnerabilities").
- No comments, no attachments — the ticket body is a pointer to the GitHub Dependabot
  dashboard.

## Evidence captured here
- 0 images analysed in `image-analysis.md`
- 0 non-image attachments under `attachments/`
- 0 comments in `comments.md`

## What's missing (from `missing-context.md`)
- Live Dependabot list for `tetherto/wdk-indexer-app-node` (the 3 alerts themselves).
- The parent Asana task's intended scope and acceptance criteria.
- Drift between the description snapshot (2026-05-11) and today.

## Before starting work
1. Pull the live Dependabot list:
   `gh api repos/tetherto/wdk-indexer-app-node/dependabot/alerts --paginate \
     -q '.[] | select(.state=="open") | {number, severity:.security_advisory.severity, package:.dependency.package.name, summary:.security_advisory.summary, fixed:.security_vulnerability.first_patched_version.identifier}'`
2. Cross-check the parent task for sprint-level scope/DoD.
3. Group the advisories by package — many repos in this sibling set will share the same
   transitive dependency (e.g. ws / cookie / micromatch / undici / semver), so a single
   `npm update` or `package-lock.json` resolution may resolve advisories across multiple
   sibling tickets at once. Coordinate with the other 6 tickets in this batch.


## Live Dependabot data (pulled 2026-05-20)

- This folder: [`live-dependabot.md`](live-dependabot.md) — per-repo advisory table.
- Cross-repo: [`shared-dependabot-analysis.md`](../27-20-may-26-WDK-1438-wdk-app-node-security-fix-high-critical-vulnerabilities/shared-dependabot-analysis.md) — clusters shared with sibling tickets and the suggested fix sequence.
- **Live count for this repo:** 0 critical, 3 high (was 3 at 2026-05-11).
