17 Nov - Rumble FE&BE Team collab

## Overview

- Proxy layer should expose HTTPS on port 443, terminating TLS and forwarding to internal RPC (e.g., Bitcoin on 8332)
- Need clarification on actual host/port of BTC proxy – verify with Vigan/DevOps (NGINX/Traefik config)
- Ensure WDK config uses host = proxy domain, port = 443 for all chains (EVM, Bitcoin, TON adapters)
- Critical webhook/tipping bug: stuck job in getTransaction; PR ready, must merge & deploy to staging/production ASAP
- Notification schema validation: no null fields, test all swap/transfer events; investigate phantom push notifications & multi‑device token handling
- Add CI/CD step with integration test for token handling and tipping flow to catch regressions early
- Scaling focus: indexer sharding bottleneck for \~100k users; continuous deployment needed to accelerate fixes and support upcoming wallet launch.