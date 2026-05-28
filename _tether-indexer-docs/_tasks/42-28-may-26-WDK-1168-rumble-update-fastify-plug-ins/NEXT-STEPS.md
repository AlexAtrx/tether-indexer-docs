# Next steps for "Rumble - Update Fastify plug ins" (WDK-1168 / RW-1680)

**Ticket:** https://app.asana.com/1/45238840754660/project/1210540875949204/task/1213226894059885

## What we know
- Part of the fastify v5 upgrade effort. After fastify is bumped to v5, every fastify plugin must be updated to a v5-compatible major.
- Example given: `@fastify/static` ^6.10.2 → ^8.3.0 (see svc-facs-httpd PR #8).
- Scope is broad: "check the repos, both internal and rumble, for what needs updating" — i.e. all HTTP/fastify-exposing repos (the `*-app-node` layer + shared `svc-facs-*` facilities).
- Marked High priority, currently Sprint 3, but flagged BLOCKED on the "update fastify version" card (which itself shows as completed — needs reconciling).
- Assignee Alex; can be handed to Usman.

## Evidence captured here
- 0 images
- 0 non-image attachments
- 1 real comment (an @-mention of Francesco Canessa); rest are system events in `comments.md`

## What's missing (from `missing-context.md`)
- Whether the blocking fastify-version card is actually done (Blocked? still BLOCKED vs ✓ on the card).
- The svc-facs-httpd PR #8 content (read via read-remote-repo when starting).
- Definitive list of target repos with fastify plugins to bump.
- Ownership (Alex vs Usman).

## Before starting work
- Reconcile the BLOCKED flag with the completed blocking card — confirm with Alex/Francesco whether this is unblocked.
- Inventory fastify + `@fastify/*` plugin versions across `wdk-app-node`, `rumble-app-node`, `wdk-indexer-app-node`, and `svc-facs-httpd`/other `svc-facs-*` repos; map each plugin's current major to its fastify-v5-compatible major.
- Note: prior fastify v5 security-fix work is already recorded for 3 app-nodes (see recent commit d7d5320) — check that work before re-doing it.
