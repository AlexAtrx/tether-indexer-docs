# Circuit Breaker & Failover Ordering for RPC Providers

## Problem Statement

The `RpcBaseManager` currently uses simple round-robin provider selection with basic retries. When an RPC provider fails repeatedly, requests continue to be routed to it, causing unnecessary delays and poor user experience for balance queries.

## Proposed Changes

### [wdk-indexer-wrk-base](file:///Users/alexa/Documents/repos/tether/_INDEXER/wdk-indexer-wrk-base)

---

#### [MODIFY] [rpc.base.manager.js](file:///Users/alexa/Documents/repos/tether/_INDEXER/wdk-indexer-wrk-base/workers/lib/rpc.base.manager.js)

**Changes:**

1. **Add Circuit Breaker State Machine**
   - Three states: `CLOSED` (normal), `OPEN` (skip provider), `HALF_OPEN` (testing)
   - Track per-provider: failure count, last failure time, state
2. **Add Provider Health Tracking**

   ```javascript
   // Per-provider health record
   {
     failureCount: 0,
     lastFailureTime: null,
     state: 'CLOSED', // CLOSED | OPEN | HALF_OPEN
     successCount: 0
   }
   ```

3. **Separate State Mutation from State Reading**

   - `_updateProviderState(provider)` - Handles OPEN → HALF_OPEN transitions (mutation)
   - `_getProviderState(provider)` - Pure read, no side effects

4. **Failover Ordering Algorithm**

   - Pre-compute states before sorting (no side effects in comparator)
   - Priority order: CLOSED → HALF_OPEN → OPEN
   - Within same state, prefer providers with lower failure counts
   - Skip OPEN providers unless all are OPEN (fallback)

5. **Single Unified Retry Loop**

   ```javascript
   for (let attempt = 0; attempt < maxRetries; attempt++) {
     // Refresh ordering each attempt
     // Cycle through providers: attempt % providers.length
     // Try selected provider or fallback to healthy one
   }
   ```

6. **Configuration Options** (with sensible defaults)
   ```javascript
   {
     failureThreshold: 3,     // Failures before opening circuit
     resetTimeout: 30000,      // ms before trying half-open
     successThreshold: 2,      // Successes to close from half-open
     maxRetries: 3             // Existing option
   }
   ```

---

## Backward Compatibility

- All new configuration is optional with sensible defaults
- Existing code using `RpcBaseManager` works without changes
- The `secondary` getter remains for any direct usage (though deprecated)
- Weights create duplicates in `secondaries` array for round-robin; health tracking deduplicates (intentional)

## Verification Plan

### Automated Tests

1. **Unit Tests** (`wdk-indexer-wrk-base/tests/`)

   ```bash
   cd wdk-indexer-wrk-base && npm test
   ```

   Test cases cover:

   - Circuit opens after N failures
   - Circuit half-opens after timeout
   - Circuit closes after success threshold
   - Failover ordering prioritizes healthy providers
   - Fallback to OPEN providers when all are OPEN
   - No side effects in sort comparator
   - Single unified retry loop distributes across providers

2. **Integration Tests**
   ```bash
   cd wdk-indexer-wrk-evm && npm test
   ```

### Manual Verification

- Start local indexer and verify balance queries work
- Simulate RPC provider failure and verify failover behavior
