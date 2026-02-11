## Plan for fixing duplicate swap notifications

Reference: `_docs/tasks/Duplicate_swap_notifications_observed/analysis.md`

### Task 1 – Gate transfer-triggered pushes on new inserts (key culprit)
- Repo: `wdk-data-shard-wrk` (base) and `rumble-data-shard-wrk` (child).
- Goal: Only emit/send `TOKEN_TRANSFER_COMPLETED` when a transfer row is newly inserted.
- Steps: Detect upsert result (or precheck existence) before emitting `new-transfer`; emit after successful commit/checkpoint; ensure rollback cannot send pushes. Add tests for replayed transfer not re-sending.

### Task 2 – Add per-notification idempotency for transfer pushes
- Repo: `rumble-data-shard-wrk`.
- Goal: Skip sending if `(toUserId, transactionHash, transferIndex, type)` was recently sent.
- Steps: Add small TTL cache (in-memory or Redis if available) keyed by transfer identity; integrate into `_walletTransferDetected`/`sendUserNotification`; add unit/integration tests.

### Task 3 – Make `/api/v1/notifications` idempotent for swap-start (manual) calls
- Repo: `rumble-app-node` and `rumble-ork-wrk`.
- Goal: Prevent upstream retries from fanning out duplicate pushes.
- Steps: Accept optional `requestId`/`idempotencyKey`; store short-lived sent keys per user/type; drop duplicates; add validation/tests for repeated requests producing one push.

### Task 4 – Move checkpoint writes before notification emission
- Repo: `wdk-data-shard-wrk`.
- Goal: Ensure re-runs don’t refetch the same transfers after a partial batch.
- Steps: Commit per-address checkpoints first, then emit notifications; ensure ordering is after DB commit but before job completion; add regression test simulating failure after emit.

### Task 5 – Reduce batch rollback churn from price fetch failures
- Repo: `wdk-data-shard-wrk`.
- Goal: Avoid sending then rolling back due to FX lookup errors.
- Steps: Add timeout/retry/fallback for `price.calculator` HTTP call; on failure, proceed with null fiat but keep commit; test retry path.

### Task 6 – Telemetry to confirm duplicates are suppressed
- Repo: `rumble-data-shard-wrk`.
- Goal: Observe dedupe effectiveness.
- Steps: Log metrics/counters for “duplicate-suppressed” vs “sent” per notification key; add debug logs with traceId.
