# Missing context

The Asana ticket is three lines and the PR-revert PR has no body or comments.
Most of the gaps below are about *why* and *exactly where*, not *what* — the
diff itself is captured in `_raw/pr192.diff`.

- [ ] **People / decisions:** "was reverted" — PR #211 reverted #192 on
  2026-04-30 with no explanation in the body or comments, and no Asana
  back-reference. **Need from Alex / Francesco:** the reason. Was the script
  buggy? Wrong target repo? Performance issue when run against prod? The
  answer changes whether we port the same code verbatim, port-with-fix, or
  rebuild differently. **Source:** description.
- [ ] **Environments / systems:** ticket says "Rumble Data Shard" but does not
  say which branch of `tetherto/rumble-data-shard-wrk` to target, nor whether
  the script needs to run against staging, prod, or both. **Need from Alex:**
  target branch (likely `dev`) and which env(s) this script is expected to run
  on. **Source:** description.
- [ ] **Repo-shape mismatch:** `rumble-data-shard-wrk/workers/lib/db/mongodb/repositories/wallets.js`
  is 1666 bytes vs. 6693 bytes in `wdk-data-shard-wrk`, with a different file
  set (txwebhook, userdata, wallets vs. address.checkpoint, user.balances,
  user.data, users, wallet.balances, wallet.transfers, wallets). The CLI in
  PR #192 calls `MongoWalletRepository` from the wdk version. **Need from
  Alex:** confirm the rumble wallets repo exposes a way to scan active wallets
  with `type` and `accountIndex` fields, or accept that part of the port is
  adding the missing methods.
  **Source:** code comparison, see `pr-context.md`.
- [ ] **Test layout:** wdk has `tests/unit/`, rumble has flat `tests/`. **Need
  from Alex:** preference for adding `tests/unit/` in rumble or placing the
  new test at the top level. **Source:** code comparison.
- [ ] **External tickets:** description references PR #192 only. PR #192 has
  substantive review history from `SargeKhan` and `francesco-ubq`. Captured
  inline in `pr-context.md` so a future session can read the merged-form
  rationale without re-fetching from GitHub.
- [ ] **Same anomaly logic still relevant?** the script was a one-off for a
  migration. **Need from Alex:** is the migration that this script reports on
  still being run on Rumble? If the migration already ran cleanly on Rumble,
  this whole task may be obsolete. **Source:** PR #192 body ("This is for
  wallet reconciliation. ... migration wallet anomalies").
