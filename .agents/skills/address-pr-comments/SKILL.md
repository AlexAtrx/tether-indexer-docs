---
name: address-pr-comments
description: Address Alex's GitHub PR review comments end to end. Use when Alex asks to review a PR, evaluate, reply to, push back on, refactor for, fix, or otherwise handle comments on a GitHub pull request, especially in Tether/Rumble repos. This includes requests to check out a PR branch locally, address comments locally without committing or pushing, draft short human replies, discuss PR comments in Slack, link a PR to its original Asana ticket, or decide which review comments deserve local code changes versus reply-only handling.
---

# Address PR Comments

## Goal

Handle PR feedback the way Alex expects: understand the ticket and full flow first, check out the PR branch locally, make only justified local code changes, do not commit or push on the first pass, and give Alex short human reply drafts for every review comment.

## Non-Negotiables

- Always check out the PR branch locally before changing code or drafting final replies.
- First-pass handling is local-only: edit files locally as needed, but do not commit and do not push.
- Never post, resolve, submit, approve, request changes, or otherwise write anything on GitHub on the first round.
- Do not perform any GitHub write until Alex has reviewed the local result and explicitly approved that specific write action.
- Draft a reply for every PR review comment in the console, even if the right action is pushback, acknowledgement, or no code change.
- In the final output, show each original PR comment and its draft reply directly underneath it.

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

## PR Review Requests

When Alex gives a PR to review, never post comments, reviews, approvals, or
requests for changes in GitHub. Do not use `gh pr review`, `gh api`, or browser
actions to submit review text.

Instead, return only the comments worth leaving. For each one, include:

- **Line**: the file and exact code line under which Alex should comment.
- **Comment**: a brief, plain-language note that sounds human and layman-friendly.

Keep suggested comments short. Skip weak or nitpicky findings. Do not include
long rationale unless Alex asks for the reasoning separately.

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
5. Stop with local uncommitted changes unless Alex explicitly asks for a separate commit/push follow-up after reviewing the result.
6. Never add AI attribution, `Co-authored-by`, generated-by footers, or similar metadata.

If Alex later explicitly approves committing or pushing, make that a separate action after the first-pass report. Keep the commit concise and push only the proper PR head branch.

## GitHub Replies

For PR review requests, never post in GitHub; give Alex manual comment
suggestions instead.

For handling existing review threads, post replies only when Alex explicitly
asks for GitHub posting. Do not post drafts by default.

On the first round, always return console-only drafts using this shape for each
review comment:

```text
Original comment:
<reviewer's exact comment text>

Reply draft:
<short casual reply Alex can paste>
```

Keep reply drafts casual, human-looking, and not verbose. Prefer one sentence.
Use "done" for implemented comments. For pushback, give the concrete reason
without sounding formal.

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

- Checked-out branch.
- Local files changed and whether they are uncommitted.
- Review comments handled locally.
- Reply draft for every original PR comment.
- Tests/lint run and results.
- Any checks blocked by unrelated baseline failures.
- Any commits, pushes, or GitHub replies intentionally not performed because Alex has not approved them yet.

Keep the final summary concise.
