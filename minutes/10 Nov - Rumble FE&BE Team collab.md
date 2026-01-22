# Rumble FE&BE Team collab

## Overview

- Finalizing **v0.10.8** for the 5 K beta launch; lock version today, then a day‑or‑two for hot‑fixes.
- Critical backend tasks:
  - Remove RPC API‑key requirement → expose public, rate‑limited proxy endpoints.
  - Move MoonPay & Swaps API keys to the same backend proxy pattern.
  - Switch logging transport from **Hyperswarm** to **Promtail** and rebuild Grafana alerts.
- Client‑side fixes:
  - Replace seed phrase string with in‑memory **seed buffer**.
  - Add **transfer‑max‑fee** property and **paymaster fee label** to transaction UI.
- Security & rate limiting:
  - Use IP‑based limits plus lightweight session hash/HMAC for per‑session throttling.
  - Assume public endpoints will be scraped; rotate keys frequently and monitor abuse.
- Stability work:
  - Stress‑test transaction loading at \~5 K users; tune shard‑worker configs.
  - Fix MongoDB connection errors that can stall the app.
- Operational items:
  - Provide dev/staging mobile builds (Android & iOS) to testers.
  - Grant staging environment access (env vars, logs) to the team.
  - Create an **Asana** board for cross‑team release tracking.
  - QA to retest onboarding, seed buffer, fee label, and notification schema before beta.