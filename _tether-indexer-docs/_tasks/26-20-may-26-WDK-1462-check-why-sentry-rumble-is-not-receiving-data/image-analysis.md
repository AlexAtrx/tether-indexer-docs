# Image analysis

## 1214842121423498-screenshot-2026-05-15-at-11.38.27.png

**Source comment:** Task description

**What it shows:** Sentry "Issues" view for the `rumble-wallet-backend` project filtered to the `production` environment over the last `7D`, returning the empty-state "No issues match your search."

**Key content:**
- Sentry org: **Rumble** (top-left, owner Francesco Canessa)
- Project filter: **rumble-wallet-backend**
- Environment filter: **production**
- Time range: **7D**
- Tab: **Prioritized** (Prioritized / For Review / Regressed / Escalating / Archived)
- Result: zero issues. Empty-state hint suggests checking project/environment/date filters, search syntax, and inbound data filters.

**Relevance:** This is the primary evidence that Sentry has stopped receiving events from `rumble-wallet-backend` in production. The empty-state in a 7-day window over a service that previously produced errors is the symptom that triggered the ticket.

## 1214842121423500-screenshot-2026-05-15-at-11.40.03.png

**Source comment:** Task description

**What it shows:** Same Sentry "Issues" view but with the time range expanded to `90D` — six prioritized issues are now visible, and the most recent error is highlighted.

**Key content:**
- Project filter: **rumble-wallet-backend**
- Environment filter: **production**
- Time range: **90D**
- Prioritized count: **6**
- Top issue: `Error — while open a file for lock: store/3002/db/LOCK: Perm…` (truncated)
- Issue project tag: **RUMBLE-WALLET-BACKEND-2D**, marked **Unhandled**, frame `Object.onopen(r…`
- **Last Seen: 2wk ago**, **Age: 2wk**

**Relevance:** Confirms two things at once:
1. Sentry ingestion did work historically — events from `rumble-wallet-backend` exist within the 90-day window, so the DSN, project, and routing are in principle correct.
2. The last event landed roughly two weeks before the ticket was opened (i.e. around 2026-05-01, which matches the description's "last task was May 1st"). Either the service stopped throwing/capturing errors, the SDK was disabled / mis-configured / removed in a deploy on/around May 1st, the process is no longer running where Sentry expects it, or events are being filtered out (inbound filters / sampling / DSN swap).
3. The last surviving error is a LevelDB / Hyperbee-style `open a file for lock: store/3002/db/LOCK: Permission denied`, surfaced from an `onopen` callback. That itself is worth noting — it may indicate the worker crashed/restarted and never came back up cleanly under the same process that initialised Sentry.
