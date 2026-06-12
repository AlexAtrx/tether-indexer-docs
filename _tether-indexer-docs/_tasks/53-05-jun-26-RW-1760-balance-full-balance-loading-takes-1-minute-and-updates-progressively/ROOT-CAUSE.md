# RW-1760 Root Cause

Date: 2026-06-05

## Summary

There are two separate findings under this ticket.

1. The 1-minute progressive Home balance load is a mobile orchestration issue.
2. The malformed-address theory was checked directly in Mongo for the known Anton/kartofili staging user. It does not hold for that user: all 20 active wallets have valid-looking stored non-EVM addresses, including the two balance-bearing wallets.
3. Staging does contain malformed non-EVM addresses, but the sampled bad rows belong to other synthetic users/shards, not `ag5ezVDrcxU`.

These should not be treated as the same bug.

## 1. Progressive Home Balance Load

The video symptom is still mobile-side.

On wallet `READY`, the app starts balance probes per Rumble `accountIndex`. Each probe fetches balances across the configured chains/tokens, and `useAggregatedBalances` merges results as each probe settles. For heavy accounts, the UI shows partial totals climbing in chunks until the last probe finishes.

For Anton's staging account, this shape is enough to reproduce the slow progressive load:

- User: `ag5ezVDrcxU`
- Active wallets/account indexes: `20`
- Wallet types: `17 channel`, `2 unrelated`, `1 user`
- Most wallets have `5-7` chain addresses.
- Most wallets have a Spark deposit address.

Staging app logs for this user showed wallet/transfer fan-out, but no evidence that the Home loading path was using `/api/v1/balance` or `/api/v1/wallets/balances` as the source of the progressive UI state.

Conclusion: the UX fix belongs in mobile. The initial aggregate should be gated until the initial probe batch settles, or the UI should clearly show a loading/cached/partial state instead of a final-looking total.

## 2. BE Balance Mismatch / Malformed Address Theory

The backend balance mismatch is separate from the progressive Home loading UX.

One proposed explanation was that Anton's known staging user had malformed non-EVM addresses stored in shard data. That would make backend balance calls query bad addresses verbatim while mobile derives valid addresses locally.

I checked that directly against Mongo. For known user `ag5ezVDrcxU`, this explanation is not supported:

- ORK routes the user to `wrk-data-shard-proc-w-2-0-133a344a-862d-4f7c-a313-556ea89fb197`.
- Matching DB: `wdk_shard_wrk_data_shard_proc_w_2_0`.
- Active wallets checked: `20`.
- Malformed active-wallet non-EVM addresses found for this user: `0`.
- The two balance-bearing wallets have valid-looking Bitcoin, TON, Spark, and Spark deposit addresses.

So malformed stored addresses are a real staging data issue, but not proven as the cause of the BE mismatch for this specific account.

### Malformed Address Samples Found Elsewhere

| Chain | Stored malformed value | Expected encoding |
| --- | --- | --- |
| Bitcoin | `bc1q50f3317c44ce69bb353164c76f8459d5eed0cf` | Real bech32, not pure hex after `bc1q` |
| Tron | `Tcc2f039da019b923228b1bd0d4ccd9aa3` | Base58check, 34 chars, not `T` + hex |
| Tron | `t79ee1006b33ecc...` | Base58check with uppercase `T`, not lowercase `t` + hex |
| TON | `709d0fe876366c8995499e8d0e880ad4b730967059507f92` | `EQ...` / `UQ...` base64-style address, not bare hex |
| Spark | `sprt1p78e154d78b1979fb7b304ec100867fdb4128985f30da9c21129f0aefaa` | Real bech32m, not prefix + hex |

Direct DB owner lookup for these samples found different synthetic users:

| DB | Wallet id | User id | Matching bad field(s) |
| --- | --- | --- | --- |
| `wdk_shard_wrk_data_shard_proc_w_0_0` | `30570451-5362-4f5a-a6fc-9eee2b111411` | `user-110-0-1767082831301` | Spark `sprt1p78e...`; also malformed TON/Bitcoin/Tron patterns |
| `wdk_shard_wrk_data_shard_proc_w_0_1` | `ea8fb92e-e091-4bdb-ab7f-5d76a8a3534a` | `user-112-0-1767173294578` | TON `709d0fe...`; also malformed Bitcoin/Tron/Spark patterns |
| `wdk_shard_wrk_data_shard_proc_w_0_1` | `e0acd8cd-8b8c-40a3-87c8-76386e9dd373` | `user-1078-0-1771142486461` | Bitcoin `bc1q50f...`; also malformed TON/Tron patterns |
| `wdk_shard_wrk_data_shard_proc_w_0_2` | `2ba3c94b-3a92-4ebe-a3e2-8dd6bb93cd62` | `user-1069-0-1771143240042` | Tron `Tcc2f...`; also malformed TON/Bitcoin/Spark patterns |

