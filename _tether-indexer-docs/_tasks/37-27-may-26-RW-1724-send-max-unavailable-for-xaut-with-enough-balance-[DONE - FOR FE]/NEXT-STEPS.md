# Next steps for RW-1724 — Max unavailable for XAUT with enough balance

**Ticket:** https://app.asana.com/1/45238840754660/project/1212521145936484/task/1214645854311819

## What we know
- On the XAUT (Tether Gold on ETH) send/tip flow, the **Max** button shows as
  **"Max unavailable"** even though the user holds ~$24 of XAUT and fees are
  sponsored (fee row shows **FREE**). A manual amount (0.5$) still proceeds and
  the transaction completes — so it's only the Max affordance that's broken.
- **XAUT-only.** Repro on prod IT build v2.1.0 (200), iPhone 15 / Pixel.
- Assignee Ahsan: reproduces on the installed **prod** build but **not** on a
  **local debug** build with no FE change.
- **Root cause (from `slack.txt`):** "Max unavailable" is the FE's fallback when
  the Send-screen fee preload fails. The preload calls `quoteTransfer(...)`
  which normally returns `{fee: "38"}` for XAUT (→ Max shows). Ahsan reproduced
  the bug only by forcing that call to throw. So the trigger is
  `quoteTransfer()` intermittently **throwing / returning null on prod**.
- **Ownership (from `slack.txt` + source verification):** Francesco C. —
  *"quote is not handled by the backend but directly by the bundler / paymaster
  candide."* The quote resolves against the candide bundler/paymaster
  (`${RUMBLE_WALLET_RPC_URL}/candide/paymaster/${networkLower}`), **not** our
  WDK/Rumble backend. Source check corrected one detail: with the app's
  ERC-20 paymaster-token config this path uses `pm_getPaymasterStubData`,
  `pm_getPaymasterData`, and `pm_supportedERC20Tokens`, not sponsorship-mode
  `pm_sponsorUserOperation`.
- Latest (2026-05-27): Ahsan re-tested on prod and **Max now appears/works**;
  issue "is not appearing anymore from candide/paymaster". Asked QA (Mariia) to
  re-confirm. Ticket moved back to **Ready for QA**.
- Expected behaviour: 'Use Max' should be available whenever fees can be covered.

## Evidence captured here
- 2 images analysed in `image-analysis.md` (description storyboard + Ahsan's
  prod repro screenshot)
- 5 video attachments under `attachments/` (not text-readable; see
  missing-context.md) — note two are byte-identical duplicates
- 16 comments/system stories in `comments.md`

## What's missing (now narrowed — see `missing-context.md`)
- ~~BE-team Slack thread~~ → captured in `slack.txt`.
- ~~Which service owns the quote~~ → candide bundler/paymaster (not our BE).
- FE PR #1185: confirmed **log-only**; still open is whether anyone re-ran prod
  with the merged logs to capture the actual error (no one did before it
  stopped reproducing).
- Related Asana ticket 1213298243721304 (XAUT send button disabled) — same root
  cause? still unconfirmed.
- Video contents (point to a timestamp if a value matters).

## Before starting work
`slack.txt` settles ownership: **this is not a WDK/Rumble backend bug** — the
fee quote is served directly by the candide bundler/paymaster, and "Max
unavailable" is the FE fallback when `quoteTransfer()` fails. It is also no
longer reproducing on prod (2026-05-27), consistent with a transient
paymaster-side condition. So there is most likely **no BE action for us here**;
it's parked in Ready for QA awaiting Mariia's re-confirm. If Alex still wants
something from our side, the only useful angle is to check whether the candide
paymaster had a transient outage/fix window around 2026-05-18→27 for
XAUT-on-ETH. Otherwise close-as-QA-verify.

See `root-cause-analysis.md` for the source-verified control flow and the
correct Candide RPC methods used by this app version.
