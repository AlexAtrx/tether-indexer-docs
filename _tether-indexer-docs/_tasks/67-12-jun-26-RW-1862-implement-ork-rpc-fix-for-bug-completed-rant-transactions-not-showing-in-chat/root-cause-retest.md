# RW-1862 retest failure (12 jun 26): root cause

QA (andrey.gilyov) retested on staging after the fix deploy and reported "Not
fixed" at 10:58 UTC. Debugged the same day. **The ork RPC fix works. The rant
is now dropped one hop later, by a different bug: the EVM indexer's
`getGasLessTransactionReceipt` always throws `Cannot convert undefined to a
BigInt` because `erc4337WalletConfig` has no `chainId`, so the shard webhook
cron exhausts its 3 retries and marks the rant webhook failed.**

## Deploy state verified (all 3 staging boxes identical)

- Staging runs `main` via the Jun 10 16:20 UTC dev→main merges:
  rumble-ork-wrk 8a5a1d5 (#165), rumble-app-node ea877c9 (#240),
  rumble-data-shard-wrk b652a49 (#241). All services restarted
  Jun 10 18:48–20:35 UTC, i.e. AFTER the merge — the full fix set
  (#144, #163, #164, both #238s) is live.
- rumble-ork-wrk has `SHARD_RETRY_OPTS = { autoRetry: 2, autoRetryDelay: 200 }`
  (the #164 contract fix), node_modules has the pinned wdk-ork-wrk
  b72e608 (contains #144) and hp-svc-facs-net 1.1.0 (jRequest autoRetry).
- Alex's "deployed in staging" comment of 12 Jun 09:58 did not restart
  anything (uptimes unchanged); it didn't matter, the code was already live.

## QA's failing test, traced end to end

Test rant: 12 Jun 10:55:03 UTC, user 282786612, polygon usdt 0.01,
from wallet 95f4b950-3601-4ebc-9387-225377d72a28 to 39daed57-b245-40e6-b5fb-4a34a9f2cd30
(channel `_Rncnms70AA`), gasless transfer with
`transactionReceiptId 0x7dcd27036a46f546a6ebb3952eea9cea306e5c3c493f6905d4c2e0ac16cdde65`,
traceId `mob:282786612:e7e48a80-...`.

1. **app-node (stg1:3002)** received POST /api/v1/notifications WITH the rant
   `payload` field → forwarded body verbatim → 200 in 2.9 s.
2. **ork (stg2 ork-w-1-1)** `sendNotification`: balance guard passed
   (16.169 usdt), `payload` + `transactionHash` both present →
   `_addTxWebhook` awaited → completed. **The RW-1862 fix did its job.**
3. **shard (stg3 shard-api-w-2-2-1 / shard-proc-w-2-2)** `addTxWebhook` →
   "Store webhook being called: type - rant" stored at 10:55:04. Push
   notification to recipient devices attempted (separate FCM errors, cosmetic).
4. **webhook cron `processTxWebhooks`** picked it up at 10:55:10. Because the
   tx is a receipt-id (gasless 4337), `_isTxCompleted`
   (rumble-data-shard-wrk `workers/proc.shard.data.wrk.js:391`) calls
   `getGasLessTransactionReceipt` on the usdt-pol indexer.
5. **usdt-pol indexer** returned in <1 ms:
   `[HRPC_ERR]=Cannot convert undefined to a BigInt`
   (errorCode `ERR_GET_GASLESS_TX_RECEIPT_FROM_CHAIN_FAILED`) on attempts at
   10:55:10, 10:55:30, 10:55:50 → shard-proc:
   **"Max retries exceeded for 0x7dcd..., marking as failed"** → rant dropped.

Same failure for the 10:56:42 follow-up tx 0xda7df3...3d67 (that one was also
sent without `payload`, so it would not have produced a chat post anyway).

## The new root cause

`wdk-indexer-wrk-evm/workers/lib/chain.evm.client.js:315`
`getGasLessTransactionReceipt` lazily builds
`new WalletAccountReadOnlyEvmErc4337(paymasterToken.address, config)`.
Its constructor calls `predictSafeAddress(owner, { chainId, ... })` →
`Safe4337Pack.predictSafeAddress` (`@tetherto/wdk-safe-relay-kit`) →
`const chainIdBigInt = BigInt(chainId)`.

`config` is `conf.wrk.erc4337WalletConfig`, which on every deployed staging
EVM config (usdt-eth/arb/pol/plasma, xaut-*, usat-eth) has exactly these keys:
`provider, bundlerUrls, paymasterUrl, paymasterAddress, entrypointAddress,
paymasterToken` — **no `chainId`**. The repo's own `.example` configs also
lack it, and the constructor-time validation
(`chain.evm.client.js:86`, `Object.values(cfg).length < 6`) passes at 6 keys,
so the worker boots fine and only fails at the first gasless-receipt lookup.

Implications:

- Receipt-id (gasless) rants/tips can never post to chat on staging, for ANY
  EVM chain. Hash-based webhooks work (an eth rant webhook posted fine at
  10:12:33 the same morning via the `getTransactionFromChain` path).
- Prod configs almost certainly share the gap (the original Jun 4 prod
  examples were also gasless transfers that completed on-chain but never
  appeared in chat) — worth verifying on a prod box.
- This is a second, independent root cause that was masked until the WDK-1515
  ork fix let the webhook actually reach the shard queue.

## Fix options

1. **Code fix (preferred, no config rollout):** in
   `chain.evm.client.js getGasLessTransactionReceipt`, resolve the chain id
   from the provider on first use when absent:
   `config.chainId ??= (await provider.getNetwork()).chainId`. Also tighten
   the constructor validation to require the keys the lib actually needs
   instead of counting values.
2. **Config fix:** add `"chainId"` (1 eth / 137 pol / 42161 arb / 9745 plasma)
   to `erc4337WalletConfig` in every deployed json + the `.example`s, then
   restart the EVM indexers on stg1/2/3 (and prod).

Also worth a look while in there: a permanently failed webhook is dropped
silently after 3 attempts in ~40 s — for transient indexer errors that window
is very tight (a slow chain would also lose rants).

## Open question for QA

The second test tx (10:56:42, 0xda7df3...) was sent WITHOUT the rant `payload`
field — if that was meant to be a rant, there may additionally be an FE issue
where the rant payload is omitted on some path (the 10:12:02 eth test
`0xb69f76...551a` also lacked it).
