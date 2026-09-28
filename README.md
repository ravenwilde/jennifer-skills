# jennifer-skills

My portable agent skills. One source of truth in `skills/`, published to every
agent tool on the machine, so there's only ever one copy to edit.

I try out new LLM tools all the time, so portability is the point. Skills use
only the cross-tool [Agent Skills](https://agentskills.io) format, and adding a
new tool is a one-line change to `targets.conf`.

Inspired by and adapted from
[andreasmcdermott/astack](https://github.com/andreasmcdermott/astack).

## Layout

    skills/<name>/SKILL.md       frontmatter (name, description) + instructions
    skills/<name>/references/    optional files the skill loads on demand
    targets.conf                 which tool roots to publish to, link or copy
    install.sh                   publishes skills/ to every root in targets.conf
    scripts/check.sh             lints skills (also runs in CI)

The `name` in frontmatter must match the directory name.

## Install

    ./install.sh          publish to every root in targets.conf
    ./install.sh -n       dry run: show what would change
    ./install.sh -u       uninstall: remove everything this repo published
    ./install.sh -f       replace paths this repo doesn't own (backed up first)
    ./install.sh -t DIR   publish to DIR instead (link:DIR or copy:DIR)

- **link** roots get symlinks, so edits go live immediately.
- **copy** roots are for tools that ignore symlinks (bb). They get a real copy
  with a `.agent-skills-source` marker. Re-run `./install.sh` after editing.
- A root whose parent directory is missing is skipped, so the same config works
  on machines that don't have every tool.
- Entries left behind by deleted or renamed skills are pruned automatically.

### Sharing roots with other installers

`~/.agents/skills` and `~/.claude/skills` also hold skills installed by
`npx skills` (Matt Pocock's, Vercel's, …). `install.sh` only touches entries it
created: a symlink into this repo or a copy with its marker. Anything else with
the same name is reported as `SKIP` and left alone unless you pass `-f`.
(astack relinks foreign symlinks without `-f`; this repo deliberately doesn't.)

Backups from `-f` go to `~/.agent-skills-backups/`, outside every skill root,
because a leftover `<name>.bak` inside a root would be read as a duplicate skill.

## Adding a skill

1. Create `skills/<name>/SKILL.md` with `name` and `description` frontmatter.
2. `scripts/check.sh --local`: lint, and check the name doesn't clash with a
   skill something else installed.
3. `./install.sh`
4. Commit.

## Adding a tool

Find the tool's user-level skill root and check whether it follows symlinked
skill directories. Then add `link:<root>` or `copy:<root>` to `targets.conf` and
run `./install.sh`.

## Installing someone else's way

The layout matches what `npx skills` expects, so anyone can install these with:

    npx skills add ravenwilde/jennifer-skills

## Skills

- `github-comment-drafting`: house rules for anything posted to GitHub. Draft
  first, explicit approval, plain tone, and an attribution footer naming the tool
  and model.
- `respond-to-copilot-review`: assess Copilot's PR review comments, fix the valid
  ones in one commit per round, and reply to every comment.
- `review-queue-triage`: triage the PRs waiting on me into a guide ordered
  lowest to highest effort, with what to look at in each. Filters out the drafts
  and conflicting PRs first, and flags auto-close deadlines.
- `shortcut-doc-fetch`: read a Shortcut doc from its URL, ID, or title through
  the Shortcut MCP server. Decodes the `/write/` link to the UUID the API needs.
