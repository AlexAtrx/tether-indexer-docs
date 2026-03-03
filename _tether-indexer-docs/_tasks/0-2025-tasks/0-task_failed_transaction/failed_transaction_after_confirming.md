## Slack discussion

Dev 1:
Hey guys, I want to discuss a particular scenario of failed transaction, as described in the ticket here. Basically, transaction gets confirmed in the blockchain. But the execution fails (?). Example transaction: https://polygonscan.com/tx/0x083efdddcc9946833f701a230dc3bff4cf3a7f1ee98a4006625b5db37d5b4db2. Providers update the balance and the indexers index the transaction. It gets shown in the transaction history as well. Is there something specific we need to do in such scenarios?

Dev 2:
interesting! note that it might happen also that a tx is confirmed and only a few of the internal calls revert 
9:03
in this case with the red message no state is altered, but with the yellow message some actions are done
9:04
logs tell the truth, in this case no logs are emitted for the Transfer etc...so why would it be shown to the user?