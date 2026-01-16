Alex:

Hey @george, this is regarding the issue of missing live chat notification.
Based on the logs, I shared my finding in backend-channel and will summarize it here:
The backend only creates a tx webhook when payload+transactionHash (rant) or transactionHash+dt+id (tip) are present.
The user tip flow sends TOKEN_TRANSFER notifications without payload, dt, or id.
Without those fields, no webhook is stored or dispatched to Rumble, so the live chat notification never appears.
Is there a reason why these fields are not passed? Or you're sure they are sent and I'm wrong in my analysis?

George:
Hey Alex, thanks for the follow up. In the example I shared in upper thread dt, id and transactionReceiptId (instead if transactionHash for EVM) are present. Do we send tx webhook to Rumble in that scenario?
Read: \_docs/tasks/12-jan-2026-new-notifs-issue/slack-discussion.txt

Alex:
I took time to double-check.
Yes, if dt, id, and transactionReceiptId are all present, the backend will send the tx webhook to Rumble.
The flow is:

1. transactionReceiptId → mapped to transactionHash internally
2. Gating passes: transactionHash && dt && id :+1:
3. Webhook is created and sent to Rumble
   But here's the catch:
   The production logs show requests that are missing dt and id:

```
sendNotification payload = {...,"transactionReceiptId":"..."} // no dt, no id
```

Can you confirm the real requests being sent include these fields?

George:
There are three different scenarios:
Sending via address - those logs won't have dt, id or payload. This is likely what you are referring to
Sending by scanning user or channel QR - This is example I pasted and should have dt + id, but no payload
Sending via scanning QR from live rant - This is confirmed to be working by Rumble, has dt + id + payload
Can you double check if there are logs for #2 and if they produce tx webhook to Rumble?

> Sending via address -> should produce no notifications, right
> As for now, no, but they already asked to consider adding that as an improvement. I think BE could do reverse lookup by address and add dt + id automatically

Francesco:
This is the logs:
\_docs/tasks/14-jan-26-Rumble-investigate-missing-live-chat-notification/log.txt
