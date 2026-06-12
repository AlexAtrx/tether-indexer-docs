# Description

> Refreshed from Asana 2026-06-11. Francesco edited the description on
> 2026-05-27 and 2026-06-05, adding the "RESOLVE CONFLICTS + MERGE" header
> and the PRs Slack link.

RESOLVE CONFLICTS + MERGE 

----------------------------------------



UPDATE

PRS
https://tether-to.slack.com/archives/C0A5DFYRNBB/p1779809767540199


Related asana tasks: https://app.asana.com/1/45238840754660/project/1210540875949204/task/1214143657334762?focus=true


----------------------------------------



Currently it takes 30m to restart the dev env - this is too much - it's slowing down the ability to deploy multiple times a day in DEV for smoke testing PRs.

Find slowest services (Indexer + Processor TON? - others) and either address the issue if it's obvious and easy to fix 
OR
Start discussion to remove them from the deployment temporarily (Discussion needed on slack mentioning Francesco/Vigan about this)

NOTE from Francesco: I don't think we should scale the Dev env more than what we already have - see screenshot

https://app.asana.com/app/asana/-/get_asset?asset_id=1213475123348186



LOG:

e      │ online   │ 0%       │ 145.7mb  │
│ 82 │ pm2-metrics        │ online   │ 0%       │ 42.9mb   │
└────┴────────────────────┴──────────┴──────────┴──────────┘
++ echo 'RESTARTING SHARDS'
RESTARTING SHARDS
++ jq -r '.[] | select(.name | startswith("shard-")) | .pm_id'
++ /home/work/.nvm/versions/node/v22.22.0/bin/pm2 jlist
++ xargs pm2 restart
Use --update-env to update environment variables
[PM2] Applying action restartProcessId on app [40](ids: [ '40' ])
[PM2] [shard-0-proc](40) ✓
Use --update-env to update environment variables
[PM2] Applying action restartProcessId on app [41](ids: [ '41' ])
[PM2] [shard-0-0-api](41) ✓
Use --update-env to update environment variables
[PM2] Applying action restartProcessId on app [42](ids: [ '42' ])
[PM2] [shard-0-1-api](42) ✓
Use --update-env to update environment variables
[PM2] Applying action restartProcessId on app [43](ids: [ '43' ])
[PM2] [shard-0-2-api](43) ✓
Use --update-env to update environment variables
[PM2] Applying action restartProcessId on app [44](ids: [ '44' ])
[PM2] [shard-1-proc](44) ✓
Use --update-env to update environment variables
[PM2] Applying action restartProcessId on app [45](ids: [ '45' ])
[PM2] [shard-1-0-api](45) ✓
Use --update-env to update environment variables
[PM2] Applying action restartProcessId on app [46](ids: [ '46' ])
[PM2] [shard-1-1-api](46) ✓
Use --update-env to update environment variables
[PM2] Applying action restartProcessId on app [47](ids: [ '47' ])
[PM2] [shard-1-2-api](47) ✓
Use --update-env to update environment variables
[PM2] Applying action restartProcessId on app [48](ids: [ '48' ])
[PM2] [shard-2-proc](48) ✓
Use --update-env to update environment variables
[PM2] Applying action restartProcessId on app [49](ids: [ '49' ])
[PM2] [shard-2-0-api](49) ✓
Use --update-env to update environment variables
[PM2] Applying action restartProcessId on app [50](ids: [ '50' ])
[PM2] [shard-2-1-api](50) ✓
Use --update-env to update environment variables
[PM2] Applying action restartProcessId on app [51](ids: [ '51' ])
[PM2] [shard-2-2-api](51) ✓
┌────┬────────────────────┬──────────┬──────┬───────────┬──────────┬──────────┐
│ id │ name               │ mode     │ ↺    │ status    │ cpu      │ memory   │
├────┼────────────────────┼──────────┼──────┼───────────┼──────────┼──────────┤
│ 55 │ app-0              │ fork     │ 0    │ online    │ 0%       │ 85.1mb   │
│ 56 │ app-1              │ fork     │ 0    │ online    │ 0%       │ 85.4mb   │
│ 57 │ app-2              │ fork     │ 0    │ online    │ 0%       │ 87.5mb   │
│ 1  │ idx-bitcoin-0-api  │ fork     │ 3    │ online    │ 0%       │ 95.9mb   │
│ 2  │ idx-bitcoin-1-api  │ fork     │ 3    │ online    │ 0%       │ 97.2mb   │
│ 3  │ idx-bitcoin-2-api  │ fork     │ 2    │ online    │ 0%       │ 96.4mb   │
│ 0  │ idx-bitcoin-proc   │ fork     │ 3    │ online    │ 16.6%    │ 170.9mb  │
│ 33 │ idx-spark-0-api    │ fork     │ 2    │ online    │ 0.4%     │ 132.2mb  │
│ 34 │ idx-spark-1-api    │ fork     │ 2    │ online    │ 0.4%     │ 131.5mb  │
│ 35 │ idx-spark-2-api    │ fork     │ 2    │ online    │ 0.4%     │ 130.8mb  │
│ 32 │ idx-spark-proc     │ fork     │ 2    │ online    │ 17%      │ 103.5mb  │
│ 76 │ idx-usat-eth-api-… │ fork     │ 1    │ online    │ 0.4%     │ 90.8mb   │
│ 77 │ idx-usat-eth-api-… │ fork     │ 1    │ online    │ 0.4%     │ 87.7mb   │
│ 78 │ idx-usat-eth-api-… │ fork     │ 1    │ online    │ 0.4%     │ 89.7mb   │
│ 75 │ idx-usat-eth-proc… │ fork     │ 1    │ online    │ 16.1%    │ 101.3mb  │
│ 13 │ idx-usdt-arb-0-api │ fork     │ 2    │ online    │ 0.4%     │ 98.4mb   │
│ 14 │ idx-usdt-arb-1-api │ fork     │ 2    │ online    │ 0%       │ 98.3mb   │
│ 15 │ idx-usdt-arb-2-api │ fork     │ 2    │ online    │ 0%       │ 98.2mb   │
│ 12 │ idx-usdt-arb-proc  │ fork     │ 2    │ online    │ 16.1%    │ 146.0mb  │
│ 5  │ idx-usdt-eth-0-api │ fork     │ 2    │ online    │ 0%       │ 96.6mb   │
│ 6  │ idx-usdt-eth-1-api │ fork     │ 2    │ online    │ 0.4%     │ 97.6mb   │
│ 7  │ idx-usdt-eth-2-api │ fork     │ 2    │ online    │ 0%       │ 97.9mb   │
│ 4  │ idx-usdt-eth-proc  │ fork     │ 2    │ online    │ 16.6%    │ 146.4mb  │
│ 72 │ idx-usdt-plasma-a… │ fork     │ 1    │ online    │ 0.4%     │ 90.1mb   │
│ 73 │ idx-usdt-plasma-a… │ fork     │ 1    │ online    │ 0.4%     │ 90.8mb   │
│ 74 │ idx-usdt-plasma-a… │ fork     │ 1    │ online    │ 0.4%     │ 90.2mb   │
│ 71 │ idx-usdt-plasma-p… │ fork     │ 1    │ online    │ 16.6%    │ 104.9mb  │
│ 9  │ idx-usdt-pol-0-api │ fork     │ 2    │ online    │ 0.4%     │ 98.2mb   │
│ 10 │ idx-usdt-pol-1-api │ fork     │ 2    │ online    │ 0%       │ 97.8mb   │
│ 11 │ idx-usdt-pol-2-api │ fork     │ 2    │ online    │ 0.9%     │ 98.0mb   │
│ 8  │ idx-usdt-pol-proc  │ fork     │ 2    │ online    │ 16.6%    │ 146.6mb  │
│ 25 │ idx-usdt-ton-0-api │ fork     │ 2    │ online    │ 0.4%     │ 101.9mb  │
│ 26 │ idx-usdt-ton-1-api │ fork     │ 2    │ online    │ 0.4%     │ 100.0mb  │
│ 27 │ idx-usdt-ton-2-api │ fork     │ 2    │ online    │ 0.9%     │ 99.2mb   │
│ 24 │ idx-usdt-ton-proc  │ fork     │ 2    │ online    │ 0.9%     │ 322.2mb  │
│ 21 │ idx-usdt-tron-0-a… │ fork     │ 2    │ online    │ 0.4%     │ 127.9mb  │
│ 22 │ idx-usdt-tron-1-a… │ fork     │ 2    │ online    │ 0%       │ 129.6mb  │
│ 23 │ idx-usdt-tron-2-a… │ fork     │ 2    │ online    │ 0%       │ 128.7mb  │
│ 20 │ idx-usdt-tron-proc │ fork     │ 2    │ online    │ 0.4%     │ 144.4mb  │
│ 17 │ idx-xaut-eth-0-api │ fork     │ 2    │ online    │ 0.4%     │ 96.8mb   │
│ 18 │ idx-xaut-eth-1-api │ fork     │ 2    │ online    │ 0.4%     │ 98.4mb   │
│ 19 │ idx-xaut-eth-2-api │ fork     │ 2    │ online    │ 0.4%     │ 96.1mb   │
│ 16 │ idx-xaut-eth-proc  │ fork     │ 2    │ online    │ 15.7%    │ 140.6mb  │
│ 29 │ idx-xaut-ton-0-api │ fork     │ 2    │ online    │ 0%       │ 97.0mb   │
│ 30 │ idx-xaut-ton-1-api │ fork     │ 2    │ online    │ 0%       │ 94.6mb   │
│ 31 │ idx-xaut-ton-2-api │ fork     │ 2    │ online    │ 0.9%     │ 91.7mb   │
│ 28 │ idx-xaut-ton-proc  │ fork     │ 2    │ online    │ 0.4%     │ 107.0mb  │
│ 58 │ monitor            │ fork     │ 0    │ online    │ 0.4%     │ 31.5mb   │
│ 52 │ ork-0              │ fork     │ 0    │ online    │ 0.4%     │ 92.2mb   │
│ 53 │ ork-1              │ fork     │ 0    │ online    │ 0.4%     │ 91.9mb   │
│ 54 │ ork-2              │ fork     │ 0    │ online    │ 0%       │ 90.9mb   │
│ 63 │ processor-arbitru… │ fork     │ 1    │ online    │ 0.4%     │ 82.6mb   │
│ 66 │ processor-bitcoin… │ fork     │ 1    │ online    │ 0%       │ 82.3mb   │
│ 79 │ processor-ethereu… │ fork     │ 1    │ online    │ 0.4%     │ 82.1mb   │
│ 59 │ processor-ethereu… │ fork     │ 1    │ online    │ 0.4%     │ 84.8mb   │
│ 60 │ processor-ethereu… │ fork     │ 1    │ online    │ 0.4%     │ 84.3mb   │
│ 61 │ processor-plasma-… │ fork     │ 1    │ online    │ 0%       │ 83.6mb   │
│ 62 │ processor-plasma-… │ fork     │ 1    │ online    │ 0%       │ 82.6mb   │
│ 67 │ processor-polygon… │ fork     │ 1    │ online    │ 0.4%     │ 84.2mb   │
│ 68 │ processor-spark-b… │ fork     │ 1    │ online    │ 0.4%     │ 82.6mb   │
│ 64 │ processor-ton-usd… │ fork     │ 1    │ online    │ 0%       │ 83.4mb   │
│ 65 │ processor-ton-xau… │ fork     │ 1    │ online    │ 0.4%     │ 81.9mb   │
│ 70 │ processor-tron-us… │ fork     │ 1    │ online    │ 0.4%     │ 82.4mb   │
│ 41 │ shard-0-0-api      │ fork     │ 1    │ online    │ 7.6%     │ 96.1mb   │
│ 42 │ shard-0-1-api      │ fork     │ 1    │ online    │ 0.4%     │ 97.9mb   │
│ 43 │ shard-0-2-api      │ fork     │ 1    │ online    │ 0.4%     │ 116.5mb  │
│ 40 │ shard-0-proc       │ fork     │ 1    │ online    │ 0.4%     │ 103.2mb  │
│ 45 │ shard-1-0-api      │ fork     │ 1    │ online    │ 7.2%     │ 98.9mb   │
│ 46 │ shard-1-1-api      │ fork     │ 1    │ online    │ 4.9%     │ 98.4mb   │
│ 47 │ shard-1-2-api      │ fork     │ 1    │ online    │ 0.4%     │ 115.9mb  │
│ 44 │ shard-1-proc       │ fork     │ 1    │ online    │ 0.4%     │ 137.3mb  │
│ 49 │ shard-2-0-api      │ fork     │ 1    │ online    │ 9%       │ 117.5mb  │
│ 50 │ shard-2-1-api      │ fork     │ 1    │ online    │ 58.3%    │ 114.6mb  │
│ 51 │ shard-2-2-api      │ fork     │ 1    │ online    │ 0%       │ 21.9mb   │
│ 48 │ shard-2-proc       │ fork     │ 1    │ online    │ 1.8%     │ 125.5mb  │
└────┴────────────────────┴──────────┴──────┴───────────┴──────────┴──────────┘
Modules
┌────┬────────────────────┬──────────┬──────────┬──────────┐
│ id │ name               │ status   │ cpu      │ mem      │
├────┼────────────────────┼──────────┼──────────┼──────────┤
│ 81 │ @pm2/io            │ online   │ 0.4%     │ 33.5mb   │
│ 80 │ pm2-logrotate      │ online   │ 0%       │ 146.3mb  │
│ 82 │ pm2-metrics        │ online   │ 0.4%     │ 44.3mb   │
└────┴────────────────────┴──────────┴──────────┴──────────┘
++ echo 'RESTARTING ORKS'
RESTARTING ORKS
++ /home/work/.nvm/versions/node/v22.22.0/bin/pm2 jlist
++ jq -r '.[] | select(.name | startswith("ork-w-")) | .pm_id'
++ xargs pm2 restart

  error: missing required argument `id|name|namespace|all|json|stdin'


real	31m24.892s
user	0m3.419s
sys	0m1.007s





