# Response Reduction Analysis

> Does the lead developer's suggested reduced response still fulfill the transaction history API feature?

**Short answer: Mostly yes for the core feature, but with a few gaps and hidden scope changes.**

---

## What the feature was built to solve

The core problem (Spec Section 1): raw flat transfer records confuse users — BTC shows change outputs as separate entries, EVM shows gas payments as separate rows. The solution: **one logical transaction per user action** with grouping done at write time.

**The reduced response preserves this entirely.** The grouping pipeline (indexer → processor → data-shard → `wallet_transfers_processed` collection) is untouched. The reduction is purely about which fields appear in the API response. The core value proposition survives.

---

## What works fine with the reduction

| Dropped field | Impact |
|---|---|
| `rail`, `chainId`, `networkName` | FE can derive from `blockchain`. Low loss. |
| `symbol`, `decimals` | FE can derive from `token` — especially if `amount` becomes human-friendly. |
| `direction` (in/out/self) | Redundant with `type` (sent/received/swap_out/swap_in). FE doesn't need both. |
| `explorerUrl` | FE can build this from `blockchain` + `transactionHash`. Standard practice. |
| `fromMeta.addressType`, `toMeta.addressType` | FE can infer from `blockchain`. |
| `fromMeta.isSelf`, `toMeta.isSelf` | FE already knows the wallet's addresses. Can compute locally. |
| `label` | Replaced by `feeLabel` — actually cleaner. |

---

## What's actually a scope change, not just a reduction

These items in the lead's suggested response **don't exist in the current implementation** and would require new work:

### 1. `amount: "0.0001"` (human-friendly)

The current implementation stores/returns raw chain format (`"1000000"` for 1 USDT on EVM, `"0.5"` for BTC). Converting to human-friendly means the backend must apply decimals at response time. Not hard, but it's **new work**, not a reduction.

### 2. `fromUserId` / `toUserId`

The current implementation has **no address→userId reverse lookup** in the WDK base layer. Rumble's `resolveAddress()` does wallet lookups with LRU caching, but it resolves to `displayName`/`entityType`, not `userId`. Adding `fromUserId`/`toUserId` at the base WDK level requires building an address→user mapping that doesn't exist today. This is **new scope**.

### 3. `fee: "0.00123"` / `feeToken`

The spec explicitly deferred fee extraction to Phase 2 (`networkFee: null`). The lead's response shows an actual fee value. Either this stays null for now (fine), or it requires Phase 2 fee extraction work (not a reduction).

### 4. `blockNumber` at top level

Currently only stored in `underlyingTransfers[]`. Minor move but requires a schema/processing change.

---

## What's a genuine loss

| Dropped | Impact |
|---|---|
| **`underlyingTransfers[]`** | The FE loses the ability to show individual transfer details (e.g., BTC: "sent 0.5 to recipient + 0.3 change back"). Acceptable if the FE only shows list views — for detail views, it can fall back to the old `/token-transfers` endpoint. |
| **Rumble `appTip.appContent.message`** | Rant messages (the text the user typed) won't be in the response. If the FE needs to display "Great stream!" on a rant entry, it has no way to get it from this endpoint. |
| **Rumble `appTip.counterparty` (displayName, avatarUrl)** | Replaced by `fromUserId`/`toUserId`, meaning the FE must make separate calls to resolve usernames/avatars. This adds FE complexity and latency (N+1 resolution or batch lookup). |
| **`appContext.referenceId`** | Lost. If the FE ever needs to link back to the webhook/internal event, it can't. |

---

## The Rumble side is under-specified

The lead's Rumble suggestion (`subType`, `tipDirection`, `rantDirection`, `channelId`) is quite skeletal and has open questions:

- **`channelId`** — the lead themselves says "not sure if doable tbh"
- **`rantDirection` vs `tipDirection`** — why two separate direction fields? In the current implementation, `tipDirection` covers both tips and rants
- **`subType: "transfer", "rant", "tip",...`** — the ellipsis suggests this isn't fully thought through yet

---

## Bottom line

**The reduction fulfills ~85% of the feature realistically.** The grouped-transaction core is intact. The FE gets clean, predictable responses. Most dropped fields are derivable client-side.

**But it's not purely a reduction** — `fromUserId`/`toUserId` and human-friendly amounts are new requirements disguised as simplification. And the Rumble addon response needs more definition before it can be implemented.

---

## Questions for the lead

1. **`fromUserId` / `toUserId`** — This requires a new address→userId reverse lookup in WDK base. Is this expected to work cross-deployment (i.e., resolve Rumble userIds from WDK base)? Or is it Rumble-only? If Rumble-only, should WDK base return these as null?

2. **Human-friendly `amount`** — Should the backend convert amounts (apply decimals) at response time? Or does "human friendly" just mean BTC-style where it's already in BTC denomination? EVM amounts are currently stored in smallest unit (`"1000000"` = 1 USDT).

3. **`fee` / `feeToken` / `feeLabel`** — Should `fee` be null for Phase 1 (matching the current deferred scope)? Or is fee extraction now expected in this iteration?

4. **Rant message content** — The reduced Rumble response doesn't include the rant text message. Does the FE not need to display rant messages in the transaction list?

5. **Counterparty resolution** — With `fromUserId`/`toUserId` replacing `appResolved` (displayName, avatarUrl), is the FE expected to resolve usernames and avatars client-side? If so, is there an existing batch-resolve endpoint?

6. **`rantDirection` vs `tipDirection`** — Why separate fields? A rant is a subtype of tip. Can this be a single `direction` field under the Rumble addon (matching the current `tipDirection` that covers both)?

7. **`channelId`** — The lead flagged uncertainty. Should we skip this field for now and add it later if feasible?

8. **`underlyingTransfers` fallback** — With underlying transfers dropped, should the FE use the old `/token-transfers` endpoint for detail views? Or is there no detail view planned?
