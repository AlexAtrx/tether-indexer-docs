# Comments — [Send] Max unavailable for XAUT with enough balance

Chronological (oldest first). System stories included where they carry triage signal.

---

**2026-05-08 13:23 — Mariia Nikolaichuk** *(system)*
Priority set to High; task assigned to Eddy WM.

**2026-05-08 14:22 — Mariia Nikolaichuk** *(system, mentioned)*
Mentioned this task in another task: "[Send] Unable to send XAUT send button disabled, no error/info message shown".

---

**2026-05-18 20:09 — Ahsan Akhtar** *(system)*
Reassigned task to himself; moved "To Triage" → "In-Progress".

**2026-05-18 22:58 — Ahsan Akhtar** *(comment)*
> @Mariia Nikolaichuk I've investigated this ticket in detail but couldn't reproduce this issue (**attaching a video here**). I tried with 'masharumble' account on prod and even tried the exact same steps as you have shown in your video but I was able to see and use the **Max** button fine ('*Max unavailable*' button didn't appear when I tried to scan the same XAUT address to send XAUT from the tip jar). Can you test it again?

*(attachment: `Screen_recording_20260519_025047.mp4`)*

**2026-05-18 22:59 — Ahsan Akhtar** *(comment)*
> cc: @Eddy WM

**2026-05-18 22:59 — Ahsan Akhtar** *(system)*
Moved "In-Progress" → "Ready for QA".

---

**2026-05-19 15:36 — Ahsan Akhtar** *(comment)*
> @Eddy WM Okay I've installed the [prod app](https://play.google.com/apps/internaltest/4700432386751456399) on my phone! And I can reproduce the issue (*max unavailable* button) with `masharumble` user in that only.

*(inline image: `image.png` — the "Max unavailable" state for Tether Gold/XAUT)*

**2026-05-19 15:48 — Ahsan Akhtar** *(comment)*
> @Eddy WM But it works fine for me when I build and run it locally to debug it. I am sharing another screen recording I did just now where I cannot reproduce this issue when I run locally!
>
> **My question is how could I debug it now?** It seems to me a BE error as nothing is changed from FE in both cases!

*(attachment: `Screen_recording_20260519_203805.mp4`)*

**2026-05-19 22:16 — Ahsan Akhtar** *(comment)*
> discussed with BE team here:
> https://tether-to.slack.com/archives/C0A5DFYRNBB/p1779228490793649

**2026-05-19 23:28 — Ahsan Akhtar** *(comment)*
> logs added to track **Max unavailable** case in fee preload while sending XAUT in prod in this PR:
> https://github.com/tetherto/rumble-wallet-app-mobile/pull/1185

**2026-05-19 23:32 — Ahsan Akhtar** *(system)*
Moved "Ready for QA" → "In Review".

---

**2026-05-20 20:35 — Ahsan Akhtar** *(system)*
Sprint set to Sprint 2.

---

**2026-05-27 12:25 — Mohamed Elsabry** *(system)*
Sprint changed Sprint 2 → Sprint 2, Sprint 3.

**2026-05-27 12:57 — Ahsan Akhtar** *(system)*
Changed the description.

**2026-05-27 13:21 — Ahsan Akhtar** *(comment)*
> I tested again on [prod app](https://play.google.com/apps/internaltest/4700432386751456399) just now, and looks like this issue of **Max unavailable** is not appearing anymore from `candide/paymaster`.
> Fee estimation works fine and **Max** button appears fine after I scan the QR and select XAUT from the tokens. I'm sharing a video recording of it here!
> @Mariia Nikolaichuk I tested with your user `masharumble`. So, can you test again and confirm if **Max unavailable** is not appearing anymore for you as well?
> cc: @Eddy WM

*(attachment: `Screen_recording_20260527_181205.mp4`)*

**2026-05-27 13:22 — Ahsan Akhtar** *(system)*
Moved "In Review" → "Ready for QA".
