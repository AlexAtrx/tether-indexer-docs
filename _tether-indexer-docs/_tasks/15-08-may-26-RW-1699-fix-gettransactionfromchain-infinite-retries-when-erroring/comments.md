# Comments

Chronological. Only `comment_added` and signal-bearing system events are kept.

---

## 2026-05-04T18:40:30Z — Francesco Canessa (system: added_to_project)

Added this task to `WDK Indexer and Wallet Backends`.

## 2026-05-04T18:40:39Z — Francesco Canessa (system: assigned)

Assigned to Alex Atrash.

## 2026-05-04T18:43:00Z — Francesco Canessa (system: added_to_project)

Added this task to `Rumble Wallet`.

## 2026-05-05T11:47:58Z — Alex Atrash (system: section_changed)

Moved this task from "TO DO" to "DEV IN PROGRESS" in `WDK Indexer and Wallet Backends`.

## 2026-05-08T09:56:10Z — Alex Atrash (comment)

> @Francesco Canessa — to write the command I need:
>
> 1. wallet/user/shard id for `86e0c91e…`
> 2. one-shot script for Andrei tonight, or a small admin RPC on the proc worker?
>
> Side note on "stop after N retries": that cap exists already
> ([proc.shard.data.wrk.js:259](https://github.com/tetherto/rumble-data-shard-wrk/blob/dbafa2b77179de62f07e7ee3c7bd45366c9ef779/workers/proc.shard.data.wrk.js#L259),
> ~50min for BTC) but it isn't firing here because `getTransactionFromChain`
> throws instead of returning `{retry:true}`. I'll fix that as part of this
> ticket.

## 2026-05-08T15:57:15Z — Francesco Canessa (system: notes_changed)

Changed the description.

## 2026-05-08T15:57:39Z — Francesco Canessa (system: name_changed)

Renamed task to `Fix  \`getTransactionFromChain \` infinite retries when erroring` (was: "Provide commands to delete a transaction that is not on the mempool anymore").

## 2026-05-08T15:58:13Z — Francesco Canessa (system: enum_custom_field_changed)

Cleared Priority (was Critical — Bugs only). Now reads as High via the WDK Priority field.
