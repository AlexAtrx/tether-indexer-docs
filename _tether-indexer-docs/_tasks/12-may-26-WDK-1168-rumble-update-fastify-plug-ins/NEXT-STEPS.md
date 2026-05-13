# Next steps for Rumble - Update Fastify plug ins (WDK-1168 / RW-1680)

**Ticket:** https://app.asana.com/1/45238840754660/project/1210540875949204/task/1213226894059885

## What we know
- Fastify is being upgraded to v5 across Tether/Rumble backends; every `@fastify/*` plugin needs to move to a v5-compatible major (e.g. `@fastify/static` 6.x → 8.x).
- Reference PR for the pattern: `tetherto/svc-facs-httpd#8` ("Update fastify to v5").
- Alex's 2026-05-06 comment: PR #8 is blocking. `svc-facs-httpd@v1.0.0` was tagged 2026-04-30 without it, so the consumer repos (`wdk-indexer-app-node`, `wdk-app-node`, `rumble-app-node`) can't fully bump their `@fastify/*` plugins. Boka's bump on `wdk-indexer-app-node#52` was partially reverted on 2026-05-01.
- Ticket is marked **BLOCKED** and **High priority**, Sprint 1, Area = Rumble.
- Description says scope covers both internal (WDK) and Rumble repos. The Rumble-only fixes/migrations rule applies — anything Rumble-specific lands in `rumble-*` repos, not the public `wdk-*` repos.

## Evidence captured here
- 2 comments in `comments.md` (plus relevant system events)
- 0 images analysed (no screenshots on this ticket)
- 0 non-image attachments

## What's missing (from `missing-context.md`)
- Current state of `svc-facs-httpd#8` (merged yet?) and the partial-revert commit on `wdk-indexer-app-node#52`.
- Status / overlap of the sibling tickets `1213145412557891` ("Security - Chore - update fastify version") and `1213478780310237` ("Rumble - Security - Fix Tron Indexer High Vulnerabilities").
- Confirmation of the full repo scope (just the three Alex named, or are there more `rumble-*` / `wdk-*` services with fastify plugins?).
- Whether BLOCKED is purely the PR-#8 gate or something else.

## Before starting work
Ask Alex for the missing items above first — especially the live state of `svc-facs-httpd#8` and the exact revert on `wdk-indexer-app-node#52`. Then:

1. Grep `package.json` across the WDK + rumble repos for `@fastify/` deps and tabulate the version each repo is on.
2. Identify which repos still need the bump and which were already partially done (per Boka's #52).
3. Once `svc-facs-httpd#8` lands and a new major is cut, plan the consumer PRs. Keep Rumble-only changes in `rumble-*` repos.
