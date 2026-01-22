# Retry Queue Strategy & Wallet Limits

## Action Items

- Alex: join 2 pm CET meeting on retry‑queue design (Slack invite pending)
- Alex: sync on Slack to clarify token flow & permissions for notification testing
- Alex: create separate ticket for wallet‑whitelisting feature
- Alex: schedule quick debugging session (≈1 hr) with Kulwinder on duplicate notifications
- Alex: follow up with Nicholas & Jtas on GitHub Actions token generation and private‑dependency fix

## Retry Queue Discussion

- Prefer Redis now for fast retry handling (already used for cache)
- Build generic abstraction layer to swap Redis, Mongo, or in‑memory queue later
- Possible Mongo collection for failed balances, poll every \~30 min
- In‑memory queue as temporary fallback alongside Redis
- Meeting to finalize approach scheduled for 2 pm CET

## Wallet Creation Rate Limits

- Issue: users creating hundreds of tip jars overload indexer/provider
- Proposed default hard limit: 10 wallets per user, configurable
- Whitelist option for institutions or high‑volume creators (e.g., media companies)
- Upper bound suggestion: 100 wallets total per address (front‑end acceptable)
- Rate‑limit per request also implemented; both limits configurable on dev/staging

## Account Index Deployment

- Account index feature deployed to staging, initial issue resolved after redeploy
- Solana dependency bug fixed; PR opened for staging environment
- Next step: pick backlog task after current fixes are verified

## Notification & Balance Bugs

- Duplicate notifications observed in production, not in staging
- Address normalization bug identified; PR raised, discussion with Usman ongoing
- Intermittent wallet‑balance discrepancy still not fully resolved; further digging needed
- Plan: debugging session with Kulwinder to reproduce and fix notification issue

## GitHub Actions & CI/CD

- Private‑dependency token problem blocks CI for both staging and production workflows
- Need alignment on token generation: Nicholas requires help from Jtas to obtain token
- Current loop causing delays; aim to streamline token handling for GitHub Actions
- Suggest a dedicated chat (Alex, Usman, Nicholas) to resolve and automate CI pipeline

## Backlog & Other Updates

- Public indexer monitoring task unblocked, ready to be taken up
- No new tasks from Nicolas; open to assist where needed
- Reminder: ensure GitHub Actions run tests to catch regressions before merge
- Continue tracking open tickets for rate limits, whitelisting, and notification fixes.
