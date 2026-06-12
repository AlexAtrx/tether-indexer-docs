# Missing context

- [x] **Attachment (video):** "Full balance load takes about ~1min.MOV" — Alex extracted 4 frames into `shots/`, analysed in `image-analysis.md`. They confirm the progressive multi-stage load, show per-asset values recomputing (Bitcoin 0→879→928→2 317 sats), and surface a totals-don't-reconcile correctness question. Remaining: only re-watch the full `.MOV` if a frame between the captured ones is needed. **Source:** task attachment, Gocha Gafrindashvili, 2026-05-19.

- [ ] **People / decisions:** "my best guess this should be postponed until trx history V2 is out" — **Need from Alex:** is "transaction history V2" the agreed dependency/blocker for this fix, and is there a ticket/PR tracking that V2 work to link here? **Source:** comment, Alex Atrash, 2026-05-27.

- [ ] **Reproduction detail:** Bug is reported on iPhone 14 Pro, iOS 26.4.2, app v2.2.0 (596) — a frontend/app build — but Stack is set to "BE - Backend". **Need from Alex:** confirm whether the slow/progressive balance is believed to be a backend (indexer/balance aggregation) issue vs. app-side rendering, so the investigation starts on the right layer. **Source:** description + custom fields.
