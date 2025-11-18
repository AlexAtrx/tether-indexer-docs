Jesse Eilers
The same transaction (rant) arrives to us twice with different hashes
First request has payload , doesn't have wallet_id and its hash is: https://etherscan.io/tx/0xa01eaa88334e18e42643304c214234c07a1e93c095a2e008c51e35e4f95e1c9a
We accept it as a proof of payment for a rant and save it in our database

Jesse Eilers
This issue comes from AA giving us two hashes for the same action. The webhook for the rant uses the userOp hash (0xa01e…) and our tx history API returns the bundle tx hash (0x578e…). Since we don’t map those two, Rumble sees them as different transactions.
We should update the indexer so that when we process UserOperationEvent we store both the userOpHash and the transactionHash from the same log. Then:
Pick the bundle tx hash as our canonical transaction_hash in webhooks and in the history API.
Still expose the AA hash separately as aa_transaction_hash if needed.
Update the payment webhook to include both hashes so partners can match them immediately.
Once we add this mapping the duplicate problem will go away.

Kulwinder Singh
@Jesse Eilers agree with this, but it require changes at rumble webhook server, data-shard-layer and indexer level

