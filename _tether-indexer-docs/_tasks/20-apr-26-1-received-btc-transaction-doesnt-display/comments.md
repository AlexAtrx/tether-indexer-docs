# Comments and key system events

## 2026-03-18T09:25 — andrey.gilyov@itrexgroup.com (system: added_to_project)
Added to Rumble Wallet V3.

## 2026-03-18T09:30 — andrey.gilyov@itrexgroup.com (system: assigned)
Assigned to Ahsan Akhtar.

## 2026-03-18T18:38 — Ahsan Akhtar (comment)
> andrey.gilyov@itrexgroup.com I have investigated this issue while using your user you've mentioned in this ticket, I found out that actually BE is not sending the transactions in BTC Holdings screen when `token` query parameter is sent as `BTC` for your user, so it appears there is some issue on BE with `token-transfers` endpoint (it's not sending the tx you're expecting), so I believe you have to escalate to BE team by providing your user!

## 2026-03-18T19:03 — andrey.gilyov@itrexgroup.com (system: unassigned / assigned)
Unassigned Ahsan Akhtar, re-assigned to Usman Khan.

## 2026-03-19T07:29 — Usman Khan (comment)
> andrey.gilyov@itrexgroup.com, I can see that for this particular user, we have just 1 wallet created on March 16th. Wallets endpoint returns:
>
> ```json
> {
>   "wallets": [
>     {
>       "id": "3efa0461-b62d-4629-bc1c-1346bb204d1e",
>       "type": "unrelated",
>       "userId": "pagZrxLHnhU",
>       "name": "klemensqwerty",
>       "accountIndex": 0,
>       "addresses": {
>         "ethereum": "0x0466e9233ca36ecf701a7d3ebc8075def8e7c274",
>         "bitcoin": "bc1qh7ehdzkh49lhxt5rz6ysckle76ercevsv2ujwc",
>         "polygon": "0x0466e9233ca36ecf701a7d3ebc8075def8e7c274",
>         "arbitrum": "0x0466e9233ca36ecf701a7d3ebc8075def8e7c274",
>         "plasma": "0x0466e9233ca36ecf701a7d3ebc8075def8e7c274",
>         "spark": "spark1pgssxfensumhna2rf3jvxnky9t0mzfaysf2kukhadm85eq54lh993x35cwsluk"
>       },
>       "enabled": true,
>       "createdAt": 1773687758473,
>       "updatedAt": 1773687759226,
>       "meta": {
>         "spark": {
>           "sparkIdentityKey": "0x032733873779f5434c64c34ec42adfb127a482556e5afd6ecf4c8295fdca589a34",
>           "sparkDepositAddress": "bc1pct6hc86kpac42kszzykmafjhhlt49g3wwv3x7l4x4rwvy297af0s367e9a"
>         }
>       }
>     }
>   ]
> }
> ```
>
> Furthermore, this wallet's bitcoin address doesn't display any transactions on the blockchain explorer: https://www.blockchain.com/explorer/addresses/btc/bc1qh7ehdzkh49lhxt5rz6ysckle76ercevsv2ujwc
>
> So it seems to me that this account doesn't have any bitcoin transactions associated with it. Secondly, I am wondering why this user has only 1 wallet. Shouldn't user have 1 unrelated wallet and 1 user wallet at least, or is this the expected behaviour?

## 2026-03-19T08:33 — Usman Khan (system: section_changed)
Moved "To Triage" → "In-Progress".

## 2026-03-19T10:25 — andrey.gilyov@itrexgroup.com (comment)
> @Usman Khan In the wallet, I see another address https://www.blockchain.com/explorer/addresses/btc/bc1qgm7k56yqdzzn30vzzxrjnle6nkdn2wgt0m9ph2

## 2026-03-19T12:24 — Usman Khan (comment)
> andrey.gilyov@itrexgroup.com are you experiencing this issue on the staging or prod environment?

## 2026-03-19T12:31 — andrey.gilyov@itrexgroup.com (comment)
> @Usman Khan staging environment

