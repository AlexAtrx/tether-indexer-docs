# Team Comment Correction

Correction after the DB proof pass:

I checked staging logs and the stored wallet data.

We still have 2 separate topics here, but I need to correct the BE part.

The slow/chunky Home balance load is still FE/mobile. Test account `ag5ezVDrcxU` is heavy: ~20 active wallets/account indexes, so the app starts multiple balance probes and the UI updates as each one finishes. This matches the video where the total climbs in chunks.

For the BE mismatch: malformed non-EVM addresses do exist on staging, but I checked the known test user directly in Mongo and `ag5ezVDrcxU` does **not** have malformed stored non-EVM addresses. Its balance-bearing wallets have valid-looking BTC/TON/Spark addresses. So we should not use malformed addresses as the root cause for this specific account unless we get a concrete failing BE request/account that shows it.

So for this ticket, the fix is still mobile: gate the initial aggregate balance so users don't see partial totals climbing. Backend address validation is still worth doing, but it looks like a separate staging data-quality issue, not the root cause of RW-1760.
