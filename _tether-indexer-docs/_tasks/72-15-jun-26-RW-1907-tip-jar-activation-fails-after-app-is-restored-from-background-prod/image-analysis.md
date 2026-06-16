# Image analysis for [Tip Jar] Activation fails after app is restored from background - Prod

## IMG_0992.jpg

**Source comment:** Gocha Gafrindashvili / 2026-06-15T08:15:36.010Z attachment

**What it shows:** TestFlight/Rumble Wallet Tip Jars settings screen after restoring the app, with two red error toasts over the Tip Jars list.

**Key content:**
- Status bar shows `TestFlight`, time `12:13`, `5G`, and low battery (`20`).
- First toast: `Could not activate ggaph...ili's Tip Jar` for `ggaphrindashvili's Tip Jar` (`12 followers`), whose toggle is off.
- Second toast: `Could not deactivate Cattsssss Tip Jar` for `Cattsssss` (`1 follower`), whose toggle is on.
- Settings screen shows `App Version v2.4.0(207)`.

**Relevance:** Confirms the ticket's reported failure mode: Tip Jar activation/deactivation actions surface client-visible errors in the Tip Jars settings flow after the app has been restored from background.
