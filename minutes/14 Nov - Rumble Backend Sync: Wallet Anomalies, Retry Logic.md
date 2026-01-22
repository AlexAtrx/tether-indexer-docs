# Rumble Backend Sync: Wallet Anomalies, Retry Logic

## Overview

- Wallet endpoint ignores arbitrary userId; API enforces authenticated user – suspect manual RPC call by someone with prod access, needs verification and possible security incident response.
- Stress‑test findings shared; Grafana alerts now in place, but error volume rising – team to design scalable monitoring and mitigation.
- BTC indexer refactor near complete; end‑to‑end testing pending (needs worker repo import). Additional blockchain added to indexer after PR merges.
- Gasless transaction cron stuck on invalid receipt IDs; agreed on retry strategy: 3‑5 attempts with chain‑aware back‑off, separate handling for provider rate‑limit errors.
- Retry intervals to be adaptive per chain (e.g., BTC ≈ 3‑4 min, Arbitrum/Polygon ≈ 20‑30 s); document and get approval from Jesse/Vegan.
- Deployment automation progress: stabilizing workers, planning multi‑server scripts; issues to be posted in backend channel for peer input.
- Security audit prep: collect line counts for all backend repos and include shared libraries (store-facility, net-facility, etc.) in audit scope; update Asana and sync with Gany.
