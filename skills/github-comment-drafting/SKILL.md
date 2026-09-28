---
name: github-comment-drafting
description: House rules for anything posted to GitHub on the user's behalf - PR descriptions, PR or issue comments, review replies, issue bodies, release notes. Draft first, get explicit approval, write plainly, and add an attribution footer naming the tool and model that drafted it. Use whenever you are about to run `gh pr create`, `gh pr comment`, `gh issue create`, `gh api ... /comments`, or any other call that publishes text to GitHub, even when another skill is driving the workflow.
---

# GitHub comment drafting

Text posted to GitHub goes out under the user's name, notifies other people, and
is hard to take back. So it is drafted in the conversation, approved, and only
then posted.

## 1. Draft, show, wait

- Write the full text exactly as it will appear, footer included, and show it in
  the conversation. Say where it will go (repo, PR/issue number, and which comment
  it replies to).
- Post only after the user explicitly approves that text. Approval covers the
  drafts they saw. It does not carry over to later comments or edited versions.
- When a workflow produces several posts (e.g. one reply per review comment),
  show them all together and get one approval for the set.
- If the user edits the draft, post their version verbatim.

## 2. Write plainly

- Get straight to the point. No openers like "Good question!", "Great catch!",
  "Thanks for the feedback!". They read as patronizing and add nothing.
- Lead with the answer or the change, then the reasoning.
- Use code blocks for code, and link commits, files, and lines instead of
  describing them.
- Match the length to the question: a one-line fix gets a short reply.

## 3. Attribution footer

End every post with:

```
---
*This comment was drafted by <tool> (<model-id>)*
```

- `<tool>` is the agent actually doing the work (Claude Code, Codex, OpenCode,
  Cursor, …). `<model-id>` is the exact model ID from your own system context
  (e.g. `claude-opus-5-5`, `gpt-5-codex`).
- If you don't know the exact model ID, leave it out (`drafted by OpenCode`)
  rather than guess. A wrong attribution is worse than a vague one.
- For PR descriptions, the footer goes above any attribution lines the tool
  itself requires.

## 4. Post safely

- Pass bodies through a file (`--body-file`, or `-F body=@file` with `gh api`)
  rather than inline shell strings. Backticks, `$`, and quotes in markdown break
  inline quoting.
- After posting, give the user the URL of each thing posted.
