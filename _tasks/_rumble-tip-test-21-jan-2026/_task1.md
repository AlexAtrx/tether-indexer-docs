## The ticket we are trying to handle now is:

Test staging app with backend log tracing

The mobile team, that is the Rumble mobile team, is confirming that they always send a payload in this.
Run a test using staging mobile app wallet:
send tip and trace payload, id, ld, etc in the backend
check propagation of data `

---

Go through all the repos that are in this project. I'm talking about only the coding repos.

Exmaple: This is a file that handles sending the webhook when there is a tip or rant being sent by a user on Rumble wallet to a Rumble channel: rumble-data-shard-wrk/workers/proc.shard.data.wrk.js

The above piece of code shows where the rumble webhook is being called and what are the conditions for it to be called.
Particularly the line 402:

```
if (type === WEBHOOK_TYPES.RANT && payload) {
...
```

The Rumble mobile app team is confirming that they always send a payload when there is a tip being sent to the channel. In our finding, we suspect that the payload is not being sent.

We have an issue where if the fan sends a tip to a channel in Rumble, that is a live channel, the tip doesn't show in the chat.

What we need to find in this ticket and in this test is are we 100% sure that our backend does send the tip message if it receives a payload? The issue might not be in this report only. It might be some upstream or downstream dependencies. I need to verify and double check that.

So your task in this is only to answer this plain question. Does the backend 100% send the webhook if the payload is given?
