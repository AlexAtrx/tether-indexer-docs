# Findings: Missing live chat notifications (14 Jan logs)

## Observations from log.txt
- Case 2 (scan user/channel QR) requests include `dt` + `id` and no `payload`. Example: `sendNotification payload = {...,"transactionReceiptId":"0xf0d5...","dt":"u","id":"dNXkvOUnLeI"}` followed by ork `Notification req include payload and transactionHash: undefined - 0xf0d5... -true` and data-shard `Store webhook being called: payload - undefined type - tip`. This shows the TIP webhook is stored.
- Case 3 (live rant QR) includes `payload` and we see `Store webhook being called: payload - <payload> type - rant`, then `Init webhook being called`, and `Sending webhook to rumble server`. This path is working.
- The same log file shows multiple TOKEN_TRANSFER requests missing `dt` and/or `id`, including:
  - `transactionReceiptId` + `dt` but no `id`.
  - `transactionHash` + `dt` but no `id`.
  - `toAddress`-based tips with no `dt`, `id`, or `payload`.
  These do not pass the webhook gating in `rumble-ork-wrk`, so no tx webhook is created and no Rumble webhook can be sent.

## Root cause
Missing live chat notifications are driven by production requests that do not include the required Rumble identifiers (`dt` and `id`) or a `payload`. When those fields are absent, the backend skips `_addTxWebhook`, so no downstream Rumble webhook is stored or dispatched. The log lines above show this happening in prod.

## Secondary note (case 2)
When `dt` + `id` are present but `payload` is not, the backend stores a TIP webhook and does not send a Rumble "transaction-init" call (only applies to rants). The only Rumble call would be on transaction completion. The provided log excerpt does not include any later "Sending webhook to rumble server" lines for case-2 hashes, so if these still fail in practice, the next step is to confirm the tx completion job is finding those hashes on chain.
