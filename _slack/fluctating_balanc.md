Jesse
@george @Usman Khan @Matteo Giardino just funded me 10 USDT on polygon, I received the notification, but I still don't see the balance reflected in-app in balances (also not when pulling to refresh). It's been 7 minutes now... Is this issues with indexers? Issues with rate limiting? Something else? (CC @Matteo Giardino)

Gohr
@Jesse Eilers it may be the same  issue https://tether-to.slack.com/archives/C094R63HQ64/p1762937924894349
it is the same flow, I sent the money to @Kulwinder Singh he got the push notification but the balance weren’t changed

Iveri Atskureli
Hey team,
 The /api/v1/wallets/balances endpoint is returning different amounts between transfers.
Starting balance was 7.377555
After receiving the first 2 USDT transaction, the endpoint started returning a Polygon balance of 9.377555.
A few minutes later, I received the second 2 USDT transaction, and the endpoint started returning a Polygon balance of 11.377555.
However, after a few API calls, the endpoint went back to showing the previous balance 9.377555 for about a minute.
After that, the endpoint finally started showing the correct balance 11.377555.

Alex
@Matteo Giardino @Kulwinder Singh @Jesse Eilers
This is about the cache flickering issue.
Checking code, I found out that (most probably) balances flicker because:
:point_right: The param cache=false only skips the 30s HTTP cache read but still writes its result back, and each fetch round-robins across RPC providers at different block heights. Therefore a 'refresh' can poison the cache with a stale provider response, so subsequent cache=true requests bounce between differing heights (plus price cache) and the UI oscillates.
However, i'm not 100% sure if this will fix the issue. It's just a blind guess.

Matteo
Thanks @Alex Atrash this seems like a plausible cause - can you replicate it locally and test if a fix works?

Usman
I think the reason why we are getting flickering values is because the lru cache library we use is specific for each worker. So, it's possible that
first request goes to app-node worker A and we cache this value. 2nd request goes to server B and by this time balance is updated, we cache this value as well. 3rd request goes again to app-node worker A and it returns the stale cached value. Resulting in this issue.

Aelx
@Usman Khan indeed, i didn't think of this. We need shared cache. And this could be why I can't reproduce it with a single instance locally. (edited) 

Usman
@Iveri Atskureli and @george can you confirm if you guys always call this endpoint with cache=false  param or not?

george
for batched endpoint we're calling it without cache=false

Usman
@george and @Iveri Atskureli I think this issue will require a bit more work than we initially thought. Could you pass the param cache=false  with these requests so that we always get the latest changes from the provider always?
