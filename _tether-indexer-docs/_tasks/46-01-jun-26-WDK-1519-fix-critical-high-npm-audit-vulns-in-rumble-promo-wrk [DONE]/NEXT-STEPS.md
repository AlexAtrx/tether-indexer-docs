# Next steps for WDK-1519: fix npm audit vulns in rumble-promo-wrk

**Ticket:** https://app.asana.com/1/45238840754660/project/1210540875949204/task/1215296496783524

## What we know
- High-priority Sprint 3 ticket: fix all CRITICAL and HIGH `npm audit` vulns in **rumble-promo-wrk**.
- `npm audit` reports 16 vulns: 4 low, 5 moderate, 6 high, 1 critical.
- CRITICAL: `tether-wrk-base` flagged as malware (GHSA-wvh9-3hgj-7f22), NO FIX AVAILABLE. Top priority — investigate whether we actually depend on it / replace.
- HIGH called out: `tar` (<=7.5.10) path-traversal / file-overwrite chain, NO FIX AVAILABLE. Pulled in via node-gyp -> make-fetch-happen -> ... -> sqlite3 -> @bitfinex/bfx-facs-db-sqlite, and node-gyp directly. Likely build/dev-time only.
- For anything unfixable, write a justification to share with Andrei's Rumble team.
- Reported by Andrei on Wed 27 May late PM. No user comments, no attachments.

## Suggested plan (from ticket)
1. `npm audit fix` for non-breaking fixes (brace-expansion, ip-address).
2. Triage the CRITICAL tether-wrk-base malware advisory — confirm actual dependency / replace.
3. Evaluate breaking fixes (ws/ethers, diff/sinon) and the no-fix HIGH tar chain.
4. Document justifications for remaining unfixable HIGH/CRITICAL.

## Evidence captured here
- 0 images
- 0 non-image attachments
- 0 user comments (3 system events only)

## What's missing (from `missing-context.md`)
- Full `npm audit` output (only CRITICAL + 1 HIGH enumerated) — regenerate by running `npm audit` in the repo.
- Confirm rumble-promo-wrk clone location / use read-remote-repo.
- Confirm Andrei identity + format/channel for the justification writeup.

## Before starting work
First step of handling: run `npm audit` (and `npm audit --json`) in rumble-promo-wrk to get the complete advisory list, since the ticket only names 2 of the 7 HIGH/CRITICAL items. This is self-serviceable; no need to block on Alex. This connects to the broader security-vuln batch work ([[project_security_vuln_batch]]) and the rumble fastify-v5 upgrade already done for WDK-1168.
