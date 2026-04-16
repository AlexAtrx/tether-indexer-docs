# [Notifications] Amount in push has incorrect decimals — root-cause analysis

**Asana:** RW-1601 · [task](https://app.asana.com/1/45238840754660/project/1212521145936484/task/1214000621998015)
**Tx:** `0x43179369ffdda55ad061ef17c7ea16abc512e0b70cfa41e2a4e45c7f3e31d28b` (Polygon, USDT)
**Env:** Pixel 10 / Android 16 · Severity: High · Stack: FE (mis-tagged — see below)

---

## 1. What the screenshot shows

Two pushes for effectively the same transaction:

| Title | Body (amount part) | Status |
|---|---|---|
| **Transfer Successful** | `A transfer of 0.026882 USD₮ on Polygon has been successfully completed…` | ✅ correct |
| **Token Transfer Initiated** | `A transfer of 0.02688280000000002 USD₮ on Polygon is about to be initiated…` | ❌ broken |

Below that the notification tray also shows two more `Token Transfer Initiated` pushes for `0.01 USD₮` (truncated in the screenshot).

The trailing `...0000000002` is the classic IEEE-754 double-precision artifact, not a real balance. USDT has 6 decimals on Polygon, so the correct display is `0.026882`.

---

## 2. The two code paths

There are **two independent notification paths** with **different sources of truth** for `amount`. That is why only one of them is broken.

### 2a. ❌ "Token Transfer Initiated" — broken path (external caller → HTTP → template)

The upstream Rumble backend POSTs to `rumble-app-node` whenever a transfer is submitted.

1. **HTTP endpoint** — `rumble-app-node/workers/lib/server.js:276+` (`POST /api/v2/notifications`)
   - Fastify body schema at `server.js:220` and `:304` declares:
     ```js
     amount: { type: 'number' }
     ```
   - As soon as the request body is parsed, `amount` becomes a JS `Number` (float64).
   - There is **no** `multipleOf`/precision guard and **no** string form accepted.

2. **Ork dispatcher** — `rumble-ork-wrk/workers/api.ork.wrk.js:420-474` (`sendNotificationV2`)
   - Spreads the payload unchanged into `_sendNotificationWithIdempotency` → `_sendUserNotification` (`:404-408`).
   - **No formatting, no decimals lookup, no `toFixed`, no BigInt coercion.**

3. **Template** — `rumble-data-shard-wrk/workers/lib/utils/notification.util.js:87-90`
   ```js
   [NOTIFICATION_TYPES.TOKEN_TRANSFER]: ({ amount, token, blockchain }) => ({
     title: 'Token Transfer Initiated',
     body: `A transfer of ${amount} ${token} on ${blockchain} is about to be initiated to your wallet`
   }),
   ```
   `${amount}` calls `Number.prototype.toString()` on the float. Any imprecise binary representation is printed verbatim — e.g. `0.026882800000000002`.

The same pattern applies to `TOKEN_TRANSFER_RANT` (`:91-94`), `TOKEN_TRANSFER_TIP` (`:95-98`), `SWAP_STARTED` (`:103-106`), `TOPUP_STARTED` (`:107-110`), `CASHOUT_STARTED` (`:111-114`), and both `*_COMPLETED` variants of topup/cashout (`:119-126`). **All of these will exhibit the same bug** whenever the upstream caller sends an imprecise float.

### 2b. ✅ "Transfer Successful" — correct path (indexer → data shard)

This notification is emitted **internally** by the indexer pipeline, not via the HTTP endpoint.

- Entry: `rumble-data-shard-wrk/workers/proc.shard.data.wrk.js:105-147` — `_walletTransferDetected({ wallet, tx })`
- The `tx` object is produced upstream by `wdk-indexer-wrk-evm` and arrives with `amount` already as a **decimal string** (derived from the raw on-chain `uint256` using the token's decimals metadata — 6 for USDT).
- It is passed through untouched at `:135-145` to `sendUserNotification({ type: TOKEN_TRANSFER_COMPLETED, amount, ... })`.
- The template at `notification.util.js:99-102` interpolates the **string** directly, so no float formatting happens and the display is clean (`0.026882`).

---

## 3. Root cause

The bug is a **type / precision mismatch at the `/api/v2/notifications` boundary**, not a template bug in isolation and not something FE can fix.

Concretely:

1. **Upstream caller** (Rumble BE or similar, whatever posts `TOKEN_TRANSFER`) is computing the display amount via floating-point math — almost certainly `rawUnits / 10 ** decimals`. In JS, `268828n` → `Number(268828n) / 1e7 === 0.026882800000000002`. This already loses precision before the HTTP call is even made.
2. **`server.js:220` schema** accepts `amount: { type: 'number' }`, so the imprecise float is validated and forwarded. Had the schema required a string (e.g. a decimal regex), Fastify would have rejected the malformed call and the issue would have surfaced during integration.
3. **`notification.util.js:87-90` template** does `${amount}` on a `Number`, which exposes the full binary-to-decimal artifact in the user-visible push body.

None of the three layers owns the decimals of the token, so none of them can round to 6 places. The completed-path is only correct by accident — the indexer happens to hand off a pre-formatted string.

### Why the Asana FE comment is misleading

Aliaksei's comment ("can't be fixed on FE side, we need to address it to Backend team") points at the template owner. That's correct in the sense that the FE does not own the template, but the **real** fix has to happen at the **caller** (the service that POSTs `TOKEN_TRANSFER` to `/api/v2/notifications`) — the template just needs to be defensive. The task is currently tagged `Stack: FE - frontend`; it should be re-tagged to **BE** (both the caller and `rumble-app-node` / `rumble-data-shard-wrk` are backend).

---

## 4. Where to fix it — in priority order

**(A) Caller side (highest-leverage, fixes the data at source)**
Whoever calls `POST /api/v2/notifications` for `TOKEN_TRANSFER` must send the amount pre-formatted to the token's real decimals. Safe recipe:
```js
// rawUnits is the on-chain BigInt; decimals is per-token (6 for USDT)
const amountStr = formatUnits(rawUnits, decimals) // ethers v6 / viem
```
and send it as a string, not a number. This is where the precision is actually being lost; any downstream mitigation is cosmetic.

**(B) API boundary (`rumble-app-node/workers/lib/server.js:220`, `:304`)**
Change the schema to accept and require a string, so callers are forced to serialize exactly:
```js
amount: { type: 'string', pattern: '^[0-9]+(\\.[0-9]+)?$' }
```
Then nothing downstream can receive an imprecise float. Treat this as the contract fix.

**(C) Template (`rumble-data-shard-wrk/workers/lib/utils/notification.util.js:87-126`)**
Defensive coercion in case (A)/(B) lag or older callers remain:
- If `amount` is a `Number`, stringify via a non-exponential, non-artifact formatter (e.g. `Decimal.js`, `bignumber.js`, or `toFixed(decimals).replace(/\.?0+$/, '')` with a decimals lookup). Don't use bare `toFixed(6)` for all tokens — decimals differ by chain/token.
- Minimum hardening (one-line, no new deps): `String(amount).includes('e') || /\.\d{10,}/.test(String(amount))` → log a warn; the notification won't be blocked but at least we'll see it in logs.

**Do not** just call `Number(amount).toFixed(6)` in the template — the correct decimals are token-specific (USDT=6 on Polygon, USDT=6 on Tron, ETH=18, etc.), and this would silently mis-format other tokens.

---

## 5. Quick verification plan

1. Reproduce: POST to `/api/v2/notifications` with `type: TOKEN_TRANSFER` and `amount: 26882800 / 1e9` — confirm the push body shows `0.026882800000000002`.
2. Same POST with `amount: '0.026882'` (string) and schema-change from (B) — confirm the push body shows `0.026882`.
3. Search upstream Rumble BE (outside this repo) for the call site that builds the POST body for `TOKEN_TRANSFER`; look for `rawAmount / 10 ** decimals` or `Number(...)` on a BigInt.
4. Re-check `TOKEN_TRANSFER_COMPLETED` end-to-end with a token whose decimals are 18 (e.g. native ETH/MATIC) to confirm the indexer side really does hand back a string — if not, the "correct" path is correct only for USDT-like 6-dec tokens and will fail elsewhere.

---

## 6. Files touched by this bug (summary for a PR)

| File | Lines | Role |
|---|---|---|
| `rumble-app-node/workers/lib/server.js` | 220, 304 | Schema accepts `amount: number` — change to string |
| `rumble-ork-wrk/workers/api.ork.wrk.js` | 420-474 | Passes payload through; safe once schema is fixed |
| `rumble-data-shard-wrk/workers/lib/utils/notification.util.js` | 87-126 | Templates use `${amount}`; add defensive formatting |
| `rumble-data-shard-wrk/workers/proc.shard.data.wrk.js` | 105-147 | `_walletTransferDetected` — reference for the correct (string-amount) path |

Upstream caller (Rumble BE that triggers `TOKEN_TRANSFER`) is out of this repo and needs its own fix — that is the actual source of the imprecise float.
