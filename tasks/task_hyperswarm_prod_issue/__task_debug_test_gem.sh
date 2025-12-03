Read the important parts of the assure and handling in this folder _docs/task_hyperswarm_prod_issue. 

This is a test. I'm running five times _docs/task_hyperswarm_prod_issue/_run_the_test_repeat.sh. 

Conclude what exactly I want to repeat from _docs/task_hyperswarm_prod_issue/NEXT_STEPS.md. 

So far I'm failing to reproduce the mentioned error "Pool was force destroyed". 

I'm told that the error should show in terminal three, and this is what the terminal logs is all about:

----
{"level":30,"time":1764255364207,"pid":66587,"hostname":"Alexs-MacBook-Pro.local","name":"wrk-data-shard-proc-shard-1-f265d83d-441b-4774-9ae5-8580e52ba65c","msg":"Sync Jar https://web190181.rumble.com/-wallet/webhook/jar-sync failed on attempt 2"}
{"level":30,"time":1764255365067,"pid":66587,"hostname":"Alexs-MacBook-Pro.local","name":"wrk-data-shard-proc-shard-1-f265d83d-441b-4774-9ae5-8580e52ba65c","msg":"Sync Jar https://web190181.rumble.com/-wallet/webhook/jar-sync failed on attempt 3"}
{"level":30,"time":1764255370004,"pid":66587,"hostname":"Alexs-MacBook-Pro.local","name":"wrk-data-shard-proc-shard-1-f265d83d-441b-4774-9ae5-8580e52ba65c","msg":"started syncing wallet transfers for wallets 8749b653-0550-49e4-a21c-e048c140f595, 2025-11-27T14:56:10.004Z"}
{"level":30,"time":1764255370018,"pid":66587,"hostname":"Alexs-MacBook-Pro.local","name":"wrk-data-shard-proc-shard-1-f265d83d-441b-4774-9ae5-8580e52ba65c","msg":"finished syncing wallet transfers for wallets 8749b653-0550-49e4-a21c-e048c140f595, total: 0, 2025-11-27T14:56:10.018Z"}
{"level":30,"time":1764255378835,"pid":66587,"hostname":"Alexs-MacBook-Pro.local","name":"wrk-data-shard-proc-shard-1-f265d83d-441b-4774-9ae5-8580e52ba65c","msg":"Sending webhook to rumble server: {\"id\":\"8749b653-0550-49e4-a21c-e048c140f595\",\"addresses\":{\"ethereum\":\"0xcf31f1a06067066cb050d6baf7d2c8e4c020c0e1\"},\"enabled\":false,\"name\":\"pool-test-1764255363-4867\",\"type\":\"user\",\"userId\":\"user-123\"}"}
{"level":30,"time":1764255379302,"pid":66587,"hostname":"Alexs-MacBook-Pro.local","name":"wrk-data-shard-proc-shard-1-f265d83d-441b-4774-9ae5-8580e52ba65c","msg":"Sync Jar https://web190181.rumble.com/-wallet/webhook/jar-sync failed on attempt 1"}
{"level":30,"time":1764255379919,"pid":66587,"hostname":"Alexs-MacBook-Pro.local","name":"wrk-data-shard-proc-shard-1-f265d83d-441b-4774-9ae5-8580e52ba65c","msg":"Sync Jar https://web190181.rumble.com/-wallet/webhook/jar-sync failed on attempt 2"}
{"level":30,"time":1764255380009,"pid":66587,"hostname":"Alexs-MacBook-Pro.local","name":"wrk-data-shard-proc-shard-1-f265d83d-441b-4774-9ae5-8580e52ba65c","msg":"started syncing wallet transfers for wallets 8749b653-0550-49e4-a21c-e048c140f595, 2025-11-27T14:56:20.009Z"}
{"level":30,"time":1764255380019,"pid":66587,"hostname":"Alexs-MacBook-Pro.local","name":"wrk-data-shard-proc-shard-1-f265d83d-441b-4774-9ae5-8580e52ba65c","msg":"finished syncing wallet transfers for wallets 8749b653-0550-49e4-a21c-e048c140f595, total: 0, 2025-11-27T14:56:20.019Z"}
{"level":30,"time":1764255380753,"pid":66587,"hostname":"Alexs-MacBook-Pro.local","name":"wrk-data-shard-proc-shard-1-f265d83d-441b-4774-9ae5-8580e52ba65c","msg":"Sync Jar https://web190181.rumble.com/-wallet/webhook/jar-sync failed on attempt 3"}
{"level":30,"time":1764255390006,"pid":66587,"hostname":"Alexs-MacBook-Pro.local","name":"wrk-data-shard-proc-shard-1-f265d83d-441b-4774-9ae5-8580e52ba65c","msg":"started syncing wallet transfers for wallets 8749b653-0550-49e4-a21c-e048c140f595, 2025-11-27T14:56:30.006Z"}
{"level":30,"time":1764255390010,"pid":66587,"hostname":"Alexs-MacBook-Pro.local","name":"wrk-data-shard-proc-shard-1-f265d83d-441b-4774-9ae5-8580e52ba65c","msg":"finished syncing wallet transfers for wallets 8749b653-0550-49e4-a21c-e048c140f595, total: 0, 2025-11-27T14:56:30.010Z"}
{"level":30,"time":1764255400005,"pid":66587,"hostname":"Alexs-MacBook-Pro.local","name":"wrk-data-shard-proc-shard-1-f265d83d-441b-4774-9ae5-8580e52ba65c","msg":"started syncing wallet transfers for wallets 8749b653-0550-49e4-a21c-e048c140f595, 2025-11-27T14:56:40.005Z"}
{"level":30,"time":1764255400013,"pid":66587,"hostname":"Alexs-MacBook-Pro.local","name":"wrk-data-shard-proc-shard-1-f265d83d-441b-4774-9ae5-8580e52ba65c","msg":"finished syncing wallet transfers for wallets 8749b653-0550-49e4-a21c-e048c140f595, total: 0, 2025-11-27T14:56:40.013Z"}
----

The lost investigation attempt by another LLM ended with:

---
Wait - before running it 5 times, let's check if v4 is actually working!

From the single v4 test we just ran, please check your Terminal 3 (data-shard-proc) logs and tell me:

Do you see ANY [RPC_TRACE] messages at all? (around timestamp 1764254946 when the test ran)
Do you see 
syncWalletTransfersJob
 or sync-related messages?
If you see [RPC_TRACE] logs, then yes, run the repeat script - v4 is working and we just need more attempts to catch the race condition.

If you don't see any [RPC_TRACE] logs, then running it 5 times won't help - we need to figure out why the sync jobs aren't actually calling the indexer.

Quick way to check:

bash
# Look for RPC_TRACE in your data-shard-proc terminal
# or grep the logs if you're logging to a file
grep "RPC_TRACE" /tmp/data-shard-proc-trace.log 2>/dev/null || echo "No RPC_TRACE logs found"

# Or look for sync job logs
grep "sync" /tmp/data-shard-proc-trace.log 2>/dev/null | tail -20
What to look for:

✅ Good: [RPC_TRACE] Initiating RPC request to... - means RPC calls are happening, run repeat script
❌ Problem: No RPC_TRACE logs at all - means we need to investigate why sync jobs aren't calling the indexer
Share what you find and I'll guide you on next steps!
----


Your task:

Read as much context and code as you can and try to find out why this is not being repeated and try to help me updating the test by writing a new version of it, which makes you repeat it.

PS: At the moment, there are no service that is running.