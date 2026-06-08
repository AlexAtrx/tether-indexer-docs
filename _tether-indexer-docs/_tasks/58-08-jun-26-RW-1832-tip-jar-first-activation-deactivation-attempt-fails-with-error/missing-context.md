# Missing context

- [ ] **Backend logs**: The attached logs are the **mobile client** logs only.
  The failing call is `PATCH /api/v1/wallets/{walletId}` returning
  `[HRPC_ERR]=RPC client closed` from `wallet-8s4anfsr6it9.rmbl.ws`
  (rumble-app-node). **Need from Alex:** which environment is
  `wallet-8s4anfsr6it9.rmbl.ws` (prod / staging), and access to the
  rumble-app-node + downstream ork/shard logs around `2026-06-02 18:57:13-18:57:24`
  so we can see which HRPC client closed and why. **Source:** 06-02 client log.

- [ ] **Reproduction window timestamps**: Confirm the timezone of the client log
  timestamps (`18:57:xx`) vs server log timezone before correlating.
  **Need from Alex:** none if backend logs are in the same TZ; otherwise the
  offset. **Source:** log files.

- [x] **Screen recording UX captured**: 10 frames of one recording are saved in
  `images/recording 1/` and analysed in `image-analysis.md` — they confirm the
  intermittent first-tap failure with green/red banners. The two original videos
  were not stored in-repo to keep it light; they remain on the Asana ticket if
  the raw video is ever needed. **Source:** attachments / images.

- [ ] **Credentials are live test creds in the ticket body**: usable to reproduce
  against whatever env `gwallet126` points to. **Need from Alex:** confirm it is
  safe/intended to use these for repro. **Source:** description.
