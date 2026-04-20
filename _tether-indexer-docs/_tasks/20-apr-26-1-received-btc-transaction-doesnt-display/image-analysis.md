# Image analysis

## 1213704628745123-screenshot-20260318-112858.png

**Source comment:** Task description (andrey.gilyov, 2026-03-18 09:25, taken 11:28 device-time)

**What it shows:** The BTC holding / Total Balance screen in the Rumble Wallet app, Pixel 10 Android 16.

**Key content:**
- Header: "Total Balance" dropdown selected
- Balance: **$15.82** / **0.00021337 BTC**
- Action row: Receive / Send / Buy / Cash Out / Swap
- "My BTC addresses" section, two rows:
  - **BTC — LIGHTNING/SPARK** — $0.00 / 0 BTC
  - **BTC — ON CHAIN** — $15.82 / 0.00021337 BTC
- "Latest transactions" area: **"No transactions yet — Once you send, receive, or swap, your transactions will show up here."**
- Status bar: 11:28, wifi on, battery 46%

**Relevance:** The balance (0.00021337 BTC / $15.82) is *visible* for the on-chain BTC address, which proves the backend indexed the UTXO and knows the funds are there. But the wallet's BTC transactions list shows "No transactions yet" — the bug. Balance is derived from the BTC received via the tx `f0fcd10294218e84b06e457e3fd740ca70188d84944e45e4aba43a59c2b10d95`, yet that tx is missing from the transaction feed.

## 1213704628745125-screenshot-20260318-112909.png

**Source comment:** Task description (andrey.gilyov, 2026-03-18 09:25, taken 11:29 device-time)

**What it shows:** The global Transactions screen (Completed tab selected), filterable by Type / Currency / Date.

**Key content (completed transactions listed, newest first):**
- **Wednesday · Mar 18** — Received $21.51 at 11:03, 21.51553 USD₮
- **Monday · Mar 16** — Received $1.00 at 12:43, 1 USD₮
- **Monday · Mar 16** — Sent $2.02 at 12:38, 2.016068 USD₮
- **Monday · Mar 16** — Received $2.00 at 11:02, 2 USD₮
- **Friday · Mar 13** — Received $0.10 at 15:47, 0.1 USA₮
- **Thursday · Mar 12** — Sent $1.34 at 18:23, 0.263 scudos
- **Tuesday · Mar 10** — Sent $0.01 at 18:51, 0.01 USD₮

**Relevance:** The global Transactions screen also fails to show the BTC received tx from 2026-03-18 11:10 (`f0fcd10294…`). Only USD₮/USA₮/scudos transactions show up. The BTC receive is missing from both the BTC-specific holdings feed (image 1) and the global transaction history (image 2), which isolates the bug to the BTC `token-transfers`/history fetch rather than a filter on the Transactions tab.

---

# Video frame analysis — `attachments/screen-20260406-172125-1775485270371.mp4`

7 screenshots (`attachments/video-file-screenshots/Screenshot 2026-04-20 at 12.11.25 … 12.12.53.png`) were captured from the 2026-04-06 screen recording andrey.gilyov attached to reproduce the bug using the reporter's credentials on staging.

## Frame 1 — `12.11.25.png` (video t≈00:00)

**What it shows:** App root / Total Balance view, "All Wallets & Tip Jars" aggregation.

**Key content:**
- **Total Balance: $2.17** (down from the original $15.82 reported 2026-03-18).
- Holdings tiles: Bitcoin **630 sats**, Tether Gold **0.075 scudos**, Tether USD₮ **1.01 USD₮**, Tether USA₮ **0.37 USA₮**.
- Wallet list: `klemensqwerty · No followers yet · $1.15`.
- Tip Jars list: `klemensqwerty's Tip Jar · 1 follower · $1.02`, `newchannetbestbitf0 · $0.00`.
- Action row: Receive / Send / Buy / Cash Out / Scan.

**Relevance:** Confirms on 2026-04-06 the BTC on-chain holding is down to 630 sats ($0.44) — the originally reported 0.00021337 BTC ($15.82) has been mostly drained between 2026-03-18 and 2026-04-06. Balance still populates, i.e. the backend still knows about the address's UTXO state.

## Frame 2 — `12.11.57.png` (t≈00:03)

**What it shows:** Profile screen after opening the user menu.

