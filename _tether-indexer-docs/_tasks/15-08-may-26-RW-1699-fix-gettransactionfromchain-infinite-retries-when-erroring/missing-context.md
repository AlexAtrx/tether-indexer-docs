# Missing context

Things referenced from the ticket / comments / logs that are NOT included in
this folder. Resolve these before / while picking the ticket up.

- [ ] **Slack thread:** "https://tether-to.slack.com/archives/C0A5DFYRNBB/p1778255800792219?thread_ts=1778250967.008189&cid=C0A5DFYRNBB" — **Need from Alex:** export of the full Slack thread, including any messages after Francesco's "I would need to check myself or with the team" reply (e.g. did the team suggest a path? did Andrei share more error context?). **Source:** description, top.

Find it in: \_tether-indexer-docs/\_tasks/08-may-26-RW-1699-fix-gettransactionfromchain-infinite-retries-when-erroring/slack1.txt

- [ ] **Logs — actual error block:** the description pastes level-30 "finished processing" lines, none of which show `ERR_GET_TX_FROM_CHAIN_FAILED`. **Need from Alex:** a Grafana / log-viewer URL or a raw paste of the error stream that includes the failing BTC tx (`86e0c91e…`) so we can see the worker name, retry cadence, and surrounding context. **Source:** description "LOGS" section.

- [ ] **Wallet / user / shard id for tx `86e0c91e…`:** Alex asked Francesco for this in his 2026-05-08 comment. Without it we can't write a targeted delete command — we'd have to scan all BTC shards. **Need from Alex:** Francesco's reply with the wallet GID, user GID, or at minimum which shard the tx record sits on. **Source:** Alex's comment, 2026-05-08T09:56:10Z.

- [ ] **Delivery format decision:** Alex asked "one-shot script for Andrei tonight, or a small admin RPC on the proc worker?" — Francesco hasn't answered. **Need from Alex:** which path Francesco wants. The first is faster; the second is reusable. **Source:** Alex's comment, 2026-05-08T09:56:10Z.

- [ ] **`getTransactionFromChain` call sites:** the comment says it `throws` instead of returning `{retry:true}`, but doesn't pin the file. **Need from Alex / next session:** verify whether this is the BTC indexer's `proc.shard.data.wrk.js` calling into a chain client, or a wrapper inside `tether-wallet-lib-bitcoin`. Confirm via Grep before editing.

- [ ] **External Slack pings about ignoring errors:** "Francesco pinged Andrei to ignore these errors at the moment so we can work on a proper fix." **Need from Alex:** confirm Andrei is muting alerts on his side so we don't get pinged about the same hash while iterating, and confirm the production tx record is still pending (i.e. still being retried) at the time we ship the fix.
