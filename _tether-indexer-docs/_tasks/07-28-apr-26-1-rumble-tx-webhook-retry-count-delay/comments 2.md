# Comments

Chronological, oldest to newest. System events included only where they carry signal.

---

**2026-02-23T11:59:15Z — Gohar Grigoryan** _(system / assigned)_

Assigned to Patricio Vicens.

---

**2026-02-24T13:26:28Z — Patricio Vicens** _(comment)_

> If you are creating the user from the web it's most likely a Rumble thing. I can't do much there. https://app.asana.com/1/45238840754660/profile/1210223164593225 Might also want to check with our backend team in case they can do something about it.

---

**2026-02-24T17:07:12Z — Gohar Grigoryan** _(comment)_

> https://app.asana.com/1/45238840754660/profile/1212219485201948 I checked with Rumble, Andrei said that on the Rumble appearing tip button can take 10 minutes, anyway right now the button appears on web but send tip remains not active in the app nearly 10 or more minutes.

---

**2026-02-24T17:09:06Z — Gohar Grigoryan** _(comment)_

> I compared with V1, the button becomes active very quickly.

---

**2026-02-25T17:47:02Z — Patricio Vicens** _(comment)_

> @Gohar if you pull to refresh does the button update?

---

**2026-02-25T18:22:12Z — Gohar Grigoryan** _(comment)_

> no

---

**2026-02-25T19:16:40Z — Patricio Vicens** _(system / section_changed)_

Moved from "To Triage" to "In Review".

---

**2026-02-25T19:41:06Z — Patricio Vicens** _(comment)_

> We get the address from `/wallet/v1/address-book` and that isn't returning the proper `tipping_enabled` updated boolean. So seems more like an API issue.

---

**2026-02-25T19:45:19Z — Gohar Grigoryan** _(comment)_

> @Ignacio @Mohamed (mentions only)

---

**2026-02-26T11:26:27Z — Patricio Vicens** _(system / section_changed)_

Moved from "In Review" to "Ready for QA".

---

**2026-02-27T19:42:29Z — Gohar Grigoryan** _(comment)_

> I still can reproduce it.

---

**2026-02-27T19:42:54Z — Gohar Grigoryan** _(system / attachment_added)_

Attached `1000002629.mp4`.

---

**2026-02-27T19:42:56Z — Gohar Grigoryan** _(system / assigned)_

Reassigned to Patricio Vicens. Moved back to "In-Progress".

---

**2026-04-08T14:43:26Z — Eddy WM** _(system / assigned)_

Assigned to Patricio Vicens.

---

**2026-04-08T17:17:10Z — Patricio Vicens** _(comment)_

> Reassigning to BE team. If you guys need a hand to test anything lmk! But basically after tapping follow there's a delay from what the APIs mentioned above return, after a while they properly return the boolean as true.

---

**2026-04-08T17:17:16Z — Patricio Vicens** _(system / assigned)_

Reassigned to Alex Atrash (backend).

---

**2026-04-15T13:58:25Z — Eddy WM** _(system / name_changed)_

Renamed to "[Bckend - Tip jar] Tip button doesn't appear on the Rumble and Send Tip button is inactive after following the channel, user".

---

**2026-04-20T11:09:30Z — Alex Atrash** _(comment)_

> Hey @Patricio Vicens — can you please confirm if the endpoint you're calling (`/wallet/v1/address-book`) this on our wallet backend or the Rumble backend?

---

**2026-04-20T12:38:00Z — Patricio Vicens** _(system / story_reaction_added)_

Reacted to Alex's question — no textual reply.

---

**2026-04-28T10:32:25Z — Eddy WM** _(system / multi_enum_custom_field_changed)_

Changed Sprint to **Sprint 1**.

---

**2026-04-28 — Alex Atrash** _(out-of-band confirmation, recorded here)_

Confirmed verbally that `/wallet/v1/address-book` is served by **Rumble's API**, not our wallet backend. Matches the local code-grep result in `findings.md` (zero matches across every `_INDEXER/` repo). Implication: the stale `tipping_enabled=false` is a Rumble-side propagation issue; we cannot fix it in the indexer / wallet-backend.