**Key content:**
- Profile: `klemensqwerty`, `klemens.andrew@gmail.com`, badge "Backed up in Rumble Cloud".
- Tip Jars: `klemensqwerty's Tip Jar` (toggle ON), `newchannetbestbitf1` (toggle OFF).
- Settings entries: Theme (Auto), Secret Phrase, FAQs, Delete Account, **App Version v2.0.3**.
- Log Out button.

**Relevance:** Confirms client build is **v2.0.3** — matches the Fix Version (FE) field on the ticket.

## Frame 3 — `12.12.10.png` (t≈00:05)

**What it shows:** Profile screen again (navigation bounce). Same content as Frame 2.

**Relevance:** Transition frame, no new info.

## Frame 4 — `12.12.21.png` (t≈00:06)

**What it shows:** Back to Total Balance ($2.17). Same holdings as Frame 1. A "Security tip — Back up your wallet before changing biometrics" banner overlays the Tip a Creator card.

**Relevance:** Transition frame.

## Frame 5 — `12.12.34.png` (t≈00:09)

**What it shows:** User has drilled into the **BTC wallet** (the same screen as image #1 in the task description, but 19 days later).

**Key content:**
- Balance: **$0.44 / 0.0000063 BTC**.
- My BTC addresses:
  - LIGHTNING/SPARK — $0.00 / 0 BTC.
  - ON CHAIN — **$0.44 / 630 sats** (with a small spinner icon next to the amount — likely refresh indicator).
- "Latest transactions" section still shows **"No transactions yet — Once you send, receive, or swap, your transactions will show up here."**

**Relevance:** The bug is still reproducible on 2026-04-06 — balance shows, transactions list is empty. The 0.00021337 BTC receive tx *and* whatever subsequent outgoing tx(s) drained the balance from 21337 sats to 630 sats are both absent from the list.

## Frame 6 — `12.12.43.png` (t≈00:10)

**What it shows:** "Receive" bottom sheet opened over the BTC wallet, "BTC · ON CHAIN Address — Receive BTC using the ON CHAIN network" with a QR code and the address below.

**Key content (CRITICAL):**
- Visible address text: **`bc1qgm7k56yqdz…kdn2wgt0m9ph2`** (truncated in the middle, matches `bc1qgm7k56yqdzzn30vzzxrjnle6nkdn2wgt0m9ph2`).
- Copy button and Share button next to the address.

**Relevance:** **This is the evidence that resolves the biggest open mystery in the ticket** — the FE is serving `bc1qgm7k56yqdzzn30vzzxrjnle6nkdn2wgt0m9ph2` as the user's BTC ON-CHAIN receive address. That is exactly the address Usman's BE `/wallets` response **did not contain** on 2026-03-19 12:47 (either in the single-wallet or two-wallet snapshot). So the user didn't "somehow acquire" this address — the app itself is presenting it as their receive address while the BE `/wallets` endpoint returns a different set of BTC addresses entirely. Either:
1. The FE reads the receive address from a different endpoint than `/wallets` (e.g. a per-token address / deposit-address endpoint that is out of sync), OR
2. `/wallets` is filtering/omitting this address for this user, OR
3. There is stale cached state on the client (but the QR is rendered on demand, so this is less likely).

Any fix needs to explain why the BE returns one address set while the app shows a different one — and why the tx history lookup keys off the `/wallets` list but the receive-address flow doesn't.

## Frame 7 — `12.12.53.png` (t≈00:12)

**What it shows:** Tap-to-copy confirmation: green toast "Address copied to clipboard". QR sheet still open with a share/native-share overlay revealing the full address.

**Key content:**
- Toast: "Address copied to clipboard".
- Full address confirmed visible in the share-sheet chip (wraps across lines): `bc1qgm7k56y / qdzzn30vzzx / rjnietnkdin2w / gt0m9ph2` — i.e. `bc1qgm7k56yqdzzn30vzzxrjnietnkdn2wgt0m9ph2`. **NOTE:** a visual inspection of the wrap suggests the address shown here may be `bc1qgm7k56yqdzzn30vzzxrjnietnkdn2wgt0m9ph2` (…**rjnietnkdn2w**…) rather than `bc1qgm7k56yqdzzn30vzzxrjnle6nkdn2wgt0m9ph2` (…**rjnle6nkdn2w**…) quoted by andrey earlier. This may just be a render/OCR artifact in the screenshot — **verify the exact character sequence against the video before using this address in BE queries.**

**Relevance:** Confirms the user actually copies this address from within the app (not pasted from elsewhere), closing the loop on "how the user got the address": the app handed it to them via the standard Receive flow.
