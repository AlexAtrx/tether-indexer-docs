# Comments

## Nicholas Hrboka — 2026-02-11T16:14:45Z

@Francesco Canessa

---

## Alex Atrash — 2026-05-06T15:40:31Z

@Francesco Canessa, picking this up. Confirming the blocker: `svc-facs-httpd` PR #8 ("Update fastify to v5", https://github.com/tetherto/svc-facs-httpd/pull/8) is still open, and `@tetherto/svc-facs-httpd@v1.0.0` was tagged Apr 30 without it, so the consumers (`wdk-indexer-app-node`, `wdk-app-node`, `rumble-app-node`) can't move their `@fastify/*` plugins to v5-era yet. Boka's bump on `wdk-indexer-app-node` (#52) was partially reverted May 1 for this reason.

Plan: land #8, cut a new `svc-facs-httpd` major, then redo the bumps on the three consumers? Any other repos in scope?

---

# Relevant system events

- 2026-02-11T16:11:31Z — Nicholas Hrboka added this task to WDK Backends
- 2026-02-11T16:56:14Z — Francesco Canessa assigned to Alex
- 2026-02-11T17:18:13Z — Nicholas Hrboka mentioned this task in another task: [Security - Chore - update fastify version](https://app.asana.com/1/45238840754660/project/1210540875949204/task/1213145412557891)
- 2026-03-23T13:58:31Z — Francesco Canessa mentioned this task in another task: [Rumble - Security - Fix Tron Indexer High Vulnerabilities](https://app.asana.com/1/45238840754660/project/1210540875949204/task/1213478780310237)
- 2026-04-24T15:40:35Z — Francesco Canessa changed Area / Project to Rumble
- 2026-04-27T19:09:52Z — Francesco Canessa changed Sprint to Sprint 1
- 2026-04-27T19:10:04Z — Added to Rumble Wallet project; RW field set to RW-1680
