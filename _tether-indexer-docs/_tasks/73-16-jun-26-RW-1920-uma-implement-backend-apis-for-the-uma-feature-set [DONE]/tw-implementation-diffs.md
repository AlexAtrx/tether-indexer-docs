# Rumble UMA vs Tether Wallet Implementation Diffs

Core payment flow is close to Tether Wallet: `lnurlpLookup`, Spark callback selection, settlement options, metadata/currencies, ORK username lookup, and Spark payreq routing follow the same overall shape.

## Differences

1. **Username ownership**

   Tether Wallet lets the client choose/check/suggest a UMA username and validates it during wallet creation.

   Rumble does not expose suggest/check/set. It stamps `req._info.user.username` from auth onto user wallets.

2. **Username validation**

   Tether Wallet enforces its UMA username rules.

   Rumble only trims and lowercases, because the username comes from Rumble auth. This depends on `preferred_username` always being present and UMA-compatible.

3. **Missing username behavior**

   Tether Wallet requires a username in the create-wallet UMA flow.

   Rumble creates the wallet without UMA if the token username is missing. It avoids advertising an unresolvable UMA handle, but it is a behavioral difference.

4. **Wallet response decoration**

   Tether Wallet applies UMA defaults through app service wrappers.

   Rumble uses inherited WDK routes plus a preSerialization decorator/schema override, and only advertises UMA when the stored wallet has `username`.

5. **Stored UMA data**

   Tether Wallet stores `username` plus optional per-wallet `uma` config from the wallet payload.

   Rumble stores only `username`. Domain, limits, and settlement defaults come from app-node config.

6. **Data-shard create path**

   Tether Wallet has a custom one-wallet-per-user create flow.

   Rumble keeps the inherited batch/channel wallet flow and uses `AsyncLocalStorage` plus a Mongo repo `save` override to stamp the username inside the base unit of work.

7. **Username uniqueness index**

   Tether Wallet uses a sparse unique username index.

   Rumble uses a partial unique index scoped to active wallets, so soft-deleted wallets release the username.

8. **ORK lookup reservation**

   Tether Wallet writes the `uma_username` lookup after wallet creation and does not check the returned owner.

   Rumble checks lost races and rolls back the just-created UMA wallet if lookup reservation fails.

9. **Account-block checks**

   Tether Wallet blocks UMA lookup/pay for blocked accounts through `accountDeletion`.

   Rumble does not have the same account-block check in this implementation.

10. **Validation strictness**

    Tether Wallet currently uses looser amount parsing and less strict layer/asset validation in parts of the UMA pay flow.

    Rumble rejects malformed amounts, enforces min/max limits, validates settlement layer/asset compatibility, and propagates backend errors instead of masking some `getUmaByUserId` failures as username misses.

## Review Risk

The main review risk is around username assumptions: Rumble depends on auth usernames being present and UMA-safe. The other differences are mostly Rumble-specific architecture, compatibility with batch/channel wallet creation, or stricter validation around behavior that Tether Wallet currently allows.