## 2026-03-19T12:47 — Usman Khan (comment)
> These are the wallets returned by the backend on the staging environment for this user. I still don't see the address you shared or any of the addresses involved in the transaction hash that you shared: `f0fcd10294218e84b06e457e3fd740ca70188d84944e45e4aba43a59c2b10d95`. Are we sure that the user is correct?
>
> ```json
> {
>   "wallets": [
>     {
>       "id": "95f4b950-3601-4ebc-9387-225377d72a28",
>       "addresses": {
>         "ethereum": "0x3b9d549e59e3003dd1d17a7f10f4c542d1d9aba1",
>         "arbitrum": "0x3b9d549e59e3003dd1d17a7f10f4c542d1d9aba1",
>         "bitcoin": "bc1pu036lhtmx7ny9ztzcj5twg4sehaxgxsnjj3hgcg5zl9p95zn7wusygetkd",
>         "spark": "spark1pgss9glc4l5p689ryldm09c00cxg6cdcjk3uj4tngfq6hcllmnw6wyuceyclhp",
>         "polygon": "0x3b9d549e59e3003dd1d17a7f10f4c542d1d9aba1",
>         "plasma": "0x3b9d549e59e3003dd1d17a7f10f4c542d1d9aba1"
>       },
>       "createdAt": 1767985547939,
>       "enabled": false,
>       "name": "klemensqwerty",
>       "type": "unrelated",
>       "updatedAt": 1771579889595,
>       "userId": "pagZrxLHnhU",
>       "meta": {
>         "spark": {
>           "sparkIdentityKey": "0x02a3f8afe81d1ca327dbb7970f7e0c8d61b895a3c955734241abe3ffdcdda71398",
>           "sparkDepositAddress": "bc1parpw4p487ea33gq2n7fqz27agw7xt9f4dgf6r2hq8lkkvsd90sls522s9q"
>         }
>       },
>       "accountIndex": 0
>     },
>     {
>       "id": "4e3f7bb3-b525-44dd-a903-83bd9710e740",
>       "addresses": {
>         "ethereum": "0x50790ab2bca322dd0e91c1e41ce978af259439ee",
>         "arbitrum": "0x50790ab2bca322dd0e91c1e41ce978af259439ee",
>         "bitcoin": "bc1p9phkf0wwgjaja5yumfscpd5krqhj5wc9q4e5lldv3qcxc09lakzsvjm4ax",
>         "spark": "spark1pgss890xgdakcajppfh9satftcfwtlwrp2sy4yy9n5f02d0h6s4wasr6etjc48",
>         "polygon": "0x50790ab2bca322dd0e91c1e41ce978af259439ee",
>         "plasma": "0x50790ab2bca322dd0e91c1e41ce978af259439ee"
>       },
>       "createdAt": 1768213410518,
>       "enabled": true,
>       "name": "klemensqwerty",
>       "type": "user",
>       "updatedAt": 1773759994233,
>       "userId": "pagZrxLHnhU",
>       "meta": {
>         "spark": {
>           "sparkIdentityKey": "0x0395e6437b6c76410a6e5875695e12e5fdc30aa04a90859d12f535f7d42aeec07a",
>           "sparkDepositAddress": "bc1p22zsl9wjpt4ruumy37g0jrqg2dd3e8sy380d48l5pzre5e8q26msvz8esz"
>         }
>       },
>       "accountIndex": 1
>     }
>   ]
> }
> ```

## 2026-03-19T13:41 — andrey.gilyov@itrexgroup.com (comment)
> **Sent Address**: `bc1qqfr4t0d9nraxfk7xgk7qd7sg6vq7flsaljk6kp`
> **Recipient Address**: `bc1qgm7k56yqdzzn30vzzxrjnle6nkdn2wgt0m9ph2`
> **Crypto Amount**: 0.00021337 BTC
> **USD Amount**: $15.82
> **Date/Time**: Mar 18, 2026 · 11:10
> **Status**: confirmed
> **Link**: https://mempool.space/tx/f0fcd10294218e84b06e457e3fd740ca70188d84944e45e4aba43a59c2b10d95
> **Transaction id**: `f0fcd10294218e84b06e457e3fd740ca70188d84944e45e4aba43a59c2b10d95`
>
> I see the transaction history in Sender, but don't see the transaction in Recipient.

