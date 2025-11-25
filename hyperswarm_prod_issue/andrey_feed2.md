netstat -an | grep ESTABLISHED | wc -l
357
394
333

-----
Asking:
pm2 logs wrk-data-shard-proc --lines 1000 | grep -E "11:14:0[0-5]"

Igot _docs/mongo_prod_issue/image4.png
And he asked: is this what you are looking for?

------

I asked:
Also... looking at the 1st screenshot you shared, I see idx-xaut-eth-proc-w-0 (row 18). Is this the XAUT Ethereum indexer?
Can you check its logs specifically around 11:14 UTC when the errors occurred?

Got _docs/mongo_prod_issue/image5.png

-----

