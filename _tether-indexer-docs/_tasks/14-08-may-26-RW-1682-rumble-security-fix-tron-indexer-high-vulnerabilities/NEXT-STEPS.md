# Next steps for Rumble - Security - Fix Tron Indexer High Vulnerabilities

**Ticket:** https://app.asana.com/1/45238840754660/project/1210540875949204/task/1213478780310237

## What we know
- Original ask: upgrade npm to fix two high-severity Dependabot alerts on `tetherto/wdk-indexer-wrk-tron` (alerts #3 and #7), then run `npm audit`.
- Secondary ask in the description: extend the audit to Rumble and dependent packages, addressing all critical/high findings, and open follow-up cards. Fastify upgrade (Asana 1213226894059885) was called out as a prerequisite.
- Verified on 2026-05-04 (Alex's comment): both referenced alerts are already fixed (closed 2026-04-26). Current `npm audit --package-lock-only` on `main` (commit `6e02432`): `critical: 0, high: 0, moderate: 0, low: 10`.
- Residual 10 lows trace to a single still-open Dependabot alert (`elliptic <= 6.6.1`, no upstream patch), via `@ethersproject/*` → `tronweb` → `@tetherto/wdk-wallet-tron[-gasfree]`.
- Two open questions to Francesco posted 2026-05-04 — no reply yet. Task moved to DEV IN PROGRESS on 2026-05-06.

## Evidence captured here
- 0 images analysed (no attachments on the ticket)
- 0 non-image attachments under `attachments/`
- 7 entries in `comments.md` (3 actual comments + 4 system events with signal)

## What's missing (from `missing-context.md`)
- Confirmation that the Fastify upgrade prerequisite (Asana 1213226894059885) is done.
- Decision on whether to close this ticket or keep it open as the parent for the broader Rumble npm audit sweep, plus the per-repo card structure.
- Decision on how to handle the remaining open elliptic low (dismiss with risk note / accept / pin to a fork).
- Clarification on the Asana link `0/1212252648700200/1212252648700200` Alex referenced on 2026-04-28.
- Pull the original Dependabot alert details (CVE, package, fixed-in) from `gh` if Francesco wants them captured for the close-out.

## Before starting work
The narrow ask (fix the two referenced highs on the Tron indexer) is already verified done. Before doing more, get Francesco's answers on the two open questions in the 2026-05-04 comment — they determine whether this ticket gets closed or expanded into a multi-repo audit sweep.
