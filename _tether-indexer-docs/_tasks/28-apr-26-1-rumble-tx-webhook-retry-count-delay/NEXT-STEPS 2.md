# Next steps for RW-1120 — Tip button inactive after follow

**Ticket:** https://app.asana.com/1/45238840754660/project/1212521145936484/task/1213391745549211

## What we know

- After a user follows a new channel or user on Rumble (from web), the **Send Tip** button stays **inactive in the Rumble Wallet app** and **does not render on the Rumble web profile** for that newly-followed creator.
- Relogin in the app makes the button appear correctly.
- Pull-to-refresh in the app does **not** fix it (Gohar confirmed 2026-02-25).
- V1 of the wallet did not have this delay — button became active "very quickly".
- Patricio's diagnosis (2026-02-25): `/wallet/v1/address-book` returns `tipping_enabled=false` for the newly-followed creator and only flips to `true` after a delay. He classified this as an **API / backend issue**.
- A first fix attempt was made (task moved to Ready-for-QA on 2026-02-26), but Gohar reproduced the bug on 2026-02-27 and reassigned.
- Ticket bounced FE → BE on 2026-04-08 and is now with Alex.
- Environment: **staging**, iOS app v3.0.1 (build 339), iPhone 17 Pro Max / iOS 26.2.

## Evidence captured here

- **2 images** analysed in `image-analysis.md` (app screenshot showing inactive Send Tip, web screenshot showing no tip button on profile).
- **1 non-image attachment** under `attachments/` (25.5 MB screen recording `1000002629.mp4` of the reproduction).
- **~12 comments** plus relevant system events in `comments.md`.
- **Code investigation** in `findings.md` — ownership of `/wallet/v1/address-book`, our tip-jar path, likely failure modes, and how to get `fguuj`'s channelId.

## Key finding — `/wallet/v1/address-book` is NOT ours

See `findings.md`. Grep across every local repo returned zero matches. That endpoint lives on the Rumble side, fronting our real tip-jar endpoints (`/api/v1/users/:userId/tip-jar`, `/api/v1/channels/:channelId/tip-jar`). On our side, `tipping_enabled` is derived on every call from the wallet row's `enabled` flag in the HyperDB shard — we do not cache it.

**Confirmed by Alex 2026-04-28** (verbally) — endpoint is Rumble's. Reframes the ticket from "BE fix on our side" to "Rumble propagation issue → coordinate / mitigate, don't patch our backend".

## What's missing (from `missing-context.md`)

- Rumble-side contact / ticket (Andrei's 10-minute SLA claim).
- V1 vs V3 diff for the equivalent endpoint.
- PR / commit for the first fix attempt (section move on 2026-02-26).
- Any out-of-band Slack discussion after Gohar's mentions on 2026-02-25.
- Staging access details (`web190181.rumble.com` and backing app-node instance).
- `fguuj` / `gstaging65` channelIds — not resolvable locally; see `findings.md` for four ways to get them.

## Before starting work

Run the disambiguation test described in `findings.md` first — it decides whether this is a backend fix at all:

1. Get `fguuj`'s channelId (network capture from the staging app is fastest).
2. Hit `GET /api/v1/channels/<channelId>/tip-jar` on staging the moment the channel is followed.
3. **200 immediately** → Rumble-side cache; push back to Rumble (ask them to drop TTL or invalidate on follow).
4. **`ERR_CHANNEL_TIP_JAR_NOT_FOUND` for minutes** → our wallet-provisioning lag; trace where channel-wallet rows are created on follow (ork webhook or on-demand shard create) and look for a missed event / race around `enabled=true`.

Do NOT write any fix before this test.

## Update 2026-04-28

- Sprint changed to **Sprint 1** (Eddy WM).
- Alex's 2026-04-20 question to Patricio went unanswered (Patricio only reacted), but Alex has since confirmed the endpoint ownership himself: it's Rumble's.
- Direction stands: run the disambiguation test, then either escalate to Rumble (likely outcome) or trace our provisioning path (only if our side returns `ERR_CHANNEL_TIP_JAR_NOT_FOUND` for minutes).
