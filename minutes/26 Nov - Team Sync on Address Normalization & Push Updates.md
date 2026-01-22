# Team Sync on Address Normalization & Push Updates

## Proposal for push based system

- Alex finalizing push‑based mechanism; awaiting Vegan’s review after Alex’s own feedback.
- No client‑side changes needed – existing backend endpoints will return identical results.
- Push‑notification fix PR ready; Alex will raise it immediately after the meeting.
- Address‑normalization migration script being revisited – ensure full org‑level consistency and idempotent normalization.
- Vegan invited to join the call for deeper context on the recent deletion issue and its impact on debugging.

## Meeting points about the push based system

- System confirmed that the inconsistent wallets API issue is resolved.
- Question raised about required spec changes for the push mechanism – answer: none for the application layer.
- Trace‑ID feedback points addressed; admin‑transfer bug (missing transfer index) fixed and deployed.
- New task: investigate any 5xx responses; current example is a 404 “data shard not found” error.
- Goal to keep the dashboard clean, eliminating false‑positive alerts.

## Detailed findings about the push based system

- Production logs show heavy error volume from providers on two blockchains, but not a release blocker for Dawn/Prawn.
- Hyperswarm integration appears stable (&gt;99% success) per Alex’s Slack update.
- ORC worker benchmarking assigned; results will inform further performance tuning.
- Analytics webhook PR pending Jesse’s review before staging deployment; Gohar will run smoke tests.
- Mobile‑app test‑flight access for staging still pending (Android via Firebase, iOS not yet available).

## Opinion supporting the push based system

- Push‑based path offers immediate latency benefits without requiring app changes.
- Keeping the router stateless with an in‑memory address→wallet cache (fed by change streams) mitigates consistency risks.
- Incremental rollout behind a feature flag allows fallback to existing pull jobs while validating end‑to‑end flow.
- Prioritize fixing critical backend issues (MongoDB timeouts, security hardening) before scaling the push architecture further.