Based on everything so far, the implementation path should be:

Keep the existing surface area as much as possible. Reuse rumble-app-node POST /api/v1/promo/:campaignId/claim and the existing worker RPC contract, then modify internals only where the new campaign requirements force it. That matches both the current architecture and the explicit goal of minimal change for testing and rollout risk

Refactor rumble-promo-wrk from the old single-purpose promo flow into a reusable multi-campaign worker. The current worker already has SQLite-backed promo_campaigns and promo_codes, plus claim and claim-status RPCs, so the main task is extending semantics rather than introducing a new service

Add support for reusable codes under the new campaign model. The old design assumes short promo codes with claim-state tracking, but this new flow needs the same code to be claimable by multiple users, so the dedup rule has to move from “code is unique and consumable once” to a campaign-specific user or wallet claim invariant

Lock the invariant for dedup before coding. The key backend rule to define is whether it is one claim per wallet per campaign or one claim per user per campaign or campaign type, because that changes schema, indexes, and claim validation logic

Support Polygon in the worker execution path. The current implementation is hard-coded around VALID_BLOCKCHAINS=['ethereum'] and a singular chain config, so chain configuration, token config, transaction building, gas estimation, and send flow all need to be generalized at least enough to handle Polygon cleanly

Likely keep one campaign = one token + one chain for now unless Andre says otherwise. That is the safest minimal-change backend shape and is explicitly one of the main architecture questions in the notes. It avoids turning this into a pluggable reward engine too early

Review funding-wallet strategy. Today the reward is sent from a hot wallet on the worker, and one open design question is whether to keep one shared wallet or isolate by campaign. For minimal work, shared may be fine, but per-campaign wallets are cleaner for nonce management, refill ops, and auditability if they expect concurrent campaigns at scale

Keep campaign lifecycle lightweight for this iteration. Since they want minimal work, the likely short-term path is DB or config-driven campaign setup, not a full admin system, but this still needs to be explicitly decided because campaign creation is a core open item in the planning doc

Clarify code generation ownership with Andre. The notes already flag this: are codes pre-generated and loaded into the DB, generated on demand, or both, and who owns the loader job. Since they mentioned a standalone script and local SQLite flow, the simplest near-term option is still pre-generation plus load script, unless product now wants live dynamic code issuance

Decide where eligibility lives. Today eligibility is enforced by the worker calling back into the Rumble backend over HTTP via /promo_eligibility, but the planning notes explicitly question whether that should move up into rumble-app-node so the worker becomes a pure execution engine. Architecturally, moving eligibility to app-node is the cleaner boundary, but keeping it in the worker is the smallest change

Preserve backward compatibility if similar old campaigns may still run. The notes explicitly raise whether this should remain backward compatible or become a v2 shape. If existing campaign behavior might still recur, introduce a versioned internal flow or campaign-type-specific logic instead of hard-breaking the worker contract

Clean up the transaction path inside the worker. Right now the implementation uses a server-side WDK wrapper plus some custom EVM code, and falls back to ethers because of a WDK gas estimation bug. If that bug is fixed upstream, refactor back toward the standard WDK path; otherwise keep ethers but isolate it behind a clean execution adapter so Polygon support does not spread more custom logic through the service

Replace the ad hoc token-transfer encoding with a typed ABI-based builder. From the walkthrough, this is currently too manual. Even if you keep the rest of the worker simple, this is a good hardening step because transaction construction is safety-critical.

Keep persistence in SQLite for now unless concurrency or operational needs force a move. The current worker is intentionally small and self-contained with SQLite state, which is consistent with minimal change and local reproducibility. A DB migration would add risk without clear product benefit at this stage

Retain rate limiting and status semantics unless FE asks for change. The current app-node route is already rate-limited and has known status outcomes like claimed | paying | paid | failed, plus HTTP error mappings. Reusing that contract reduces FE churn and lets the worker evolve behind a stable API

Add or preserve operational alerts for low wallet balance. They mentioned Slack alerts were used before to top up the bot wallet during the campaign. Even if simplified, some balance threshold alerting should remain because payout failure due to an empty hot wallet is the highest-probability operational issue in this design.

Keep the current deployment model unless there is a strong reason to realign now. The promo flow today is routed through promoService[] and worker selection on app-node, but one of the highest-leverage architecture questions is whether promo should stay on that custom model or align with the normal WDK proc/api split over Hyperswarm RPC. The WDK truth doc confirms the standard pattern is proc workers owning write work and API workers reading via shared capability-based transport, so long-term normalization makes sense, but for this campaign the safer move is probably to avoid an architectural migration unless it is already cheap to do

Validate local dev and docs paths as part of implementation. The broader WDK notes show setup and docs drift exist in this workspace, and Swagger/docs auth defaults are not ideal, so for this worker specifically it is worth making sure the local standalone flow, scripts, config, and auth instructions are actually reproducible before handoff