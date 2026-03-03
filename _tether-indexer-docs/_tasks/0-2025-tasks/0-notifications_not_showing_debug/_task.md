### Context

This task concerns the **INDEXER** project.  
A canonical reference file for this project exists at:

```
_docs/___TRUTH.md
```

Use it whenever needed to understand the project’s conventions, architecture, or constraints.

These repos are deployed in Staging:
https://github.com/tetherto/wdk-data-shard-wrk/pull/122
https://github.com/tetherto/rumble-app-node/pull/94
https://github.com/tetherto/rumble-data-shard-wrk/pull/104
https://github.com/tetherto/rumble-ork-wrk/pull/63

The repos have to do with handling this issue of double notifications prevention: \_docs/tasks/Duplicate_swap_notifications_observed

### Issue

Now we have another issue. The issue is that **swap notifications are emitted by the backend on staging** (`SWAP_STARTED` logs appear in Grafana) but **the mobile app doesn’t receive them**. In production, version 1 of the Rumble walle t receives notifications correctly, but version 2 on staging does not. The backend deployment yesterday included the double-notification fix, which doesn’t block events, so the problem likely lies in the **notification delivery path or mobile listener**, not in event emission.

We believe that maybe these PR's effected the notifications in staging and the frontend app now doesn't receive any notifications on swaps.

### Task

- Check all the repos and codes.
- Checkout the relevant branches in the relevant repos locally.
- Check the code changes.
- Try to figure how can the code change break the notification mechanism.
