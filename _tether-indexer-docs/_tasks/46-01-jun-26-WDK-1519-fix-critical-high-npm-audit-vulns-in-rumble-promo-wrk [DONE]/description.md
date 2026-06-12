Address `npm audit` findings in rumble-promo-wrk. Goal: fix all CRITICAL and HIGH severity vulns. For anything we can't fix, write a short justification we can share with Andrei's Rumble team explaining why the issue is not high/critical for us.

== npm audit summary ==
16 vulnerabilities (4 low, 5 moderate, 6 high, 1 critical)

== CRITICAL ==
- tether-wrk-base (*) — Malware in tether-wrk-base — GHSA-wvh9-3hgj-7f22 — NO FIX AVAILABLE.
  Action: investigate/replace; this is the top priority.

== HIGH ==
- tar (<=7.5.10) — multiple arbitrary file create/overwrite, symlink/hardlink path traversal, race condition advisories — NO FIX AVAILABLE.
  Pulled in via: node-gyp -> make-fetch-happen -> ... -> sqlite3 -> @bitfinex/bfx-facs-db-sqlite, and node-gyp directly.
  Action: fix if possible; otherwise justify (build/dev-time dep, not exposed to untrusted archives at runtime, etc.).


== Plan ==
1. Run `npm audit fix` for the no-breaking-change fixes (brace-expansion, ip-address).
2. Triage CRITICAL tether-wrk-base malware advisory — confirm whether we actually depend on it / replace.
3. Evaluate breaking fixes (ws/ethers, diff/sinon) and the no-fix HIGH tar chain.
4. For each remaining HIGH/CRITICAL that we cannot fix, document a justification for Andrei's Rumble team.

Reported on Wed 27th of May late PM by Andrei
