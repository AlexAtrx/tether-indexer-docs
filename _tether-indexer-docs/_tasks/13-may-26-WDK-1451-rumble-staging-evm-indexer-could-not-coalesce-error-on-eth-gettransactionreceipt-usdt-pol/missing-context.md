# Missing context

## Resolved by `Explore-logs-2026-05-13 20_48_02.json`

- ~~Full Loki query result for the filter~~ — exported, see `logs-summary.md`.
- ~~Untruncated sample log entry~~ — every one of the 1000 entries is uniform; full payload + stack captured in the export.
- ~~Reproducibility (luganodes-only? USDT-POL-only?)~~ — yes to both, confirmed in 1.68h slice (1000/1000 entries are luganodes + USDT POL + walletstg1; both workers w-0-0 and w-0-1 affected).
- ~~How many `debug-<timestamp>` hashes are stuck?~~ — exactly **4**, all enqueued in a 46-min window on **2026-05-06** (15:40 → 16:27 UTC).

## Still open

- [ ] **Code origin of `debug-<timestamp>`:** the user-code frame is not in the stack — only ethers internals. **Need to find by grepping the rumble/wdk repos** for `` `debug-${Date.now()}` ``, `'debug-' +`, `"debug-"` prefixes, and any test/seed/replay path that enqueues a receipt-fetch job. (Not something Alex can answer — this is a code investigation step.)

- [ ] **Backing store of the stuck queue:** the 4 hashes have been retrying for ~7 days. **Need from Alex:** confirm where the EVM indexer receipt-fetch queue is persisted (HyperDB? in-memory with reschedule? Redis? a worker DB on walletstg1?). Once we know the store, we can pull the 4 records to see if they have extra fields that point at their origin (account, txHash source, request id).

- [ ] **Drain plan:** once the producer is fixed, what's Rumble's preferred way to manually drop these 4 stuck items from staging — operational runbook or just "kill and redeploy"? **Need from Alex.**

- [ ] **Other envs:** the log slice is staging-only because the Loki filter was `env="staging"`. **Need from Alex:** confirm prod has no `debug-` hashes (or run the same Loki query against `env="prod"` for sanity).

- [ ] **Sprint mismatch:** description says `Sprint: 1`, Asana custom field says `Sprint 2`. **Need from Alex:** confirm intended sprint.
