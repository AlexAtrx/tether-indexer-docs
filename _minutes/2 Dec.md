# Cross-Chain Swap Architecture Sync

## Action Items
- Finish **add‑timeout** PR and close within the next hour  
- Address uniqueness‑of‑addresses comments (≈1 hr) and then tackle **duplicate‑to‑swap‑notification** ticket  
- Move the expired MongoDB timeout task to the **Interview** section in Asana  
- Copy, simplify, and post the failed‑Polygon‑transaction proposal to the shared channel  
- Follow up with Usman on any remaining review comments for the timeout PR  
- Coordinate with Nicholas on Redis provisioning before opening related PRs  
- Tag Vegan for input on the cross‑chain swap‑linking architecture  

## Progress Updates
- Alex reviewing and responding to PR comments; expects to finish within two hours  
- Usman reported successful testing of the push‑based mechanism; fast transaction confirmations  
- Security audit feedback to be triaged; only high‑impact items will be added to the sprint  
- Kulwinder working on metric‑calculation improvements after Alex’s research share 
- Nicholas handling benchmark performance adjustments after accounting for missed days  
- Gober confirmed dev‑environment swaps work correctly across BTC and EVM chains  

## Technical Discussion
- Proposed **transactions** table + **transaction_legs** table to model cross‑chain swaps  
- Suggested embedding `metadata.swapId` or `metadata.type="swap"` in each on‑chain leg for deterministic linking  
- Highlighted that adding cross‑chain logic inside data shards violates current isolation architecture  
- Considered an external **orchestration/aggregation service** to correlate legs via shared swap IDs  
- Discussed anti‑pattern risk of linking transactions at the shard level; prefer higher‑level service  

## Architecture Decisions
- Keep data shards **blockchain‑agnostic**; only ingest raw events and associate with wallets  
- Store swap metadata at the **application/orchestration layer**, not within the shard itself  
- Potential new **user_transactions** table for front‑end‑driven swap grouping (needs further review)  
- Need consensus on whether to implement swap linking in the orchestrator or a dedicated service  

## Testing & Deployment
- Push‑based mechanism deployed to dev; awaiting PR merges for staging rollout  
- Prometheus research underway; base code added, aiming for improved metrics collection  
- Planned scripts to generate 100 k test records in Autobase for reusable load testing  

## Outstanding Issues
- Clarify process for responding to security audit findings: prioritize critical issues, add to sprint, ignore low‑priority items  
- Determine how failed transactions (e.g., Polygon) will be identified and reported to the mobile team  
- Resolve whether the mobile app should push swap tags back to the backend or rely on on‑chain metadata  
- Finalize orchestration service responsibilities for cross‑chain transaction correlation  

---

More comments on the Swap issue:

Exactly, that’s the case — a cross-chain swap where one leg is on BTC and the other on an EVM chain. The challenge is how to deterministically link those two legs without introducing blockchain-specific logic into the backend layers.

Right, so the clean approach is to introduce a `transactions` table that represents the logical swap, and a `transaction_legs` table that stores each on-chain leg with fields like `chainId`, `txHash`, and `direction` (in/out). The linking key can be a shared `swapId` generated at the app layer when the swap is initiated, so both legs reference the same parent transaction without inferring relationships from blockchain data.

That’s true, and to stay within that boundary, the linking logic should live above the data shard—ideally at the app node or orchestration layer. The shard just stores raw legs, while the higher layer can correlate them using a shared swap identifier or metadata emitted at swap initiation.

I agree it shouldn’t live inside the core backend layers. A lightweight orchestration or aggregation service could handle this mapping externally—consume events from both chains, correlate them via swap metadata, and expose a unified view without breaking the shard isolation principle.

can the trx itself have 'swap' as metadata?
Yes, that’s a clean approach. Each on-chain leg can carry a `metadata.swapId` or `metadata.type = "swap"` field emitted from the initiating layer. The indexers just persist it as-is, and the front end or orchestration layer can group legs sharing the same `swapId` without adding cross-chain logic inside the backend.