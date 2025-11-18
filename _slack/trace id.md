Kulwinder Singh
Hi team,
I have observed that we have multiple workers and services in our backend, and the request flow passes through several components — user → app-node → ork-wrk → data-shard → indexer. Since there are multiple app nodes, ork workers, and data shards running simultaneously, it becomes quite complicated to debug any single request because the logs are scattered across many services.
To improve this, we should introduce a single trace ID for every incoming request. This trace ID would be forwarded through the entire flow so that all logs across all services include the same identifier. With this in place, we can simply search by the trace ID in Grafana and easily track the full request path end-to-end, making debugging significantly easier and faster.
Let me know your thoughts.

Gani
One global trace ID is great, but you’ll often want to know where in the flow a log came from.
So along with trace_id, also log:
service or component (app-node / ork-wrk / data-shard / indexer)
@Jesse Eilers @Vigan @Usman Khan plz confirm

Kulwinder
@Gani that's already appended in logs
:ty:
2

8:15
2025-11-18T07:15:03: {"level":30,"time":1763450103299,"pid":605297,"hostname":"walletprd1","name":"wrk-data-shard-proc-w-0-0-b8f4f8c9-2c4d-4202-86ff-82e442fbd27d","msg":"finished syncing wallet transfers for wallets f789754b-a62c-4dad-98d4-9e20e58875b6, f882889e-6296-48c7-a525-b0528256dc73, f8c7fd66-8285-4970-a1bd-5ba85b7b7216, fbee55f3-26d7-44a1-ae29-9f243a5682c3, ff47ef0b-3714-4d82-ba16-c36affd6c862, total: 0, 2025-11-18T07:15:03.299Z"}
Example
8:16
can you create ticket for this we will discuss in today's call

Gani
yes

Jesse
makes perfect sense @Kulwinder Singh 

Alex 
All in for trace ID.
