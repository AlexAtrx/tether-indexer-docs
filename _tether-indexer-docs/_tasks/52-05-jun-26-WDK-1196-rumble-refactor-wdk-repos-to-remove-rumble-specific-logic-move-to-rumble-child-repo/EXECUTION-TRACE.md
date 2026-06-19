# Execution trace - umbrella

Date: 2026-06-19. The three-card split was implemented and committed on local
branches (off current dev, not pushed). Full rollup with all commits, per-repo
detail, review findings, and PR sequencing:

  `_tasks/80-19-jun-26-WDK-1196-RW-1683-channel-split-execution-rollup/` (README.md, COMMITS.md, FINDINGS.md)

Six branches (one commit each):
- wdk-data-shard-wrk `refactor/WDK-1196-remove-channel-wallet-ownership` @ `22ed36d`
- rumble-data-shard-wrk `feat/WDK-1196-channel-wallet-ownership` @ `4f3164a`
- wdk-ork-wrk `refactor/WDK-1196-remove-channel-shard-routing` @ `c6a544f`
- rumble-ork-wrk `feat/WDK-1196-channel-shard-routing` @ `37543e3`
- wdk-app-node `refactor/WDK-1196-remove-channel-wallet-api` @ `26054bf`
- rumble-app-node `feat/WDK-1196-channel-wallet-api` @ `9a48eec`

Split-out: rumble-data-shard-wrk `fix/balance-request-timeout-budget` @ `e867c8d`.

PR sequencing blocker: rumble git-SHA pins must be bumped only after each WDK
removal merges on tetherto. Order: data-shard -> ork -> app-node.
