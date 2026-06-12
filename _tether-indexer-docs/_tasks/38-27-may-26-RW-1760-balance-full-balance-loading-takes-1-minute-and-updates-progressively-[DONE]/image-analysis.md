# Image / video analysis

The original ticket attachment is a screen recording (`.MOV`, saved under
`attachments/`). Alex extracted four representative frames from it into `shots/`.
Those frames are analysed below; the `.MOV` itself is the source of record but is
not text-readable.

## Summary (Alex's read of the video)

The balance does **not** update quickly. The user has to pull-to-refresh and then
wait a long time before the balance changes, and it is **unclear whether the final
balance shown is even correct**. The four frames below show the Total Balance
climbing in stages over ~1 minute rather than resolving once.

## Frame-by-frame

| File (`shots/`)                     | Phone clock | Total Balance | Bitcoin    | Tether Gold  | USD₮      | USA₮      | Local / kartofili wallet |
|-------------------------------------|-------------|---------------|------------|--------------|-----------|-----------|--------------------------|
| Screenshot 2026-05-27 at 16.52.51   | 18:17       | _(blank, loading)_ | 0 sats     | 0 scudos     | 0.00 USD₮ | 0.00 USA₮ | $0.00 / $0.00            |
| Screenshot 2026-05-27 at 16.53.14   | 18:17       | $0.67         | 879 sats   | 0 scudos     | 0.00 USD₮ | 0.00 USA₮ | $0.67 / $0.67            |
| Screenshot 2026-05-27 at 16.54.00   | 18:18       | $2.27         | 928 sats   | 0.218 scudos | 0.37 USD₮ | 0.21 USA₮ | $2.08 / $2.08            |
| Screenshot 2026-05-27 at 16.54.08   | 18:18       | $4.25         | 2 317 sats | 0.238 scudos | 1.06 USD₮ | 0.35 USA₮ | $2.08 / $2.08            |

**Source:** all frames extracted from `Full balance load takes about ~1min.MOV`
(task attachment, Gocha Gafrindashvili, 2026-05-19).

## What the frames evidence

- **Progressive, multi-stage load.** Total Balance resolves in steps
  (blank → $0.67 → $2.27 → $4.25), not in a single update. The main-balance
  loading state persists while assets trickle in — exactly the reported behavior.
- **Values are being recomputed, not just revealed.** Bitcoin moves
  0 → 879 → 928 → 2 317 sats across the frames. If this were purely a UI delay
  surfacing an already-known balance, the per-asset numbers would jump straight to
  their final value once shown. The intermediate, increasing values suggest the
  balance is being assembled/recomputed source-by-source (per chain/per asset)
  on the read path, with the UI rendering each partial state.
- **Totals do not reconcile (possible correctness bug).** Final frame: Total
  $4.25, but Local $2.08 + kartofili $2.08 = $4.16. Earlier frames also fail to
  add up (frame 3 Total $2.27 vs two $2.08 wallets). Either the wallet-row figures
  lag the header total, or the aggregate is summing something the per-wallet rows
  don't. This matches Alex's "not sure the new balance is the right balance" and is
  worth treating as a distinct question from the slowness.

## Open question for investigation

Is the climbing total a UI that renders each asset's balance as it arrives, or is
the backend balance-aggregation path itself returning partial sums until every
chain/asset query completes? The recomputing per-asset values lean toward the
latter (a backend/aggregation read-path issue), consistent with the
Stack = "BE - Backend" tag.
