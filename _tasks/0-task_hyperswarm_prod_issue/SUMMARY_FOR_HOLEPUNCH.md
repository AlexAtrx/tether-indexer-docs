# Pool Destruction Error - Summary for Holepunch Team

## Issue Description

We're experiencing intermittent `[HRPC_ERR]=Pool was force destroyed` errors in production when using `@hyperswarm/rpc` for communication between distributed workers.

## Architecture

```
┌─────────────────┐         RPC          ┌──────────────────┐
│  Data Shard     │ ◄─────────────────► │   EVM Indexer    │
│  Proc Worker    │    (where error      │   Proc Worker    │
│                 │     occurs)           │                  │
└─────────────────┘                       └──────────────────┘
       │
       │ RPC
       ▼
┌─────────────────┐
│  Data Shard     │
│  API Worker     │
└─────────────────┘
```

## Error Scenario

### Production Symptoms:
- Error appears in data-shard worker logs
- Happens during `syncWalletTransfersJob` execution
- Affects multiple workers simultaneously (same timestamp across hosts)
- All errors for same RPC target (e.g., ethereum:xaut indexer)

### Root Cause (Our Analysis):
1. RPC connection pool is established between data-shard and indexer
2. No RPC calls for > `poolLinger` time (default 300s / 5 minutes)
3. Pool destruction begins
4. Scheduled job (`syncWalletTransfersJob`) fires many parallel RPC calls via `Promise.all()`
5. Requests hit the dying/destroyed pool
6. All requests fail with `[HRPC_ERR]=Pool was force destroyed`

## Configuration

```javascript
// Current production config (default)
{
  poolLinger: 300000,  // 5 minutes
  timeout: 30000        // 30 seconds
}

// Test configuration (for reproduction)
{
  poolLinger: 30000,   // 30 seconds
  timeout: 10000       // 10 seconds
}
```

## Code Path

```javascript
// Data shard proc worker
async syncWalletTransfersJob() {
  // ...
  await this.blockchainSvc.getTransfersForWalletsBatch(wallets)
}

// blockchain.svc.js
async getTransfersForWalletsBatch(wallets) {
  await Promise.all(wallets.map(async ({ chain, ccy, address }) => {
    // Makes RPC call to indexer
    const res = await this._rpcCall(
      chain, ccy, 'queryTransfersByAddress',
      { address, fromTs, limit: 1000 },
      { timeout: REQ_TIME_LONG }
    )
  }))
}

// This calls through hp-svc-facs-net → @hyperswarm/rpc
```

## Stack Trace (from production)

```
Error: [HRPC_ERR]=Pool was force destroyed
    at NetFacility.handleInputError (hp-svc-facs-net/index.js:58:11)
    at NetFacility.jRequest (hp-svc-facs-net/index.js:84:10)
    at async BlockchainService.getTransfersForWalletsBatch (blockchain.svc.js:408:5)
    at async WrkDataShardProc._walletTransferBatch (proc.shard.data.wrk.js:471:57)
    at async WrkDataShardProc.syncWalletTransfersJob (proc.shard.data.wrk.js:455:9)
```

## Questions for Holepunch

1. **Is this expected behavior?**
   - Should pools be destroyed while requests are in-flight?
   - Is there a graceful shutdown mechanism we're missing?

2. **Best practices:**
   - What's the recommended approach for long-lived RPC connections?
   - Should we implement connection keep-alive / heartbeat?
   - Should we recreate pools when destroyed?

3. **Pool lifecycle:**
   - When exactly does pool destruction start?
   - Can we detect when a pool is being destroyed?
   - Can we prevent destruction if requests are queued?

4. **Workarounds:**
   - Would increasing `poolLinger` to 600s (10 min) help?
   - Should we implement retry logic at the application level?
   - Is there a way to disable pool destruction entirely?

## Local Reproduction Setup

We've created a local test environment with:
- Reduced `poolLinger` to 30 seconds for faster testing
- Comprehensive RPC tracing (see TRACE_FOR_HOLEPUNCH.md)
- Test scripts to trigger the race condition
- All trace logs captured to files

## Package Versions

```json
{
  "@hyperswarm/rpc": "^X.X.X",
  "hyperdht": "^X.X.X",
  "hyperswarm": "^X.X.X"
}
```

(See system-info.txt in trace bundle for exact versions)

## Our Current Mitigation Strategy

1. **Add retry logic** to RPC calls (application level)
2. **Increase poolLinger** from 300s to 600s
3. **Use Promise.allSettled** instead of Promise.all for better error handling

## Request for Holepunch

We'd appreciate:
1. Confirmation if this is a known issue or expected behavior
2. Recommended best practices for this use case
3. Any patches or workarounds available
4. If this is a bug, we're happy to provide more traces or help test fixes

## Contact

[Your contact information]

## Attached Files

- `TRACE_FOR_HOLEPUNCH.md` - How to collect traces
- `system-info.txt` - System and package versions
- `*-trace.log` - Full worker logs with RPC tracing
- `DIAGNOSIS_REPORT.md` - Our detailed investigation

Thank you for maintaining these excellent tools!
