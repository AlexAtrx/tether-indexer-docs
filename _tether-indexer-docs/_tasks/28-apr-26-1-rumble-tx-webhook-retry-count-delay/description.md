# Description

In case of user operation hash, the tx webhooks have a maximum number of retryCount and retryDelay that we can rely to process or discard webhooks saved in the database. However, when the user sends an transaction hash, the backend keeps retrying indefinitely without having any logic present for discarding the failed webhooks. More details are provided here: https://github.com/tetherto/rumble-data-shard-wrk/pull/179/changes#r2959235681

The linked slack thread in the github comment gives detail on what should be the retrycount/delay.
