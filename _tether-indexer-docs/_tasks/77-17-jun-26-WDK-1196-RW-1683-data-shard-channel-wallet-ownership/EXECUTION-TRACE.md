# Execution trace - card 1 (data-shard)

Date: 2026-06-19. Local branches off current dev, not pushed.
Full rollup: `_tasks/80-19-jun-26-WDK-1196-RW-1683-channel-split-execution-rollup/` (README.md, COMMITS.md, FINDINGS.md).

- wdk-data-shard-wrk: `refactor/WDK-1196-remove-channel-wallet-ownership` @ `22ed36d` (remove channel logic, generify hooks, drop walletTypes/getActiveChannelWallet/Mongo index; HyperDB schema kept).
- rumble-data-shard-wrk: `feat/WDK-1196-channel-wallet-ownership` @ `4f3164a` (own channel hooks + channelId validation/persistence, re-add getActiveChannelWallet + Mongo index + walletTypes filtering).

Finding fix included: channelId now type-gated in `_validateNewWallet` (rejects channelId on non-channel wallets).

Split-out (NOT this card): rumble-data-shard-wrk `fix/balance-request-timeout-budget` @ `e867c8d` - the balance-timeout policy was extracted here.
