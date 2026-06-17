**Finding:** Owned wallets without a stored username can still be advertised as UMA-capable
**File:** rumble-app-node/workers/lib/utils/uma.js:102
**Exact code:**
```js
const user = req?._info?.user
const ownsWallet = user?.id != null && wallet.userId != null && String(wallet.userId) === String(user.id)
// Resolution key: the wallet's stored username (authoritative, present after
// creation), falling back to the owner's immutable token username for a freshly
// created wallet the ork echoes back before the stored copy is read.
const username = wallet.username || (ownsWallet ? user.username : undefined)
// Only advertise UMA when the wallet has a resolvable username. Without one,
// getUmaByUsername cannot resolve the handle, so advertising uma config would
// be a lie (the receiver is unpayable). Keeps the response truthful when the
// username claim is absent instead of over-advertising UMA.
if (!username) {
  return wallet
}
return {
  ...wallet,
  username,
  uma: buildUmaConfig(ctx)
}
```
**Remark:** `POST /api/v1/wallets` still only stamps the token username when it is present, so a missing `preferred_username` claim can create a user wallet with no stored username. On any later owner wallet response, this decorator falls back to the token username and returns `username` plus `uma` even though data-shard/ORK never stored or reserved that username for `getUmaByUsername`. RW-1920 says the wallet username is sourced from Rumble's `preferred_username` at wallet creation; TW persists the username on the wallet record, not as a response-only fallback.
**Critical criticism:** This leaves UMA identity persistence optional while the HTTP layer can still advertise a handle. The payment identity invariant belongs at wallet creation, and the fallback turns a missing canonical username into an unresolvable public receive address.

---

**Finding:** Direct LNURL pay can mint a Lightning invoice for an asset the Lightning layer does not support
**File:** rumble-app-node/workers/lib/services/uma.js:180
**Exact code:**
```js
let layer
let assetIdentifier
try {
  const validated = validateLnurlpPayParams(settlementLayer, settlementAsset, amountNum, uma, chainsConfig)
  layer = validated.layer
  assetIdentifier = validated.assetIdentifier
} catch (err) {
  throw createAppError(err.message, 400)
}

const wallet = await orkService.getWalletById(ctx, req, uma.walletId)
if (isLightningLayer(layer)) {
  const sparkIdentityKey = wallet?.meta?.spark?.sparkIdentityKey
  if (!sparkIdentityKey) throw createAppError('ERR_UMA_SPARK_IDENTITY_KEY_NOT_FOUND', 400)
  const payreqUrl = `${baseUrl}/api/lnurl/payreq/${encodeURIComponent(sparkIdentityKey)}${queryString ? (queryString.startsWith('?') ? queryString : `?${queryString}`) : ''}`
  const response = await indexerService.requestSparkPayreq(ctx, sparkIdentityKey, payreqUrl)
  return response.data
}
```
**Remark:** `validateLnurlpPayParams` only verifies that `settlementAsset` is globally configured as a currency. The POST `/api/uma/payreq/:uuid` handler then performs the missing per-layer check, but `lnurlpPay` returns from the Lightning branch before checking that the requested asset belongs to the Lightning layer. A local service probe resolved `{ pr: "lnbc1" }` for `settlementLayer=lightning&settlementAsset=usdt` with Lightning configured for `["sat"]`.
**Critical criticism:** The exposed `GET /.well-known/lnurlp/:username?amount=...` path can silently satisfy a USDT request with a Lightning invoice. The validation contract is split between two pay paths, and the focused tests cover the POST path while leaving the direct LNURL GET path unsafe.
