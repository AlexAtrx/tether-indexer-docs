# Migrate setting user data on wdk base layer

- **URL:** https://app.asana.com/1/45238840754660/project/1210540875949204/task/1216237230149454
- **GID:** 1216237230149454
- **Project:** WDK Backends
- **Section:** TO DO
- **Assignee:** Alex Atrash (inbox)
- **Status:** open
- **Created:** 2026-07-02T08:50:37.392Z (by Vigan Abdurrahmani)
- **Modified:** 2026-07-02T08:52:32.309Z
- **Due:** —
- **Tags:** —
- **Custom fields:** WDK: WDK-1589, Priority: High, Area: Dev, Sprint: Sprint 5, Label: Open Source, TW Support, City Support, RW Support, Generic Support

## Related ticket

- **WDK-1522** "Support setting multiple user-data keys in one request" (GID 1215365454673850) — local folder:
  `_tasks/83-01-jul-26-WDK-1522-support-setting-multiple-user-data-keys-in-one-request [DONE]/`
  WDK-1522's description was updated on 2026-07-02 to cross-link back to this ticket. The batch
  set/get implementation for WDK-1522 is done on the tether-wallet fork (PRs: app-node #169,
  ork #81, data-shard #141, all into `dev`). This refactor ticket exists because that work
  surfaced the duplication of the user-data API across the tether-wallet and rumble forks.
