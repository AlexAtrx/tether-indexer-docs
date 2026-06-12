# Image analysis — RW-1724

## 1214645854311822-send-max-unavailable-for-xaut-with-enough-balance.jpg

**Source comment:** Task description (reporter Mariia Nikolaichuk)

**What it shows:** A 6-panel storyboard of the full XAUT send flow, walking from
QR scan through to a completed transaction, with the bug captured in panel 3.

**Key content (per panel):**
1. **Scan QR** — "Scan QR Code" screen with camera + QR in view.
2. **Select XAUT Eth (24$)** — "Choose what to send" sheet: `Tether USDt` $0.00,
   `XAUT` ~$24, `Tether Gold` selected. Confirms the user has ~$24 of XAUT.
3. **'Max unavailable' displays** *(red-boxed — the bug)* — amount entry on
   `MashaRumble (You)` tip jar, amount `0.00` / `$0.00`, with a greyed-out
   **Max unavailable** pill. Even though balance is ~$24, Max is disabled.
4. **Enter 0.5$ > Continue enabled** — amount `0.5`, Continue button enabled,
   so a manual amount still proceeds.
5. **Fee shows FREE > Submit** — "Send XAUT" review screen; network/fee row
   shows **FREE**; Submit/Confirm enabled.
6. **Transaction completed** — "Transaction Submitted" success screen, balance
   shown ~$192.81. Confirms the send succeeds despite Max being unavailable.

**Relevance:** Demonstrates the contradiction at the heart of the ticket — fee
is FREE (i.e. sponsored / coverable) and a manual send completes, yet the
**Max** button is shown as unavailable. Expected: Max should be available
whenever fees can be covered.

---

## 1214949704887746-image.png

**Source comment:** Ahsan Akhtar, 2026-05-19 15:36 (reproduction on prod app)

**What it shows:** Single phone screenshot of the XAUT send amount-entry screen
reproducing the bug.

**Key content:**
- Header: `mtester1001 tip jar's tip jar`
- "You're about to send Tip to **MashaRumble (You)**"
- Select token: **Tether Gold  ETH** (XAUT on Ethereum)
- Amount: `0.00` / `$0.00`
- Greyed-out **Max unavailable** pill
- **Continue** button disabled (greyed) at this 0.00 state

**Relevance:** Independent reproduction by the assignee on the prod (internal
test) Android build, same `masharumble` user, confirming the Max-unavailable
state for XAUT on ETH. Notably reproduces on the installed prod build but NOT
on a local debug build — pointing at a backend/paymaster fee-estimation
difference rather than FE logic.