The `Tcc2...` log line came from `walletstg1` process `wrk-data-shard-proc-w-0-2-e98d6fdb-7d50-4f9b-bce0-dd8166724968`, not from the `ag5ezVDrcxU` shard `w-2-0`.

## Staging Data Collected

### Routing

ORK lookup routes `ag5ezVDrcxU` to:

`wrk-data-shard-proc-w-2-0-133a344a-862d-4f7c-a313-556ea89fb197`

The matching shard Mongo DB on staging was:

`wdk_shard_wrk_data_shard_proc_w_2_0`

### Wallet Shape

| Wallet id | Type | Account index | Chains |
| --- | --- | --- | --- |
| `f507e4be-2046-4290-b411-063b89f2c2aa` | unrelated | `0` | ethereum, arbitrum, polygon, bitcoin, spark, plasma |
| `2adbf052-e987-48e5-9d24-82e2b300ce03` | user | `10` | ethereum, arbitrum, polygon, ton, bitcoin, spark, plasma |
| `a68711eb-9d59-4550-9e16-12d5c3316585` | channel | `100` | ethereum, arbitrum, polygon, bitcoin, spark, plasma |
| `7305dab2-86b8-4cf5-b887-bf77d0901bce` | channel | `101` | ethereum, arbitrum, polygon, bitcoin, spark, plasma |
| `91b35cbb-4241-456d-9d7c-4e0b6141db2a` | channel | `102` | ethereum, arbitrum, polygon, bitcoin, plasma, spark |
| `7d2dbbfb-1566-40df-8251-a74cbf7e2955` | channel | `103` | ethereum, arbitrum, polygon, bitcoin, spark, plasma |
| `1732e9f8-49a1-4f81-9dae-80920aeebbcc` | channel | `104` | ethereum, arbitrum, polygon, bitcoin, plasma, spark |
| `2f0aca3c-8803-492e-9d32-a0d525fd8534` | channel | `105` | ethereum, arbitrum, polygon, bitcoin, spark, plasma |
| `d2534f45-dcbc-408e-b452-5d1c4e49b306` | channel | `106` | ethereum, arbitrum, polygon, bitcoin, plasma, spark |
| `77712225-e3e4-4b8d-bd93-ff72d05ffef8` | channel | `107` | ethereum, arbitrum, polygon, bitcoin, spark, plasma |
| `2ea6d8d1-01d3-4aa6-8e2f-1a01e1244ac2` | channel | `108` | ethereum, arbitrum, polygon, bitcoin, plasma |
| `1162de3c-4ac1-49f7-93dd-8b5b59483e2f` | channel | `109` | ethereum, arbitrum, polygon, bitcoin, plasma |
| `e6c69077-e30c-463a-80dc-6fe2a0808221` | channel | `110` | ethereum, arbitrum, polygon, bitcoin, spark, plasma |
| `282e46a3-33d8-4df0-9034-fe8cf5125c15` | channel | `111` | ethereum, arbitrum, polygon, bitcoin, plasma, spark |
| `fb746fa3-dff9-4754-b8c7-8234fb7e32a3` | channel | `112` | ethereum, arbitrum, polygon, bitcoin, spark, plasma |
| `cd6c64aa-44c2-4c12-bd7a-0e675d352f42` | channel | `113` | ethereum, arbitrum, polygon, bitcoin, spark, plasma |
| `5b1e53be-3425-42f7-95aa-2a09b17d503c` | channel | `114` | ethereum, arbitrum, polygon, bitcoin, spark, plasma |
| `5481deab-b99b-4c7c-b9be-bb0dd918d747` | unrelated | `115` | ethereum, arbitrum, polygon, ton, bitcoin, plasma, spark |
| `037162b8-e29b-4c88-abcc-a4e552477713` | channel | `116` | ethereum, arbitrum, polygon, bitcoin, spark, plasma |
| `6fba7f0c-8e9d-4c4f-ac52-2c0aaff78045` | channel | `117` | ethereum, arbitrum, polygon, bitcoin, spark, plasma |

Other staging checks:

- Duplicate stored addresses for this user: `0`
- Malformed active-wallet non-EVM addresses for this user: `0`
- Stored wallet balance rows for these wallets: `229`
- Latest stored user balance snapshot: `2026-03-28T06:00:00.009Z`

Latest stored user balance snapshot:

```json
{
  "userId": "ag5ezVDrcxU",
  "ts": 1774677600009,
  "balance": "15.246845197155",
  "tokenBalances": {
    "btc": "0.00002915",
    "usdt": "10.049083",
    "xaut": "0.000726",
    "usat": "0"
  }
}
```

Notable non-zero latest wallet snapshots:

