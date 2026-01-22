# Production Deployment & Tenderly RPC Discussion

## Overview

- Nicolas completed observability changes; document shared with Andre
- Stress‑test work to be reviewed on staging after the call
- Mobile app shows “unable to connect to wallet backend” – likely app‑team issue, script confirms endpoint works
- Base repos (WTK, data‑chart, WDK, indexer) merged to main; need PR reviews for updated rumble packages before workers get new code
- Tenderly RPC can be swapped for Alchemy/QuickNode; no new premium plan required for simple calls (eth_getBlockByNumber, etc.)
- [GasFree.io](http://GasFree.io) API key for Tron is mandatory for gasless transactions; confirm source and decide whether to proxy or rotate it
- Include Jesse (and Andre) on the metrics‑API email thread; forward the last email once clarified
- Production rollout planned for Thursday US time; internal testing first, then beta release
- Define a hot‑fix/quick‑update process (dedicated channel, trigger steps) before go‑live
- Notification bug: null dt/id fields cause schema validation failures; discard such requests, don’t update Redis cache – not a blocker for release
- Ongoing updates:
  - Bitcoin indexer being standardized as template for other indexers
  - Wallet duration tests being aligned across teams
  - PR for WDK node with JWT auth under review (Vegan)
- Request list of pending PRs for development branch to keep merge flow smooth
- Task allocation needs clarification; keep separate Asana projects for indexer and Rumble repos per repository boundaries.