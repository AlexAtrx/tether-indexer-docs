The Spark "existing address data update forbidden" case is currently logged as an Error and reported to Sentry. It is an expected/benign condition and should be a warning, not an error — it should NOT go to Sentry.

Error: [HRPC_ERR]=ERR_EXISTING_ADDRESS_SPARK_DATA_UPDATE_FORBIDDEN
Endpoint: PATCH /api/v1/wallets/:id
Level: Error -> should be Warning

Sentry issue:
https://sentry.rumble.work/organizations/rumble/issues/132843/?environment=production&project=43

Action: downgrade this from error to warning so it stops creating Sentry error issues.
