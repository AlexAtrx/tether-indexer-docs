# Image / media analysis

Alex saved 10 frames of one screen recording under `images/recording 1/`
(analysed first, below). The ticket also carries 2 screen recordings and 2
client log files (all under `attachments/`). The log files contain the
backend-relevant evidence and are analysed after the frames.

## images/recording 1/ — Tip Jar toggle sequence (10 frames)

**Source:** Screen recording of the repro, frame-grabbed by Alex.
App version **v2.3.0 (717)**, iOS, recorded over ~24s.

**What it shows:** The user rapidly toggles a series of Tip Jars on. Success
shows a green banner ("<name> Tip Jar enabled"); failure shows a red banner
("Could not activate <name> Tip Jar"). The outcome is **intermittent** — some
toggles succeed on the first tap, others fail on the first tap and succeed on a
later one. The toggle visibly flips back to off when the call fails.

**Frame-by-frame (timer = recording elapsed):**
- `00:00` — Profile screen. `gwallet126's Tip Jar` OFF, `20Channell` OFF.
- `00:03` — Green: **"gwallet126's Tip Jar enabled"** (success, first try). Toggle on.
- `00:06` — Red: **"Could not activate 20Channell Tip Jar"** (first attempt FAILS).
  gwallet126 still on; 20Channell still off.
- `00:07` — 20Channell now showing a loading spinner (retry in flight).
- `00:10` — Tip Jars "View All" list. Green: **"20Channell Tip Jar enabled"**
  (retry SUCCEEDS). gwallet126 + 20Channell both on.
- `00:13` — Green: **"18Channell Tip Jar enabled"** (success, first try).
  1Channell shows a spinner (next toggle in flight).
- `00:16` — Red: **"Could not activate 1Channell Tip Jar"** (first attempt FAILS).
  1Channell back to off.
- `00:18` — Green: **"1Channell Tip Jar enabled"** (retry SUCCEEDS).
- `00:21` — Red: **"Could not activate 2Channelll Tip Jar"** (first attempt FAILS).
- `00:24` — Green: **"2Channelll Tip Jar enabled"** (retry SUCCEEDS).
  3Channell now showing a spinner (next toggle in flight).

**Relevance:** Confirms the bug end to end from the UI side and shows it is
**intermittent, not deterministic-on-first-tap** — gwallet126 and 18Channell
succeeded first try while 20Channell, 1Channell and 2Channelll failed first and
succeeded on retry. This matches the log root cause exactly: the first
`PATCH /api/v1/wallets/{id}` after the app-node's HRPC client to the downstream
worker has dropped returns 500 `[HRPC_ERR]=RPC client closed`; once the client
reconnects, subsequent toggles in the same burst go through. The red banner is
the only feedback the user gets, so a transient backend reconnect reads as a
hard failure.

---

## attachments/ (logs and original recordings)

## attachments/rumble-wallet-2026-06-02.log (client log, primary evidence)

**Source:** Gocha's 2026-06-02 comment ("Attaching fresh logs and a new recording").

**What it shows:** A Rumble Wallet mobile session (user `gwallet126`,
userId `mMb4ez3v2Cs`) toggling Tip Jars. The first toggle after the app comes
back to foreground fails with a 500, and the immediate retries also 500 a few
times before succeeding.

**Key content (verbatim):**
- `18:57:11 DEBUG [ListItemTipJar] Toggle pressed {"name":"gwallet126's Tip Jar","isEnabled":true,...}`
- `18:57:13 DEBUG [api/WalletAPI] Request {"url":".../api/v1/wallets/da3075ba-7383-4223-9494-615ba747cefc","method":"PATCH"}`
- `18:57:14 ERROR [api/WalletAPI] Error response {"status":500,"url":".../api/v1/wallets/da3075ba-7383-4223-9494-615ba747cefc","errorData":{"statusCode":500,"error":"Internal Server Error","message":"[HRPC_ERR]=RPC client closed"}}`
- `18:57:14 ERROR [useTipJarManagement] Failed to toggle tip jar {"status":500,...,"message":"[HRPC_ERR]=RPC client closed"} {"channelId":"user-mMb4ez3v2Cs","tipJarItemName":"gwallet126's Tip Jar","walletId":"da3075ba-..."}`
- The same `[HRPC_ERR]=RPC client closed` 500 also hits other endpoints in the
  same window: `POST /api/v1/device-ids` (FCM token registration, lines 691-707)
  and a second tip-jar toggle on `/api/v1/wallets/3ec62cf6-...` (lines 1351, 1368).
- Backend host: `https://wallet-8s4anfsr6it9.rmbl.ws` (rumble-app-node).

**Relevance:** This is the smoking gun. The Tip Jar toggle is a
`PATCH /api/v1/wallets/{walletId}` on rumble-app-node. The first call after the
app idles/backgrounds returns HTTP 500 with `[HRPC_ERR]=RPC client closed` — the
app-node's HRPC client to the downstream worker (ork/shard) was closed, so the
first request after the connection dropped fails, and the retry succeeds once the
client reconnects. The bug is backend (matches the "BE - Backend" tag): a closed
HRPC client should be re-established (or the request retried) transparently
instead of surfacing a 500 to the client on the first attempt.

## attachments/rumble-wallet-2026-05-29.log (client log, first report)

**Source:** Task creation, 2026-05-29.

**What it shows:** Earlier session, also user-side. Contains wallet restore noise
(`backupService All backup restore attempts failed`, `Encryption key not found`)
and network blips (`Backend offline - skipping wallet refresh`,
`[api/WalletAPI] Shard connect failed ... NetworkError`, `Request failed {}`).
This log captures intermittent backend/shard connectivity around the same flow
but does not contain a clean single `[HRPC_ERR]=RPC client closed` toggle trace
like the 06-02 log does.

**Relevance:** Corroborates flaky downstream connectivity (shard connect failures,
backend-offline) on the same wallet/tip-jar path. Treat the 06-02 log as the
canonical reproduction; this one is supporting context.

## Source screen recordings (not stored here)

The ticket carried two screen recordings (a 2026-05-29 mp4 and a 2026-06-02
mov) showing the Tip Jar toggle failing on the first tap then succeeding on
retry. They were not committed to keep the repo light; the retained evidence is
the `images/recording 1/` frames analysed above plus the log traces. The
originals remain on the Asana ticket if the raw video is ever needed.
