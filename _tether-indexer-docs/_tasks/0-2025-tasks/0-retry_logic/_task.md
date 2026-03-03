## Context

- This is a PR that has been merged into the dev branch: https://github.com/tetherto/wdk-data-shard-wrk/pull/115

- Using Github CLI you can still check it changes and understand why they are done based on the PR description and the comment messages. As a continuation of this PR work, you are requested to do the following:

---
- Maybe you can add retry for read requests along with the timeout as part of this ticket: Add timeout for read operations for mongodb. 
- But let's make this option configurable, so that we can set retry to 1 in case we notice more timeouts.
---

## Notes

- I believe the work is required on the same repo of the above PR, which is wdk-data-shard-wrk. However, it may extend into all the other repos that use mongodb, such as the indexer repo. 

## Task
- Read _docs/___TRUTH.md for mroe context awreness and app situation. 
- Add retry for read requests along with the timeout as part of this ticket: Add timeout for read operations for mongodb. 
- But let's make this option configurable, so that we can set retry to 1 in case we notice more timeouts. Make sure you use configuration the rihgt way according to the app structure.
- When done, place a short sumamry in _docs/tasks/retry_logic 

PS: Never commit or push code.