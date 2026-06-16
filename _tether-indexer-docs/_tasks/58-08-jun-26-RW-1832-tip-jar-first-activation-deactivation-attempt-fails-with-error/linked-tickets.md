# Linked tickets

## RW-1907 — Tip Jar activation fails after app is restored from background

- **Local folder:** ../72-15-jun-26-RW-1907-tip-jar-activation-fails-after-app-is-restored-from-background-prod/
- **Asana:** https://app.asana.com/1/45238840754660/project/1212521145936484/task/1215639503643719
- **Relationship:** RW-1907 is the newer production/background reproduction of the same Tip Jar activation/deactivation failure class. Asana story `1215664418408369` on RW-1907 records that it was mentioned from this RW-1832 task.
- **Why it matters:** RW-1907 has current v2.4.0(207) production evidence, while this RW-1832 folder has the stronger logs and prior root-cause analysis around first HRPC calls returning `[HRPC_ERR]=RPC client closed`.
- **Useful local notes:** `production-evidence-2026-06-11.md` already connects the background-restore report back to the RW-1832 investigation and should be read before debugging RW-1907.
