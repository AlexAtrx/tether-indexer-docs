# Rumble Indexer and Data Shard Review

## Overview

- Repo layout: base **UDK indexer** repo with child repos per chain; schema changes trigger version bump, HyperDB fields must be appended, not inserted.
- Workers: per‑chain indexer workers sync blocks & expose RPC methods for the front‑end; deployed on GCP (staging/dev) on shared EC2 instances, managed by Usman & Vegan.
- Data shard: core library handling business logic, RPC, encrypted user seeds/entropy (client‑side encryption); stores public data; multiple shard instances partition \~100 M users; limited backup – staging uses migrations only.
- Rumble extensions: child repo adds notifications, webhooks, etc.; any base‑repo change must be mirrored in the child repo.
- Org service (wdk‑org‑wrk): acts as API gateway routing requests to appropriate data shard; does **not** perform authentication.
- App node (wdk‑app‑node): exposes mobile‑app routes, includes proxy endpoints for third‑party provider tokens; currently no shared TypeScript/OpenAPI spec—consistency handled manually.
- Deployment & tooling: manual one‑by‑one deployments; team wants CI/CD automation (GitHub Actions/K8s); local dev uses MongoDB container, Hyperswarm topic & key validation; Bruno used as shared API client (similar to Postman).