| Wallet id | Balance | Token balances |
| --- | --- | --- |
| `2adbf052-e987-48e5-9d24-82e2b300ce03` | `11.28389705` | btc `0.00001229`, usdt `8.42`, xaut `0.000456`, usat `0` |
| `5481deab-b99b-4c7c-b9be-bb0dd918d747` | `3.864535310465` | btc `0.00001686`, usdt `1.530649`, xaut `0.00027`, usat `0` |
| `a68711eb-9d59-4550-9e16-12d5c3316585` | `0.028228929475` | usdt `0.028235` |
| `7305dab2-86b8-4cf5-b887-bf77d0901bce` | `0.070183907215` | usdt `0.070199` |

Note: The stored snapshot is old relative to the investigation date, so historical/snapshot balance data should not be used to validate the current Home balance.

### Raw Address Proof For Balance-Bearing Wallets

Money wallet `2adbf052-e987-48e5-9d24-82e2b300ce03`:

```json
{
  "type": "user",
  "accountIndex": "10",
  "latestBalance": {
    "balance": "11.28389705",
    "tokenBalances": {
      "btc": "0.00001229",
      "usdt": "8.42",
      "xaut": "0.000456",
      "usat": "0"
    }
  },
  "addresses": {
    "ethereum": "0xc499c5717007ac2386289f93f0e7c1e719fa7982",
    "arbitrum": "0xc499c5717007ac2386289f93f0e7c1e719fa7982",
    "polygon": "0xc499c5717007ac2386289f93f0e7c1e719fa7982",
    "ton": "UQAroRqYO5kwyqe-Yhjz7s6_Hq6Kq1cJCpbImh6Kyx-5NGqw",
    "bitcoin": "bc1qgw297c4zs5lehkdh6wt99lahl7kdz8zgf32a78",
    "spark": "spark1pgss8csrk56pjyqspe7sawmmnpve9sr5nrx2d96lxhltmanzspuw75gn57tp3y",
    "plasma": "0x72f98199f6f1f229df14a234ca2d328e880ee5cd"
  },
  "sparkDepositAddress": "bc1p3yr73wrxwzzq3seaym86rwqr0hka23h0w9ff8sk4grgcdnhan62qnaeuxc",
  "malformedNonEvmFlags": {}
}
```

Money wallet `5481deab-b99b-4c7c-b9be-bb0dd918d747`:

```json
{
  "type": "unrelated",
  "accountIndex": "115",
  "latestBalance": {
    "balance": "3.864535310465",
    "tokenBalances": {
      "btc": "0.00001686",
      "usdt": "1.530649",
      "xaut": "0.00027",
      "usat": "0"
    }
  },
  "addresses": {
    "ethereum": "0x809807c3b2815da0c401400e46821d1849ad89da",
    "arbitrum": "0x809807c3b2815da0c401400e46821d1849ad89da",
    "polygon": "0x809807c3b2815da0c401400e46821d1849ad89da",
    "ton": "UQCFtNZLnS3weQNAZhDdSqw3aEAkbp_RZxIi7PNN0IH69398",
    "bitcoin": "bc1qjgsd7mm06970dd90dem3t40ygwa0mv2tphe2wy",
    "plasma": "0x56979c33f92dfb78579dda9a110c8c19d756755e",
    "spark": "spark1pgss80xd2x6slcgpetp9kejxpc52vekzkyjvkd5q5r733yuq94jqm48z0jl4g2"
  },
  "sparkDepositAddress": "bc1psvrhr2qkg4xqmyxz4xmsy286jkckwehg7u8f4mr2zrnxnuqa2paqvkp6wf",
  "malformedNonEvmFlags": {}
}
```

## Backend Balance Mismatch Status

Backend balance endpoints use stored wallet addresses, so malformed stored non-EVM data can absolutely cause bad/null/partial backend balances. Staging has examples of that, listed above.

But for the known Anton/kartofili account, the direct DB proof does not show malformed stored addresses. For that account, the BE mismatch remains separate from the Home progressive-load root cause and should not be attributed to malformed addresses unless a different Anton test account/request is provided.

## Fix Split

### Mobile

- Gate the initial Home aggregate until all relevant cold-start balance probes settle.
- Or show an explicit loading/cached/partial state until the batch is complete.
- Keep fixing the query-key/refetch mismatch so refresh touches the same balance queries that the probes own.
- Separately verify the mobile address encoder path if it is still capable of registering prefix + hex non-EVM addresses.

### Backend / Data

- Add chain-specific address validation on wallet registration/update so malformed staging data cannot be created again.
- Reject prefix + hex strings for non-EVM chains such as Bitcoin, Spark, Tron, and TON.
- Repair malformed synthetic staging wallets separately; do not treat that as the fix for `ag5ezVDrcxU`.
- Optionally change balance aggregation to return explicit per-chain failure markers instead of silently degrading into null/partial totals.

## Final Position

RW-1760's 1-minute progressive loading is mobile orchestration.

Malformed non-EVM addresses are real on staging, but the direct DB proof pass shows they are not present on the known Anton/kartofili account `ag5ezVDrcxU`. The BE mismatch for that account needs a request-specific repro before assigning a backend root cause.
