This folder includes context data of old task you worked on, and you even up finding out that the problem is in Hyperswam, not MongoDB issue. 

You already did find in your analysis in the file DIAGNOSIS_REPORT.md the problem is 'Hyperswarm RPC pool timeout race condition' with 100% assurance. I raised PRs to solve this issue but they were not merged yet. Now the team is asking me to reproduce the issue locally to confirm to them with 100%.

For your understanding, these are the PRs I raised to solve this issue:
https://github.com/tetherto/wdk-data-shard-wrk/pull/115
https://github.com/tetherto/tether-wrk-base/pull/19
https://github.com/tetherto/rumble-data-shard-wrk/pull/94
Check the PRs, and if can't, let me know how to give you access to them. 
The 3 repos have the branch fix/hyperswarm-pool-destoyed-error chekced out here. 

Before you go about this task, it's probably helloing to read ‘./_docs/___TRUTH.md’ for context. Optionally you can read all what's in ‘./_docs’ to get a good grasp of this app.

Your taks is to help me reproduce the issue locally. I want you to give me, step by step, what should I do to reproduce the issue locally. 