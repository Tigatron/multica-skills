#!/usr/bin/env bash
# Install multica-skills into a target AI agent's skill directory.
#
# Usage:
#   ./install.sh                         # Install to ~/.claude/skills (Claude Code, user-global)
#   ./install.sh --target claude-project # Install to ./.claude/skills (Claude Code, project-local)
#   ./install.sh --target opencode       # Install to ~/.config/opencode/skills
#   ./install.sh --target dir --dir PATH # Install to an arbitrary directory
#   ./install.sh --list                  # List skills in this package and exit
#   ./install.sh --dry-run               # Show what would be copied, do not write
#
# Re-runnable: existing skill dirs at the target are overwritten.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_DIR="$ROOT/skills"

target="claude"
custom_dir=""
dry_run=false

usage() {
  sed -n '2,13p' "$0" | sed 's/^# \{0,1\}//'
  exit "${1:-0}"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --target) target="$2"; shift 2 ;;
    --dir)    custom_dir="$2"; shift 2 ;;
    --dry-run) dry_run=true; shift ;;
    --list)
      for d in "$SKILLS_DIR"/*/; do
        name="$(basename "$d")"
        desc="$(awk -F': ' '/^description:/{sub(/^description: /,""); print; exit}' "$d/SKILL.md")"
        printf "  %-22s %s\n" "$name" "$desc"
      done
      exit 0
      ;;
    -h|--help) usage 0 ;;
    *) echo "Unknown arg: $1" >&2; usage 1 ;;
  esac
done

case "$target" in
  claude)         dest="$HOME/.claude/skills" ;;
  claude-project) dest="$PWD/.claude/skills" ;;
  opencode)       dest="$HOME/.config/opencode/skills" ;;
  dir)
    if [[ -z "$custom_dir" ]]; then
      echo "--target dir requires --dir PATH" >&2
      exit 1
    fi
    dest="$custom_dir"
    ;;
  *) echo "Unknown target: $target (valid: claude, claude-project, opencode, dir)" >&2; exit 1 ;;
esac

echo "Installing multica skills to: $dest"
if $dry_run; then
  echo "(dry run — no files will be written)"
fi

for src in "$SKILLS_DIR"/*/; do
  name="$(basename "$src")"
  target_dir="$dest/$name"
  echo "  -> $name"
  if $dry_run; then
    continue
  fi
  mkdir -p "$target_dir"
  cp -R "$src"* "$target_dir"/
done

if $dry_run; then
  exit 0
fi

cat <<EOF

Installed. Next steps:
  1. Make sure the Multica CLI is on PATH:   command -v multica
     (If missing, open the multica-setup skill for install instructions.)
  2. Restart your AI agent so it picks up the new skills.
  3. Try: "list multica issues" or "create a multica issue assigned to <agent>".
EOF
