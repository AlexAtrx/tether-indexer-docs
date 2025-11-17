# Rate Limiting Mitigation Planning Session

## Overview

- Authenticated flow: aggregated balance fetch, 3‑4 RPC calls max → no rate‑limit concerns
- Unauthenticated recovery flow: single proxy endpoint, one provider/API key → hits provider limits
- Immediate mitigations
  - Increase internal rate‑limit thresholds on the proxy
  - Verify Alchemy subscription (premium/pay‑as‑you‑go) and upgrade if needed
  - Add provider rotation / multiple API keys for fallback
- Longer‑term options
  - Run own node (full control, higher cost)
  - Use free providers only as low‑priority fallback
- Validation plan
  - Simulate high‑traffic (thousands of requests) in staging environment
  - QA the indexer/webhook flow for live‑stream donations across all supported chains
  - Deploy changes to production over weekend, then freeze for a few days before 5 k‑user rollout (target Wednesday)
- Action items
  - Increment proxy rate‑limit settings
  - Confirm Rumble/Alchemy are on the highest‑tier plan
  - Run staging load test and report results
  - Coordinate QA sign‑off before production push.