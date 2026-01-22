# Alex Fix Merge and Alert Strategy

## Overview

- Worker stalls during bulk wallet creation; manual restart & Redis clear needed now
  - Alex’s PR adds automatic retry logic
- Quick alerting: use Grafana Alertmanager → Slack/Telegram webhook; add missing production contact points
- Merge plan: validate Alex’s PR in dev, then push staging changes to production; Andrea to handle deployment
- Documentation tasks: deployment flow, container setup, on‑call strategy (PagerDuty or auto‑restart) to be drafted next week
- Observability update: staging alerts configured, need production docs and contact points; Nicholas to finalize
- Mobile app testing: ensure latest code in dev/staging builds (Android APK, iOS TestFlight); coordinate with app team
- Backlog items: Ansible deployment automation, GitHub Actions for tests, integration‑test improvements, parallel indexer design, Sepolia & plasma indexing assigned to Alex, JWT auth discussion pending.