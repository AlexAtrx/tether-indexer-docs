Environment: staging
Service: wrk-erc20-indexer-api (usdt pol) — host walletstg1
Provider: luganodes

Error: "could not coalesce error" — failed to get transaction receipt.
The indexer is calling eth_getTransactionReceipt with an invalid param
"debug-1778084251656" (not a 0x-prefixed hex hash), causing the RPC to
return -32602 invalid argument.

RPC error:
  code: -32602
  message: invalid argument 0: json: cannot unmarshal hex string
           without 0x prefix into Go value of type common.Hash
  payload: eth_getTransactionReceipt(["debug-1778084251656"])

Ethers stack:
  makeError (utils/errors.js:137)
  JsonRpcProvider.getRpcError (provider-jsonrpc.js:749)

Likely cause: a debug/placeholder tx hash leaking into the receipt-fetch
path. Need to find where "debug-<timestamp>" hashes originate and either
filter them before the RPC call or fix the upstream producer.

Grafana (level=50, env=staging, "could not coalesce error", last 6h):
https://data-wdk-monitoring.tail8a2a3f.ts.net/grafana/explore?schemaVersion=1&panes=%7B%22dnp%22:%7B%22datasource%22:%22cez1q12nhgs8wf%22,%22queries%22:%5B%7B%22refId%22:%22A%22,%22expr%22:%22%7Bagent%3D%5C%22alloy%5C%22,%20env%3D%5C%22staging%5C%22,%20level%3D%5C%2250%5C%22%7D%20%7C%3D%20%5C%22could%20not%20coalesce%20error%5C%22%22,%22queryType%22:%22range%22,%22datasource%22:%7B%22type%22:%22loki%22,%22uid%22:%22cez1q12nhgs8wf%22%7D,%22editorMode%22:%22code%22%7D%5D,%22range%22:%7B%22from%22:%22now-6h%22,%22to%22:%22now%22%7D%7D%7D&orgId=1

Sample log (truncated):
{"level":50,"name":"wrk-erc20-indexer-api-w-0-1-usdt-pol-...","traceId":"shard-5e94508f-...","err":{"message":"could not coalesce error ... payload={ id:78630, method:eth_getTransactionReceipt, params:[\"debug-1778084251656\"] } code=UNKNOWN_ERROR","code":"UNKNOWN_ERROR"},"msg":"failed to get transaction receipt, Provider: luganodes"}

Sprint: 1
