## Extra discussion and context

Dev1:
in the _isTxCompleted we just call the indexers with getTransaction only to rumble webhooks if transaction was confirmed. But we don't save it in the database by fetching it from getTransaction. Saving transaction only happens via syncTransfers job.
If you view the video shared below, you can see that https://polygonscan.com/tx/0x083efdddcc9946833f701a230dc3bff4cf3a7f1ee98a4006625b5db37d5b4db2 is stuck in on-going. But with the same timestamp and amount, another txn: https://polygonscan.com/tx/0x23b92fd39e29d3589fb5cc572aa2fde78da24e8cc59c236894b362b637b57410 relating to the same account get confirmed (with successful Op).
I am not sure if the provider/mobile app creates a different transaction automatically behind the scenes?
A video is shared - screenshots of it are here:
_docs/task_failed_transaction/Screenshot 2025-12-01 at 10.14.55.png
_docs/task_failed_transaction/Screenshot 2025-12-01 at 10.15.37.png
_docs/task_failed_transaction/Screenshot 2025-12-01 at 10.15.55.png
_docs/task_failed_transaction/Screenshot 2025-12-01 at 10.16.12.png
_docs/task_failed_transaction/Screenshot 2025-12-01 at 10.16.29.png
_docs/task_failed_transaction/Screenshot 2025-12-01 at 10.16.51.png
_docs/task_failed_transaction/Screenshot 2025-12-01 at 10.17.22.png


Dev2:
in https://polygonscan.com/tx/0x23b92fd39e29d3589fb5cc572aa2fde78da24e8cc59c236894b362b637b57410 beneficiary is different when I check this other one both bundle tx and AA tx return same results
```
hp-rpc-cli -s idx-usdt-pol-api-w-0-1 --cp 73746167696e672d6361706162696c6974792d736563726574 -m getTransactionFromChain -d '{"hash": "0xf294aa7c17f1c5ff9e0c7895034adf98038aec0a2ee7ba921ec8adb1a91968f3"}' -t 30000 |jq .
[
  {
    "blockchain": "polygon",
    "blockNumber": "79489992",
    "transactionHash": "0xf294aa7c17f1c5ff9e0c7895034adf98038aec0a2ee7ba921ec8adb1a91968f3",
    "transferIndex": 0,
    "from": "0xe4fba99b52137de9cd0c4bbbe2448ca061a21a38",
    "to": "0x7f841ef732b4528335ed125d8e1cf00a8b0f7205",
    "token": "usdt",
    "amount": "0.11",
    "timestamp": 1764085019000,
    "label": "transaction"
  },
  {
    "blockchain": "polygon",
    "blockNumber": "79489992",
    "transactionHash": "0xf294aa7c17f1c5ff9e0c7895034adf98038aec0a2ee7ba921ec8adb1a91968f3",
    "transferIndex": 1,
    "from": "0xe4fba99b52137de9cd0c4bbbe2448ca061a21a38",
    "to": "0x8b1f6cb5d062aa2ce8d581942bbb960420d875ba",
    "token": "usdt",
    "amount": "0.025672",
    "timestamp": 1764085019000,
    "label": "paymasterTransaction"
  }
]
vabdurrahmani@walletstg1:/srv/data/staging$ hp-rpc-cli -s idx-usdt-pol-api-w-0-1 --cp 73746167696e672d6361706162696c6974792d736563726574 -m getTransactionFromChain -d '{"hash": "0x23b92fd39e29d3589fb5cc572aa2fde78da24e8cc59c236894b362b637b57410"}' -t 30000 |jq .
[
  {
    "blockchain": "polygon",
    "blockNumber": "79489992",
    "transactionHash": "0x23b92fd39e29d3589fb5cc572aa2fde78da24e8cc59c236894b362b637b57410",
    "transferIndex": 0,
    "transactionIndex": 80,
    "logIndex": 662,
    "from": "0xe4fba99b52137de9cd0c4bbbe2448ca061a21a38",
    "to": "0x7f841ef732b4528335ed125d8e1cf00a8b0f7205",
    "token": "usdt",
    "amount": "0.11",
    "timestamp": 1764085019000,
    "label": "transaction"
  },
  {
    "blockchain": "polygon",
    "blockNumber": "79489992",
    "transactionHash": "0x23b92fd39e29d3589fb5cc572aa2fde78da24e8cc59c236894b362b637b57410",
    "transferIndex": 1,
    "transactionIndex": 80,
    "logIndex": 665,
    "from": "0xe4fba99b52137de9cd0c4bbbe2448ca061a21a38",
    "to": "0x8b1f6cb5d062aa2ce8d581942bbb960420d875ba",
    "token": "usdt",
    "amount": "0.025672",
    "timestamp": 1764085019000,
    "label": "paymasterTransaction"
  }
]
```

if you see here transaction id is different from what is being opened on explorer
_docs/task_failed_transaction/image.png

Dev1:
Yeah, I noticed that as well. But it's the same amount and timestamp as the one that is shown in the beginning, which failed..

Dev 2:
so I'm 100% sure we're not storing failed transaction on backend
10:08
that could be just some retry logic, please check with George and Jonathan
10:09
but my main concern is that a failed transactions gets stuck in outgoing state in app side

## Task
- Go through it all along with the screesnshots.
- In light of this discussion, give me in short your final findgins.