# Comments

## 2026-03-02T04:29:29Z — Francesco Canessa (system: added_to_project)
Added this task to WDK Indexer and Wallet Backends.

## 2026-03-23T13:53:34Z — Francesco Canessa (system: assigned)
Assigned the task to Alex Atrash.

## 2026-04-27T19:10:17Z — Francesco Canessa (system: added_to_project)
Added this task to Rumble Wallet.

## 2026-04-28T13:21:16Z — Mohamed Elsabry (comment)
@Francesco Canessa why a Tron ticket for RW?

## 2026-04-28T13:24:00Z — Alex Atrash (comment)
We discuss it. I think the reason was that Tron is to be used in WL later? @Francesco Canessa

## 2026-05-04T13:08:33Z — Alex Atrash (comment)
@Francesco Canessa
Verified on tetherto/wdk-indexer-wrk-tron@main (commit 6e02432, "promote dev to main #107", 2026-05-03).

Both dependabot alerts referenced in the description are already: fixed (closed 2026-04-26).

```
npm audit --package-lock-only on main:
{ critical: 0, high: 0, moderate: 0, low: 10, total: 10 }
```

The 10 lows are a single chain rooted at the still-open Dependabot alert #1 (elliptic <= 6.6.1, no upstream patch), surfacing through @ethersproject/* -> tronweb -> @tetherto/wdk-wallet-tron[-gasfree].

**So, what this ticket requires is actually done.**

Two open questions:
1. Close this ticket, or keep it open as the parent for the broader "Rumble + dependents" npm audit sweep called out in the description? If keeping open, can you confirm the repo list (Rumble app-node / ork / shard / indexers / wallet libs) and whether you want one card per repo or one bundled card?
2. The remaining open elliptic low has no upstream patch. Options: dismiss with risk note, accept, or pin to a fork. Preference?

## 2026-05-06T14:33:19Z — Alex Atrash (system: section_changed)
Moved this task from "TO DO" to "DEV IN PROGRESS" in WDK Indexer and Wallet Backends.
