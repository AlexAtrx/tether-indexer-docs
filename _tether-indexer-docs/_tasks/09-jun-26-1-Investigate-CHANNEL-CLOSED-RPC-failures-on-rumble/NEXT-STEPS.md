# Next steps for Investigate-CHANNEL-CLOSED-RPC-failures-on-rumble

**Ticket:** https://app.asana.com/1/45238840754660/project/1210540875949204/task/1215530880671665

## What we know
- Ticket title: Investigate CHANNEL_CLOSED RPC failures on rumble data-shard worker (staging)
- Investigate recurring ERR_WALLET_TRANSFER_RPC_FAIL / CHANNEL_CLOSED errors on the rumble data-shard worker (staging).
- Alex provided a Grafana Explore link for staging data-shard proc CHANNEL_CLOSED warnings after a deploy following dev -> main merge.

## Evidence captured here
- 0 images analysed in `image-analysis.md`
- 0 non-image attachments under `attachments/`
- 0 comments in `comments.md`

## What's missing (from `missing-context.md`)
- Slack threads: Ticket text references Slack/thread/DM context
- Logs: Ticket text references logs/Grafana/Loki context

## Before starting work
- Inspect staging PM2/logs for `CHANNEL_CLOSED` on `wrk-data-shard-proc-w-*` around the deployment window.
- Compare current deployed revision/config against the merge from dev into main.
- Trace the caller or peer closing the HRPC/channel if logs include stack/context.
