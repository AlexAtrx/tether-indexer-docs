# Ticket: Fix ork discovery empty-list failure after restart

## Background
After a full system restart, new wallet creation failed for ~4.5 hours because the app attempted ork RPC calls before any ork workers were available. This produced a generic internal error instead of a controlled "service unavailable" response. A related RoundRobin bug can also leave selection state invalid after an empty update.

## Scope
- Guard ork RPC selection when the ork list is empty and return a clear 503-style error.
- Map `ERR_NO_ORKS_AVAILABLE` (and optionally `ERR_EMPTY`) to HTTP 503 in `wdk-app-node/workers/lib/utils/errorsCodes.js`.
- Fix RoundRobin update behavior to avoid NaN/invalid index on empty lists (wdk-app-node and wdk-ork-wrk).
- Improve ork discovery handling during startup and periodic refresh (log/metric on empty, optional readiness gate or non-empty policy).
- Add a small regression test for /api/v1/connect behavior when ork list is empty.

## Acceptance Criteria
- New wallet creation returns a clear, controlled error when no orks are available (not a generic 500).
- The “no orks available” error is explicitly mapped to HTTP 503 in `errorsCodes.js`.
- RoundRobin selection does not become invalid after empty updates.
- Ork discovery emptiness is visible in logs/metrics.
- A test covers the empty ork list scenario.

## Notes
- Keep behavior safe for Autobase deployments; Mongo deployments should not regress.
