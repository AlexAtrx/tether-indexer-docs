Impact: 

What's Happening

When the syncWalletTransfersJob runs, some RPC requests to chain indexers fail with "Pool was force destroyed". This causes wallet transfer history to not sync for the affected wallets during that job run.

  User Impact

  - Severity: Low to Medium
  - Users may see delayed transaction history - transfers won't appear immediately
  - The data will sync on the next job run (typically within minutes)
  - No data loss - just delayed visibility
  - Balances are NOT affected (different code path with retry logic already)

  Frequency

  - Occurs sporadically when RPC connection pools timeout after 5 minutes of inactivity
  - More likely during low-traffic periods (fewer requests keep pools alive)
  - The logs you shared showed ~15 failures in a single batch - all recovered on next sync cycle

  Business Risk

  - No financial impact
  - No data corruption
  - Worst case: user sees a transaction 5-10 minutes later than expected
  - Current system is self-healing (next job run catches up)

  After Fix

  - Transient failures will auto-retry (2 attempts, 500ms delay)
  - Users should see near-real-time transaction history
  - Eliminates the error noise in logs