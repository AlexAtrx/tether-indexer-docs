# Proposal Relevance Note

## Summary

The proposal referenced in `_docs/_tasks/1- trx history api/proposal.txt` is **NOT relevant** to this ticket.

## Comparison

| Aspect | Proposal | This Ticket |
|--------|----------|-------------|
| **Topic** | Rumble Wallet non-custodial infrastructure | BTC transaction amount display |
| **Scope** | Onboarding, backup, recovery flows | Transaction history API |
| **Features** | Seed phrase generation, encryption, keychain storage, Rumble Cloud backup, Passkey PRF, recovery logic | Fix incorrect "Sent" amounts caused by change outputs |
| **Components** | WDK seed management, local keychain, cloud sync | BTC indexer, data shard, transfer labeling |

## Details

**The Proposal** covers:
- Wallet creation and BIP-39 seed phrase generation
- Encryption key management (local keychain vs cloud sync)
- Three recovery methods: Rumble Cloud (automatic), Manual (QR/seed phrase), Passkey PRF (biometric)
- User identity binding to Rumble userID
- Security requirements for non-custodial wallet infrastructure

**This Ticket** addresses:
- BTC transactions showing incorrect amounts in transaction history
- Change outputs being displayed as separate "Sent" transactions
- Users seeing confusing multiple entries instead of one clear transaction
- Root cause: indexer creates one transfer per output without distinguishing change

## Conclusion

These are completely separate features addressing different parts of the system. The proposal is about wallet infrastructure (how wallets are created, backed up, and recovered), while this ticket is about transaction history display (how BTC transactions appear to users).

The ticket originated from a user-reported bug where BTC send transactions showed wrong amounts due to change outputs being treated as separate transactions.
