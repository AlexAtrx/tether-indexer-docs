# Next steps for Rumble - Security - Fix Tron Indexer High Vulnerabilities

**Ticket:** https://app.asana.com/1/45238840754660/project/1210540875949204/task/1213478780310237

## What we know

- Two High Dependabot alerts on `tetherto/wdk-indexer-wrk-tron` referenced in
  the description: **#3 (axios, CVE-2026-25639)** and **#7 (minimatch,
  CVE-2026-26996)**. Both are now `state: fixed` (fixed 2026-04-26).
- **Verified on `main`** (commit `6e02432`, "promote dev to main #107",
  2026-05-03): lockfile has `axios 1.15.2`, `minimatch 3.1.5`, and every other
  previously-flagged package at or above its patched version.
  `npm audit --package-lock-only` → `{critical:0, high:0, moderate:0, low:10,
  total:10}`. Details in `verification.md`.
- The 10 remaining lows are all one chain rooted at the still-open Dependabot
  alert #1 (`elliptic <= 6.6.1`, no upstream patch), surfacing through
  `@ethersproject/*` → `tronweb` → `@tetherto/wdk-wallet-tron[-gasfree]`.
- Description also asks for a broader follow-up: run `npm audit` across "rumble
  and dependent packages" and file new cards for each fix. That sweep has not
  been started.
- Description orders Fastify-plugin upgrade first (Asana `1213226894059885`).
  Status of that prerequisite ticket is unverified, but moot given the fix
  has already landed.
- Mohamed asked why a Tron ticket is filed under Rumble. Alex's reply suggests
  Tron may be wired into Rumble later — unconfirmed.
- Priority: High. Sprint 1. Progress State: TO TRIAGE.

## Evidence captured here

- 0 images analysed in `image-analysis.md`
- 0 non-image attachments under `attachments/`
- 2 user comments + relevant system events in `comments.md`
- Full Dependabot alert detail in `dependabot-alerts.md` (raw JSON in `_raw/`)
- Lockfile + audit verification in `verification.md`

## What's missing (from `missing-context.md`)

- Confirmation that we should close this ticket vs. keep it open as a parent
  for the broader sweep.
- Scope list for the broader `npm audit` sweep cards (which repos = "rumble
  and dependent packages", one card per repo or bundled).
- Decision on the remaining open `elliptic` alert (dismiss / accept / fork).
- Confirmation Tron is in Rumble Wallet release scope.

## Before starting work

Verification is done. The literal ask is complete. Proposed handling:

1. Reply on the Asana ticket with the verification summary (axios 1.15.2,
   minimatch 3.1.5, audit High+ count = 0 on `main@6e02432`) and ask whether
   to close it or repurpose it as a parent for the broader sweep.
2. If broader sweep stays in scope: get the repo list from Alex, then file one
   card per repo with the same `npm audit --package-lock-only` summary.
3. Separately decide what to do with the open `elliptic` low — likely a
   dismiss-with-risk-note since there is no upstream patch and the chain is
   inside the Tron signing path.
