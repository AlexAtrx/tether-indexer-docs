# Recommendations: MongoDB Pool Destruction Error

## Root Cause
The `[HRPC_ERR]=Pool was force destroyed` error is **not an RPC issue**—it's a MongoDB error from the Indexer that gets wrapped by the RPC layer.

## Required Fixes

### 1. Add Retry Logic to Indexer (Priority: High)
**Where:** `wdk-indexer-wrk-base/workers/api.indexer.wrk.js`  
**What:** Wrap all MongoDB queries with retry logic using exponential backoff  
**Why:** MongoDB replica set failovers destroy connection pools. Retries allow graceful recovery instead of cascading failures across all Data Shard workers

### 2. Enhance Error Context in RPC Wrapper (Priority: Medium)
**Where:** `hp-svc-facs-net/index.js` (the `handleReply` method)  
**What:** Preserve error types or add metadata to distinguish transport errors from application errors  
**Why:** The current blanket `[HRPC_ERR]=` prefix makes debugging difficult—you can't tell if it's a network issue or a database issue without reading the error message

## Debugging Best Practices
- **Don't trust the `[HRPC_ERR]=` prefix alone**—it wraps all errors, including DB and application errors
- **Always check upstream service logs**—in this case, check the Indexer logs, not just Data Shard logs, to see the original MongoDB error
