# Missing context

- [ ] **Logs / dashboards**: "Sentry issue: https://sentry.rumble.work/organizations/rumble/issues/132843/?environment=production&project=43" — **Need from Alex:** access to this Sentry issue (or a paste of the stack trace / breadcrumb) to confirm exactly where `ERR_EXISTING_ADDRESS_SPARK_DATA_UPDATE_FORBIDDEN` is raised and where it is being logged at error level. **Source:** description.

Otherwise the ticket is self-contained — the error code, endpoint, and required change (error -> warning, suppress Sentry) are all stated explicitly. The fix is locating where this HRPC error is logged/reported on the `PATCH /api/v1/wallets/:id` path and downgrading the log level so it does not reach Sentry.
