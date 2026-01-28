# Phase 2 Summary: Retire Legacy Transaction Handling

## Context

This phase follows Phase 1, where we introduced explicit transaction types for tips and rants. Phase 2 should only begin after mobile apps have fully adopted the new approach.

## What We're Doing

Removing the old "guessing" behavior from the backend. Once all apps use explicit transaction types, the legacy code that tries to infer user intent becomes unnecessary technical debt.

## Why This Matters

- **Cleaner System** — Removes ambiguous behavior that caused silent failures
- **Easier Maintenance** — Future developers won't need to understand legacy edge cases
- **Consistent Behavior** — Every tip and rant either succeeds or returns a clear error

## Prerequisites

Before starting Phase 2:

- Phase 1 must be live for 2-3 app release cycles
- Mobile teams confirm migration is complete
- Monitoring shows the old approach is no longer in use

## Suggested Timeline

| Milestone                    | Timing    |
| ---------------------------- | --------- |
| Phase 1 deployed             | Week 0    |
| Mobile apps migrate          | Weeks 1-4 |
| Monitor legacy usage         | Week 5    |
| Add deprecation notices      | Week 6    |
| Notify teams of removal date | Week 8    |
| Remove legacy behavior       | Week 12   |

## Risk & Mitigation

If any older app versions are still using the legacy approach, we can delay removal until those users update. Monitoring will give us visibility before making the final change.

## Outcome

After Phase 2, the system will have a clear, explicit contract: tips and rants must be properly declared, and any issues will surface immediately rather than failing silently.
