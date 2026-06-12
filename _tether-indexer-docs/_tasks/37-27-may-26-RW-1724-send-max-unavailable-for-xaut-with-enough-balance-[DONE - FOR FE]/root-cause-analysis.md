# Root cause analysis - RW-1724

## Conclusion

The issue was not caused by the indexer or Rumble/WDK backend balance APIs.
`Max unavailable` is the mobile app fallback when the send-screen fee preload
cannot quote the fee. For XAUT on Ethereum, that preload calls the ERC-4337
wallet SDK's `quoteTransfer(...)`, which talks to the configured Candide
bundler/paymaster endpoints. During the repro window, the prod Candide
paymaster quote path for XAUT intermittently failed or returned no quote.

Because no device log from the failing state was captured after PR #1185, the
exact Candide-side error is not proven. The narrowest defensible root cause is:
transient Candide paymaster XAUT-on-Ethereum quote failure, not an app balance
bug and not a WDK/Rumble backend bug.

## Evidence

- The reported account had XAUT balance and manual XAUT sends completed. That
  rules out a simple "no funds" condition.
- `rumble-wallet-app-mobile` PR #1185 was logging only. It did not change the
  fee/max behavior.
- In `hooks/useFeePreload.ts`, EVM fee preload:
  - resolves the selected token address,
  - calls `quoteTransfer({ token, recipient, amount: 1 }, { paymasterToken })`,
  - throws if the quote is null,
  - catches quote errors and sets `feeEstimationFailed = true`.
- In `useSendTipFlow.ts`, `isMaxReady` is `!isEstimatingFees &&
  !feeEstimationFailed`.
- In `SendInputView.tsx`, `hasUsableMax` requires `isMaxReady`; otherwise the
  button renders `SEND.MAX_UNAVAILABLE`.
- The app config points Ethereum quotes to:
  - provider: `${RUMBLE_WALLET_RPC_URL}/eth`
  - bundler: `${RUMBLE_WALLET_RPC_URL}/candide/bundler/ethereum`
  - paymaster: `${RUMBLE_WALLET_RPC_URL}/candide/paymaster/ethereum`
- App v2.1.0 uses `@tetherto/wdk-wallet-evm-erc-4337@1.0.0-beta.6`, which uses
  `@tetherto/wdk-safe-relay-kit@4.1.5`.
- In that SDK path, `quoteTransfer` delegates to `quoteSendTransaction`, then to
  Safe4337 `createTransaction` and `getTokenExchangeRate`.
- For the app's ERC-20 paymaster-token mode, the relay kit calls Candide
  paymaster methods `pm_getPaymasterStubData`, `pm_getPaymasterData`, and
  `pm_supportedERC20Tokens`. The Slack/task note's `pm_sponsorUserOperation`
  wording is not the path used by this app config; that is sponsorship mode.
- Current prod paymaster responds to `pm_supportedERC20Tokens` and includes
  XAUT at `0x68749665ff8d2d112fa859aa293f07a622782f38`, matching the later
  "bug no longer reproduces" report.

## Practical next step

Ask QA to re-check on prod. If it reproduces again, collect the PR #1185 device
logs around `Fee preload failed` / `[fee-preload] quoteTransfer ...`; without
that log, there is no historical proof of the exact Candide response code or
error payload.
