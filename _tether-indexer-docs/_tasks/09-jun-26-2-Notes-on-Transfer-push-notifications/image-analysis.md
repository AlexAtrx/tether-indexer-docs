# Image analysis

## Screenshot_20251112-155726.png

**Source comment:** task

**What it shows:** Phone notification shade with two Rumble Wallet push notifications for a Polygon USDT transfer.

**Key content:**
- Top notification title: `Transfer Successful`
- Top notification body: `A transfer of 3.0 USDT₮ on Polygon has been successfully completed into your wallet.`
- Bottom notification title: `Token Transfer Initiated`
- Bottom notification body: `A transfer of 3 USDT₮ on Polygon is about to be initiated to your wallet`
- The completed notification shows `3.0` while the initiated notification shows `3`.
- The completed copy uses `completed into your wallet.` with terminal punctuation.
- The initiated copy uses `initiated to your wallet`.

**Relevance:** Confirms the ticket's amount-formatting and wording concerns. Current source has since added `formatAmount`, which should normalize `3.0` to `3`, but the backend templates still use the old prepositions and punctuation.
