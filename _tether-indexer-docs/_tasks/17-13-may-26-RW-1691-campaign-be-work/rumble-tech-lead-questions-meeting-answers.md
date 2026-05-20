Here is the canonical summary of the meeting, with the final understanding after speaking with both Francisco and Andre.

The initial historical context matched what was already captured in the prep notes: the old implementation was a promo-code flow where a user entered a code in the Rumble wallet, the request went through app-node to `rumble-promo-wrk`, the worker checked code state in SQLite, and if valid it sent an on-chain payout from a hot wallet. That old worker also exposed claim and claim-status behavior, and the earlier design questions in `rumble-tech-lead-questions.md` were built around understanding whether the new campaign would extend or replace that old model  

What changed during the call is important: the core mechanic described in the original question doc turned out to be outdated. The doc had assumed a creator-tipping model where the user redeems a code and a creator gets paid, but Andre explicitly corrected that. In the new flow, the money still goes to the user, not to the creator. The creator is only attribution context for campaign analytics and marketing, meaning creators share codes and Rumble tracks which creator drove more new users or redemptions. So there is no creator-address payout flow in the final requirement as discussed on the call, even though that was the starting assumption in the question document

The old campaign was described as follows. Users received physical flyers with promo codes, installed the Rumble wallet, entered the code, waited a few minutes, and received funds. The reward token for that original launch was `USAT`, and it ran on Ethereum. The worker used a single EVM private key or mnemonic-backed wallet on the server side, connected to Lugano nodes for broadcast, and had Slack alerts to warn when the wallet was running low and needed funding. The worker persisted campaign and code state in SQLite, not in memory, and it could be run standalone locally without app-node, using Holepunch CLI RPC calls. The repo name for that service is `rumble-promo-wrk`.

The old technical flow was:

- mobile app submits claim
- request reaches app-node endpoint
- app-node forwards via RPC to `rumble-promo-wrk`
- worker checks SQLite-backed code state
- worker calls an eligibility endpoint on Rumble backend
- if allowed, worker updates DB state and sends the blockchain transaction
- worker exposes claim-related RPCs such as claim and claim-status

That old flow aligns with the WDK and Rumble backend split in `___TRUTH.md`, where `rumble-app-node` is the Rumble-specific extension layer on top of the wallet app-node surface, and the broader platform uses worker boundaries and Hyperswarm RPC internally  

Several implementation details of the old worker were also reviewed:

- the worker currently has both an API and a processor path
- code-generation scripts exist and can be run locally
- SQLite wrappers and raw queries are used for persistence
- blockchain execution is wrapped around WDK plus some custom EVM code
- the transaction path currently uses `ethers` in places because there was a WDK EVM gas-estimation bug
- token transfer encoding in `utils` is too ad hoc and should ideally be replaced with safer typed ABI-based encoding
- the current codebase is small, self-contained, and considered workable but not stylistically ideal

On the architecture side, the earlier design questions from the prep doc were useful because they framed the right decisions: old-vs-new flow compatibility, token and chain scope, code model, redemption rules, eligibility boundary, campaign lifecycle, and webhook/status expectations

The most important outcome of the meeting is that the backend ownership model has changed significantly for the new campaign.

The new desired architecture is:

- user submits a promo code through the app
- wallet backend receives it
- wallet backend sends a request to Rumble backend with:
  - `promoCode`
  - `userId`
  - `userIpAddress`
- Rumble backend performs all business validation
- if validation passes, Rumble backend responds with `ok` and a generated claim `id`
- WDK backend then queues and processes the actual on-chain payout
- after processing, WDK backend sends Rumble a webhook:
  - success webhook if payout succeeded
  - failure webhook if payout failed

This new validation endpoint replaces the old `/promo_eligibility` style contract. Andre was explicit that they want promo code validation, user validation, IP checks, limits, amounts, and reporting all to move to their backend so that the WDK side becomes a slim payout client. That directly answers one of the major open questions in the prep doc around where eligibility and business logic should live: for this campaign, it moves to Rumble’s backend, not ours

The consequence of that change is that local promo-code business state is no longer needed on our side. Andre explicitly said we no longer need local `promo campaign` or `promo code` tables in the worker, because all of that migrates to their backend. So the old SQLite role changes from being source of truth for campaigns and codes to, at most, execution or queue tracking on our side. The canonical correlation key for our processing should become the claim ID returned by their backend during validation. That ID should be what we use for payout tracking and webhook correlation.

Business logic ownership was clarified very clearly:

- Rumble backend will validate promo codes
- Rumble backend will validate the user
- Rumble backend will validate the IP address
- Rumble backend will enforce redemption rules and limits
- Rumble backend will decide amounts and token in the validation response
- Rumble backend will maintain reporting, accounting, and audit state
- WDK backend should be a slim client focused on payout execution and status reporting

That means we should not implement campaign usage limits, reusable code business rules, or user-level redemption policy ourselves unless explicitly needed for defensive execution handling.

The reusable-code requirement was confirmed and is important. In the old system, promo codes were effectively unique or single-use from a campaign perspective. In the new system, promo codes are reusable. The example Andre gave was a streamer publicly sharing something like `ABC123`, and the first 500 people redeeming it would receive the promo amount. So the promo code itself is not the deduplication key anymore. Deduplication and limit enforcement are handled on Rumble’s side. This directly maps to the “Will each user receive a unique code, or is it one shared code that many users redeem?” question in the prep doc, and the answer is now clearly shared reusable codes for many users

