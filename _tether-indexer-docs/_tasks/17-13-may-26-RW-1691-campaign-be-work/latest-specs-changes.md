No I have these updates:

## 1:

we can deprecate the old way of doing claims  (one code per claim, local db for tracking codes, etc) by removing the code and the old api endpoints

## We don't need old way of claiming, you can kill it

## 2:

Hey Alex,

Sorry, week didn't go as expected. I deployed a mock API that you can play with, real api coming next week

staging claim api
https://web190181.rumble.com/-wallet/v1/admin/campaign-redeem
body
{
"code": "fakecode",
"id": "lalala",
"clientIp": "8.8.8.8"
}
response
{
"claimId": "2576690190715342544",
"amount": "10.00",
"token": "USAT"
}

stage success api
https://web190181.rumble.com/-wallet/v1/admin/campaign-claim-settled
body
{
"claimId": "123",
"walletAddress": "456",
"txHash": "0x123"
}
response
{
"success": true
}

stage failed claim api
https://web190181.rumble.com/-wallet/v1/admin/campaign-claim-failed
body
{
"claimId": "123",
"walletAddress": "456",
"reason": "omg"
}
response
{
"success": true
}

:bangbang: these endpoints require valid staging server ip + signature, the same signature that was implemented for transaction webhooks: x-signature and x-signed-on headers - sorry for not mentioning it in my document, I hope you can relatively easily reuse signing mechanism

One more thing - on https://web190181.rumble.com/-wallet/v1/admin/campaign-redeem endpoint you can trigger error responses, e.g
{
"code": "ERR_WRONG_GEO",
"id": "lalala",
"clientIp": "8.8.8.8"
}
will return you
{
"errorCode": "WRONG_GEO",
"message": "User country is not in the campaign target geos"
}

---

Are they clear to you?

## 3: Settled = mined, not broadcast (clarified by Rumble TL on 2026-05-20)

Followed up on the ambiguous wording in `campaign-builder-wallet-backend-spec-by-rumble-backend-lead.md` §3 ("Once the on-chain tx is broadcast (no need to wait for block confirmation), call Rumble's settled webhook"). Asked Rumble TL to clarify A (mempool/broadcast) vs B (mined on chain).

His reply:

> B sounds better, sorry for the confusion. I missed this part when I was reviewing the doc, sorry.

So the contract is now:
- `settled` webhook fires only after a status=1 receipt is observed on chain (the tx was mined into a block).
- `failed` webhook is no longer mutually exclusive after broadcast. If a broadcast tx mines with status=0 (reverted), or is dropped from the mempool and never lands, `failed` fires.
- `§3` and `§4` together cover the full outcome space; for a given claim, exactly one fires once a terminal chain state is observed.

This changes the wallet-BE state machine from `queued -> paying -> broadcast -> notified` to `queued -> paying -> broadcast -> mined -> notified` and reshapes the observer/reconciler logic. Implementation lands on `feat/rw-1691-campaign-builder-v2` (PR tetherto/rumble-promo-wrk#46).

Open question for Andre: confirm Rumble's `campaign-claim-failed` endpoint accepts a claim whose `claimId` may already have been broadcast (i.e. their accounting can release budget for a claim that briefly looked in-flight on chain). The wallet side now sends `failed` in that scenario; needs to be a no-op on a missing/stale claim and not double-charge anyone.
