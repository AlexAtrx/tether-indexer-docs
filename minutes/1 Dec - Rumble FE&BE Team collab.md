# Rumble FE&BE Team collab

## Action Items
- Ask George and Jonathan (frontend/SDK) to review how the mobile app tracks UserOperation hashes and handles bundler retries.  
- Share the location of the backend transaction model (repo path or file) with the mobile team.  
- Verify that address‑normalization changes won’t break any mobile‑side flows; run targeted tests.  
- Add the `trace-id` header to mobile requests (or ensure the backend generates it when missing).  
- Prioritize the ticket for read‑request timeouts before tackling duplicate‑notification work.  
- Continue fixing the address‑uniqueness security issue and close it today.  
- Move forward with the lubrication‑swap notification ticket after confirming it isn’t already picked up.  

## Key Decisions
- Use the pending Rumble bundle as the official staging bundle after configuration.  
- Opt for a dedicated staging environment for v2 first; defer the dev environment until later.  
- Avoid adding an in‑app environment switch for now – it’s not the preferred approach.  
- Implement swap‑transaction labeling on the backend rather than relying on local mobile tags.  

## Issues Discussed
- **ERC‑4337 retry flow:** first bundle failed (invalid nonce), bundler auto‑retried with a new tx hash; backend indexed only the successful retry, mobile app stayed on the failed hash.  
- **Ongoing transaction UI bug:** mobile shows the original failed transaction forever because it never learns about the retry.  
- **Swap transaction labeling:** local tags are lost on logout/device change, causing UI inconsistencies.  
- **Notification persistence:** similar loss issue noted, but not a current request—added to backlog.  

## Technical Updates
- Deployed new transaction‑pushing mechanism on dev; no memory leaks or delays observed.  
- Processor deployment script now supports multiple chains; hard‑coding chain list is acceptable for now.  
- Completed pool‑connection fix (merged by Vegan, reviewed by Osman).  
- Ongoing security audit; monitoring for additional backend fixes.  

## Backend Enhancements
- Will tag swap‑related transactions with a `swap` label in transaction metadata.  
- Address normalization: all wallet addresses will be stored in lowercase; migration will run on existing data.  
- Introduce `trace-id` propagation to enable end‑to‑end request tracing.  

## Mobile App Considerations
- Implement polling of the bundler for the final transaction hash and update local state on retry success.  
- Ensure the app can handle the new `trace-id` header.  
- Test impact of address‑normalization on mobile address handling.  
- Plan to re‑enable the old environment‑switch mechanism only if absolutely needed.  