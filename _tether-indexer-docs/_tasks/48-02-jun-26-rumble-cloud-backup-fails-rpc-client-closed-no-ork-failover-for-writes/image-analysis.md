# Image analysis

`images/backup-failed-screenshot.png` - mobile wallet, staging build (the "S"
badge and bug icon in the top-left are the staging/debug overlay).

Screen: "Backup Your Wallet" -> "Choose how to back up your wallet", showing
the Cloud Backup / Manual Backup options. A bottom sheet titled **"Backup
Failed"** is open with body text:

```
[HRPC_ERR]=RPC client closed
```

and two buttons, **Try Again** and **Skip**. Time on device 11:47.

This is the raw backend HRPC error rendered directly in the failure sheet,
which is what tied the symptom to the `storeEntropy` / `storeSeed` write path.
See `root-cause.md`.
