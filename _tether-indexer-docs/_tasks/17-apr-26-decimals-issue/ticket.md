Ticket link: https://app.asana.com/1/45238840754660/project/1210540875949204/task/1214119276348483?focus=true

# Push notifications: format token amounts server-side (fix decimal/precision artifacts)

## Summary

Push notifications for the "Token Transfer Initiated" flow display amounts with
incorrect decimals (e.g. `0.026882800000000002` instead of `0.0268828`, and
overly long BTC sums). Implement server-side number formatting for push
notification amounts so the rendered message is always human-readable,
regardless of what the client sends.

Scope per Francesco: transaction list keeps full precision and is formatted on
the frontend (matches Tether Wallet behavior); push notifications must be
formatted on our side.

## Root cause (analysis)

Two notification paths exist with different amount sources:

- Successful path ("Transfer Successful"): emitted internally by the indexer
  (`rumble-data-shard-wrk`). `tx.amount` arrives as a pre-formatted string from
  the EVM indexer, so interpolation is clean.
- Failing path ("Token Transfer Initiated"): emitted by the mobile app via
  `POST /api/v2/notifications`. The schema in `rumble-app-node` declares
  `amount: { type: 'number' }` (JS `float64`). The app computes
  `rawUnits / 10 ** decimals` in floating point
  (e.g. `26882800 / 1e9 === 0.026882800000000002`), the backend accepts it, the
  ork layer (`rumble-ork-wrk`) forwards it unchanged, and the template does
  `${amount}` on the `Number`, exposing the IEEE-754 artifact verbatim.

## Acceptance criteria

- Push notification templates never render raw JS `Number` interpolation for
  token amounts. Amounts are formatted on the backend before the push is sent.
- Formatting is token/chain aware (do not hardcode `toFixed(6)`; decimals
  differ by chain/token).
- Floating-point artifacts (e.g. trailing `...0000002`) are eliminated from
  "Token Transfer Initiated" notifications.
- BTC notifications no longer show overly long sums.
- Behavior is verified for at least: ETH, BTC, USDT (ERC-20 and TRC-20 if
  applicable), and a 9-decimal token (repro case above).

## Proposed implementation

Primary (in scope for this ticket): format on the backend.

1. At the push emission boundary (ork layer / template pre-render), coerce
   `amount` to a canonical decimal string using token-aware decimals before
   interpolation.
2. Guard against both number and string inputs: if a `Number` is received,
   convert via a safe big-decimal path (avoid re-entering `float64`).
3. Apply a display rule that trims trailing zeros and caps max fractional
   digits per token/chain (configurable, not a global `toFixed`).

Recommended follow-ups (separate tickets, out of scope here):

- Mobile app: send amounts pre-formatted as strings
  (`formatUnits(raw, decimals)`) so the wire format is unambiguous.
- Schema hardening at `/api/v2/notifications`: change `amount` to
  `{ type: 'string', pattern: '^[0-9]+(\\.[0-9]+)?$' }` once the client change
  has rolled out.

## Affected components

- `rumble-app-node` (`/api/v2/notifications` endpoint + schema)
- `rumble-ork-wrk` (forwarding / template render)
- Push notification templates

## Out of scope

- Transaction list formatting (stays on the frontend, full precision on the
  wire, per Francesco).
- Mobile app changes (tracked separately as a follow-up).
- Schema change to `string` at `/api/v2/notifications` (tracked separately;
  requires client rollout first).

## References

- Slack thread: see `slack.txt` in this folder.
- Repro: `26882800 / 1e9 === 0.026882800000000002` rendered verbatim in the
  "Token Transfer Initiated" push.
