# Questions for Rumble Tech Lead — creator-tipping promo

> **Context for the meeting:** Tether's backend ran a previous promo campaign with Rumble where the user typed in a code and received tokens themselves. The new campaign is different: the user enters a code **and a creator's public address**, and the credit goes to that **creator**, not to the user. I'm new to this feature on our side and want to lock down what the two backends need to do together.
>
> Below I lead with the new mechanic, then cover the rest.

## 1. The new mechanic (creator tipping)

- Just to confirm we're aligned: the user redeeming a code is not the one being paid — the credit goes to a creator's address that the user picks. Right?
- Where does the user choose the creator — typing the address freehand, picking from a list inside your app, scanning a QR code, something else?
- Can a user tip more than one creator with the same code, or is one code = one creator forever?
- Can the same creator be tipped by many different users? Any cap per creator?
- Should we block "self-tipping" (the user submits their own wallet as the creator), or is that allowed?

## 2. Recipient creator address — what we should accept

- Will Rumble give us a list of valid creator addresses, or should our backend accept any well-formed address?
- If there's a list: how do we get it — a config file, an API endpoint on your side, embedded in the eligibility check, something else?
- How does Rumble decide who counts as a creator? Anyone with a Rumble account, or a curated/onboarded set?
- What should happen if a user submits an address that looks valid but isn't a known creator — accept and pay anyway, or reject?
- What should happen if the address is malformed — what error message do you want shown?

## 3. Old campaign vs new campaign

- Is the previous promo campaign finished, or will it continue to run alongside the new one?
- If both will run, are you OK with us putting the new campaign on the same API route (with a flag on the campaign), or do you want a separate v2 path?
- Are there still users out there with un-claimed codes from the old campaign that we have to keep honoring?

## 4. The reward itself

- What token is being sent to the creator, and on which blockchain — Polygon, Ethereum, both?
- Is the amount the same for every claim, or does it vary per creator / per code?
- Who funds the wallet that pays out the creators — your team or ours?

## 5. The code

- Will each user receive a unique code, or is it one shared code that many users redeem?
- Who generates the codes — your side or ours?
- How does the user actually receive the code — in your app, by email, social post, somewhere else?
- What format and length will the codes be? (Today's are 6-character alphanumeric.)

## 6. How many redemptions per user

- Should one user be allowed one total redemption, one per creator, or unlimited as long as they have codes?
- If they try to redeem the same code twice, what should we tell them?
- If they try to redeem a different code but tip the same creator they already tipped, allowed or blocked?

## 7. Eligibility (where our backends already talk)

- Our worker currently calls your `/promo_eligibility` endpoint before allowing a claim. Are we keeping that contract, or do you want to change fields / add a creator-validation step there?
- What does "eligible" mean for this campaign — KYC, country, account age, follower count, anything else?
- Should we check eligibility every time a user tries to redeem, or only once per user?
- Would it be cleaner if our public API (one layer above the worker) made that eligibility call instead of the worker — any preference on your side?

## 8. Campaign lifecycle

- When does the campaign start and end?
- How does it end — fixed date, when all codes are used, when the funding wallet runs out, or you tell us to stop?
- If our payout wallet runs low, who refills it — your team or ours? Who do we alert?

## 9. Errors and what the user sees

- If a payout transaction to a creator fails on-chain (reverts, no gas), what should the user see in your app?
- Should the **creator** also be notified somehow (in your app, by email), or does only the redeemer see status?
- Do you need real-time webhooks from us when a claim succeeds / fails, or is it enough that your app polls our status endpoint?

## 10. Rollout and testing

- When does this campaign need to be live?
- Is there a staging environment where we can run the end-to-end flow together before launch?
- Who flips the switch on launch day — your frontend deploy, or our backend enabling the campaign?

## 11. Documentation and other contacts

- Is there a requirements / product doc I can read? (There's a Google Doc linked on our ticket — I'm not sure I have access yet.)
- Who else on your side should I be talking to — product manager, frontend engineer, ops, security?
