# Rumble tip/rant missing chat — dt/id gating

## Evidence from logs
- `_docs/tasks/_rumble-tip-test-21-jan-2026/Explore-logs-2026-01-21 14_18_22.json` contains entries like:
  `Notification req include payload and transactionHash: undefined - 0x... - true/false`
- This log line only prints `payload` and `transactionHash`. `dt` and `id` are missing from the log output, so their presence is not visible in these traces.

## What happens if dt or id are missing
- `rumble-ork-wrk/workers/api.ork.wrk.js` only calls `_addTxWebhook` when:
  - RANT: `payload` + `transactionHash` + `dt` + `id`
  - TIP: `transactionHash` + `dt` + `id`
- If `dt` or `id` is missing, `_addTxWebhook` is skipped and no tx webhook is stored.
- `rumble-data-shard-wrk/workers/proc.shard.data.wrk.js` only sends the Rumble webhook for stored tx webhooks.
- Result: missing `dt` or `id` => no webhook to Rumble => no live chat entry.

## Practical read for the 21‑Jan traces
- `payload: undefined` is expected for tips without a message.
- If those same requests also lacked `dt` or `id`, the backend would drop them before any Rumble webhook is sent.
