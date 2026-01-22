# MongoDB Timeout Debugging and Docker Setup

## Action Items

- Alex to share repository link (or relevant files) with the team
- Provide a Docker‑Compose file that spins up a 3‑node MongoDB replica set
- Include instructions to kill/stop individual nodes to simulate majority loss
- Run local tests that trigger the wtimeout, maxCommitTimeMS, and maxTimeMS settings
- Monitor logs for WriteConcernFailed or MaxTimeMSExpired errors after changes
- Verify that sessions are always ended (add finally block around abortTransaction)

## Issue Summary

- Jobs run on indexer and data‑shard layers stop logging after a few executions
- Wrapper around node‑schedule uses a flag (isRunning) to prevent overlapping runs
- For the “sync wallet transfer” job, the flag never resets, likely due to a hanging async call
- Potential hang points:
  - blockchainSvc.getUserBalancesIterator()
  - db.writeBatch(pipe) inside a MongoDB transaction
- If a promise rejects or never resolves, the finally block isn’t hit, leaving the flag true

## MongoDB Transaction Concerns

- Sessions and transactions must be closed even on errors; otherwise driver hangs
- Current implementation adds wtimeout to write concern – good for preventing indefinite waits on majority acknowledgment
- Missing timeout handling for:
  - Transaction commit (maxCommitTimeMS)
  - Individual queries (maxTimeMS)
- bulkWrite does **not** accept maxTimeMS; need to apply timeout at query or session/driver level

## Recommended Fixes

- Add maxCommitTimeMS when calling session.startTransaction()
- Apply maxTimeMS to each query inside the transaction (or set driver‑level socketTimeoutMS)
- Wrap abortTransaction() in try/catch and always call endSession() in a finally block
- Use Promise.allSettled (or per‑call timeouts) for batch RPC calls to avoid one stalled request blocking the whole job
- Keep unique indexes and idempotent upserts to avoid duplicate‑key errors

## Validation Steps

- Run the updated code locally against the replica‑set Docker environment
- Simulate node failures to trigger majority loss and confirm WriteConcernFailed is thrown after the wtimeout period
- Check logs for MaxTimeMSExpired or WriteConcernFailed to ensure timeouts fire as expected
- Verify that the isRunning flag is always cleared, even when errors occur

## Next Actions

- Alex to set up the local MongoDB cluster and share the repo/files
- Team to review the Docker‑Compose setup and confirm it matches production topology
- After testing, merge the timeout changes and monitor production for resumed job logging.