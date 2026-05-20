Hey Alex,

Sorry, week didn't go as expected. I deployed a mock API that you can play with, real api coming next week

staging claim api
<https://web190181.rumble.com/-wallet/v1/admin/campaign-redeem>
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
<https://web190181.rumble.com/-wallet/v1/admin/campaign-claim-settled>
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
<https://web190181.rumble.com/-wallet/v1/admin/campaign-claim-failed>
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

One more thing - on <https://web190181.rumble.com/-wallet/v1/admin/campaign-redeem> endpoint you can trigger error responses, e.g
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
