# Task 02 — Identify the BE-side taproot derivation source

**Priority:** high. Without this, the FE/BE format split has no name.

**Why:** `wdk-wallet-btc` has never produced taproot, but `/wallets` returns taproot `bc1p…` BTC addresses. Something on the BE side is producing them. Until we know what, we can't ship a real fix — only the FE-constraint symptomatic patch.

## What to find

1. Which BE service/module populates `addresses.bitcoin` on the `/api/v1/wallets` response.
2. Whether it derives the taproot address itself, or copies it from elsewhere (e.g., an alias of the spark deposit address — though the values *differ* from `meta.spark.sparkDepositAddress`, so it's not a simple alias).
3. The library it uses for the derivation (a different branch of WDK? A bespoke BE lib?).

## Where to look (suggested order)

1. **`tetherto/rumble-wallet-backend`** — most likely owner of `/api/v1/wallets`. Grep for `bitcoin`, `addresses.bitcoin`, `bc1p`, `bip86`, `p2tr`, `taproot`.
2. **`tetherto/wdk-data-shard-wrk`** — the data shard that holds wallet state. Same greps.
3. **`tetherto/wdk-indexer-wrk-btc`** — BTC indexer worker. Less likely to *derive* addresses but worth checking for any taproot logic.
4. **Any spark-related repo** — since the spark deposit address is also taproot, there may be a shared derivation utility.

## Concrete next steps

1. Confirm which repo owns `/api/v1/wallets` route (grep for `'/wallets'` and `users/:userId/token-transfers` together).
2. From the route handler, trace where the `addresses.bitcoin` field is constructed.
3. If the address is derived from the user's seed (or a sub-key thereof), find the derivation code and confirm it produces taproot.
4. Compare to `wdk-wallet-btc` — what's different? Why did the BE pick taproot when the FE module is segwit-only?

## Output

A note appended to `_consolidated/03-investigation.md` (new section: "Part 4 — BE taproot derivation source") naming the file/lines and the derivation path. Plus an Asana update on RW-1428 with the finding.
