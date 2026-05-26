# Context
This is a campaign feature for Rumble:
_tether-indexer-docs/_tasks/17-13-may-26-RW-1691-campaign-be-work
The directory underdone multiple spec changes along with the way, so take it with an 'old consideration'.

There is a prior V1 version of this campaign that ran sometime ago. It's in the code. 

These are the final, definitive PRs that were approved by most of the team:
  - rumble-app-node: https://github.com/tetherto/rumble-app-node/pull/219
  - rumble-promo-wrk: https://github.com/tetherto/rumble-promo-wrk/pull/51

However, backed lead stipulated a refresh and simplification. 

This is what he wants:

---
- move code from v2 to v1 so code delta is easier to review
- restore the deleted pay scripts
- move queries into ./queries
- in general try to reduce complexity, don't handle all minor edge cases, leave them in error
- Update the claimCode RPC endpoint to accept new parameters,
- Call rumble endpoints for validating the code
- Add the code to the database
- Modify the existing payout _processClaimedCodes and _monitorPayingCodes to use the new repository that we've defined.
- Once the the code changes to paid or failed, fire the webhook to the rumble server.
---

In short and important: the approach must be minimal (that is to say: no major changes over V1).

PS: we merged a pervious two PRs that have the very same code:
https://github.com/tetherto/rumble-app-node/pull/211
https://github.com/tetherto/rumble-promo-wrk/pull/46
They are subject to revert (will be reverted or are reverted).

# Task
1- Go through the new PRs code (key source of truth) and understand it. 
2- Find and understand V1 code. 
3- Understand the requirement on how to start from V1. 

Plan for updating the new PRs to meet the requirements. 
Please your plan in a .md file here.