## Task 2

This task is to debug why **Rants** and **Tips** sometimes do not appear in Rumble live channels.

On Rumble, creators can host **live channels** where viewers can send:

- **Rants** → money **with a message**
- **Tips** → money **without a message**

Both should appear in the live chat.

### What works

During a live debugging session with a tester:

- The tester shared a Rumble live channel.
- From my mobile app, I sent a **Tip**.
- The Tip appeared correctly in the chat.
- The **Rant** feature also works correctly and displays in the chat.

So both Rants and Tips are confirmed to work in some cases.

### The problem

Despite using the **same app version**, it is **100% confirmed** that:

- The tester and another tester **sometimes do not see**:

  - Rants
  - Tips

- This happens intermittently.
- Neither the Tip nor the Rant shows in the chat during these cases.

### Logs & investigation

I captured live logs during testing.
The logs were specifically filtered for this line:

> **"Notification req include payload and transactionHash"**

This log was added to verify whether the **payload is being sent from the frontend**.

You can find the log output here:

```
_docs/tasks/_rumble-tip-test-21-jan-2026/Explore-logs-2026-01-21 14_18_22.json
```

In these logs:

- Some values appear as `undefined`.
- It is **not yet clear**:

  - Which exact fields are undefined
  - Why they are undefined

Despite this:

- The webhook **is** being sent to Rumble.
- Rants and Tips **sometimes** appear correctly.

### Additional analysis notes

There is also a file containing thoughts, monologues, and speculative analysis:

```
_docs/tasks/_rumble-tip-test-21-jan-2026/thoughts-analysis.txt
```

These notes may suggest possible causes, but:

- They are **not confirmed**
- They should **not** be treated as factual conclusions

### Goal

The objective is to:

- Identify why Rants and Tips **sometimes fail to appear**
- Understand what the `undefined` values represent
- Determine whether the issue is:

  - Frontend payload construction
  - Backend processing
  - Webhook handling
  - Rumble-side ingestion

- Find the **root cause** of the inconsistency