Related to reward configuration, the final understanding was:

- for now this is single-chain
- the likely chain is Ethereum
- the token should be selectable per campaign or per claim response
- supported tokens should be `USAT` and `USDT`
- Andre specifically said the response includes the amount to pay and the token
- so the API should not hardcode token choice if their response is the source of truth

This is a bit different from the earlier assumption that the campaign would simply be fixed ahead of time in our config. The more final answer is that their backend response will indicate at least `amount` and `token`, while the overall rollout still appears to be one chain only for now. This resolves the reward-scope questions from the prep doc: not multi-chain, but token can vary across the supported set and is part of the contract returned by their backend

On backward compatibility with the old campaign, Francisco raised the question and Andre answered that he is not aware of any plans to reuse the old version. The old March Times Square campaign appears finished, and current needs are only for the new flow. So there is no known product requirement to preserve the old promo behavior, although the idea of a `v2` boundary was still discussed as an engineering option if endpoint semantics become too different. This resolves the “old campaign vs new campaign” section in the prep doc: the expectation is that the new flow is what matters, and legacy support is likely not required unless something changes later

On wallet operations and funding:

- Rumble’s side will fund the payout wallet
- they will also monitor it operationally
- Slack alerting from the worker was part of the previous setup and should remain in some form
- they want a fresh wallet for this new flow
- the currently installed promo worker wallet should not simply be reused
- they expect a new address, new seed phrase, and a newly funded wallet for the new service version

That means operationally the payout wallet is still hosted with the WDK-managed service, but funding and supervision responsibility sits with Rumble.

On implementation style, Francisco advised minimal change where possible:

- if the new requirements are not too different, modify the existing worker and endpoints
- if requirements diverge too much, a `v2` endpoint or cleaner overhaul is acceptable
- but the preferred delivery shape is still a PR against the existing codebase rather than creating an entirely separate unrelated service immediately

At the same time, because the new architecture removes most business logic from our side, the worker should now be thought of as a thin payout executor rather than a promo management service. This is also more aligned with cleaner backend boundaries. In broader WDK terms, `___TRUTH.md` confirms the platform already distinguishes HTTP edge nodes from write-owning workers and uses internal RPC boundaries; the new slim-client design is closer to that separation of responsibilities, even if the legacy promo worker was originally more self-contained and custom  

Practical implementation changes implied by the meeting are:

- remove or bypass local campaign and promo-code tables as business source of truth
- replace worker-side eligibility logic with a call to the new Rumble validation endpoint
- send `promoCode`, `userId`, and `userIpAddress` to that endpoint
- receive `ok` or failure
- on success, also receive a claim ID
- likely also receive token and amount details from Rumble backend response
- queue and execute payout after successful validation
- use claim ID as canonical correlation key in our execution records
- send webhook on payout success
- send webhook on payout failure
- support Ethereum for now
- support payouts in `USAT` and `USDT`
- provision a fresh wallet and seed for this new flow
- preserve low-balance and status alerting
- keep the worker thin and avoid owning business rules like code reuse limits or redemption counts

Items that were previously thought to matter, but are now explicitly not our business logic:

- promo code uniqueness or one-time use
- per-user redemption counting
- code validity windows
- campaign inventory or first-N logic
- user eligibility rules
- IP-based validation
- accounting and reporting state

All of those now belong to Rumble backend.

On environments and delivery:

- Andre said he would finalize and deploy the new APIs sometime this week
- they likely have a staging environment, but exact connection details were not fully clarified in the call
- you asked about staging and how to connect
- Andre indicated Francisco can help with that
- until the endpoints are live, the expectation is that we proceed based on the shared document and likely a mock or sample payloads if needed
- they also shared the document in the group chat and said they would send links after the call
- Francisco said after Alex works on the payment service, they will do an internal review, deploy it, and then test for edge cases

You also confirmed one operational ownership point:

- Alex will work on the service to do the payments

Two smaller but relevant notes:

- Swagger/docs auth had come up earlier in the discussion, and from `___TRUTH.md` we know Rumble Swagger UI is protected by docs basic auth, with a risky fallback if config is missing
- more broadly, `___TRUTH.md` also notes that service-to-service trust in this workspace is still shared-secret based rather than stronger service identity, which is relevant context when thinking about webhook auth and backend-to-backend validation hardening for this integration

The final product and backend understanding from this meeting is:

- this is not creator-address tipping in the implementation discussed on the call
- users still receive the funds
- creators are attribution context for marketing analytics
- Rumble backend becomes the source of truth for promo code validity, eligibility, limits, amount, token, and claim state
- WDK backend becomes a slim payout executor
- the old SQLite-heavy promo state model should largely disappear from business logic
- reusable codes are expected
- old campaign compatibility is probably not needed
- target execution is single-chain, likely Ethereum
- token support should cover `USAT` and `USDT`
- a fresh payout wallet must be created and funded by Rumble’s team
- success and failure must be pushed back to Rumble via webhooks
- claim ID from Rumble should be the canonical key

If I compress the meeting into one implementation sentence:

We should turn `rumble-promo-wrk` from a SQLite-backed promo validation service into a thin payout worker that calls Rumble’s new validation API, trusts their claim decision and returned claim ID, executes the transfer on Ethereum in `USAT` or `USDT`, and reports the final result back by webhook, while Rumble owns all promo business logic, limits, reporting, and wallet funding.
