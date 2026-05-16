# Image analysis

## 1214269983129060-img-0088.jpg

**Source comment:** Task description (uploaded by Mariia Nikolaichuk, 2026-04-24).

**What it shows:** iPhone 15 (iOS 26.1) screenshot of the Rumble Wallet "Transaction Submitted" sheet, with a banner push notification overlaying the top of the screen. The push title is **"Token Transfer Initiated"**, body **"A transfer of 8e-7 XAUT on Plasma is about to be initiated to your wallet"** — the `8e-7 XAUT` substring is circled in red.

**Key content:**

- **Push title:** `Token Transfer Initiated`
- **Push body:** `A transfer of 8e-7 XAUT on Plasma is about to be initiated to your wallet`
  - Bug: amount is rendered in JS scientific notation (`8e-7`) instead of a fixed-decimal user-facing string. No space between number and ticker (`8e-7XAUT`-ish, though the screenshot shows a space).
- **In-app sheet header:** `Transaction Submitted` — `XAU₮ transfer in progress, we'll notify you once the transaction is completed.`
- **Arriving time:** `~5 seconds`
- **From:** `mtester1001 tip jar` — `0x159c…3Cb4`
- **To:** `MashaRumble Wallet` — `0x159c…3cb4`
- **Network:** `PLASMA`
- **Transfer amount:** `< $0.01`
- **Estimated fees:** `< $0.01`
- **Actual fees:** `0.001 scudos` (`< $0.01`)
- **Final amount with fees:** `$0.01` (`0.002 scudos`)
- **Total Balance:** `$222.57`

**Relevance:** Shows that the in-app sheet correctly formats the amount as `< $0.01`, but the OS push notification body (delivered via APNs by the backend, not the in-app sheet) is using a raw JS number → string conversion which falls into scientific notation for sub-1e-6 values. The actual on-chain amount must be on the order of `8e-7 XAUT` (~0.0000008 XAU₮ ≈ < $0.01 given ~$3.3k/oz gold), so the underlying value isn't wrong — just the formatting in the push payload.

---

## 1214783831990609-image.png

**Source comment:** Comment by Gocha Gafrindashvili, 2026-05-13T15:37:28Z (QA reproduction).

**What it shows:** Android Pixel 7 (Android 16) lock-screen / notification panel at `7:33 Wed, May 13`, showing two stacked Rumble Wallet Dev pushes.

**Key content:**

- **Notification 1 — `Transfer Successful`:** `A transfer of 0.00000013 BTC on Spark has been successfully completed into your wallet.`
  - Amount rendered in plain decimal — formatting is OK on the success notification.
- **Notification 2 — `Token Transfer Initiated`:** `A transfer of 1.3e-7 BTC on Spark is about to be initiated to your wallet`
  - **Same scientific-notation bug** as the XAUT/Plasma case, but on a different chain (Spark) and asset (BTC).
- **App label:** `Rumble Wallet Dev` (dev build, not prod, but reproduces the same string).

**Relevance:** Confirms the bug is **not chain-specific** (XAUT/Plasma + BTC/Spark both affected) and **not notification-type-specific in the data path** (success and initiated come from the same code path but only `Token Transfer Initiated` mishandles the small amount on this run — likely because the `Transfer Successful` body builder uses a different formatter, or because the on-chain confirmed amount happened to be `0.00000013` which has 8 decimals and stays out of scientific notation while `1.3e-7` has only 2 significant figures and drops into exponent form via `Number.toString()`). Either way, the "initiated" push uses a formatter that falls through to default JS number stringification for very small values.
