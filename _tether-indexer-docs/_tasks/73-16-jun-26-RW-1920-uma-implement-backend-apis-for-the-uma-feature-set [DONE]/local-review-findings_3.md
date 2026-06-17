**Finding:** Spark UMA lookups advertise a userId callback instead of the TW Spark payreq callback
**File:** rumble-app-node/workers/lib/services/uma.js:149
**Exact code:**
```js
// Callback the sender hits next. Keyed on the receiver id so the payreq
// handler can resolve the wallet (and its spark key) itself; works for both
// spark (lightning) and EVM receivers.
const callback = getUmaPayreqCallback(baseUrl, userId || username)
```
**Remark:** For a wallet with `meta.spark.sparkIdentityKey`, Tether Wallet advertises the Spark payreq callback (`/api/lnurl/payreq/:sparkIdentityKey`) from `lnurlpLookup`; this Rumble port always advertises `/api/uma/payreq/:userId` instead. A local probe against the current service returned `https://rumble.test/api/uma/payreq/u1` for a Spark wallet with key `deadbeef`, while the surrounding route comment and test name still say the callback is keyed on the resolved Spark identity key. This is not a Rumble username-specific change, because Rumble already has the same Spark payreq proxy route and Spark identity key path.
**Critical criticism:** The receive callback flow is unnecessarily farther from TW and internally inconsistent with the comments/tests. It exposes a different public callback contract for the same Spark UMA receive path, which is exactly the kind of divergence the team is likely to reject unless there is an explicit Rumble-only requirement.
