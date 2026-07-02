# Slack thread that spawned this ticket (2026-07-02)

Alex opened a thread proposing the refactor after the WDK-1522 batch work surfaced the
duplication. Thread starter (paraphrased): the user-data key/value API is duplicated
across `tether-wallet-*` and `rumble-*` (same limits, validation, per-user key-count
logic); the wdk base only has the storage layer (`UserDataRepository`); the actual
`setUserData` / `getUserData` / `deleteUserData` endpoints and RPC handlers live only in
the forks. Proposal: lift the common user-data API into the wdk base; `getUserDataMulti`
and `countByKeyPrefix` are TW-only but generic so they move down too; the immutable
seeds/entropies handling (`immutableUserDataRepository` / `isImmutableUserDataKey`) stays
TW-only. Diff the two fork copies first to catch drift.

Replies:

> **Vigan** (10:46): hmm afaik we support user data on wdk base level no?
>
> **Francesco C.** (10:49): yes but some additions were done into tether and rumble
> layers unfortunately, especially API
>
> **Vigan** (10:49): I see them on data shard but not on ork or app node
> https://github.com/tetherto/wdk-data-shard-wrk/blob/main/workers/api.shard.data.wrk.js
>
> **Francesco C.** (10:49): that's why we think we should refactor
>
> **Vigan** (10:49): I was always under assumption that we had full support for this on
> wdk-app-node. we should add support for this asap. @Alex can you work on refactoring?
> with high prio as it's related to open sourcing
>
> **Alex** (10:51): Hi @Vigan, I can refactor.
>
> **Vigan** (10:51): ty, here's ticket (this ticket, WDK-1589)
>
> **Francesco C.** (10:52): cross linked tickets (WDK-1522)

Key signals:

- Team is fully on board with the refactor; Vigan (tech lead) set it High priority.
- Motivation is **open sourcing**: the wdk base is the open-source layer, and the
  labels on the ticket ("Open Source, TW Support, City Support, RW Support, Generic
  Support") say the base-level user-data API must serve Tether Wallet, City, Rumble,
  and generic consumers.
- Vigan expected full user-data support to already exist on `wdk-app-node`; it does
  not — only the storage-layer pieces exist on the wdk data shard.
- Vigan's own look at `wdk-data-shard-wrk/workers/api.shard.data.wrk.js` confirmed
  some user-data support on the base data shard but nothing on base ork or app node.
