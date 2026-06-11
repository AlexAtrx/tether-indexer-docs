# Missing context

- [ ] **Related prior incident (linked, local):** the May 2026 staging shard-lookup
  outage lives in `_tasks/34-issue-ERR_DATA_SHARD_NOT_FOUND/` (Slack thread export +
  screenshots). It was closed as a Mongo UUID mismatch in `tw_ork.wdk_ork_lookups` /
  `tw_ork.wdk_ork_wallet_id_lookups`, suspected to come from a failed staging
  deployment. **Need from Alex:** what remediation was actually applied in May
  (UUID fixup script? redeploy? nothing?) — the thread ends at root-cause, the fix
  itself is not recorded. **Source:** prior task folder, thread end 21 May 2026.
- [ ] **Server-side logs:** the ticket only contains the client log. The matching
  staging ork/data-shard logs around 2026-06-11 14:10 (local device time) for user
  `stg012` are needed to see whether `resolveUserShardRpc` failed because the USERS
  lookup row is missing or because the shard registered under a different UUID again.
  **Need from Alex:** ok to pull via the access-staging-servers skill. **Source:**
  description (log attached is FE-only).
- [ ] **Environments:** staging cluster walletstg1-3, Mongo `tw_ork` collections —
  access needed to diagnose; covered by existing staging skill + Yubikey. **Source:**
  description ("Environment: Staging build 2.4.0 (586)").
