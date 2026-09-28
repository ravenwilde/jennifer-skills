---
name: respond-to-copilot-review
description: Work through GitHub Copilot's automated review comments on a pull request - fetch them, assess each one on its merits, agree a plan with the user, fix the valid ones in a single commit, and reply to every comment. Use when the user asks to review, respond to, address, or handle Copilot comments or Copilot review feedback on a PR, including follow-up rounds after Copilot re-reviews.
---

# Respond to a Copilot review

Copilot's comments are suggestions, not instructions. Some are real defects,
some are style preferences, and some are wrong because Copilot didn't see the
wider context. The job is to judge each one, fix what deserves fixing, and leave
a clear reply on every comment so human reviewers can see what happened.

All posting to GitHub follows the `github-comment-drafting` skill: draft, get
approval, attribution footer. Read it if it isn't already loaded.

## 1. Fetch the comments

Resolve `{owner}/{repo}` and the PR number (from the user, or with
`gh pr view --json number,url`). Then:

```bash
gh api --paginate repos/{owner}/{repo}/pulls/{pr}/comments \
  --jq '.[] | select(.user.login == "Copilot" or (.user.login | startswith("copilot-pull-request-reviewer"))) | {id, path, line, body, created_at, in_reply_to_id}'
```

Skip comments that already have a reply from the PR author (a later comment
whose `in_reply_to_id` matches). Those were handled in an earlier round. Count
earlier rounds so the commit can say "round N".

## 2. Assess each comment

Read the referenced file around the line, plus whatever it calls or is called
by, before judging. For each comment, decide:

| Aspect | Question |
|---|---|
| Validity | Is the concern technically correct for this code? |
| Impact | What actually happens if we leave it? |
| Scope | Local fix, or does it ripple into other files? |
| Trade-offs | Does the suggestion cost clarity, performance, or consistency? |

Group comments that describe the same underlying issue.

## 3. Present the plan and wait

```markdown
| # | File | Issue | Valid? | Proposed fix |
|---|------|-------|--------|--------------|
| 1 | path/to/file.ts:42 | … | Yes / No / Partly | … |
```

Under the table, for each comment: what Copilot suggested, what the code does
now, and whether to act and why. Recommend declining when a suggestion is wrong
or not worth it. Ask the user to approve or adjust the plan before editing.

## 4. Fix, commit, push

- Make only the approved changes. Run the project's relevant lint and tests for
  the touched files.
- One commit per review round:

  ```
  [<story-id>] Address Copilot review feedback (round N)

  1. <fix for comment 1>
  2. <fix for comment 2>
  ```

  Use a story/ticket ID if the branch name or repo convention has one, otherwise
  drop the prefix. Add any commit trailer the tool requires.
- Pushing publishes to GitHub. Confirm with the user before pushing unless they
  already said to push as part of this request.

## 5. Reply to every comment

Draft one reply per comment, show them all together, and post after approval:

```bash
gh api repos/{owner}/{repo}/pulls/{pr}/comments/{comment_id}/replies \
  -X POST -F body=@reply.md
```

- **Fixed:** `Addressed in [<short-sha>](<commit-url>).`, then a short
  before/after snippet and one or two sentences on how it resolves the concern.
- **Declined:** the specific reason (context Copilot lacked, trade-off, out of
  scope), and a follow-up link if one was filed.
- Grouped comments each get a reply, which can point to the main one.

Finish with a summary: comments fixed, declined, commit link, and reply URLs.
