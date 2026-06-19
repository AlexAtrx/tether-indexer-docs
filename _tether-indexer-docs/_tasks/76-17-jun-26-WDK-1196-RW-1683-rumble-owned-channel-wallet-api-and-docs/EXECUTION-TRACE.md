# Execution trace - card 3 (app / API / docs)

Date: 2026-06-19. Local branches off current dev, not pushed.
Full rollup: `_tasks/80-19-jun-26-WDK-1196-RW-1683-channel-split-execution-rollup/` (README.md, COMMITS.md, FINDINGS.md).

- wdk-app-node: `refactor/WDK-1196-remove-channel-wallet-api` @ `26054bf` (drop channel type/channelId/walletTypes/tip-jar codes from schemas + responses, genericize route descriptions, generic staticRootPath).
- rumble-app-node: `feat/WDK-1196-channel-wallet-api` @ `9a48eec` (re-add channel type, channelId, walletTypes, response channelId, tip-jar codes at the HTTP boundary; restore Swagger route descriptions).

Finding fix included: Rumble route descriptions restored (CHANNEL_ROUTE_DESCRIPTIONS) + new schema/docs unit test.
