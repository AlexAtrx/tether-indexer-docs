Your focus is on the repo: ./rumble-data-shard-wrk

The original task was:

+++++++++++++++++++++++

## Context:
Ensure uniqueness of addresses in wallet creation or update
Currently, we allow users to create wallets with addresses that already exist. We throw warning in such scenarios. We need to ensure that such issues result in rejection of the user request.

1. Use GitHub CLI to fetch the diff and comments of this PR: 
https://github.com/tetherto/rumble-data-shard-wrk/pull/97
If you cannot access the PR (e.g. code not visible or access denied), stop and inform me — we’ll address the access issue together.

One of the comments particularly say:

---
================================================================================
Migration: Normalize Wallet Addresses (MongoDB)
================================================================================
Mode: DRY RUN (no changes will be made)

Step 1: Scanning wallets collection...

  Wallet 2fd0143e:
    ethereum: 0x870585e3Df9da7ff5dcd8f897ea0756f60f69cc1 → 0x870585e3df9da7ff5dcd8f897ea0756f60f69cc1

================================================================================
Summary:
================================================================================
Total wallets: 7
Wallets to normalize: 1
Wallets unchanged: 6
Errors: 0

Addresses by chain:
  ethereum             7 (case-sensitive)
  ton                  7 (case-sensitive)
  bitcoin              7 (case-sensitive)
  tron                 4 (case-sensitive)
  polygon              4 (case-sensitive)
  solana               4 (case-sensitive)
  spark                4 (case-sensitive)

================================================================================
DRY RUN MODE - No changes applied
================================================================================
Would normalize addresses in 1 wallets.
To apply changes, run without --dry-run flag.
2025-12-02T08:43:24.191Z finished running /mnt/data/code/tether/rumble/rumble-data-shard-wrk/migrations/mongodb/2025-11-26_normalize-wallet-addresses.js

---

2. Review the code changes in the PR **and** the existing comments on it.
	* Locally check the code of the repo on which the PR is raised.
	* Evaluate whether the comments align with the code logic.
	* Identify any comments that are unclear, misleading, incorrect, or outdated with respect to the code.
	* Provide concrete feedback for each comment.
	* Important: your target is the truth, follow convension, and best practice; not argument or supporting my work.

**Important**
- Never commit or push any code.

+++++++++++++++++++++++

I did this task and changed some code locally. 

Make sure you understand the comments and their purpose (the ones in the PR and the one I placed here for importance). 

Check the local code and figure if it does address the needed job.

Think about this from scratch - meaning: we don't need to stick to I wrote so far. We can change that. The base and the requirement is what matters. 

This is the 1st analysis of the PR: _docs/tasks/check_scurity_bug_PR/1st_analysis.md

Make sure you review the code, the comments, the analysis, then provide your feedback.