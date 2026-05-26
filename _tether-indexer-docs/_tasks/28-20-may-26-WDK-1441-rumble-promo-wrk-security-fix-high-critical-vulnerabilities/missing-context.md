# Missing context

The ticket is a thin pointer to the GitHub Dependabot dashboard. The
actual content (which advisories, which packages, severity, affected
versions, suggested upgrades) lives entirely in GitHub and is not
captured in the Asana ticket itself.

- [ ] External system: "https://github.com/tetherto/rumble-promo-wrk/security/dependabot" — **Need from Alex / GitHub:** the
  full list of 11 open high/critical advisories on
  `tetherto/rumble-promo-wrk` (package, advisory id/CVE, severity, affected
  range, fixed version, transitive vs direct). Use the GitHub CLI
  (`gh api repos/tetherto/rumble-promo-wrk/dependabot/alerts --paginate`) or
  open the Dependabot dashboard. **Source:** description.
- [ ] External tickets: "https://app.asana.com/1/45238840754660/project/1210540875949204/task/1213478780310237" — **Need from Alex:** review the
  parent Asana task ("Security - Fix Tron Indexer ..." family) for the
  intended scope, deadline, and definition of done across all sibling
  repos. **Source:** description.
- [ ] Alert count drift: the description fixes the count at
  "11 open at 2026-05-11". Today is 2026-05-20, so the live
  Dependabot count may differ — pull the live list before scoping the
  fix. **Source:** description.
