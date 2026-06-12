# Missing context

No images or attachments were posted on this ticket; it is a written refactor spec. There are no Slack threads, logs, external tickets, or missing artifacts referenced.

- [ ] **Blocked flag:** ticket is marked **Blocked? = BLOCKED** with no recorded reason. **Need from Alex:** what is the blocker (waiting on Rumble child-repo readiness? on an architecture sign-off?), and is it still blocked now that it was reassigned to you on 2026-06-05. **Source:** custom field, set 2026-04-30.
- [ ] **HyperDB migration semantics:** WDK HyperDB wallet specs currently contain optional `channelId` and an `active-wallets-by-channel-id` index. **Need from Alex/reviewer:** confirm whether WDK should merely stop using these fields/indexes or perform a versioned schema/index removal. Avoid destructive HyperDB edits without an explicit migration decision. **Source:** local code audit 2026-06-09.

Clarified on 2026-06-09: the ticket is definitely to be split; no separate scope confirmation is needed. Local code audit also found rant handling already lives in Rumble-only code, so there is no separate WDK rants removal item.
