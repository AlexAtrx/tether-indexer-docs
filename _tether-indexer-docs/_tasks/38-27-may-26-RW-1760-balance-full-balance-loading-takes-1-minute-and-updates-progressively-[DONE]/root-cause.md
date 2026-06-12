# Root cause

This is not primarily an indexer `/balance` API issue. The Home balance screen is
fed by the mobile app's WDK balance probes, not by `wdk-app-node` balance
endpoints.

## What is happening

After wallet auth, the root layout mounts `RumbleBalanceProbes` when
`walletStatus === 'READY'`:

- `rumble-wallet-app-mobile/app/_layout.tsx:379-384`

`RumbleBalanceProbes` creates one probe per Rumble `accountIndex`:

- `rumble-wallet-app-mobile/hooks/useRumbleAccountIndexes.ts:8-21`
- `rumble-wallet-app-mobile/hooks/useRumbleBalanceProbes.tsx:123-135`

Each probe calls `useBalancesForWallet(accountIndex, getAllTokenAssets(), ...)`
for every configured asset:

- `rumble-wallet-app-mobile/hooks/useRumbleBalanceProbes.tsx:25-32`
- `rumble-wallet-app-mobile/config/tokens.ts:16-150`

The locked SDK version is `@tetherto/wdk-react-native-core@1.0.0-beta.10`:

- `rumble-wallet-app-mobile/package.json:54-59`

In that SDK, `useBalancesForWallet` keys its query by the WDK
`activeWalletId`, not by the Rumble wallet identifier:

- `@tetherto/wdk-react-native-core@1.0.0-beta.10/src/hooks/useBalance.ts:290-318`

It then fetches balances by fanning out through the wallet worklet:

- `@tetherto/wdk-react-native-core@1.0.0-beta.10/src/services/balanceService.ts:359-411`
- `@tetherto/wdk-react-native-core@1.0.0-beta.10/src/services/balanceService.ts:414-472`

For each account index, the SDK groups assets by network, calls the worklet
for native balances and token balances, and applies a per-network 15s timeout.
The app has 15 assets across bitcoin, spark, ethereum, polygon, arbitrum, and
plasma. This makes the first Home load scale as:

`Rumble account indexes x networks/providers x 15s timeout/retry behavior`

As each account-index query settles, `useAggregatedBalances` merges that query's
rows into the display tree and the Home total is recalculated:

- `rumble-wallet-app-mobile/hooks/useAggregatedBalances.ts:66-83`
- `rumble-wallet-app-mobile/hooks/useAggregatedBalances.ts:118-155`
- `rumble-wallet-app-mobile/hooks/useAggregatedBalances.ts:182-184`

That explains the video's staged totals: the UI is not waiting for one coherent
"all wallets/all assets" result. It renders the aggregate after each probe cache
update, so totals climb as account indexes finish at different times.

## Pull-to-refresh bug

Home pull-to-refresh currently targets the wrong balance query keys.

The active balance probes/readers use:

`balanceQueryKeys.byWallet(activeWalletId || '', accountIndex), 'all'`

Evidence:

- `rumble-wallet-app-mobile/hooks/useRumbleBalanceProbes.tsx:27-32`
- `rumble-wallet-app-mobile/hooks/useAggregatedBalances.ts:69-82`
- `rumble-wallet-app-mobile/hooks/useBalanceFetcher.ts:36-48`

But `handleRefresh` invalidates and refetches:

`balanceQueryKeys.byWallet(wallet.identifier, wallet.accountIndex), 'all'`

Evidence:

- `rumble-wallet-app-mobile/hooks/useHomeCallbacks.ts:136-139`
- `rumble-wallet-app-mobile/hooks/useHomeCallbacks.ts:181-189`

Those are different namespaces. `activeWalletId` is the WDK seed/wallet id
(current user email in the authenticated flow), while `wallet.identifier` is the
Rumble wallet/user/channel identifier. For most wallets, pull-to-refresh does
not refetch the active balance probe query at all. The user then waits for the
root probes' polling / initial refetch to finish, which looks like a manual
refresh that takes a long time.

## Why the loading state persists

`useBalanceFetcher` is now explicitly read-only and says its options are no-ops:

- `rumble-wallet-app-mobile/hooks/useBalanceFetcher.ts:1-4`
- `rumble-wallet-app-mobile/hooks/useBalanceFetcher.ts:19-24`

But `useHomeWallets` still passes `refetchInterval: 5000` and `staleTime: 5000`,
which no longer control fetching:

- `rumble-wallet-app-mobile/hooks/useHomeWallets.ts:75-86`

Actual polling is owned by `RumbleBalanceProbes` at 30s:

- `rumble-wallet-app-mobile/hooks/useRumbleBalanceProbes.tsx:17-31`

So the Home layer believes it has a 5s balance refresh path, but the active
fetcher is a separate 30s root probe path. Combined with the query-key mismatch,
this produces the observed "pull to refresh, then wait" behavior.

## Fix direction

1. Refetch the same query keys that `RumbleBalanceProbes` owns:
   `balanceQueryKeys.byWallet(activeWalletId || '', accountIndex), 'all'`.
2. Consider centralizing a helper for "Rumble balance probe query key" so
   probes, read-only subscribers, and refresh callbacks cannot drift again.
3. Avoid rendering a final-looking aggregate until all tracked account-index
   probes have either settled or a deliberate cache fallback policy is applied.
4. Keep the 30s probe interval unless the worklet/provider fan-out is reduced;
   lowering the interval alone risks the overload already noted in
   `useAppResumeBalanceRefresh`.

This does not need to wait for transaction history v2. Transaction history v2 may
help reconciliation/history UX, but this balance-loading bug is in the mobile
balance probe/query-key/aggregation path.
