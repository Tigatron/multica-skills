#!/usr/bin/env bash
#
# drift-pr-body.sh — emit the markdown body for a CLI drift PR.
#
# Usage: drift-pr-body.sh [BASE_REF]
#   BASE_REF defaults to "origin/main"; falls back to "HEAD" if absent.
#
# Reads `git diff` of cli-snapshot/ vs BASE_REF, groups changed files into
# added / modified / removed buckets, maps each prefix to the SKILL.md a
# reviewer is most likely to update, and prints the checklist that captures
# the auto-PR contract (snapshot files may move; Gotchas / Common flows /
# description frontmatter never do).

set -euo pipefail

BASE="${1:-origin/main}"

# Fall back gracefully if the requested base ref doesn't exist yet (first run).
if ! git rev-parse --verify "$BASE" >/dev/null 2>&1; then
  BASE="HEAD"
fi

VERSION=$(awk '{print; exit}' cli-snapshot/_version.txt 2>/dev/null || echo "unknown")
BASE_VERSION=$(git show "${BASE}:cli-snapshot/_version.txt" 2>/dev/null | awk '{print; exit}' || echo "(no baseline yet)")

# Collect changed snapshot files relative to BASE.
# Filter out _version.txt — its change is already reflected in the version table.
filter_files() {
  sed 's|^cli-snapshot/||' | grep -v '^_version\.txt$' || true
}
ADDED=$(git diff --name-only --diff-filter=A "$BASE" -- cli-snapshot 2>/dev/null | filter_files)
MODIFIED=$(git diff --name-only --diff-filter=M "$BASE" -- cli-snapshot 2>/dev/null | filter_files)
DELETED=$(git diff --name-only --diff-filter=D "$BASE" -- cli-snapshot 2>/dev/null | filter_files)

# Map a snapshot filename to a SKILL.md path; "" if no mapping.
skill_for() {
  case "$1" in
    multica.issue.*|multica.attachment.*) echo "skills/multica-issues/SKILL.md" ;;
    multica.agent.*)                      echo "skills/multica-agents/SKILL.md" ;;
    multica.autopilot.*)                  echo "skills/multica-autopilot/SKILL.md" ;;
    multica.project.*)                    echo "skills/multica-projects/SKILL.md" ;;
    multica.skill.*)                      echo "skills/multica-skills/SKILL.md" ;;
    multica.daemon.*|multica.runtime.*|multica.repo.*) echo "skills/multica-daemon/SKILL.md" ;;
    multica.setup.*|multica.login.*|multica.auth.*|multica.config.*|multica.workspace.*|multica.update.*|multica.version.*) echo "skills/multica-setup/SKILL.md" ;;
    multica.txt)                          echo "(root help — affects every skill's prerequisites; check each)" ;;
    *)                                    echo "(unmapped — please decide which skill owns this command)" ;;
  esac
}

print_section() {
  local heading="$1" files="$2"
  [ -z "$files" ] && return
  echo "**$heading**"
  echo
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    printf -- '- `%s` → %s\n' "$f" "$(skill_for "$f")"
  done <<EOF
$files
EOF
  echo
}

cat <<EOF
## CLI drift detected

|              |                       |
|--------------|-----------------------|
| Baseline CLI | \`${BASE_VERSION}\`   |
| Current CLI  | \`${VERSION}\`        |
| Diff base    | \`${BASE}\`           |

### Snapshot changes

EOF

print_section "Added"    "$ADDED"
print_section "Modified" "$MODIFIED"
print_section "Removed"  "$DELETED"

if [ -z "$ADDED$MODIFIED$DELETED" ]; then
  echo "_No file-level changes detected in \`cli-snapshot/\` vs \`${BASE}\`. The version string may have moved without any command-surface change._"
  echo
fi

cat <<'EOF'
### Reviewer checklist

Auto-PRs only commit the new snapshot. Edits to skills are manual on purpose — the gotchas section is the part of each SKILL.md that `--help` can't generate, and is the main reason these skills exist.

- [ ] Skim each modified snapshot file in this PR to identify new / removed / renamed commands and flags
- [ ] Edit the mapped `SKILL.md` to reflect the new command surface
  - Limit edits to: `Core commands`, `Updating`, `Creating ...`, example blocks, flag tables
- [ ] **Do not auto-update these sections** (they encode hand-on knowledge):
  - `Gotchas` — only add a new gotcha after you've reproduced it
  - `Common flows` — cross-command workflows
  - `description:` frontmatter — agent routing predicates
- [ ] If a newly added command needs gotchas, file a follow-up issue with `testing-notes-needed` so it's tracked separately
- [ ] Remove the `needs-review` label and merge once skills reflect the new surface

### Skill ownership map

| Snapshot prefix                                       | Skill                              |
|-------------------------------------------------------|------------------------------------|
| `multica.issue.*`, `multica.attachment.*`             | `skills/multica-issues/SKILL.md`   |
| `multica.agent.*`                                     | `skills/multica-agents/SKILL.md`   |
| `multica.autopilot.*`                                 | `skills/multica-autopilot/SKILL.md`|
| `multica.project.*`                                   | `skills/multica-projects/SKILL.md` |
| `multica.skill.*`                                     | `skills/multica-skills/SKILL.md`   |
| `multica.daemon.*`, `multica.runtime.*`, `multica.repo.*` | `skills/multica-daemon/SKILL.md` |
| `multica.setup.*`, `multica.login.*`, `multica.auth.*`, `multica.config.*`, `multica.workspace.*`, `multica.update.*`, `multica.version.*` | `skills/multica-setup/SKILL.md` |

---

Generated by `.github/workflows/cli-drift.yml` via `bin/snapshot-cli.sh` + `bin/drift-pr-body.sh`.
EOF
