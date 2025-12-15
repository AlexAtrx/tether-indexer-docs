## Title

Debug notification not showing after swap in staging

## Description (team chat)

Gohar Grigoryan
12:23 PM
Hey @Usman Khan I swapped from Polygon to BTC and i don’t get any notification, by the way the same issue now I have on the staging while checking V2, can it be that something is broken from BE side?

Alex Atrash
Friday at 2:12 PM
@Gohar Grigoryan you din't have notification until now?
2:13
Polygon indexer sync interval ~15s
Bitcoin indexer sync interval ~10 minutes

Usman Khan
Friday at 2:19 PM
@Gohar Grigoryan so you see the transaction in the transaction history, but don't see the notification?

Alex Atrash
Friday at 2:26 PM
Q1: you din't have notification until now?
Q2: so you see the transaction in the transaction history, but don't see the notification?

Gohar Grigoryan
Friday at 2:27 PM
Q1 yes
Q2 yes
@Alex Atrash when proceeding the swap after confirming I should get a notification related starting swap

Alex Atrash
Friday at 2:41 PM
In staging, in the last 6 hours, I can only see a SWAP_STARTED log of arbitrum.
No Polygon or BTC swaps.
2:42
@Gohar Grigoryan when did you do the swap? Can you check the transaction time?

Gohar Grigoryan
Friday at 2:44 PM
when I wrote this post
2:45
sorry I switch to staging what is why I cannot tell you the exact time
2:45
but right now I can make transaction on staging and see

Alex Atrash
Friday at 2:46 PM
ah!
@Usman Khan I don't have access.
@Gohar Grigoryan well, can you test staging then?
2:47
@Gohar Grigoryan what time did you see it on staging?
2:48
@Usman Khan
The current notification payload doesn't include the destination chain, so we won't be able to distinguish Polygon → BTC from Polygon → anything else based solely on these logs.
I think we need to add that to the logs.

