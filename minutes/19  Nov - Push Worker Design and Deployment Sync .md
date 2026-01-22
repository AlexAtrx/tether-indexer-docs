# Push Worker Design and Deployment Sync

## Overview

- Dev‑build access gaps: Alex and others missing; admin can add Gmail/Tether accounts for build testing.
- Webhook hashes resolved; dev‑env payload testing still pending.
- New field in transaction‑complete webhook (user ID) to display usernames on Rumble.
- Push‑based sync proposal: single worker consumes events from all indexers, deduplicates by transaction hash/block height, stores in Mongo (primary key = hash + index).
- Ordering & reorg handling: recommend indexing only finalized blocks (e.g., Ethereum +12, Tron +19) to avoid duplicate/conflicting events; trade‑off = slight latency.
- CI/CD automation: Ansible playbooks for dev/staging, need three test instances and Mongo cluster; rollout/rollback tested on one server.
- Wallet address uniqueness: enforce hard validation at org‑level on wallet creation to prevent address‑collision attacks; change warning to error.
- Asana usage: every task (including ad‑hoc/debug sessions) must have story points (1 pt ≈ 4 h) and due dates for performance tracking and management reporting.
- Alerts: pending configuration for production and staging error alerts; follow‑up needed.