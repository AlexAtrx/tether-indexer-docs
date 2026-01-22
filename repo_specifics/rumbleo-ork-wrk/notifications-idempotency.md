## Notification idempotency

- **What**: Manual notification types (`SWAP_STARTED`, `TOPUP_STARTED`, `CASHOUT_STARTED`) are deduped per `(userId, type, idempotencyKey/requestId)` using an in-memory LRU.
- **Defaults**: `windowMs: 600000` (10 minutes) and `maxKeys: 5000` in `config/common.json.example` under `notifications.idempotency`.
- **Trade-offs**:
  - A longer window is safer for upstream retries but can block repeats only when the same key is reused.
  - Distinct `idempotencyKey`/`requestId` values are treated as separate requests (tested), so clients can send back-to-back operations by changing the key.
  - Shorten `windowMs` (e.g., 1–2 minutes) if clients never retry beyond a brief window; increase if retries happen later.
- **Failure semantics**: Keys are marked before send and cleared on failure; dedupe applies only to identical keys.
