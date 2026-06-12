# Missing context — RW-1760

- [x] **Attachment:** "Full balance load takes about ~1min.MOV" — downloaded to
  `attachments/`. It is a screen recording, not a still, so no in-text frame
  analysis was possible. **Source:** Gocha Gafrindashvili, 2026-05-19.

- [ ] **External source code (mobile repo):** The diagnosis lives entirely in
  `tetherto/rumble-wallet-app-mobile` (NOT cloned in this workspace). Hooks cited
  at commit `885d6a6`: `hooks/useRumbleBalanceProbes.tsx#L25`,
  `hooks/useAggregatedBalances.ts#L66`, `hooks/useFlowSelection.ts#L136`,
  `hooks/useBalanceFetcher.ts#L19`. **Need from Alex:** confirm whether this
  ticket is now mobile-team scope (it is assigned to anton.kurdo + Aliaksei on the
  mobile side) or whether the backend angle below is what he wants looked at.
  **Source:** Alex Atrash 2026-05-27, anton 2026-06-01.

- [ ] **Backend "total balance" endpoint returns wrong balance:** George proposed
  using an existing BE endpoint that returns total balance per token and wallet
  for the fresh-install case; anton reports it "returns an incorrect balance that
  doesn't match the actual balance" (tested across several wallets). This is the
  one genuinely backend-side thread. **Need from Alex:** which endpoint is this
  (wdk-app-node? wdk-indexer-app-node?), and is verifying / fixing that endpoint's
  total-balance number the part Alex wants handled here. Example wallet given:
  seed "collect sphere asset adult split write fatigue twelve predict width
  another crew" (login kartofili / 123qweASD!). **Source:** George 2026-06-01,
  anton 2026-06-05.

- [ ] **People / decision:** Eddy assigned the fix to anton + Aliaksei (mobile),
  ticket moved back to "To Triage" on 2026-06-05. **Need from Alex:** clarify why
  it landed in his fetch queue and what slice he owns (likely just the BE
  total-balance endpoint accuracy, per his own 2026-05-27 comment that this is not
  an indexer backend issue). **Source:** Eddy 2026-06-01, section change 2026-06-05.
