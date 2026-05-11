#!/usr/bin/env bash
#
# snapshot-cli.sh — dump the multica CLI --help tree into a flat directory.
#
# Usage: snapshot-cli.sh [OUTPUT_DIR]
#   OUTPUT_DIR defaults to "cli-snapshot/".
#
# Output layout:
#   OUTPUT_DIR/_version.txt              -> `multica --version`
#   OUTPUT_DIR/multica.txt               -> `multica --help`
#   OUTPUT_DIR/multica.issue.txt         -> `multica issue --help`
#   OUTPUT_DIR/multica.issue.list.txt    -> `multica issue list --help`
#   ...
#
# Design notes:
#   - One file per node so PR diffs show exactly which command surface moved.
#   - Subcommands are discovered by parsing the "Commands:" / "Available
#     Commands:" / "Subcommands:" section in each parent's --help output.
#   - Bash 3.2 safe (macOS default) — no associative arrays, no `${arr[@]+...}`
#     unquoted, no mapfile.

set -euo pipefail

OUT="${1:-cli-snapshot}"

if ! command -v multica >/dev/null 2>&1; then
  echo "error: multica CLI not on PATH" >&2
  exit 1
fi

mkdir -p "$OUT"

# Wipe prior snapshot so removed commands actually disappear from the diff.
find "$OUT" -mindepth 1 -maxdepth 1 -name '*.txt' -delete 2>/dev/null || true

# Force non-color output for stable diffs. Most clap-based CLIs honor NO_COLOR.
export NO_COLOR=1
export TERM=dumb

# Strip ANSI escapes defensively in case the CLI ignores NO_COLOR.
strip_ansi() {
  sed $'s/\x1b\\[[0-9;]*[a-zA-Z]//g'
}

# Capture the version line.
multica --version 2>&1 | strip_ansi > "$OUT/_version.txt"

# Extract subcommand names from a --help blob piped on stdin.
#
# Section headers we recognize (any of these opens a "commands" section):
#   - Multica's bespoke format: `COMMANDS`, `CORE COMMANDS`, `RUNTIME COMMANDS`,
#     `ADDITIONAL COMMANDS`, etc. — uppercase, no colon.
#   - clap default: `Commands:`
#   - cobra default: `Available Commands:`
#   - others: `SUBCOMMANDS`, `Subcommands:`
#
# A section ends at the first blank line or the next non-indented line.
# Command lines look like `  assign:   Assign an issue ...`; we strip the
# trailing colon from the command name and skip `help` and flag-like tokens.
extract_subcommands() {
  awk '
    BEGIN { in_section = 0 }
    /^[A-Z][A-Z ]*COMMANDS$/         { in_section = 1; next }
    /^COMMANDS$/                     { in_section = 1; next }
    /^SUBCOMMANDS$/                  { in_section = 1; next }
    /^(Available Commands|Commands|Subcommands):$/ { in_section = 1; next }

    in_section && /^[A-Za-z]/         { in_section = 0; next }
    in_section && /^[[:space:]]*$/    { in_section = 0; next }

    in_section {
      sub(/^[[:space:]]+/, "")
      cmd = $1
      sub(/:$/, "", cmd)
      if (cmd == "" || cmd == "help" || cmd ~ /^-/) next
      print cmd
    }
  '
}

# Recursive walker. Args are the command path words (may be empty for root).
snapshot_node() {
  local label="multica"
  local i
  for (( i=1; i<=$#; i++ )); do
    label="$label.${!i}"
  done
  local outfile="$OUT/${label}.txt"

  local helptext
  # Run --help; bash 3.2 safe expansion of "$@" handles empty argv correctly.
  if ! helptext=$(multica "$@" --help 2>&1); then
    # Some CLIs exit non-zero for help on intermediate nodes; still record
    # what we got so a reviewer can see the breakage.
    :
  fi
  helptext=$(printf '%s\n' "$helptext" | strip_ansi)
  printf '%s\n' "$helptext" > "$outfile"

  # Recurse over discovered subcommands.
  local subs sub
  subs=$(printf '%s\n' "$helptext" | extract_subcommands)
  while IFS= read -r sub; do
    [ -z "$sub" ] && continue
    snapshot_node "$@" "$sub"
  done <<EOF
$subs
EOF
}

snapshot_node

count=$(find "$OUT" -name '*.txt' ! -name '_version.txt' | wc -l | tr -d ' ')
echo "Snapshot complete: ${count} command files in ${OUT}/"
echo "CLI version: $(cat "$OUT/_version.txt")"
