# Missing context — RW-1724

- [x] **Slack thread:** "discussed with BE team here:
  https://tether-to.slack.com/archives/C0A5DFYRNBB/p1779228490793649" —
  **RESOLVED:** thread captured in `slack.txt`. Conclusion below.
  **Source:** Ahsan Akhtar, 2026-05-19 22:16.

- [x] **External PR (FE):** PR #1185 — **RESOLVED via `slack.txt`:** it is
  **log instrumentation only** (Eddy WM asked Ahsan to add an error-case log so
  QA can capture the failure on the next repro), not a fix. What prod logs
  showed is still open: no one re-ran prod with the merged logs before the bug
  stopped reproducing. This is a mobile-app repo, not in the local workspace.
  **Source:** Ahsan Akhtar, 2026-05-19 23:28 + `slack.txt`.

- [ ] **Related ticket:** "[Send] Unable to send XAUT send button disabled, no
  error/info message shown" (Asana task 1213298243721304) — referenced as a
  cross-mention. **Need from Alex:** confirm whether it's the same root cause /
  should be tracked together.
  **Source:** system mention, 2026-05-08 14:22.

- [ ] **Video evidence (not analysable as text):** 5 screen recordings are saved
  under `attachments/` but cannot be read here:
  - `1214645854311827-...mp4` (17 MB) — reporter's original repro.
  - `1214926422233068-...025047.mp4` and `1214949704887751-...025047.mp4` —
    Ahsan's "cannot reproduce on prod" recording (identical duplicate upload).
  - `1214950666236731-...203805.mp4` — Ahsan's local-debug "cannot reproduce"
    recording.
  - `1215175005744698-...181205.mp4` (2026-05-27) — Ahsan's latest "Max now
    works fine on prod, candide/paymaster fixed" recording.
  **Need from Alex:** if any specific value/log in a recording matters, point me
  to the timestamp.

- [x] **Env / system / ownership:** Bug is on **prod IT** (Google Play internal
  test build, app v2.1.0 build 200), XAUT-on-ETH only, via `candide/paymaster`
  fee sponsorship. **RESOLVED via `slack.txt`:** Francesco C. — *"quote is not
  handled by the backend but directly by the bundler / paymaster candide."* So
  this is **not** a WDK/Rumble backend concern; the fee quote (`quoteTransfer`)
  is served directly by the candide bundler/paymaster. Endpoint:
  `${RUMBLE_WALLET_RPC_URL}/candide/paymaster/${networkLower}`. Source
  verification corrected the RPC-method detail: the app's ERC-20
  paymaster-token mode uses `pm_getPaymasterStubData`, `pm_getPaymasterData`,
  and `pm_supportedERC20Tokens`; `pm_sponsorUserOperation` is sponsorship mode,
  not this app path. XAUT addr on ETH:
  `0x68749665FF8D2d112Fa859AA293F07A622782F38`.
  **Source:** description Notes + Ahsan comments + `slack.txt`.

## Conclusion from `slack.txt`

The "Max unavailable" pill is the FE's fallback when the Send-screen fee
preload fails. Ahsan's debugging: `quoteTransfer()` normally returns
`{fee: "38"}` for XAUT and Max shows fine; he reproduced "Max unavailable" only
by forcing that call to throw (`if (!quoteResult)` → `if (quoteResult)`). So the
real trigger is `quoteTransfer()` intermittently **throwing or returning null on
the prod URL** — and per Francesco that call resolves against the candide
bundler/paymaster, not our backend. The bug has since stopped reproducing on
prod (2026-05-27), consistent with a transient/paymaster-side condition rather
than a code defect on either FE or our BE.
