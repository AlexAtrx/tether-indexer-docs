Implement what did with [WDK-1515 — Investigate rumble prod ERR_WALLET_TRANSFER_RPC_FAIL (RPC client closed) requiring data-shard restarts](https://app.asana.com/0/search?q=WDK-1515&searched_type=task&child=1215216504545662&f=true) (Asana GID 1215216504545662) in `wdk-ork-wrk` and `rumble-ork-wrk`

When a rant is sent through the wallet, the transaction completes on-chain and the recipient receives the funds, but nothing shows up in the chat. Seen on both prod and staging.

Reported by Mariia in Slack during mobile testing.

Examples (all confirmed, nothing displayed in chat):

**Prod**
- `0x1de8c852f240aE0a90ae6BeD9d32DF1AFd9C5cDE` | 0.045 scudos ($0.20) | Jun 4, 16:04
  https://etherscan.io/tx/0x73717270150ab968f5e909c5f2a4f93832b421cf46ffec4d21075ceb605ccaa5
- `0x1de8c852f240aE0a90ae6BeD9d32DF1AFd9C5cDE` | 0.3 USDt ($0.30) | Jun 4, 16:09
  https://plasmascan.to/tx/0xa1c7498d44b98970871ac5e437a64820938b5b5ad8ca3a32a52d23df6a64d7fe

**Staging**
- `0x5430Ba7a62979b84B1894638c41776Ec7DC2EfE8` | 0.227 scudos ($1.00) | Jun 5, 09:17
  https://etherscan.io/tx/0x424b06075da787533c5fad5c833b6f9608c13859c70318e1c89c7ee9fc30b027

Need to figure out why these rants are not appearing in the chat.

Slack ref: https://tether-to.slack.com/archives/C094R63HQ64/p1780603661792139
