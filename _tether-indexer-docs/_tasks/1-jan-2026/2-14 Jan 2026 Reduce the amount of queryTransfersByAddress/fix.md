## Fix Applied

**Branch:** `fix/rumble-reduce-queryTransfersByAddress-job-config`

**File changed:** `config/common.json.example`

**Change:** Added `wrk.syncWalletTransfers` config with 5-minute interval:

```json
"wrk": {
  "syncWalletTransfers": "*/5 * * * *"
}
```

**Root cause:** Production config had `*/5 * * * * *` (6-part cron = every 5 seconds) instead of `*/5 * * * *` (5-part cron = every 5 minutes), causing ~2000 `queryTransfersByAddress` calls/second.

**Note:** After merging, production `common.json` needs to be updated with this setting and the service restarted.
