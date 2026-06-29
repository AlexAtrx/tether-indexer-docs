---
name: address-pr-comments
description: >-
  Locally review GitHub PRs and handle Alex's GitHub PR review comments. Use
  when Alex says "review" with one or more PR links, asks to review a
  teammate's PR, evaluate a PR, reply to review feedback, push back on
  comments, refactor/fix from comments locally, draft short human replies,
  discuss PR comments in Slack, link a PR to its original Asana ticket, or
  decide which review comments deserve local code changes versus reply-only
  handling. GitHub is read-only for this skill: never post comments, submit
  reviews, resolve threads, approve/request changes, or push commits.
---

# Address PR Comments

## Goal

Handle PR reviews and PR feedback the way Alex expects: inspect the PR locally, find only real defects or risks, and return exact file/line findings with short human comments Alex can paste manually. Never write anything to GitHub and never push commits while using this skill.

## Non-Negotiables

- Always check out the PR branch locally before changing code or drafting final replies.
- If Alex writes only `review` plus one or more PR links, treat it as a teammate PR review request.
- GitHub is read-only: use GitHub only to fetch metadata, diffs, branches, review threads, or files.
- Never post comments, submit reviews, approve, request changes, resolve threads, update labels, edit PR text, or otherwise write anything on GitHub.
- Never run `git push`, never push commits, and never create a remote branch while using this skill.
- Do not use `gh pr review`, GitHub mutation APIs, browser submit buttons, or any other write path.
- Keep all results local in the Codex chat/console.
- For review-only requests, do not edit files unless Alex explicitly asks for local code changes.
- Report only bad stuff: correctness bugs, broken edge cases, missing required validation/tests, regressions, security/privacy risks, or maintainability problems that matter.
- Skip praise, summaries of what looks good, weak preferences, style nits, and speculative findings.
- Every review finding must include the exact file, exact line number, the code line to comment on, and a concise paste-ready comment.
- Draft a reply for every PR review comment in the console, even if the right action is pushback, acknowledgement, or no code change.
- In the final output, show each original PR comment and its draft reply directly underneath it.

## Required Context

Before reviewing, changing code locally, or drafting replies:

1. Resolve the PR URL, repo, base branch, head branch, and head owner.
2. Check out the PR branch locally. Preserve unrelated local changes.
3. Fetch thread-aware review comments, including outdated/resolved state.
4. Link the PR to its original ticket/context:
   - Read PR title/body/commits for `RW-*`, `WDK-*`, Asana links, Slack links, and related PRs.
   - Search `_tether-indexer-docs/_tasks/` for matching ticket folders or notes.
   - If the PR references an Asana ticket URL and the task is not local, use the project `fetch-asana-ticket` skill first.
   - If a Slack thread is part of the ticket context and Alex asks to use Slack, read the relevant Slack context before deciding.
5. Read the relevant code flow, not only the commented lines. Include upstream callers and downstream effects when deciding whether feedback makes sense.

## Review-Only PR Requests

When Alex gives a PR to review, especially with a terse request like
`review <GitHub PR URL>`, perform a local-only review of the PR diff and relevant
surrounding code. Multiple PR links mean review each PR independently.

Use read-only GitHub operations such as `gh pr view`, `gh pr diff`, read-only
GraphQL queries, or a local checkout. Never use `gh pr review`, mutation APIs,
browser actions, or any submit path to leave review text on GitHub.

Instead, return only the comments worth leaving. For each one, include:

- **File**: the exact repo-relative file path.
- **Line**: the exact line number where Alex should leave the comment.
- **Code**: the exact code line to comment on, quoted briefly so Alex can find it.
- **Comment**: a brief, plain-language note that sounds human and layman-friendly.

Keep suggested comments short. Skip weak or nitpicky findings. Do not include
long rationale unless Alex asks for the reasoning separately.

Anchor each finding to the tightest changed line in the PR diff. If the issue
spans multiple lines, comment on the first line where the bad behavior becomes
clear. If the concern is missing coverage, comment on the changed line that
introduced the behavior requiring a test. If an exact line cannot be determined,
do not report the finding until it can be anchored precisely.

Use this output shape for review-only findings:

```text
PR: <repo>#<number> <title>

Finding:
File: <path>
Line: <line number>
Code: <exact code line>
Comment: <short paste-ready comment>
```

If there are no material findings, say only that there are no blocking findings.

## Comment Triage

For each review thread, decide one of:

- **Refactor/fix locally**: the comment points to a real readability, correctness, maintainability, or test issue.
- **Push back**: the comment would regress behavior, remove an intentional contract, or oversimplify important edge cases.
- **Acknowledge only**: the comment is already handled, outdated, or informational.
- **Ask a question**: only when the choice changes behavior and local context cannot decide it.

Prefer the existing repo style and smallest useful change. Do not refactor unrelated code.

## Code Changes

When Alex explicitly asks to address existing review comments locally and a
comment deserves code changes:

1. Make the local refactor/fix on the checked-out PR branch.
2. Keep changes traceable to the review thread.
3. Run focused tests and lint for touched files. Run broader checks only when risk warrants it.
4. If repo-wide checks fail on unrelated baseline issues, say that clearly and do not patch unrelated files.
5. Stop with local uncommitted changes unless Alex explicitly asks for a local commit.
6. Never add AI attribution, `Co-authored-by`, generated-by footers, or similar metadata.

Do not push from this skill. If Alex asks for publishing, stop and use an
explicit commit/publishing workflow outside this PR-review skill.

## GitHub Replies

For PR review requests, never post in GitHub; give Alex manual comment
suggestions instead.

For handling existing review threads, never post replies in GitHub. Give Alex
manual reply drafts to paste.

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

Manual draft style:

- Keep replies short, factual, and nice.
- Make the meaning clear for developers without over-explaining basics.
- Do not use em dashes.
- Do not sound polished or corporate.
- Occasional lowercase sentence starts are fine, but not every reply.
- If Alex explicitly asks for human imperfection, allow at most one harmless typo across the drafts. Do not make it affect readability.
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
- For review-only requests: only the bad findings, grouped by PR, with exact file, line, code, and paste-ready comment.
- For existing review-thread handling: review comments handled locally.
- Reply draft for every original PR comment.
- Tests/lint run and results.
- Any checks blocked by unrelated baseline failures.
- Confirmation that no GitHub comments, reviews, approvals, thread resolutions, commits, or pushes were performed.

Keep the final summary concise.
