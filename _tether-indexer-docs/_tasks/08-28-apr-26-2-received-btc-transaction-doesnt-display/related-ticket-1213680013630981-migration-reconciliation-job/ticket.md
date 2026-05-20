# [Backend] Migration Reconciliation Job

- **URL:** https://app.asana.com/1/45238840754660/project/1212521145936484/task/1213680013630981
- **GID:** 1213680013630981
- **Project:** Rumble Wallet V3
- **Section:** In-Progress
- **Assignee:** Alex Atrash (inbox)
- **Status:** open
- **Created:** 2026-03-15T23:17:42.811Z
- **Modified:** 2026-04-17T18:35:56.427Z
- **Due:** —
- **Tags:** —
- **Custom fields:**
  - Priority: High
  - Rumble Area: Onboarding
  - Stack: BE - Backend
  - Task Type: Task
  - RW: RW-1409
  - Fix Version (FE): RW 2.0.4 (was RW 2.0.2 until 2026-04-01)

## Why this is linked to the parent BTC-tx ticket

Alex linked it in the parent ticket on 2026-04-09: the BTC receive address that isn't in the BE `/wallets` response (`bc1qgm7k56…`) is plausibly a *migration mismatch* — i.e. the FE recreated the user's wallet during migration and produced a set of addresses different from what the BE already had, and the BE did not overwrite. The job described in this ticket is the mechanism for detecting exactly that class of discrepancy across all migrated users.
