Minor incident on rumble production backend (cc Alex).

Status: currently mitigated via data shard restarts.

Restart command used:
  pm2 jlist | jq -r '.[] | select(.name | startswith("shard-")) | .pm_id' | xargs pm2 restart

Symptom: data shard workers logging ERR_WALLET_TRANSFER_RPC_FAIL ("RPC client closed") from @hyperswarm/rpc. Affects wallet transfers (sample chain: polygon / usdt).

Sample log line:
```json
{"level":40,"time":1779985775859,"pid":902267,"hostname":"walletprd3","name":"wrk-data-shard-proc-w-2-2-ed0edb86-94f5-484e-a8c4-ad2faf486263","traceId":"shard-f273431d-4af3-4c04-9224-a312feab4999","errorCode":"ERR_WALLET_TRANSFER_RPC_FAIL","err":{"type":"Error","message":"RPC client closed","stack":"Error: RPC client closed\n    at Client.request (/srv/data/production/rumble-data-shard-wrk/node_modules/@hyperswarm/rpc/index.js:257:28)\n    at process.processTicksAndRejections (node:internal/process/task_queues:105:5)"},"chain":"polygon","ccy":"usdt","address":"0x8e07be7888dc738cae559daa775aec0a7e52794f","msg":"Wallet transfer RPC failed"}
```

Grafana (pm2 errors, level=40):
https://rwg.rmbl.ws/explore?schemaVersion=1&panes=%7B%22xdv%22:%7B%22datasource%22:%22cf3bb6f6m44xsb%22,%22queries%22:%5B%7B%22expr%22:%22%7Bjob%3D%5C%22pm2%5C%22,%20level%3D%5C%2240%5C%22%7D%5Cn%22,%22refId%22:%22A%22,%22datasource%22:%7B%22type%22:%22loki%22,%22uid%22:%22cf3bb6f6m44xsb%22%7D,%22editorMode%22:%22code%22,%22queryType%22:%22range%22%7D%5D,%22range%22:%7B%22from%22:%221779936172369%22,%22to%22:%221779940187449%22%7D%7D%7D&orgId=1&var-app=pm2&var-search=Error

Slack thread (full context, screenshots, log export):
https://tether-to.slack.com/archives/C0A5DFYRNBB/p1779986078317469

Investigation goals:
- Root-cause why @hyperswarm/rpc clients are closing (network flap? peer death? backpressure?).
- Decide on a durable fix (reconnect/retry, supervision, healthcheck) vs. relying on shard restarts.
- Add alerting so this is detected before manual restart is needed.
