# Description

**Goal**
Create a backend job to reconcile wallet addresses generated during migration on the frontend with the wallet addresses stored in the backend. This is required to monitor the accuracy of the migration and identify discrepancies.

**Context**
During migration from the old app to the new version:
- The frontend recreates the user wallets locally
- After migration, the frontend sends the recreated wallet addresses to the backend
- The backend does not overwrite existing stored addresses
- Therefore we need a reconciliation job to compare both datasets and detect mismatches

## Requirements

### 1. Input Data

Use:
- Wallet addresses stored in backend database
- Wallet addresses sent by the frontend after migration

### 2. Reconciliation Logic

For each migrated user:

- Compare one address is enough — like one of the EVM addresses generated on the frontend with addresses stored in the backend.
- Identify the following cases:
  - **Match**: frontend address equals backend address.
  - **Mismatch**: addresses differ.
  - **Missing in FE**: backend address exists but frontend did not send it.
  - **Missing in BE**: frontend address exists but backend does not have it.
- **When mismatch → we should get the balance of the two mismatches (EVMs and BTC). Why?**
  - Users who don't have any balance are at zero risk, but the ones who have any balance in the BE address are at risk and we need to do something about it.

### 3. Output

The job should produce a reconciliation report containing:
- UserId
- WalletID
- Wallet Name
- Wallet type
- Account index
- Backend address
- Frontend address
- Reconciliation status (Match / Mismatch / Missing)

### 4. Storage / Visibility

- Store reconciliation results in a dedicated table or log store.
- Must allow querying to analyze migration performance.

### 5. Metrics

We should be able to aggregate metrics when needed:
- Total wallets checked
- Matches
- Mismatches
- Missing in backend
- Missing in frontend
- Match accuracy %
