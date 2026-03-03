# Jan 5 Prod Issue: Summary and Proposed Fix

## What happened
After a full system restart, new wallet creation failed for about 4.5 hours. The API tried to contact ork workers before any were available, so the request had nowhere to go and returned an internal error to users.

## Why it happened
The service that picks an ork worker did not handle the “no orks available yet” case. When the ork list was empty, it sent an undefined destination into the RPC layer, which then crashed the request. A related bug could also leave the round‑robin selector in an invalid state after an empty update.

## Proposed solution (concise)
1) Add a clear check for “no orks available” before making RPC calls, and return a clean “service unavailable” response instead of a generic 500.
2) Fix the round‑robin selector to avoid corruption when the ork list is empty.
3) Improve startup readiness: log/alert when ork list is empty and optionally delay accepting traffic until at least one ork is discovered.

## Expected outcome
New wallet creation will fail fast with a clear, controlled error during warm‑up periods, and will recover automatically as soon as orks come online, instead of remaining broken or crashing requests.
