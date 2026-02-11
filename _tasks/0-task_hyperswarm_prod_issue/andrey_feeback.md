This is what I got from Andre in phases:

==============

1:
------------
all indexers up with 0 restarts
^ same on all 3 nodes

(Screenshot shared: _docs/mongo_prod_issue/img2.png). 
-----------

2:
```
wallet@walletprd1:/srv/data/production$ pm2 logs wdk-indexer-wrk-evm --lines 200
[TAILING] Tailing last 200 lines for [wdk-indexer-wrk-evm] process (change the value with --lines option)
```
He said: empty on all 3 nodes.

3:
netstat -an | grep -E "49737|49738" | wc -l  # DHT ports
2

4:
dmesg | grep -i "network\|eth0\|connection" | tail -50
said: gives nothing

5:
usdt eth indexer proc logs, only level 30 in last 30m
(Screenshot attached: _docs/mongo_prod_issue/img1.png).

6:
rwp0 [direct: primary] test> db.serverStatus().connections
{
  current: 2208,
  available: 48992,
  totalCreated: 1233239,
  rejected: 0,
  active: 927,
  queuedForEstablishment: Long('0'),
  establishmentRateLimit: {
    rejected: Long('0'),
    exempted: Long('0'),
    interruptedDueToClientDisconnect: Long('0')
  },
  threaded: 2208,
  exhaustIsMaster: Long('0'),
  exhaustHello: Long('923'),
  awaitingTopologyChanges: Long('924'),
  loadBalanced: Long('0')
}

7:
The values of 'poolLinger' and 'timeout' do not exist in the config file. 

==============

Do we have enough knowledge to call you diagnosis 100%? Or there is still some doubt? If so, we can run more commands.