```
[{"line":"2025-12-12T09:34:32: {\"level\":20,\"time\":1765532072872,\"pid\":3599387,\"hostname\":\"walletstg2\",\"name\":\"wrk:http:wrk-data-shard-proc:3599387\",\"traceId\":\"7d671628-04be-4cd8-9578-92f690cb95d1\",\"msg\":\"sendUserNotification: sending notification of type SWAP_STARTED to user p1ynbYRHiIg\"}","timestamp":"1765532073036107683","fields":{"app":"shard-proc-w-1-1","detected_level":"20","env":"staging","filename":"/srv/data/pm2/logs/shard-proc-w-1-1-out.log","host":"walletstg2","job":"pm2","level":"20","pm2_app":"shard-proc-w-1-1","service_name":"shard-proc-w-1-1","stream":"out"}},{"line":"2025-12-12T09:34:32: {\"level\":20,\"time\":1765532072743,\"pid\":3599387,\"hostname\":\"walletstg2\",\"name\":\"wrk:http:wrk-data-shard-proc:3599387\",\"traceId\":\"7d671628-04be-4cd8-9578-92f690cb95d1\",\"msg\":\"sendUserNotification: type=SWAP_STARTED, payload={\\\"toUserId\\\":\\\"p1ynbYRHiIg\\\",\\\"fromUserId\\\":\\\"p1ynbYRHiIg\\\",\\\"token\\\":\\\"usdt\\\",\\\"amount\\\":11.24,\\\"blockchain\\\":\\\"arbitrum\\\"}\"}","timestamp":"1765532072785647928","fields":{"app":"shard-proc-w-1-1","detected_level":"20","env":"staging","filename":"/srv/data/pm2/logs/shard-proc-w-1-1-out.log","host":"walletstg2","job":"pm2","level":"20","pm2_app":"shard-proc-w-1-1","service_name":"shard-proc-w-1-1","stream":"out"}},{"line":"2025-12-12T09:34:32: {\"level\":20,\"time\":1765532072681,\"pid\":3599387,\"hostname\":\"walletstg2\",\"name\":\"wrk:http:wrk-data-shard-proc:3599387\",\"traceId\":\"d31c10dc-4e6e-4415-a06a-1e0572e4638a\",\"msg\":\"sendUserNotification: sending notification of type SWAP_STARTED to user p1ynbYRHiIg\"}","timestamp":"1765532072785562997","fields":{"app":"shard-proc-w-1-1","detected_level":"20","env":"staging","filename":"/srv/data/pm2/logs/shard-proc-w-1-1-out.log","host":"walletstg2","job":"pm2","level":"20","pm2_app":"shard-proc-w-1-1","service_name":"shard-proc-w-1-1","stream":"out"}},{"line":"2025-12-12T09:34:32: {\"level\":20,\"time\":1765532072650,\"pid\":3599387,\"hostname\":\"walletstg2\",\"name\":\"wrk:http:wrk-data-shard-proc:3599387\",\"traceId\":\"d31c10dc-4e6e-4415-a06a-1e0572e4638a\",\"msg\":\"sendUserNotification: type=SWAP_STARTED, payload={\\\"toUserId\\\":\\\"p1ynbYRHiIg\\\",\\\"fromUserId\\\":\\\"p1ynbYRHiIg\\\",\\\"token\\\":\\\"usdt\\\",\\\"amount\\\":11.24,\\\"blockchain\\\":\\\"arbitrum\\\"}\"}","timestamp":"1765532072785530707","fields":{"app":"shard-proc-w-1-1","detected_level":"20","env":"staging","filename":"/srv/data/pm2/logs/shard-proc-w-1-1-out.log","host":"walletstg2","job":"pm2","level":"20","pm2_app":"shard-proc-w-1-1","service_name":"shard-proc-w-1-1","stream":"out"}},{"line":"2025-12-12T09:34:31: {\"level\":30,\"time\":1765532071500,\"pid\":3512431,\"hostname\":\"walletstg1\",\"name\":\"wrk:http:wrk-ork-api:3512431\",\"traceId\":\"7d671628-04be-4cd8-9578-92f690cb95d1\",\"msg\":\"Notification payload info: type - SWAP_STARTED \"}","timestamp":"1765532071627102373","fields":{"app":"ork-w-0-2","detected_level":"30","env":"staging","filename":"/srv/data/pm2/logs/ork-w-0-2-out.log","host":"walletstg1","job":"pm2","level":"30","pm2_app":"ork-w-0-2","service_name":"ork-w-0-2","stream":"out"}},{"line":"2025-12-12T09:34:31: {\"level\":30,\"time\":1765532071465,\"pid\":1278016,\"hostname\":\"walletstg3\",\"name\":\"wrk:http:wrk-node-http:1278016\",\"traceId\":\"7d671628-04be-4cd8-9578-92f690cb95d1\",\"msg\":\"sendNotification payload = {\\\"type\\\":\\\"SWAP_STARTED\\\",\\\"token\\\":\\\"usdt\\\",\\\"amount\\\":11.24,\\\"blockchain\\\":\\\"arbitrum\\\"}\"}","timestamp":"1765532071480243020","fields":{"app":"app-3000","detected_level":"30","env":"staging","filename":"/srv/data/pm2/logs/app-3000-out.log","host":"walletstg3","job":"pm2","level":"30","pm2_app":"app-3000","service_name":"app-3000","stream":"out"}},{"line":"2025-12-12T09:34:31: {\"level\":30,\"time\":1765532071153,\"pid\":3512431,\"hostname\":\"walletstg1\",\"name\":\"wrk:http:wrk-ork-api:3512431\",\"traceId\":\"d31c10dc-4e6e-4415-a06a-1e0572e4638a\",\"msg\":\"Notification payload info: type - SWAP_STARTED \"}","timestamp":"1765532071376823834","fields":{"app":"ork-w-0-2","detected_level":"30","env":"staging","filename":"/srv/data/pm2/logs/ork-w-0-2-out.log","host":"walletstg1","job":"pm2","level":"30","pm2_app":"ork-w-0-2","service_name":"ork-w-0-2","stream":"out"}},{"line":"2025-12-12T09:34:31: {\"level\":30,\"time\":1765532071116,\"pid\":1278002,\"hostname\":\"walletstg3\",\"name\":\"wrk:http:wrk-node-http:1278002\",\"traceId\":\"d31c10dc-4e6e-4415-a06a-1e0572e4638a\",\"msg\":\"sendNotification payload = {\\\"type\\\":\\\"SWAP_STARTED\\\",\\\"token\\\":\\\"usdt\\\",\\\"amount\\\":11.24,\\\"blockchain\\\":\\\"arbitrum\\\"}\"}","timestamp":"1765532071308191541","fields":{"app":"app-3001","detected_level":"30","env":"staging","filename":"/srv/data/pm2/logs/app-3001-out.log","host":"walletstg3","job":"pm2","level":"30","pm2_app":"app-3001","service_name":"app-3001","stream":"out"}}]
```

Gohar Grigoryan
Friday at 2:48 PM
right now
2:48
from Arb-BTC

Alex Atrash
Friday at 2:49 PM
BTC takes 10 mins (max) (edited)

Gohar Grigoryan
Friday at 2:49 PM
noo
2:49
we are mixing
2:51
when the swap is complete and it is appears in ongoing we getting notification related to started swap
2:51
when the swapping is done we getting another notification that the swap is completed

Alex Atrash
Friday at 2:54 PM
ok
2:58
There is no SWAP_STARTED in staging log in the last hour
2:59
Unless i'm doing it wrong @Usman Khan please help if so.

## Conclusion

- We had an issue where the notification were sent twice or more for the same swap. We fixed it in a few PRs like:
  https://github.com/tetherto/wdk-data-shard-wrk/pull/122
  https://github.com/tetherto/rumble-app-node/pull/94
  https://github.com/tetherto/rumble-data-shard-wrk/pull/104
  https://github.com/tetherto/rumble-ork-wrk/pull/63
  (check the merged PRs to see what we did to fix the buplicate notifications issue).

- It looks like (maybe) this fix started blocking notifications for completed swaps. Or maybe not. This needs to be investigated.

- Don't change code. Just debug and find the root cause.
