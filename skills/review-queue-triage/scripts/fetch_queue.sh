#!/usr/bin/env bash
# Collect the triage signals for a queue of pull requests in two gh passes.
#
#   scripts/fetch_queue.sh                        PRs awaiting my review, current repo
#   scripts/fetch_queue.sh -R owner/repo
#   scripts/fetch_queue.sh -s 'is:open author:@me'
#   scripts/fetch_queue.sh -n 3078,3076          just these PRs
#   scripts/fetch_queue.sh -l 100
#
# Pass 1 lists the queue (size, files, labels, draft). Pass 2 pulls per-PR
# review state, CI, mergeability and bot comments. Output is one text block per
# PR, newest first, plus a TOTALS line. Read-only: no gh call here writes.
#
# Works with the macOS system bash (3.2). Needs gh (authenticated) and jq.
set -eo pipefail

repo=""
search="is:open review-requested:@me"
limit=50
numbers=""

while [ $# -gt 0 ]; do
  case "$1" in
    -R|--repo)   repo="$2"; shift 2 ;;
    -s|--search) search="$2"; shift 2 ;;
    -l|--limit)  limit="$2"; shift 2 ;;
    -n|--numbers) numbers="$2"; shift 2 ;;
    -h|--help)   sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done

command -v gh >/dev/null || { echo "error: gh not found" >&2; exit 1; }
command -v jq >/dev/null || { echo "error: jq not found" >&2; exit 1; }

repo_args=""
[ -n "$repo" ] && repo_args="-R $repo"

LIST_FIELDS=number,title,author,additions,deletions,changedFiles,isDraft,createdAt,updatedAt,labels,reviewDecision,baseRefName,headRefName,url,files
VIEW_FIELDS=number,mergeable,mergeStateStatus,reviewRequests,latestReviews,statusCheckRollup,comments,body

if [ -n "$numbers" ]; then
  # shellcheck disable=SC2086
  list=$(printf '%s' "$numbers" | tr ',' '\n' | grep -v '^[[:space:]]*$' |
    while read -r n; do gh pr view "$n" $repo_args --json "$LIST_FIELDS"; done | jq -s '.')
else
  # shellcheck disable=SC2086
  list=$(gh pr list $repo_args --search "$search" --limit "$limit" --json "$LIST_FIELDS")
fi

count=$(printf '%s' "$list" | jq 'length')
if [ "$count" -eq 0 ]; then
  echo "No PRs matched: $search"
  exit 0
fi

pr_numbers=$(printf '%s' "$list" | jq -r '.[].number')

for n in $pr_numbers; do
  # shellcheck disable=SC2086
  view=$(gh pr view "$n" $repo_args --json "$VIEW_FIELDS")
  printf '%s' "$list" | jq -r --argjson v "$view" '
    def checks($rollup):
      ($rollup // []) as $c
      | {
          fail: [$c[] | select((.conclusion // .state) as $s
                 | $s == "FAILURE" or $s == "ERROR" or $s == "TIMED_OUT")
                 | (.name // .context)],
          pending: [$c[] | select(.status == "IN_PROGRESS" or .status == "QUEUED"
                    or .state == "PENDING")] | length,
          total: ($c | length)
        };
    # The stale bot warns 7 days before it closes a PR; surface the last warning.
    def stale($comments):
      [ $comments[]? | select(.body | test("no activity for";"i")) | .createdAt[0:10] ]
      | if length == 0 then "none" else (sort | last) end;
    .[] | select(.number == $v.number)
    | checks($v.statusCheckRollup) as $ci
    | "#\(.number)  \(.title)",
      "  author=\(.author.login)  +\(.additions)/-\(.deletions) in \(.changedFiles) files" +
        "  draft=\(.isDraft)  created=\(.createdAt[0:10])  updated=\(.updatedAt[0:10])",
      "  base=\(.baseRefName)  mergeable=\($v.mergeable)  state=\($v.mergeStateStatus)" +
        "  decision=\(.reviewDecision // "NONE")",
      # deploy:* labels are automation bookkeeping and crowd out the useful ones.
      "  labels: \([.labels[].name | select(startswith("deploy:") | not)] | join(", "))",
      "  requested: \([$v.reviewRequests[]? | (.login // .name // .slug)] | join(", "))" +
        (if ([$v.reviewRequests[]?] | length) == 0 then "(none left)" else "" end),
      "  reviews: \([$v.latestReviews[]? | "\(.author.login):\(.state)"] | join(", "))",
      "  checks: total=\($ci.total) failing=\($ci.fail | length) pending=\($ci.pending)" +
        (if ($ci.fail | length) > 0 then "  [\($ci.fail | join(" | "))]" else "" end),
      "  stale-warning: \(stale($v.comments))",
      # Stacked-branch and dependency claims live in the body; the agent must verify them.
      "  body mentions: " + ([ ($v.body // "")
          | scan("(?i)(?:stacked on|depends on|blocked (?:on|by)|merge after)[^.\\n]{0,60}")
        ] | unique | join(" ; ") | if . == "" then "-" else . end),
      "  paths:",
      ( [.files[].path] | .[] | "    \(.)" ),
      ""
  '
done

printf '%s' "$list" | jq -r '
  "TOTALS  \(length) PRs  " +
  "draft=\([.[] | select(.isDraft)] | length)  " +
  "lines=\([.[] | .additions + .deletions] | add)  " +
  "oldest=\([.[].createdAt] | min | .[0:10])"'
