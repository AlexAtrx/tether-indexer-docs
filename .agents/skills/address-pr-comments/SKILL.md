---
name: address-pr-comments
description: Address Alex's GitHub PR review comments end to end. Use when Alex asks to evaluate, reply to, push back on, refactor for, fix, commit, push, or otherwise handle comments on a GitHub pull request, especially in Tether/Rumble repos. This includes requests to discuss PR comments in Slack, draft short human replies, link a PR to its original Asana ticket, or decide which review comments deserve local code changes versus GitHub replies.
---

# Address PR Comments

## Goal

Handle PR feedback the way Alex expects: understand the ticket and full flow first, make only justified code changes, push the proper PR branch when asked, and post short human replies only where a reply is needed.

## Required Context

Before changing code or replying:

1. Resolve the PR URL, repo, base branch, head branch, and head owner.
2. Check out the PR branch locally. Preserve unrelated local changes.
3. Fetch thread-aware review comments, including outdated/resolved state.
4. Link the PR to its original ticket/context:
   - Read PR title/body/commits for `RW-*`, `WDK-*`, Asana links, Slack links, and related PRs.
   - Search `_tether-indexer-docs/_tasks/` for matching ticket folders or notes.
   - If the PR references an Asana ticket URL and the task is not local, use the project `fetch-asana-ticket` skill first.
   - If a Slack thread is part of the ticket context and Alex asks to use Slack, read the relevant Slack context before deciding.
5. Read the relevant code flow, not only the commented lines. Include upstream callers and downstream effects when deciding whether feedback makes sense.

## Comment Triage

For each review thread, decide one of:

- **Refactor/fix locally**: the comment points to a real readability, correctness, maintainability, or test issue.
- **Push back**: the comment would regress behavior, remove an intentional contract, or oversimplify important edge cases.
- **Acknowledge only**: the comment is already handled, outdated, or informational.
- **Ask a question**: only when the choice changes behavior and local context cannot decide it.

Prefer the existing repo style and smallest useful change. Do not refactor unrelated code.

## Code Changes

When a comment deserves code changes:

1. Make the local refactor/fix on the checked-out PR branch.
2. Keep changes traceable to the review thread.
3. Run focused tests and lint for touched files. Run broader checks only when risk warrants it.
4. If repo-wide checks fail on unrelated baseline issues, say that clearly and do not patch unrelated files.
5. Commit with a concise message explaining what changed.
6. Never add AI attribution, `Co-authored-by`, generated-by footers, or similar metadata.
7. Push to the proper PR head branch only when Alex asked to execute/push.

## GitHub Replies

Post replies only when Alex asks for GitHub posting. Do not post drafts by default.

When posting:

- Keep replies short, factual, and nice.
- Make the meaning clear for developers without over-explaining basics.
- Do not use em dashes.
- Do not sound polished or corporate.
- Occasional lowercase sentence starts are fine, but not every reply.
- If Alex explicitly asks for human imperfection, allow at most one harmless typo across the posted replies. Do not make it affect readability.
- Never include AI attribution, generated-by text, or co-author wording.
- Do not mention internal process unless it helps the reviewer.
- Prefer "done" for implemented comments and one-sentence rationale for pushback.

Examples:

```text
done, moved the policy selection into `_getTxWebhookRetryPolicy()` so the job does not branch on the retry phase inline.
```

```text
yep, shallow merge works if overrides must be full objects. I kept partial overrides here, so `{ bitcoin: { maxRetries: 5 } }` still keeps the bitcoin retry delay.
```

```text
I kept one raw shape check before merge. Otherwise bad config like `bitcoin: []` can be hidden by defaults and the final merged policy still looks valid.
```

## Slack Replies

When Alex asks for short answers to paste into Slack:

- Answer in the same short, human style as GitHub replies.
- Do not post to Slack unless Alex explicitly asks.
- Use the PR/ticket notes if available, but do not dump the whole context.
- Give one direct answer and, if useful, one tradeoff.

## Final Report To Alex

After execution, report only high-signal facts:

- Commit hash and message.
- Branch pushed.
- Threads replied to or intentionally not replied to.
- Tests/lint run and results.
- Any checks blocked by unrelated baseline failures.

Keep the final summary concise.
