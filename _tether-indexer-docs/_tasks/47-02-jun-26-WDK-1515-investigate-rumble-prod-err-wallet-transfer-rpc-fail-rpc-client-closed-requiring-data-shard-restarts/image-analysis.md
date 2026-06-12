# Image analysis

## Screenshot 2026-05-29 at 22.01.58.png

**Source comment:** team member, attached with "no this is a persistent issue ... after data shard restart it was quiet for 2.5h and then it started to happen again" (see `update.txt`).

**What it shows:** Grafana Explore on the Loki datasource, query `{job="pm2", level="40"}`, time range 2026-05-28 17:16:33 to 2026-05-28 22:45:51, "Newest first". A log-volume histogram over the window plus the raw log lines below.

**Key content:**
- Query: `{job="pm2", level="40"}` (pm2 stderr/warn level). ~0.8 MB / total scanned.
- Log-volume chart: a heavy burst in the first part of the window (roughly 17:20-18:00) then sustained lower-level noise, i.e. the errors are continuous across hours, not a single spike.
- Visible log lines repeat `errorCode":"ERR_WALLET_TRANSFER_RPC_FAIL"`, `err...message":"RPC client closed"`, `stack":"Error: RPC client closed at Client.request (/srv/data/production/rumble-data-shard-wrk/...)`, interleaved with `successCount":42,"failureCount":4 ... "fafetch:batch:partial"` (the `txFetch:batch:partial` summary line).
- Right edge marked "Start of range" / timestamps ~22:45.

**Relevance:** Confirms the failure is sustained across a multi-hour window (not a one-off restart artifact), that it is the `level=40` pm2 stream, and that `ERR_WALLET_TRANSFER_RPC_FAIL` is interleaved with partial-batch summaries — consistent with the dead-cached-client mechanism in `root-cause.md` (a subset of addresses per batch failing instantly). This is the screenshot the team used to argue the issue is persistent and needs a real fix, not restarts.
