# Backend Deployment Sync and Release Review

## Overview

- Grafana dashboard still shows old log format; likely deployment didn’t pick up latest config.
- Backend fixes (proxy endpoint, paymaster fee labeling) merged to dev; need validation in staging before prod rollout.
- Stress‑test worker stalled at \~5k wallets; logs enabled, issue still under investigation.
- Indexer‑wallet sync lag suspected for missing balance updates and transaction notifications.
- Token refresh flow: access token 1 h, refresh token 7 days; previous bug in v0.10.9 fixed, monitor for regressions.
- Frontend checklist: MoonPay protected endpoints, fee‑labeling, event tracking—all awaiting staging verification.
- One‑day chart shows a single data point by design; decision to temporarily remove the view to avoid misleading UI.
- Release target today: ensure backend deployment is stable, confirm all checklist items in staging, then push to production.
- Action items:
  - Sync with Nicholas on Grafana folder/dashboard ID.
  - Usman to redeploy proxy fixes to prod after staging sign‑off.
  - Alex to run a transaction on staging, capture logs, and share.
  - George to update UI files to remove one‑day chart and comment change.
  - Team to monitor Sentry for 404s and indexer health during release.
  