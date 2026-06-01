# Slack thread — Ahsan's root-cause findings

**Channel:** #wallet-rumble-dev (`C0A5DFYRNBB`), Tether workspace
**Permalink:** https://tether-to.slack.com/archives/C0A5DFYRNBB/p1779832928081659
**Web link:** https://app.slack.com/client/T05MWQT2W20/C0A5DFYRNBB/thread/C0A5DFYRNBB-1779832928.081659
**Captured:** 2026-05-29 (via browser, from Alex's signed-in Slack)

> **Security note:** Ahsan's root message also posted a **test-account username/password and a 12-word recovery seed phrase** in plaintext. Those have been **redacted** here on purpose — do not store seeds/passwords in the repo. If you need them, open the Slack thread directly. Flag to the team that they should be scrubbed from Slack and that test account rotated.

---

## Root message — Ahsan Akhtar, Wed 12:02 AM

@Alex @Francesco C. While investigating the ticket *[Tip Jars] Renamed Tip Jars display outdated names in Seed Phrase mode*:

- The issue is on **BE**, with the endpoint `api/v1/seed-phrases/connect/verify`. This endpoint is **not sending the updated data**. It's hit when you log in with a seed phrase and wallets are fetched for that seed-phrase user.
- On **rumble web (staging)** he renamed the tip jars (`AAAA1channel` → `BBBB1channel`, and `AAA2channel` → `BBB2channel`), but the new names are **not returned** by `api/v1/seed-phrases/connect/verify` — it still returns the outdated `AAAA1channel` and `AAA2channel` (see the JSON in the reply below).

**User Credentials:** *(redacted — test account login + recovery seed phrase were posted here; see Slack)*

cc: @Gocha Gafrindashvili @Eddy WM

**Note:** This issue is **only** with seed-phrase login. With the rumble username/password login, the app always gets fresh tip-jar names because it uses a different endpoint — `wallet/v1/channels` — which always returns fresh data with updated tip-jar names.

---

## Reply 1 — Ahsan Akhtar, Wed 12:02 AM (response payload from `seed-phrases/connect/verify`)

Evidence that the verify endpoint returns stale names — note `AAAA1channel` / `AAA2channel` are the **pre-rename** names (should be `BBBB1channel` / `BBB2channel`):

```json
[
  { "id": "a68711eb-9d59-4550-9e16-12d5c3316585", "type": "channel",   "name": "TipJarkartofili",                                                              "channelId": "qVsn9J3GD-0", "userId": "ag5ezVDrcxU", "accountIndex": 100 },
  { "id": "7d2dbbfb-1566-40df-8251-a74cbf7e2955", "type": "channel",   "name": "3channel3channel3channel3channel3channel3channel3channel3channel3channel3channel3channel3channel3channel3channel3channel3channel3channel3channel3channel3channel3channel tip jar", "channelId": "ZSqKEdXK9Ao", "userId": "ag5ezVDrcxU", "accountIndex": 103 },
  { "id": "1732e9f8-49a1-4f81-9dae-80920aeebbcc", "type": "channel",   "name": "4channel",        "channelId": "3JHtt9QNh_I", "userId": "ag5ezVDrcxU", "accountIndex": 104 },
  { "id": "2f0aca3c-8803-492e-9d32-a0d525fd8534", "type": "channel",   "name": "5channel",        "channelId": "GlHlmxNsaxU", "userId": "ag5ezVDrcxU", "accountIndex": 105 },
  { "id": "5481deab-b99b-4c7c-b9be-bb0dd918d747", "type": "unrelated", "name": "kartofili wallet", "userId": "ag5ezVDrcxU", "accountIndex": 115 },
  { "id": "2adbf052-e987-48e5-9d24-82e2b300ce03", "type": "user",      "name": "kartofili tip jar","userId": "ag5ezVDrcxU", "accountIndex": 10 },
  { "id": "7305dab2-86b8-4cf5-b887-bf77d0901bce", "type": "channel",   "name": "AAAA1channel",     "channelId": "GKBS4V9zj8E", "userId": "ag5ezVDrcxU", "accountIndex": 101 },
  { "id": "91b35cbb-4241-456d-9d7c-4e0b6141db2a", "type": "channel",   "name": "AAA2channel",      "channelId": "A-Nzi0vahC0", "userId": "ag5ezVDrcxU", "accountIndex": 102 },
  { "id": "d2534f45-dcbc-408e-b452-5d1c4e49b306", "type": "channel",   "name": "6chann",          "channelId": "kDrpdFEd7T4", "userId": "ag5ezVDrcxU", "accountIndex": 106 },
  { "id": "77712225-e3e4-4b8d-bd93-ff72d05ffef8", "type": "channel",   "name": "7channel",        "channelId": "LhjgHyIViKU", "userId": "ag5ezVDrcxU", "accountIndex": 107 },
  { "id": "2ea6d8d1-01d3-4aa6-8e2f-1a01e1244ac2", "type": "channel",   "name": "8channel",        "channelId": "lXeh8vC07CI", "userId": "ag5ezVDrcxU", "accountIndex": 108 },
  { "id": "1162de3c-4ac1-49f7-93dd-8b5b59483e2f", "type": "channel",   "name": "9channel",        "channelId": "XrAHcJdT7hQ", "userId": "ag5ezVDrcxU", "accountIndex": 109 },
  { "id": "e6c69077-e30c-463a-80dc-6fe2a0808221", "type": "channel",   "name": "10channel",       "channelId": "LCk7XL-zWIU", "userId": "ag5ezVDrcxU", "accountIndex": 110 },
  { "id": "282e46a3-33d8-4df0-9034-fe8cf5125c15", "type": "channel",   "name": "11channel",       "channelId": "-QLSLRti2vU", "userId": "ag5ezVDrcxU", "accountIndex": 111 },
  { "id": "fb746fa3-dff9-4754-b8c7-8234fb7e32a3", "type": "channel",   "name": "Switchedtest11",  "channelId": "ClXfKCv4nnM", "userId": "ag5ezVDrcxU", "accountIndex": 112 },
  { "id": "cd6c64aa-44c2-4c12-bd7a-0e675d352f42", "type": "channel",   "name": "switchertest12",  "channelId": "Xfg-oGSfgS8", "userId": "ag5ezVDrcxU", "accountIndex": 113 },
  { "id": "5b1e53be-3425-42f7-95aa-2a09b17d503c", "type": "channel",   "name": "Switchedtest",    "channelId": "tuHFNA6gccY", "userId": "ag5ezVDrcxU", "accountIndex": 114 },
  { "id": "037162b8-e29b-4c88-abcc-a4e552477713", "type": "channel",   "name": "Febr2",           "channelId": "kJMyi4CeYFc", "userId": "ag5ezVDrcxU", "accountIndex": 116 },
  { "id": "6fba7f0c-8e9d-4c4f-ac52-2c0aaff78045", "type": "channel",   "name": "newchannel111ss", "channelId": "LcrytsYOTWY", "userId": "ag5ezVDrcxU", "accountIndex": 117 },
  { "id": "f507e4be-2046-4290-b411-063b89f2c2aa", "type": "unrelated", "name": "Local Wallet",    "userId": "ag5ezVDrcxU", "accountIndex": 0 }
]
```

---

## Reply 2 — Alex (you), Yesterday 11:33 AM

@Ahsan Akhtar
- `/api/v1/seed-phrases/connect/verify` returns wallet rows from our stored WDK wallet data, **including the stored name**.
- It does **not** fetch/merge current channel metadata from Rumble, so if a channel is renamed on Rumble, this endpoint can still return the old tip-jar name.
- The regular username/password flow looks correct because it also uses `/wallet/v1/channels`, which returns the fresh channel names.

Proposed BE fix — one of:
1. Keep wallet tip-jar names in sync when Rumble channel names change, **or**
2. Add the current channel names to the response of seed-phrase verify before returning wallets.

cc: @Francesco C. @Eddy WM — opinion?
