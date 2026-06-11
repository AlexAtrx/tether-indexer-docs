# Related

- **Recurred 11 Jun 2026** as RW-1906 (`ERR_USER_DATA_SHARD_NOT_FOUND` on new-user
  creation, staging): see
  `_tasks/66-11-jun-26-RW-1906-auth-an-error-hrpc-err-err-user-data-shard-not-found-when-creating-a-new-user/`.
  Same source file (`wdk-ork-wrk/workers/lib/data.shard.util.js`), this time the
  USERS lookup in `resolveUserShardRpc`.
