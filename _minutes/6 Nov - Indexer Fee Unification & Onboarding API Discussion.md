# Indexer Fee Unification & Onboarding API Discussion

## Overview

- Confusion over separate primary amount vs. network fee; propose an interim tooltip explaining fees are blockchain‑set and independent of transfer size.
- Consensus to handle fee unification at the indexer level, keeping internal breakdown for analytics while exposing a single normalized fee to UI.
- Implementation path: if fix takes &gt; 1 week, ship a temporary UI change; otherwise aim for a quick indexer‑side solution and re‑evaluate after a week.
- Indexer logic must detect and tag primary transfer vs. extra logs (e.g., Paymaster costs); plan a quick call to walk through current log‑parsing code.
- Balance fetching currently serial; parallel RPC calls cause stale balances—suggest caching confirmed balances per chain and reconciling totals after all calls complete.
- Onboarding flow makes three separate requests (wallet creation, seed storage, entropy setup); recommend a single atomic backend endpoint to reduce fragility and simplify retries.
- Rate‑limit issues with provider URLs when users log in via seed phrase; create a thread to discuss generating higher‑limit URLs and proxy usage.