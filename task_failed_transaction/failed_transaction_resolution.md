# Failed Transaction Issue - Resolution

**Date**: 2025-12-01  
**Issue**: Failed ERC-4337 transaction stuck in "ongoing" state in mobile app  
**Transaction**: [0x083efd...](https://polygonscan.com/tx/0x083efdddcc9946833f701a230dc3bff4cf3a7f1ee98a4006625b5db37d5b4db2) (Failed - AA25 invalid nonce)

---

## Summary

**Backend is working correctly** ✅ - The indexer does NOT store failed transactions. The issue is purely frontend state management.

---

## What Happened (ERC-4337 Flow)

1. **User submits transaction**: Mobile app creates UserOperation hash `0xf294aa...`
2. **First bundle attempt fails**: Bundle tx `0x083efd...` confirmed but execution failed (status: 0, AA25 invalid nonce error)
3. **Bundler automatically retries**: New bundle tx `0x23b92f...` succeeds with same UserOperation
4. **App doesn't know about retry**: Still tracking original failed hash `0x083efd...`, shows "ongoing"
5. **Backend correctly indexed**: Only stores successful tx `0x23b92f...` (has Transfer logs)

**Key insight**: Same UserOperation, different bundle transaction hashes. App tracks wrong hash.

---

## Backend Behavior (Correct)

### Why failed transaction returns `[]`:

```javascript
// chain.erc20.client.js - getTransaction()
for (const log of receipt.logs) {
  // Failed tx has receipt.logs = [] (empty)
  // No Transfer events emitted when status: 0
  // Loop never executes, returns []
}
```

### Why successful transaction is indexed:

```javascript
// chain.erc20.client.js - getBlockIterator()
const events = await tokenContract.queryFilter(Transfer, start, end);
// Only fetches emitted logs from successful transactions
// Failed tx has no Transfer logs, never appears
```

**Conclusion**: No backend changes needed. Logs are the source of truth.

---

## Root Cause: Frontend/SDK Issue

The mobile app/SDK is tracking the **bundle transaction hash** instead of the **UserOperation hash**.

**Problem**:
- App stores: `0x083efd...` (failed bundle tx)
- Bundler retries: `0x23b92f...` (successful bundle tx)
- App never learns about the retry

**ERC-4337 Standard**: Apps should query bundlers using `eth_getUserOperationReceipt(userOpHash)`, which returns the final bundle transaction hash regardless of retries.

---

## Proposed Solution

### Track UserOperation Status via Bundler

Implement polling logic in the mobile app/SDK:

```javascript
async function trackUserOperation(userOpHash, bundlerUrl) {
  const maxAttempts = 40; // 10 minutes @ 15s intervals
  
  for (let i = 0; i < maxAttempts; i++) {
    const receipt = await bundler.eth_getUserOperationReceipt(userOpHash);
    
    if (receipt) {
      if (receipt.success) {
        // ✅ Success: Update UI with receipt.transactionHash
        updateTransaction(userOpHash, {
          status: 'confirmed',
          txHash: receipt.transactionHash
        });
        return;
      } else {
        // ❌ Failed: Remove from ongoing, show error
        updateTransaction(userOpHash, {
          status: 'failed',
          reason: receipt.reason
        });
        return;
      }
    }
    
    await sleep(15000); // Poll every 15 seconds
  }
  
  // Timeout after 10 minutes
  updateTransaction(userOpHash, { status: 'timeout' });
}
```

### Key Changes

1. **Store UserOperation hash** in pending transactions, not bundle tx hash
2. **Poll bundler** using `eth_getUserOperationReceipt(userOpHash)`
3. **Update UI** when receipt returns with final bundle transaction hash
4. **Remove stale entries** when status is final (success/failed/timeout)

### Edge Cases to Handle

- **Bundler data retention**: After 24h, fall back to querying backend indexer by address
- **Multiple retries**: Polling handles this naturally - final receipt has the last successful hash
- **Never bundled**: Timeout after reasonable period, mark as failed/expired

---

## Action Items

### For Frontend/SDK Team (George & Jonathan)

- [ ] Change transaction state management to track UserOperation hash
- [ ] Implement `eth_getUserOperationReceipt` polling after submission
- [ ] Add fallback to backend indexer query after 24h
- [ ] Handle timeout/failed/success states in UI
- [ ] Test with failed nonce scenarios on testnet

### For Backend Team (No Changes Needed)

- [x] Indexer correctly ignores failed transactions
- [x] Only successful transactions with Transfer logs are stored
- [x] Webhook logic works as expected

---

## References

- Failed TX: https://polygonscan.com/tx/0x083efdddcc9946833f701a230dc3bff4cf3a7f1ee98a4006625b5db37d5b4db2
- Successful Retry: https://polygonscan.com/tx/0x23b92fd39e29d3589fb5cc572aa2fde78da24e8cc59c236894b362b637b57410
- ERC-4337 Spec: https://eips.ethereum.org/EIPS/eip-4337#bundler-behavior
- Bundler RPC Methods: `eth_getUserOperationByHash`, `eth_getUserOperationReceipt`
