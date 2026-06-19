# Next steps for RW-1940 — downgrade ERR_EXISTING_ADDRESS_SPARK_DATA_UPDATE_FORBIDDEN to warning

**Ticket:** https://app.asana.com/1/45238840754660/project/1212521145936484/task/1215865506410232

## What we know
- The Spark "existing address data update forbidden" case (`ERR_EXISTING_ADDRESS_SPARK_DATA_UPDATE_FORBIDDEN`) is currently logged at Error level and reported to Sentry.
- It is an expected/benign condition (a no-op guard against re-updating an already-set Spark address), so it should be a Warning and should NOT reach Sentry.
- Triggered on `PATCH /api/v1/wallets/:id`.
- Sentry issue 132843 (prod, project 43) is the noise being filed.
- Task type Enhancement, Priority Medium, Sprint 4, BE / API.

## Evidence captured here
- 0 images
- 0 non-image attachments
- 0 user comments (3 system stories)

## What's missing (from `missing-context.md`)
- Access to / a paste of Sentry issue 132843 to confirm the exact log call and code path raising the error.

## Before starting work
- Grep the Rumble repos for `ERR_EXISTING_ADDRESS_SPARK_DATA_UPDATE_FORBIDDEN` to find where it is thrown and where it is logged/reported. Likely in `rumble-app-node` (PATCH /api/v1/wallets/:id handler) or the spark indexer / data-shard path. Downgrade the log level (error -> warn) and ensure the Sentry transport skips it. Confirm the error is still returned correctly to the caller (HRPC error shape preserved); only the logging/Sentry level changes.
