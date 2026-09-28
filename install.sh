#!/usr/bin/env bash
# Publish every skill in ./skills to each agent tool's skill root.
#
# Adapted from andreasmcdermott/astack's install.sh. Differences:
#   - Roots come from targets.conf, so adding a tool is a one-line change.
#   - A symlink this repo did not create is left alone unless --force. Other
#     installers (e.g. `npx skills`) share these roots, and silently relinking
#     their entries on a name collision would hijack them.
#   - --uninstall removes only what this repo published.
#   - Entries left behind by deleted or renamed skills are pruned.
#
# Works with the macOS system bash (3.2).
set -eo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_DIR="$REPO_DIR/skills"
TARGETS_FILE="$REPO_DIR/targets.conf"
MARKER=".agent-skills-source"
# Backups never live inside a skill root: a leftover <name>.bak there would be
# scanned as a second skill declaring the same name.
BACKUP_ROOT="${AGENT_SKILLS_BACKUP_DIR:-$HOME/.agent-skills-backups}"

force=0
dry_run=0
uninstall=0
explicit_targets=""

usage() {
  cat <<USAGE
usage: install.sh [options]

  -t, --target [MODE:]DIR  Publish to DIR instead of targets.conf. MODE is link
                           (default) or copy. Repeatable.
  -f, --force              Replace paths this repo does not own, backing them
                           up under $BACKUP_ROOT.
  -u, --uninstall          Remove everything this repo published.
  -n, --dry-run            Print what would change without touching the disk.
  -h, --help               Show this message.

Roots come from targets.conf; a root is skipped when its parent dir is absent.
USAGE
}

while [ $# -gt 0 ]; do
  case "$1" in
    -t|--target)
      [ -n "${2:-}" ] || { echo "install.sh: $1 needs a directory" >&2; exit 2; }
      case "$2" in
        link:*|copy:*) explicit_targets="$explicit_targets$2"$'\n' ;;
        *)             explicit_targets="${explicit_targets}link:$2"$'\n' ;;
      esac
      shift 2 ;;
    -f|--force)     force=1; shift ;;
    -u|--uninstall) uninstall=1; shift ;;
    -n|--dry-run)   dry_run=1; shift ;;
    -h|--help)      usage; exit 0 ;;
    *) echo "install.sh: unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
done

if [ -n "$explicit_targets" ]; then
  targets="$explicit_targets"; require_parent=0
else
  [ -f "$TARGETS_FILE" ] || { echo "install.sh: missing $TARGETS_FILE" >&2; exit 1; }
  targets="$(grep -v -e '^[[:space:]]*#' -e '^[[:space:]]*$' "$TARGETS_FILE")"
  require_parent=1
fi

run() { if [ "$dry_run" -eq 1 ]; then echo "      would: $*"; else "$@"; fi; }

