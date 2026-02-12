## Context

1. Read the analysis you did in this directory based on task 1: \_docs/tasks/12-jan-2026-new-notifs-issue/\_task.txt

2. Check the answer of this question:

---

Andrei mentioned today that tips sent to the users without rants aren't appearing in live stream
chat. For context, we have two flows:
Scanning QR from live stream page (also called rant), which includes payload - appears in the chat
Sending tip directly to the user - doesn't appear in the chat
In #2, this is the example payload we send to backend. What can be the reason this doesn't appear as
a notification in the live chat?
`POST` https://wallet-9p1aan4nff.rmbl.ws/api/v1/notifications

```json
{
  "type": "TOKEN_TRANSFER",
  "to": "4e5d9878-28b2-4932-a7a7-e1d0efcb5839",
  "from": "63d93b4d-cc6e-4ee8-b2f3-c73f38e01b74",
  "blockchain": "arbitrum",
  "token": "usdt",
  "amount": "0.11",
  "transactionReceiptId": "0x1a4bb63c058fdb47d0317201c4585fc53177844e60b8b89ec072123857004b4c",
  "dt": "u",
  "id": "4r9UJ-g3XEs"
}
```

In the example I shared in upper thread dt, id and transactionReceiptId (instead if transactionHash
for EVM) are present. Do we send tx webhook to Rumble in that scenario?

---

The answer is:

---

Yes, the backend DOES send the tx webhook to Rumble when dt, id, and transactionReceiptId are present.

Here's the flow:

1. api.ork.wrk.js:184 - transactionReceiptId is mapped to transactionHash
2. api.ork.wrk.js:229 - Gating: if (transactionHash && dt && id) → calls \_addTxWebhook with type TIP
3. proc.shard.data.wrk.js:308 - Gating: if (type === TIP && dt && id) → sends webhook via rantTransactionConfirm

The issue is likely on the frontend/app side. Looking at the slack discussion, the prod logs show requests WITHOUT dt and id:
"sendNotification payload = {...,"transactionReceiptId":"..."}" // no dt, no id

But your example shows dt and id are present. This suggests either:

1. The actual requests being sent from the app are not including dt and id (despite what the example shows)
2. There's a discrepancy between what the frontend team thinks is being sent vs what actually arrives

## Recommendation: Check the actual network request logs (not the expected payload) to confirm dt and id are truly being sent in the failing tip requests.

## Task 2

Do you see this answer corresponding to the analysis you did?
