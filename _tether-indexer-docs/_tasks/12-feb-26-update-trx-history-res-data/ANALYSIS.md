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

## Lead's responses to objections

| Objection | Lead's decision |
|---|---|
| **1. Dropped `underlyingTransfers[]`** | Accepted. Less duplicate data. A 2nd detail endpoint can be added later if needed. |
| **2. Dropped rant message text** | **Keep it.** "Yeah let's include it then if it's doable." |
| **3. Dropped counterparty displayName/avatarUrl** | Accepted. "We don't store display names on our side, so it would be a call against Rumble APIs. User IDs are enough references from our side." |
| **4. Dropped `appContext.referenceId`** | Accepted. "Webhooks are temporary data, so they would be lost." |
| **5. `rantDirection` vs `tipDirection`** | Use single `tipDirection` for both. |
| **6. `channelId`** | Confirmed not doable. Drop it. |

---

## Agreed response shapes

### WDK Base layer

```jsonc
{
  // ─── PRIMARY KEY ───
  "userId": "....",
  "walletId": "052d6e5d-...",
  "transactionHash": "0xabc123...",
  "blockNumber": 12345,

  // ─── TIMING ───
  "ts": 1707222200000,
  "updatedAt": 1707222200000,

  // ─── CHAIN / NETWORK ───
  "blockchain": "ethereum",

  // ─── ASSET ───
  "token": "usdt",

  // ─── CLASSIFICATION ───
  "type": "sent",           // "sent" | "received" | "swap_out" | "swap_in"
  "status": "confirmed",    // Phase 1: always "confirmed"

  // ─── AMOUNT ───
  "amount": "0.0001",       // human-friendly amount
  "fiatAmount": "100.50",   // nullable
  "fiatCcy": "usd",         // nullable

  // ─── PARTICIPANTS ───
  "from": "0xabc...",
  "fromUserId": "...",       // nullable — NEW SCOPE
  "to": "0xdef...",
  "toUserId": "...",         // nullable — NEW SCOPE

  // ─── FEES ───
  "fee": "0.00123",         // nullable — NEW SCOPE (deferred from Phase 2?)
  "feeToken": "usdt",       // nullable
  "feeLabel": "paymaster"   // "gas" | "paymaster" — normalized: undefined → "gas"
}
```

### Rumble addon fields

```jsonc
{
  "subType": "transfer",     // "transfer" | "tip" | "rant"
  "tipDirection": "sent",    // "sent" | "received" — nullable, only for tips/rants
  "message": "Great stream!" // rant text — nullable, only for rants
}
```

---

## Questions and answers (resolved)

| # | Question | Lead's answer | Implication |
|---|---|---|---|
| 1 | `fromUserId` / `toUserId` — build reverse lookup now? | **Null for now** | Both fields returned as `null`. No new address→userId lookup needed. Future work. |
| 2 | Human-friendly `amount` — backend conversion? | **Keep raw, app handles it** | No change to amount format. EVM stays `"1000000"`, BTC stays `"0.5"`. Same as existing `/token-transfers`. |
| 3 | `fee` / `feeToken` — implement fee extraction? | **Null for now**, focus on it afterwards. Paymaster fees are easier to detect. | `fee: null`, `feeToken: null`. Only `feeLabel` populated (`"gas"` or `"paymaster"`). Fee extraction is next priority after this ships. |

---

## Final agreed response shapes

All questions resolved. Ready to implement.

### WDK Base layer

```jsonc
{
  // ─── PRIMARY KEY ───
  "userId": "....",                  // wallet owner's userId
  "walletId": "052d6e5d-...",
  "transactionHash": "0xabc123...",
  "blockNumber": 12345,

  // ─── TIMING ───
  "ts": 1707222200000,              // block timestamp (epoch ms)
  "updatedAt": 1707222200000,       // equals ts in Phase 1

  // ─── CHAIN / NETWORK ───
  "blockchain": "ethereum",

  // ─── ASSET ───
  "token": "usdt",

  // ─── CLASSIFICATION ───
  "type": "sent",                   // "sent" | "received" | "swap_out" | "swap_in"
  "status": "confirmed",            // Phase 1: always "confirmed"

  // ─── AMOUNT ───
  "amount": "1000000",              // raw chain format (app converts using token decimals)
  "fiatAmount": "100.50",           // nullable
  "fiatCcy": "usd",                 // nullable

  // ─── PARTICIPANTS ───
  "from": "0xabc...",
  "fromUserId": null,               // null for now — future work
  "to": "0xdef...",
  "toUserId": null,                 // null for now — future work

  // ─── FEES ───
  "fee": null,                      // null for now — fee extraction is next priority
  "feeToken": null,                 // null for now
  "feeLabel": "gas"                 // "gas" | "paymaster" — populated from existing label detection
}
```

### Rumble addon fields (added on top of base)

```jsonc
{
  "subType": "transfer",            // "transfer" | "tip" | "rant"
  "tipDirection": "sent",           // "sent" | "received" — nullable, only for tips/rants
  "message": "Great stream!"        // rant text — nullable, only for rants
}
```

---

## Implementation delta — what changes from current code

The current implementation returns the rich Section 5 response from the spec. This update is a **response shape change** — the processing pipeline and stored data remain the same, only the API response mapping changes.

### Fields to remove from response

| Field | Why safe to drop |
|---|---|
| `rail`, `chainId`, `networkName` | FE derives from `blockchain` |
| `symbol`, `decimals` | FE derives from `token` |
| `direction` (in/out/self) | Redundant with `type` (sent/received/swap_out/swap_in) |
| `explorerUrl` | FE builds from `blockchain` + `transactionHash` |
| `fromMeta`, `toMeta` | Replaced by flat `fromUserId`/`toUserId` (null for now) |
| `fees` (object) | Replaced by flat `fee`/`feeToken`/`feeLabel` |
| `label` | Replaced by `feeLabel` |
| `underlyingTransfers[]` | Less dup data; detail endpoint later if needed |
| `appActivitySubtype` | Replaced by Rumble `subType` |
| `appContext` | Dropped — webhooks are temporary |
| `appTip` (object) | Replaced by flat Rumble `tipDirection` + `message` |

### Fields to add to response

| Field | Source |
|---|---|
| `userId` | From wallet owner lookup (already available in processing context) |
| `blockNumber` | Promote from `underlyingTransfers[0].blockNumber` to top level |
| `fromUserId` | `null` (future work) |
| `toUserId` | `null` (future work) |
| `fee` | `null` (next priority after this ships) |
| `feeToken` | `null` (next priority) |
| `feeLabel` | Map from existing: `label === "paymasterTransaction"` → `"paymaster"`, else → `"gas"` |
| Rumble: `subType` | Rename from `appActivitySubtype` |
| Rumble: `tipDirection` | From existing `appTip.tipDirection` |
| Rumble: `message` | From existing `appTip.appContent.message` |

### Fields unchanged

`transactionHash`, `walletId`, `ts`, `updatedAt`, `blockchain`, `token`, `type`, `status`, `amount` (raw format), `fiatAmount`, `fiatCcy`, `from`, `to`