# Is $1 something this repo published? A symlink into skills/, or a copy whose
# marker names a path inside skills/.
owned_link() { [ -L "$1" ] && case "$(readlink "$1")" in "$SRC_DIR"/*) return 0 ;; esac; return 1; }
owned_copy() {
  [ -d "$1" ] && [ ! -L "$1" ] && [ -f "$1/$MARKER" ] || return 1
  case "$(cat "$1/$MARKER")" in "$SRC_DIR"/*) return 0 ;; esac; return 1
}

copy_matches_source() {
  owned_copy "$1" && [ "$(cat "$1/$MARKER")" = "$2" ] &&
    diff -r -q -x "$MARKER" "$2" "$1" >/dev/null 2>&1
}

backup_path() {
  local root="$1" name="$2" slug
  slug="$(printf '%s' "${root#$HOME/}" | tr '/' '_')"
  printf '%s/%s/%s.%s' "$BACKUP_ROOT" "$slug" "$name" "$(date +%Y%m%d%H%M%S)"
}

# Move an unowned path aside, or report and return 1 without --force.
displace() {
  local root="$1" name="$2" dest="$3" what="$4" backup
  if [ "$force" -eq 1 ]; then
    backup="$(backup_path "$root" "$name")"
    echo "  replace  $name ($what; backup at $backup)"
    run mkdir -p "$(dirname "$backup")"
    run mv "$dest" "$backup"
    return 0
  fi
  echo "  SKIP     $name: $what, not owned by this repo. Use --force to replace it."
  return 1
}

publish_copy() {
  local src="$1" dest="$2"
  run rm -rf "$dest"
  run cp -R "$src" "$dest"
  if [ "$dry_run" -eq 1 ]; then
    echo "      would: write $dest/$MARKER"
  else
    printf '%s\n' "$src" > "$dest/$MARKER"
  fi
}

# Remove owned entries whose skill no longer exists (or, with --uninstall, all).
prune_root() {
  local root="$1" dest name
  for dest in "$root"/* "$root"/.[!.]*; do
    [ -e "$dest" ] || [ -L "$dest" ] || continue
    name="$(basename "$dest")"
    owned_link "$dest" || owned_copy "$dest" || continue
    if [ "$uninstall" -eq 1 ] || [ ! -d "$SRC_DIR/$name" ]; then
      echo "  remove   $name"
      run rm -rf "$dest"
      removed=$((removed + 1))
    fi
  done
}

[ -d "$SRC_DIR" ] || { echo "install.sh: no skills directory at $SRC_DIR" >&2; exit 1; }

published=0
skipped=0
removed=0

while IFS= read -r entry; do
  [ -n "$entry" ] || continue
  mode="${entry%%:*}"
  root="${entry#*:}"
  case "$root" in "~/"*) root="$HOME/${root#\~/}" ;; esac
  case "$mode" in link|copy) ;; *) echo "install.sh: bad target '$entry'" >&2; exit 1 ;; esac

  if [ "$require_parent" -eq 1 ] && [ ! -d "$(dirname "$root")" ]; then
    echo "skip $root (tool not installed)"
    continue
  fi

  echo "$root [$mode]"
  if [ -d "$root" ]; then prune_root "$root"; fi
  [ "$uninstall" -eq 1 ] && continue
  run mkdir -p "$root"

  for src in "$SRC_DIR"/*/; do
    [ -d "$src" ] || continue
    src="${src%/}"
    name="$(basename "$src")"
    dest="$root/$name"

    if [ "$mode" = copy ]; then
      if copy_matches_source "$dest" "$src"; then
        echo "  ok       $name"
        published=$((published + 1)); continue
      elif owned_copy "$dest" || owned_link "$dest"; then
        echo "  update   $name"
        run rm -rf "$dest"
      elif [ -e "$dest" ] || [ -L "$dest" ]; then
        displace "$root" "$name" "$dest" "existing path" || { skipped=$((skipped + 1)); continue; }
      else
        echo "  copy     $name"
      fi
      publish_copy "$src" "$dest"
      published=$((published + 1))
      continue
    fi

    if [ -L "$dest" ] && [ "$(readlink "$dest")" = "$src" ]; then
      echo "  ok       $name"
      published=$((published + 1)); continue
    elif owned_link "$dest" || owned_copy "$dest"; then
      echo "  relink   $name"
      run rm -rf "$dest"
    elif [ -L "$dest" ]; then
      displace "$root" "$name" "$dest" "symlink to $(readlink "$dest")" || { skipped=$((skipped + 1)); continue; }
    elif [ -e "$dest" ]; then
      displace "$root" "$name" "$dest" "existing path" || { skipped=$((skipped + 1)); continue; }
    else
      echo "  link     $name"
    fi

    run ln -s "$src" "$dest"
    published=$((published + 1))
  done
done <<< "$targets"

echo
if [ "$uninstall" -eq 1 ]; then
  echo "$removed removed."
else
  echo "$published published, $skipped skipped, $removed pruned."
fi
[ "$skipped" -eq 0 ]
