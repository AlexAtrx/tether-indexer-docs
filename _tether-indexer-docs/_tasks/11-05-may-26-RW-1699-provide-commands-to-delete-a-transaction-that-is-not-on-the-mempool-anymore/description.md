# Description

(Pasted Slack thread between Andrei and Francesco — original chat presumably in Rumble Slack.)

> **Andrei  [7:31 PM]**
> Hey Francesco, do you know what this error is? I'm seeing a lot of them
>
> ```
> "errorCode":"ERR_GET_TX_FROM_CHAIN_FAILED","err":{"type":"Error","message":"[HRPC_ERR]=No such mempool or blockchain transaction. Use gettransaction for wallet transactions."
> ```
>
> **[8:35 PM]**
> `Get transaction from chain failed`
>
> it's the same hash
>
> **[8:35 PM]**
> `86e0c91ed20fccebf415f1fd201ba066549094fde793235818cc7cc335109e4a`
>
> **[8:36 PM]**
> tx not found https://mempool.space/tx/86e0c91ed20fccebf415f1fd201ba066549094fde793235818cc7cc335109e4a
>
> **[8:36 PM]**
> maybe it was underpriced and it went out of the mempool
>
> **[8:37 PM]**
> we need to delete it and also have a fix to stop checking for it after some number of retries / time
>
> **Andrei  [8:37 PM]**
> how do we safely delete it?
>
> **Francesco C.  [8:39 PM]**
> I don't know on top of my head, I would need to check myself or with the team

---

Please @Alex Atrash provide the command for Andrei to execute in production to delete one pending transaction.

---

## LOGS

```
2026-05-04 20:34:23.375
{"level":30,"time":1777919663375,"pid":2816790,"hostname":"tether-wallet-stg-0.c.tether-data-open-wdk.internal","name":"wrk-processor-indexer-w-0-16-polygon-usdt-8a65e839-2324-4ab8-870f-e68c43eed8f1","msg":"finished processing 100 new messages"}

2026-05-04 20:34:23.365
{"level":30,"time":1777919663365,"pid":2813662,"hostname":"tether-wallet-stg-0.c.tether-data-open-wdk.internal","name":"wrk-processor-indexer-w-0-17-polygon-usdt-e5fbe54a-eed1-4307-a0f6-78455627e66e","msg":"finished processing 100 new messages"}

2026-05-04 20:34:22.061
{"level":30,"time":1777919662061,"pid":2813490,"hostname":"tether-wallet-stg-0.c.tether-data-open-wdk.internal","name":"wrk-processor-indexer-w-0-9-arbitrum-usdt-8f975e00-b996-47ac-896e-e04d556c363f","msg":"finished processing 51 new messages"}

2026-05-04 20:34:21.329
{"level":30,"time":1777919661329,"pid":2813563,"hostname":"tether-wallet-stg-0.c.tether-data-open-wdk.internal","name":"wrk-processor-indexer-w-0-12-plasma-usdt-e94c9b73-558c-403a-8a70-4bc10b08fd97","msg":"finished processing 46 new messages"}

2026-05-04 20:34:21.039
{"level":30,"time":1777919661039,"pid":2813723,"hostname":"tether-wallet-stg-0.c.tether-data-open-wdk.internal","name":"wrk-processor-indexer-w-0-20-spark-btc-3c65af61-b2e3-4103-b90c-6c4e4231a738","msg":"finished processing 1 new messages"}

2026-05-04 20:34:20.728
{"level":30,"time":1777919660728,"pid":2813741,"hostname":"tether-wallet-stg-0.c.tether-data-open-wdk.internal","name":"wrk-processor-indexer-w-0-21-spark-btc-322370af-66fe-4462-a5df-ca1c0097f79d","msg":"finished processing 1 new messages"}

2026-05-04 20:34:20.725
{"level":30,"time":1777919660725,"pid":2813723,"hostname":"tether-wallet-stg-0.c.tether-data-open-wdk.internal","name":"wrk-processor-indexer-w-0-20-spark-btc-3c65af61-b2e3-4103-b90c-6c4e4231a738","msg":"finished processing 1 new messages"}

2026-05-04 20:34:20.634
{"level":30,"time":1777919660634,"pid":2814147,"hostname":"tether-wallet-stg-0.c.tether-data-open-wdk.internal","name":"wrk-erc20-indexer-proc-w-0-xaut-arb-eb5453e6-046f-486d-83be-a7eadefc9f6c","msg":"finished processing blocks 459380062-459380081, 2026-05-04T18:34:20.634Z"}

2026-05-04 20:34:20.414
{"level":30,"time":1777919660414,"pid":2814423,"hostname":"tether-wallet-stg-0.c.tether-data-open-wdk.internal","name":"wrk-spark-indexer-proc-w-0-spark-d45a9795-aa40-42f8-a125-e3f501c5d968","msg":"[sync-tx] finished syncing block range, last block #1777919657170 (2026-05-04T18:34:17.170Z), 2026-05-04T18:34:20.414Z"}
```
