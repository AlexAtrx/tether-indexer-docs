# Next steps for WDK-1529 CHANNEL_CLOSED on rumble data-shard

**Ticket:** https://app.asana.com/1/45238840754660/project/1210540875949204/task/1215530880671665

## What we know
- Recurring ERR_WALLET_TRANSFER_RPC_FAIL with CHANNEL_CLOSED on rumble-data-shard-wrk (staging), app wrk-data-shard-proc-w-0-1.
- Transfer RPC to a downstream HRPC peer fails mid-call; channel torn down (protomux-rpc _onclose). Retries exhausted (attempt 3, maxRetries 2).
- chain tron, ccy usdt, traceId shard-348d16ba-7161-40d4-b880-e1f7580ff1f3.
- Started after a staging deploy that followed merging dev into main.

## Evidence captured here
- 0 images, 0 attachments, 0 user comments.

## What's missing
- Slack deploy thread, raw Loki lines (being pulled directly from server).

## Before starting work
Investigation in progress directly on staging servers (Alex granted access).
