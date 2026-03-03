# Task

This is a task that you need to handle with the care. I think deeply about this task. 

## This is the ticket:
Update the caching of endpoints to use bfx-facs-redis as opposed to lru cache
We've noticed issues with balance fluctuations due to the usage of lru cache. 
Get a sense of how Redis is used in wdk-indexer-app-node/workers/base.http.server.wdk.js

## Slack discussion
The problem is discussed in the Slack discussions _docs/_slack/fluctating_balanc.md. Read the discussion in full to understand the issue.

## Task
- Understand the issue. 
- Figure what is bfx-facs-redis and her it's used and how it can replace lru.
- Tell me what's the issue and how to fix it in a concise way.

### Important notes
- Context: 
Read ‘./_docs/___TRUTH.md’ for context. 
Optionally you can read all what's in ‘./_docs’ to get a good grasp of this app.
- This app is not a TDD yet. Tests (units and integration might be outdated). Don’t change code to match unit test. If you must deal with unit tests, rather change unit tests to match code.