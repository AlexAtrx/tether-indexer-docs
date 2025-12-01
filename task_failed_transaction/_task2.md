## Context

A dev says:

-------
Afaik we store transactions from workers/lib/chain.erc20.client.js #L130 permanently.

However I see in rumble we have custom logic that allows storing other transactions more quickly via webhooks.

There we end up calling getTransaction via /rumble-data-shard-wrk/blob/main/workers/proc.shard.data.wrk.js#L305 we check timestamp so at least we know once it's submitted.

But again we check the transfer logs so this transaction always returns empty:
```
getTransactionFromChain -d '{"hash": "0x083efdddcc9946833f701a230dc3bff4cf3a7f1ee98a4006625b5db37d5b4db2"}' -t 30000
[]
```
also for AA bundled transactions when we decode the tx from user operation we check if status is 1
wdk-indexer-wrk-evm/blob/main/workers/lib/chain.erc20.client.js#L57

not sure if there's some angle that I'm missing.
-------

## Task

Check exactly what he's saying and understand his point. 
Review your codebase and your porposed fix. 
Give me a short answer to him. 