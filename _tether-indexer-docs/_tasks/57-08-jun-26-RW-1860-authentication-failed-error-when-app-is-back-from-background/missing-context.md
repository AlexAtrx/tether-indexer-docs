# Missing context — RW-1860

- [x] Logs: "do we have any logs?" — reporter confirmed **none available**: "it was on prod, so unfortunately no logs from my side". **Source:** Mariia Nikolaichuk, 2026-06-08T06:03:52Z. No client/server logs exist for this occurrence.
- [ ] Repro detail: only partially answered. Background duration clarified as "1 min or so". Alex's follow-up — whether a Face ID system prompt appeared before the error, or the error showed immediately on foreground — was **unanswered as of last fetch**. **Need from Alex/reporter:** confirm whether the OS biometric sheet was shown first. **Source:** Alexander Lisovyk, 2026-06-08T06:20:48Z.
- [ ] Frontend ownership: this is the iOS Rumble Wallet **app** (build 2.3.0 prod) biometric/local-auth flow. The error copy is client-side. **Need from Alex:** confirm whether this is a backend (indexer/app-node) concern at all, or purely a mobile-app (React Native / native local-auth) bug — likely the latter.
