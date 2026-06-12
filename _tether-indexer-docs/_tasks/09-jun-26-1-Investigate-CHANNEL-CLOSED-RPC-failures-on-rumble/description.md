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

Grafana (CHANNEL_CLOSED rate, staging): https://data-wdk-monitoring.tail8a2a3f.ts.net/grafana/explore?schemaVersion=1&panes=%7B%22ef4%22:%7B%22datasource%22:%22cez1q12nhgs8wf%22,%22queries%22:%5B%7B%22refId%22:%22A%22,%22editorMode%22:%22code%22,%22expr%22:%22sum%28count_over_time%28%7Bagent%3D%5C%22alloy%5C%22,%20env%3D%5C%22staging%5C%22,%20level%3D%5C%2240%5C%22,%20app%3D~%5C%22wrk-data-shard-proc-w-.%2B%5C%22%7D%20%7C%3D%20%5C%22CHANNEL_CLOSED%5C%22%20%5B5m%5D%29%29%20or%20vector%280%29%5Cn%22,%22intervalMs%22:1000,%22maxDataPoints%22:43200,%22queryType%22:%22instant%22,%22datasource%22:%7B%22type%22:%22loki%22,%22uid%22:%22cez1q12nhgs8wf%22%7D%7D%5D,%22range%22:%7B%22from%22:%22now-5m%22,%22to%22:%22now%22%7D%7D%7D&orgId=1

Slack deployment thread: https://tether-to.slack.com/archives/C0A5DFYRNBB/p1780932441711149

