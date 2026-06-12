Investigate recurring ERR_WALLET_TRANSFER_RPC_FAIL / CHANNEL_CLOSED errors on the rumble data-shard worker (staging).

Symptom: wallet transfer RPC fails with "CHANNEL_CLOSED: channel closed" after exhausting retries (attempt 3, maxRetries 2 -> ERR_TASK_RETRY_FAILURE). RPC channel is being torn down (protomux-rpc _onclose / protomux _shutdown / NoiseSecretStream destroy) mid-call.

Context from staging log:
- app: wrk-data-shard-proc-w-0-1
- service: rumble-data-shard-wrk
- chain: tron, ccy: usdt
- address: Tba43ec49fd65ac1faa2a13b259c5590b9
- errorCode: ERR_WALLET_TRANSFER_RPC_FAIL
- err.code: CHANNEL_CLOSED, err.type: RPCError
- traceId: shard-348d16ba-7161-40d4-b880-e1f7580ff1f3

Stack:
RPCError: CHANNEL_CLOSED: channel closed
    at ProtomuxRPC._onclose (protomux-rpc/index.js:64:39)
    at Channel._close (protomux/index.js:211:22)
    at Protomux._shutdown (protomux/index.js:825:25)
    at NoiseSecretStream.emit (node:events:536:35)
    at WritableState.afterDestroy (streamx/index.js:575:10)
    at NoiseSecretStream._destroy (@hyperswarm/secret-stream/index.js:538:5)

Grafana (CHANNEL_CLOSED rate, staging): https://data-wdk-monitoring.tail8a2a3f.ts.net/grafana/explore?... (query: sum(count_over_time({agent="alloy", env="staging", level="40", app=~"wrk-data-shard-proc-w-.+"} |= "CHANNEL_CLOSED" [5m])) or vector(0))

Slack deployment thread: https://tether-to.slack.com/archives/C0A5DFYRNBB/p1780932441711149
