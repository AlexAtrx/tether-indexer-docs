Environment: iPhone 16, iOS 18.6.1

Steps to Reproduce:
    Create two wallets
    Log in to the wallet 1
    Log in to the wallet 2
    Send 3 USDT from wallet 1 to wallet 2
    Check push notification on the phone with wallet 2

Actual Result: 
Incorrect wording and formatting in transfer push notifications

Expected result:
    Consistent number format – All notifications should display currency amounts uniformly (e.g., 3 USDT without unnecessary decimals).
    Correct grammar – Use proper English phrasing:
    “Transfer initiated” → “A transfer of 3 USDT on Polygon is being processed for your wallet”
    “Transfer completed” → “You’ve received 3 USDT on Polygon in your wallet”
    Natural prepositions – Replace “initiated to” → “initiated for” and “completed into” → “completed to” or “received in.”
    No terminal punctuation – Remove trailing periods at the end of short push messages.
    Unified copy structure – Use the same style and tone for all statuses, e.g.:
        Title pattern: “Transfer initiated” / “Transfer completed”
        Message pattern: “A transfer of X USDT on [network] …”

Screenshot:

https://app.asana.com/app/asana/-/get_asset?asset_id=1211923806576798
