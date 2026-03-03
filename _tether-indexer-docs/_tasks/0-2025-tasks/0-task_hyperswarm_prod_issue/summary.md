# MongoDB Connection Pool Investigation

## Proposal for push based system

- “Pool was force destroyed” error recurring in logs
- Production dashboard shows \~2 000 open connections
- Error appears during read requests, not tied to a specific API call
- Possible causes: driver reconnect storm, network hiccups, unhandled async cleanup
- Verify pool size limits per service instance; total can add up across replicas
- Enable connPoolStats and driver connection‑monitoring hooks for active/idle stats
- Draft diagnostic command list for Andre to execute on production

## Meeting points about the push based system

- Discussed MongoDB connection‑pool teardown (“Pool was force destroyed”)
- Noted high connection count (≈2 k) and questioned normalcy
- Emphasized importance of distinguishing active vs idle connections
- Suggested checking pool‑size configuration and per‑instance caps
- Recommended connPoolStats command to get detailed pool health
- Agreed to prepare a short list of metrics/commands for production run
- Plan to share logs with Andre and have him run the diagnostics

## Detailed findings about the push based system

- Error logs indicate unexpected pool destruction, likely driver‑level issue
- Connection count remains steady; could be normal for many app instances
- Lack of request‑specific correlation suggests systemic pool handling problem
- Driver may be recreating pools frequently; need to monitor reuse patterns
- connPoolStats will reveal idle/active breakdown and pool recycling rate
- Prepare a checklist: driver version, pool size settings, monitoring hooks, HMAC auth if needed
- Coordinate with Andre to collect command output and correlate timestamps

## Opinion supporting the push based system

- While not a router discussion, the same systematic approach applies:
- Identify root cause (network, driver, async handling) before adding complexity
- Use minimal, targeted diagnostics (e.g., connPoolStats) rather than broad changes
- Ensure any new monitoring or alerting is stateless and leverages existing metrics
- Incrementally roll out fixes behind a feature flag, keeping current pull‑based jobs as fallback
- Validate impact (P95 latency, CPU, connection churn) before full deployment
- Document findings and share with the team for transparent decision‑making
- Continue to prioritize critical production issues over speculative architecture changes