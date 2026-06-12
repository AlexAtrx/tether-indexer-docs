# Next steps for RW-1860 — "Authentication Failed" on foreground

**Ticket:** https://app.asana.com/1/45238840754660/project/1212521145936484/task/1215465601624114

## What we know
- iOS Rumble Wallet **prod build 2.3.0**. User logs in, backgrounds the app (~1 min), foregrounds it, and hits a full-screen **"Authentication Failed — Biometric authentication failed. Please try again."** error.
- Tapping **Try Again** restores the wallet, so the session/credentials are intact; the failure is in the biometric re-auth gate fired on the background→foreground transition.
- **Not consistently reproducible** ("can't reproduce all the time").
- Priority: **Critical (Bug)**. Rumble Area: Authentication.

## Evidence captured here
- 1 image analysed in `image-analysis.md` (the error screen)
- 0 non-image attachments
- 4 comments + system events in `comments.md`

## What's missing (from `missing-context.md`)
- No logs (prod, none captured).
- Open question to reporter: was an OS Face ID prompt shown before the error, or did the error appear immediately on foreground? (unanswered)
- Likely a **mobile-app (client-side local-auth) bug**, not a backend/indexer issue — confirm with Alex before any backend digging.

## Before starting work
This is almost certainly a frontend/mobile concern (RN/native biometric re-auth on app resume), not WDK/Rumble backend. Confirm scope with Alex first; if it is mobile-app, this workspace (backend indexer) is not where the fix lives.
