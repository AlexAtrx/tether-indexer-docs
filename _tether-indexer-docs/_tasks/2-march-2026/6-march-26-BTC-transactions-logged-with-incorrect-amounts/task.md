# Task: Investigate Root Cause of Incorrect BTC Transaction Amounts

## Your Role

You are a backend engineer working on the WDK (Wallet Development Kit) Indexer and wallet backend services for Rumble Wallet, a crypto wallet app. Your task is to investigate a bug where BTC send transactions are logged with incorrect amounts in the user's transaction history.

## Scope

**Investigation only.** Do not implement fixes yet. The goal is to identify the root cause of why sent BTC transaction amounts are displayed incorrectly, and produce a clear written analysis.

## The Bug

Read `ticket.md` in this directory for the full Asana ticket. Here is a summary:

When a user sends BTC, the transaction history records incorrect amounts. The amounts shown do not match what was actually sent. From the receiver's side, the amount appears correct. The issue is specifically on the sender's side.

### Key observations from the ticket

1. A single BTC send results in multiple transaction entries with different amounts (e.g. 0.00008501 BTC, 0.00006537 BTC, 0.00012201 BTC)
2. The sender sees incorrect amounts, but the receiver sees the correct amount
3. The BTC balance does change, but it cannot be reconciled with the listed transactions
4. The expected behavior is that the transaction history shows the sent amount and network fee clearly

### Visual Evidence

The `images/` folder contains screenshots referenced in the ticket. When analyzing the problem, refer to these by name:

- `01-holdings-and-transactions.png` - The sender's Holdings screen and transaction list. Shows the BTC balance and the transaction entries with mismatched amounts. (Attached to ticket description by Gocha)
- `02-received-transactions.png` - The received transactions view. (Attached to ticket description by Gocha)
- `03-comment-sender-side.png` - Another reproduction from Gohar: sender side showing incorrect amount
- `04-comment-receiver-side.png` - Same transaction from Gohar's reproduction: receiver side showing the correct amount
- `05-blockchain-explorer.png` - The actual on-chain transaction as shown on blockchain.com, for comparison against what the app displays

The blockchain explorer link for the reproduced transaction:
https://www.blockchain.com/explorer/transactions/btc/a86e927e07bcc8484d457f7a006f37a5c9c85a172d9ab56169a946a42a4da0a4

## Investigation Guidelines

Focus your analysis on these areas:

### 1. BTC UTXO Model vs. Account Model
BTC uses UTXOs, not account balances. A single "send" may consume multiple UTXOs and produce multiple outputs (recipient + change). Investigate whether the backend is incorrectly treating individual UTXOs or outputs as separate transactions rather than aggregating them into one logical send.

### 2. Transaction Indexing
Look at how the indexer processes and stores BTC transactions. Specifically:
- How are transaction inputs and outputs parsed?
- Is the "sent amount" calculated as (total inputs - change output - fee), or is it something else?
- Are change outputs being mistakenly recorded as separate sent transactions?

### 3. Amount Calculation Logic
Check how the amount displayed to the sender is computed:
- Is it pulling from the wrong field (e.g. showing individual output values instead of the net transfer)?
- Is the fee being subtracted or added incorrectly?
- Could there be a race condition or ordering issue during indexing?

### 4. Sender vs. Receiver Discrepancy
The receiver sees the correct amount. This suggests the issue is in how the backend attributes amounts to the sender's address, not in the raw transaction data itself.

## Expected Output

Produce a root cause analysis that includes:

1. **Where in the code** the incorrect amount is being calculated or stored
2. **Why** the calculation is wrong (the specific logic error)
3. **Why** it only affects the sender's view and not the receiver's
4. **How** the UTXO model is being handled and where that handling breaks down
5. **Suggested direction** for the fix (high-level, no implementation needed)
