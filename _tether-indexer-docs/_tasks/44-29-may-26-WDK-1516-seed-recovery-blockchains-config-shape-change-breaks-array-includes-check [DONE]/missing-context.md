# Missing context

- [ ] **Evidence mismatch (important):** The "Prod error" pasted in the
  description is a `RPC client closed` error whose stack trace is entirely in
  `rumble-app-node/workers/lib/services/promo.js` (`cleanRpcError` ->
  `claimCode`) via `server.js:552` — the promo claim-code route. It does **not**
  reference `seed.recovery.js` or any `.includes()` / blockchains-config failure
  at all. The pasted log appears to be copied from a different incident (it looks
  like the WDK-1515 prod RPC error). **Need from Alex:** the actual prod log
  line / stack trace that shows the `seed.recovery` blockchains `.includes()`
  break, or confirmation that the root-cause analysis was done by code reading
  rather than from this log. **Source:** description, "Prod error
  (2026-05-28T17:52:48)" block.

- [ ] **Logs / Grafana:** Grafana link
  `http://rwg.rmbl.ws:3000/goto/qgkOEl1vR?orgId=1` is referenced but the panel
  contents are not captured here, and the link requires VPN/Grafana access.
  **Need from Alex:** if the seed.recovery error is real in prod, the matching
  Grafana log panel export. **Source:** description, "Grafana".

- [ ] **New config shape source:** The "new object-shaped blockchains config" is
  cited via `wdk-app-node/config/common.json.example#L28` at a pinned commit.
  This is reachable via `read-remote-repo` / `gh` during handling — not blocking,
  just noted so the handler pulls the exact current shape before editing.
  **Source:** description, "References".

- [ ] **Other call sites:** The fix asks to "audit other call sites that still
  treat `blockchains` as an array." No list is provided. **Need from Alex:**
  nothing — this is investigation work for the handling step (grep across
  `rumble-app-node` / `wdk-app-node` for `blockchains` usage). **Source:**
  description, "Fix".

No Slack threads, external tickets, or attachments were referenced beyond the
two GitHub links and the Grafana link above.
