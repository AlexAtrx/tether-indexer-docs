## 1215465601624117-img_4497.png

**Source comment:** Task description (reporter: Mariia Nikolaichuk)

**What it shows:** iOS wallet app full-screen error state after returning from background.

**Key content:**
- Heading: **"Authentication Failed"**
- Body text: **"Biometric authentication failed. Please try again."**
- Single green CTA button: **"Try Again"**
- Status bar time **15:10** (matches reported timestamp 15:10 CET), iOS, silent-mode bell, full signal, battery low (~15%).
- No Face ID / passcode system prompt visible — this is the app's own error screen, not the OS biometric sheet.

**Relevance:** This is the app-rendered biometric-auth failure screen the user hits on foregrounding. The copy ("Biometric authentication failed") points at the local-auth / Face ID re-prompt path on app resume, not at a backend auth (login/session) failure. Tapping "Try Again" restored the wallet, so the underlying session/credentials were intact — the failure is in the biometric re-auth gate fired on foreground transition.
