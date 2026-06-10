# Description

Background
Some legacy users in RW V1 and migrated V2 users may have mismatches between:

- Backend wallet addresses
- Frontend-derived wallet addresses

Known causes include:

- V1 users with inconsistent backend/frontend address generation
- V2 migration cases where a new seed phrase was accidentally created, producing new frontend addresses

We currently do not know the total number of impacted users.

# Requirements

## 1. Frontend Address Consistency Check

On app startup (or after wallet initialization), FE should:

- Read all wallet addresses from backend
- Read all locally derived FE wallet addresses
- Compare addresses across all supported wallets/networks/tip jars

Comparison result rules:

- `success` only if every address matches exactly
- `failed` if any address mismatch exists

## 2. Sentry Reporting

Send a Sentry event containing:

- User ID
- Result (`success` or `failed`)

For failed comparisons also include:

- Tip jar name/ Wallet name
- Wallet type: Tipjar, unrelated, profile wallet
- Index
- Network name: of the failed match
- Backend address
- Frontend address

**One mismatch should mark the entire comparison as failed.**

## 3. FE Address Snapshot Upload

Separately from the comparison logic:

- FE should send all locally derived wallet addresses to backend
- Backend should temporarily persist/store this data for later offline processing and analysis

Sentence ticket:
Implement FE vs backend wallet address consistency checks with Sentry reporting for mismatches, and upload all FE-derived wallet addresses to backend for temporary persistence and later analysis.
