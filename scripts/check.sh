#!/usr/bin/env bash
# Lint skills/*/SKILL.md against the portable Agent Skills format.
#
#   scripts/check.sh           structure checks (what CI runs)
#   scripts/check.sh --local   also fail on name collisions with skills that
#                              other installers put in this machine's roots
#
# Frontmatter keys outside the portable set only warn: using one is allowed,
# but it should be a conscious choice because other tools ignore it.
set -eo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC_DIR="$REPO_DIR/skills"
MARKER=".agent-skills-source"
PORTABLE_KEYS="name description license compatibility metadata allowed-tools"

local_mode=0
[ "${1:-}" = "--local" ] && local_mode=1

errors=0
warnings=0
err()  { echo "error: $*"; errors=$((errors + 1)); }
warn() { echo "warn:  $*"; warnings=$((warnings + 1)); }

# Print the frontmatter block (without the --- fences), or nothing if absent.
frontmatter() {
  awk 'NR == 1 { if ($0 != "---") exit; next } $0 == "---" { exit } { print }' "$1"
}

# Value of a top-level key, joining folded (>-, |) continuation lines.
fm_value() {
  awk -v key="$2" '
    found && /^[[:space:]]/ { sub(/^[[:space:]]+/, ""); val = val (val == "" ? "" : " ") $0; next }
    found { exit }
    index($0, key ":") == 1 {
      val = substr($0, length(key) + 2); sub(/^[[:space:]]+/, "", val)
      if (val ~ /^[>|][-+]?$/) val = ""
      found = 1
    }
    END { gsub(/^["\047]|["\047]$/, "", val); print val }
  ' <<< "$1"
}

count=0
for dir in "$SRC_DIR"/*/; do
  [ -d "$dir" ] || continue
  dir="${dir%/}"
  name="$(basename "$dir")"
  file="$dir/SKILL.md"
  count=$((count + 1))

  if [ ! -f "$file" ]; then err "$name: missing SKILL.md"; continue; fi

  fm="$(frontmatter "$file")"
  if [ -z "$fm" ]; then err "$name: SKILL.md has no --- frontmatter"; continue; fi

  fm_name="$(fm_value "$fm" name)"
  desc="$(fm_value "$fm" description)"

  [ "$fm_name" = "$name" ] || err "$name: frontmatter name '$fm_name' must match its directory"
  printf '%s' "$name" | grep -Eq '^[a-z0-9]+(-[a-z0-9]+)*$' && [ "${#name}" -le 64 ] ||
    err "$name: name must be lowercase letters, digits and single hyphens, max 64 chars"
  if [ -z "$desc" ]; then
    err "$name: description is missing"
  elif [ "${#desc}" -gt 1024 ]; then
    err "$name: description is ${#desc} chars (max 1024)"
  fi

  for key in $(printf '%s\n' "$fm" | sed -n 's/^\([A-Za-z0-9_-]*\):.*/\1/p'); do
    case " $PORTABLE_KEYS " in
      *" $key "*) ;;
      *) warn "$name: '$key' is not a portable frontmatter key; other tools will ignore it" ;;
    esac
  done

  if [ "$local_mode" -eq 1 ]; then
    while IFS= read -r entry; do
      root="${entry#*:}"
      case "$root" in "~/"*) root="$HOME/${root#\~/}" ;; esac
      dest="$root/$name"
      [ -e "$dest" ] || [ -L "$dest" ] || continue
      if [ -L "$dest" ]; then
        case "$(readlink "$dest")" in "$SRC_DIR"/*) continue ;; esac
      elif [ -f "$dest/$MARKER" ]; then
        case "$(cat "$dest/$MARKER")" in "$SRC_DIR"/*) continue ;; esac
      fi
      err "$name: collides with an existing skill at $dest (installed by something else)"
    done < <(grep -v -e '^[[:space:]]*#' -e '^[[:space:]]*$' "$REPO_DIR/targets.conf")
  fi
done

echo "$count skills checked, $errors errors, $warnings warnings."
[ "$errors" -eq 0 ]
