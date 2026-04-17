---
description: Triage unanswered PR review comments on a tetherto PR (author = AlexAtrx). Classify each and recommend adjust-code or reply-with-text. Does not post or edit.
argument-hint: <pr-url> (defaults to wdk-data-shard-wrk/pull/192 if omitted)
---

# Context

Project: **INDEXER** (workspace root: `/Users/alex/Documents/repos/indexer/`).
Canonical truth doc: `_tether-indexer-docs/___TRUTH.md` (aka `_docs/___TRUTH.md`). Refer to it when needed.
PR author: **AlexAtrx**. Commenters may be anyone. You are helping AlexAtrx respond.
PR under review: $ARGUMENTS
If `$ARGUMENTS` is empty, default to `https://github.com/tetherto/wdk-data-shard-wrk/pull/192`.

# Task

1. **Fetch the PR** via `gh`:
   ```bash
   gh pr view  <N> --repo tetherto/<repo> --json number,title,author,headRefName,baseRefName,body,state,url
   gh pr diff  <N> --repo tetherto/<repo>
   # review comments (inline, file-scoped):
   gh api /repos/tetherto/<repo>/pulls/<N>/comments --paginate
   # top-level review submissions (approve / request changes bodies):
   gh api /repos/tetherto/<repo>/pulls/<N>/reviews   --paginate
   # issue-style conversation on the PR:
   gh api /repos/tetherto/<repo>/issues/<N>/comments --paginate
   ```
   If `gh` returns 404 (AlexAtrx's `gh` token may not reach the private repo), fall back to the SSH route in `.claude/skills/read-remote-repo/SKILL.md`: fetch `pull/<N>/head` via `github-atrx` into the **local clone** (not `/tmp`). Checkout and diff against `origin/<base>`.

2. **Find the local repo** under `/Users/alex/Documents/repos/indexer/<repo>/` and check out the PR branch there (do NOT clone anywhere else, do NOT use `/tmp/tetherto-cache/` for this). If the working tree is dirty, stop and ask AlexAtrx before switching branches.
   ```bash
   cd /Users/alex/Documents/repos/indexer/<repo>
   git status --porcelain       # must be clean
   git fetch origin pull/<N>/head:pr-<N>
   git checkout pr-<N>
   ```

3. **Identify unanswered comments.** A comment is "answered" only if AlexAtrx has already replied to it (via `in_reply_to_id` threading, or a clearly-targeted follow-up) or resolved the conversation. Skip:
   - Comments authored by AlexAtrx.
   - Comments AlexAtrx has already replied to.
   - Bot comments that don't need a human reply (CI, linter, codecov summaries) unless they surface a real issue.

4. **For each remaining comment**, do this — using only information you can verify in the PR diff, the checked-out code, the repo history, or existing conversation:
   - Pull an **identifiable excerpt** of the comment (5-30 words, verbatim).
   - Read the exact file/line the comment targets on the PR branch; walk callers/consumers if relevant.
   - Consult `.claude/hotspots.md` and `___TRUTH.md` when the topic overlaps (RW-1526, RW-1601, dual ingestion, etc.).
   - **Classify** as one of:
     - `actionable` — valid concern, code needs to change
     - `unclear` — comment is ambiguous; needs a clarifying question back
     - `outdated` — code already changed, or the concern no longer applies
     - `incorrect` — reviewer is mistaken; reply with correction + evidence
   - **Recommend exactly one** next step:
     - `adjust the code` (describe what to change, but do not edit)
     - `reply with clarification / correction / justification` — include the **exact reply text**, ready to paste

# Constraints

- **Do not** write or modify any code for now. Reading, checking out, and `git log`/`git diff` are fine; edits are not.
- **Do not** post anything to GitHub: no `gh pr review`, `gh pr comment`, `gh api ... -X POST/PATCH`, no resolves.
- **Do not** create or reuse `/tmp/tetherto-cache/<repo>` for this task. The PR branch must live in the local workspace clone.

# Output (strict)

One section per comment, stacked vertically. No combined paragraphs. No summary intro, no overall takeaway. If there are zero unanswered comments, print a single line: "No unanswered review comments."

For each comment use this template exactly:

```
### <comment-index>. <commenter-login> on <file>:<line> (<permalink-or-comment-id>)

**Quote:**
> <5-30 word verbatim excerpt>

**Assessment:**
<2-5 sentences. What the reviewer is actually saying. What the code on the PR branch actually does. Whether the two agree. Cite exact file/line.>

**Classification:** actionable | unclear | outdated | incorrect

**Recommendation:** adjust the code | reply

<If "adjust the code": one paragraph describing the change. Do not write the change.>
<If "reply": a "Reply text:" subheader followed by the exact reply, ready to paste. Keep it short, engineer-to-engineer, no em dashes, no fluff.>
```

# Style

- Truthful, engineering-sound. No speculation. If you can't verify, say so and ask.
- No em dashes anywhere.
- Short, direct, human. No "great point", no "thanks for the review".
- Reply text must be copy-pasteable as-is.

# If AlexAtrx later asks you to edit code

These rules apply to the edit step, not this triage step:

1. Do **not** create a temporary folder for the repo being modified.
2. Do **not** modify or use any existing temporary folder (including `/tmp/tetherto-cache/<repo>`).
3. Do **not** re-clone the repo into any other directory.
4. Locate the relevant repo under `/Users/alex/Documents/repos/indexer/<repo>/`.
5. Check out the exact branch associated with the PR in that clone.
6. Apply the requested changes directly in that local working copy.