## 2026-03-23T14:22 — Mohamed Elsabry (system: enum_custom_field_changed)
Changed Fix Version (FE) to RW 2.0.3.

## 2026-03-24T12:42 — Mohamed Elsabry (system: assigned)
Assigned to Alex Atrash.

## 2026-04-01T11:37 — Eddy WM (system: section_changed)
Moved "In-Progress" → "Ready for QA".

## 2026-04-02T14:27 — Alex Atrash (comment)
> Analysis: https://tether-to.slack.com/archives/C0A5DFYRNBB/p1775069742706779

## 2026-04-02T15:00 — Alex Atrash (comment)
> andrey.gilyov@itrexgroup.com
> Like Usman said, we have no trace of this address in the backend.
> We need to know how the user got the address `bc1qgm7k56yqdzzn30vzzxrjnle6nkdn2wgt0m9ph2`?

## 2026-04-06T12:15 — andrey.gilyov@itrexgroup.com (comment)
> @Alex Atrash could you try to use my credentials for see it on the staging?

## 2026-04-06T14:23 — andrey.gilyov@itrexgroup.com (comment, attachments added)
Empty body. Attached `rumble-wallet-2026-04-06.log` and `screen-20260406-172125-1775485270371.mp4` (see `attachments/`).

## 2026-04-06T14:23 — andrey.gilyov@itrexgroup.com (system: section_changed)
Moved "Ready for QA" → "In-Progress".

## 2026-04-09T11:10 — Eddy WM (comment)
> @Alex Atrash @Usman Khan
>
> What have we decided about this ticket? It seems like an extreme rare case for a user to have had this address added.
>
> Is it something that can be resolved on the backend?

## 2026-04-09T11:15 — Alex Atrash (comment)
> @Eddy WM
> This links to two other tickets that are under progress. One of which https://app.asana.com/1/45238840754660/project/1212521145936484/task/1213680013630981?focus=true. We are working on it.

## 2026-04-15T06:13 — Eddy WM (system: multi_enum_custom_field_changed)
Changed Stack from "FE - frontend" to "BE - Backend".

## 2026-04-15T13:34 — Eddy WM (system: name_changed)
Renamed to `[Backend - Transactions] Received BTC transaction doesn't display`.

## 2026-04-16T13:38 — Eddy WM (system: enum_custom_field_changed)
Priority changed Critical → High.

## 2026-04-16T13:39 — Eddy WM (comment)
> The priority level for this item is changed to now high, since this is mainly a backend related item that affects only one user, and can be fixed on the backend without any change on the app.

## 2026-04-20T10:24 — Alex Atrash (comment)
> Hey @Eddy WM
> The decisive open question is where the FE gets `bc1qgm7k56yqdzzn30vzzxrjnle6nkdn2wgt0m9ph2` from, since `/wallets` doesn't contain it? Is there a way to know that?
> The log we have is from the exact session where the video shows the FE serving that address via the Receive flow. So the network call that populated the QR code is almost certainly in there.
> The address `bc1qgm7k56…` does not appear anywhere in the log. Not in any WalletAPI, RumbleAPI, or other response. No endpoint returned it during the session.
> From the logs, the mobile app is not getting `bc1qgm7k56…` from a backend endpoint at all. It's coming from client-local state.

## 2026-04-20T10:37 — Alex Atrash (comment)
> @Eddy WM
> You guys need to do these 2 in-repo investigations:
> 1. In the mobile repo, find the component behind `[QRCodeDisplay]` and trace which store supplies the bitcoin address it renders.
> 2. Grep the same repo for `bc1q` / `p2wpkh` / segwit address derivation. The `/wallets` endpoint hands back taproot (`bc1p`), but the Receive flow is clearly still producing segwit. That split is the bug.

## 2026-04-20T11:05 — Eddy WM (comment)
> My assumption here is this wallet might have been created long time ago, and possibly a very old in the address generation on wdk side since nobody else has been able to reproduce this issue in another (new) wallet
