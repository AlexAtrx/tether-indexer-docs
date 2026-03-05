# Transfer History — API Reference

---

## `GET /api/v1/wallets/:walletId/transfer-history`

### Params

- `:walletId` (path, string, required) — wallet identifier
- `token` (query, string) — filter by token e.g. `usdt`, `btc`
- `blockchain` (query, string) — filter by blockchain e.g. `ethereum`, `bitcoin`
- `type` (query, enum: `sent` | `received` | `swap_out` | `swap_in`) — filter by transaction type
- `activitySubtype` (query, enum: `transfer` | `tip` | `rant`) — filter by activity subtype
- `from` (query, integer) — start timestamp inclusive, unix ms
- `to` (query, integer) — end timestamp inclusive, unix ms
- `limit` (query, integer, default `10`) — max results
- `skip` (query, integer, default `0`) — pagination offset
- `sort` (query, enum: `asc` | `desc`, default `desc`) — sort by timestamp

### Request

```
GET /api/v1/wallets/052d6e5d-abc1-def2/transfer-history?token=usdt&type=sent&limit=20&sort=desc
Authorization: Bearer <token>
```

### Response `200`

```json
{
  "transfers": [
    {
      "userId": "user-123",
      "walletId": "052d6e5d-abc1-def2",
      "transactionHash": "0xabc123def456...",
      "blockNumber": 12345678,
      "ts": 1707222200000,
      "updatedAt": 1707222200000,
      "blockchain": "ethereum",
      "token": "usdt",
      "type": "sent",
      "status": "confirmed",
      "amount": "1000000",
      "fiatAmount": "100.50",
      "fiatCcy": "usd",
      "from": "0xabc123...",
      "fromUserId": null,
      "to": "0xdef456...",
      "toUserId": null,
      "fee": null,
      "feeToken": null,
      "feeLabel": "gas",
      "subType": "transfer",
      "tipDirection": null,
      "message": null
    }
  ]
}
```

### Errors

- `401` — missing or invalid auth token
- `404 ERR_WALLET_NOT_FOUND` — wallet does not exist or does not belong to authenticated user

---

## `GET /api/v1/users/:userId/transfer-history`

### Params

- `:userId` (path, string, required) — user identifier, must match authenticated user
- `token` (query, string) — filter by token e.g. `usdt`, `btc`
- `blockchain` (query, string) — filter by blockchain e.g. `ethereum`, `bitcoin`
- `type` (query, enum: `sent` | `received` | `swap_out` | `swap_in`) — filter by transaction type
- `activitySubtype` (query, enum: `transfer` | `tip` | `rant`) — filter by activity subtype
- `from` (query, integer) — start timestamp inclusive, unix ms
- `to` (query, integer) — end timestamp inclusive, unix ms
- `limit` (query, integer, default `10`) — max results
- `skip` (query, integer, default `0`) — pagination offset
- `sort` (query, enum: `asc` | `desc`, default `desc`) — sort by timestamp
- `walletTypes` (query, array of strings) — filter by wallet type

### Request

```
GET /api/v1/users/user-123/transfer-history?blockchain=ethereum&from=1707000000000&to=1708000000000&limit=10
Authorization: Bearer <token>
```

### Response `200`

```json
{
  "transfers": [
    {
      "userId": "user-123",
      "walletId": "052d6e5d-abc1-def2",
      "transactionHash": "0xabc123def456...",
      "blockNumber": 12345678,
      "ts": 1707222200000,
      "updatedAt": 1707222200000,
      "blockchain": "ethereum",
      "token": "usdt",
      "type": "received",
      "status": "confirmed",
      "amount": "5000000",
      "fiatAmount": "500.00",
      "fiatCcy": "usd",
      "from": "0x999888...",
      "fromUserId": null,
      "to": "0xabc123...",
      "toUserId": null,
      "fee": null,
      "feeToken": null,
      "feeLabel": "gas",
      "subType": "tip",
      "tipDirection": "received",
      "message": null
    }
  ]
}
```

### Errors

- `401` — missing or invalid auth token
- `403 ERR_USER_ID_INVALID` — path userId does not match authenticated user
- `404 ERR_USER_WALLETS_NOT_FOUND` — user has no active wallets
- `404 ERR_USER_WALLET_ADDRESSES_NOT_FOUND` — no wallets match requested walletTypes

---

## Response Field Notes

- `blockNumber` — nullable; promoted from first underlying transfer
- `ts` — block timestamp in epoch ms
- `updatedAt` — equals `ts` in Phase 1; will differ once pending/confirmed tracking is added
- `status` — always `"confirmed"` in Phase 1
- `amount` — raw chain format string (e.g. `"1000000"` for 1 USDT on EVM, `"0.5"` for BTC); app converts using token decimals
- `fiatAmount` — nullable; fiat value at ingestion time
- `fiatCcy` — nullable; fiat currency code
- `fromUserId` — always `null` in Phase 1; future address-to-user lookup
- `toUserId` — always `null` in Phase 1; future address-to-user lookup
- `fee` — always `null` in Phase 1; fee extraction is next priority
- `feeToken` — always `null` in Phase 1
- `feeLabel` — `"gas"` (default) or `"paymaster"` (when any transfer in group is paymaster-sponsored)
- `subType` — `"transfer"` | `"tip"` | `"rant"` | absent when no enrichment data exists
- `tipDirection` — `"sent"` | `"received"` | `null`; only meaningful for tips and rants
- `message` — rant text string | `null`; only populated for rants
