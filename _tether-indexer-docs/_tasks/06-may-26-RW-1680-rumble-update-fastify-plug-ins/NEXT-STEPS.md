# Next steps for Rumble - Update Fastify plug ins

**Ticket:** https://app.asana.com/1/45238840754660/project/1210540875949204/task/1213226894059885
**IDs:** RW-1680 / WDK-1168
**Status:** Open, BLOCKED, High priority, Sprint 1, assigned to Alex

## What we know
- Fastify is being upgraded to v5; every fastify plugin used across our repos must be bumped to a v5-compatible version.
- The reference example is https://github.com/tetherto/svc-facs-httpd/pull/8, which bumped `@fastify/static` from `^6.10.2` to `^8.3.0`.
- Scope is "internal and rumble" repos — i.e. both the shared `svc-facs-*` / `wrk-*` services and the Rumble-side wallet/indexer repos in this workspace.
- Description note "Already in progress from shared repos" implies the shared-repo side is partially or wholly done — only Rumble-side bumps may remain.
- Custom field `Blocked?` was set to BLOCKED on 2026-04-30 with no comment explaining why; description was edited the same minute (no diff captured here).
- Two related Asana tickets mentioned but not linked in this ticket: *Security - Chore - update fastify version* (Feb 11) and *Rumble - Security - Fix Tron Indexer High Vulnerabilities* (Mar 23).

## Evidence captured here
- 1 comment in `comments.md` (just an @-mention, no content)
- 0 images
- 0 non-image attachments

## What's missing (from `missing-context.md`)
- Confirmation that svc-facs-httpd PR #8 is the canonical pattern.
- Links to the two related Asana tickets (security/chore + Tron indexer vulnerabilities).
- Reason this is currently flagged BLOCKED.
- Confirmation of the target repo list.
- Whether this stays with Alex or goes to Usman.

## Before starting work
Ask Alex the missing-context items above first. In particular: **why is this BLOCKED?** — that gates whether to even start. Once unblocked, the obvious next step is to grep across the workspace for `@fastify/` package entries in every `package.json` and produce a per-repo bump list, mirroring the svc-facs-httpd PR #8 pattern.
