# Missing context

Items referenced (directly or implicitly) in the ticket but not captured here.

- [ ] **External ticket / vendor contact:** "I checked with Rumble, Andrei said that on the Rumble appearing tip button can take 10 minutes" — **Need from Alex:** who is Andrei (Rumble side contact), and is there a Rumble-side ticket / thread with the 10-minute SLA statement? **Source:** Gohar Grigoryan, 2026-02-24T17:07.

- [x] ~~**API endpoint details:** `/wallet/v1/address-book` returning stale `tipping_enabled`~~ — **Resolved by local code inspection (see `findings.md`):** the endpoint is **not ours** — zero matches across every `_INDEXER/` repo. On our side, `tipping_enabled` is derived on each call from the wallet row's `enabled` flag in the HyperDB shard via `rumble-app-node → rumble-ork-wrk → rumble-data-shard-wrk` (`getUserTipJar` / `getChannelTipJar`). **Source:** Patricio Vicens, 2026-02-25T19:41.

- [ ] **V1 vs V3 comparison:** "I compared with V1, the button becomes active very quickly" — **Need from Alex:** V1 backend behaviour for the same endpoint (or equivalent) — what changed between V1 and V3 that introduced the delay? Any commit / PR references? **Source:** Gohar Grigoryan, 2026-02-24T17:09.

- [ ] **Video evidence:** `1000002629.mp4` (25.5 MB) was attached with "I still can reproduce it" — video is saved under `attachments/` but a written transcript of the reproduction steps and timing would help (how long was the wait before the recording? pull-to-refresh attempted? relogin?). **Source:** Gohar Grigoryan, 2026-02-27T19:42.

- [ ] **Fix attempt:** Patricio moved the task to "Ready for QA" on 2026-02-26, implying a fix landed. On 2026-02-27 Gohar reopened it. **Need from Alex:** is there a PR / commit for the first fix attempt? Knowing what was tried helps avoid repeating it. **Source:** section moves on 2026-02-26 and 2026-02-27.

- [ ] **Mentions with no follow-up:** Gohar @-mentioned Ignacio Larrañaga and Mohamed Elsabry on 2026-02-25T19:45 with no accompanying text. **Need from Alex:** was there an out-of-band conversation (Slack / DM) that followed those mentions? **Source:** Gohar Grigoryan, 2026-02-25T19:45.

- [ ] **Environment access:** Staging host `web190181.rumble.com` is visible in the web screenshot. **Need from Alex:** do we have repro access against this staging env, and which indexer/app-node instance backs it? **Source:** screenshot `1213396653978879`.

- [ ] **Test accounts:** Screenshots show usernames `gversion1`, `gversion83v`, `fguuj`, `gstaging65`. **Need from Alex:** are these shared QA accounts, and are their wallet / follow states still in the state shown, or have they drifted? **Source:** both screenshots.
