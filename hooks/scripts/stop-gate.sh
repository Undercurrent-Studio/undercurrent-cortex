#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
source "$SCRIPT_DIR/lib/state-io.sh"
source "$SCRIPT_DIR/lib/json-extract.sh"
source "$SCRIPT_DIR/lib/escape-json.sh"

# Guard: only act in Undercurrent project
is_undercurrent_project || { printf '{}'; exit 0; }

# Graceful degradation: no state file → approve
[ -f "$STATE_FILE" ] || { printf '{}'; exit 0; }

# Buffer stdin ONCE (C1 fix — extract_json_field uses cat internally)
INPUT=$(cat)

# --- ESCAPE HATCH: consecutive_blocks >= 3 → force-approve ---
consecutive=$(read_field "consecutive_blocks" "$STATE_FILE")
consecutive="${consecutive:-0}"

if [ "$consecutive" -ge 3 ]; then
  write_field "consecutive_blocks" "0" "$STATE_FILE"
  msg=$(escape_for_json "Stop gate: force-approved after ${consecutive} consecutive blocks. Some obligations may be unmet.")
  printf '{"systemMessage":"%s"}' "$msg"
  exit 0
fi

# --- GATE CHECKS ---
failures=""

# Read state
edits=$(read_field "edits_since_last_commit" "$STATE_FILE")
edits="${edits:-0}"

# Gate 1: Uncommitted changes
if [ "$edits" -gt 0 ]; then
  failures="${failures}- Uncommitted changes (${edits} edits since last commit)\n"
fi

# Gates 2 & 3 only fire when edits > 3 (avoid nagging on quick fixes)
if [ "$edits" -gt 3 ]; then
  files_modified=$(read_section "files_modified" "$STATE_FILE")

  # Gate 2: documentation.md not updated after architectural changes
  docs_updated=$(read_field "docs_updated" "$STATE_FILE")
  if [ "$docs_updated" != "true" ]; then
    if echo "$files_modified" | grep -qiE 'scoring|pipeline|v10|v11|constants|middleware|cached-loader|signals'; then
      failures="${failures}- documentation.md not updated after architectural changes\n"
    fi
  fi

  # Gate 3: Tests not run after modifying TypeScript files
  tests_run=$(read_field "tests_run" "$STATE_FILE")
  if [ "$tests_run" != "true" ]; then
    if echo "$files_modified" | grep -qiE '\.(ts|tsx)$'; then
      failures="${failures}- Tests not run after modifying TypeScript files\n"
    fi
  fi
fi

# Gate 4: Carry-over items not addressed
carry_over=$(read_section "carry_over" "$STATE_FILE")
if [ -n "$carry_over" ]; then
  carry_over_addressed=$(read_field "carry_over_addressed" "$STATE_FILE")
  if [ "$carry_over_addressed" != "true" ]; then
    failures="${failures}- Carry-over items from prior session not addressed\n"
  fi
fi

# --- DECISION ---
if [ -n "$failures" ]; then
  new_consecutive=$((consecutive + 1))
  write_field "consecutive_blocks" "$new_consecutive" "$STATE_FILE"

  reason=$(escape_for_json "Stop gate blocked (${new_consecutive}/3). Unmet gates:\n${failures}Address these before stopping, or stop will auto-approve after 3 blocks.")
  printf '{"decision":"block","reason":"%s"}' "$reason"
  exit 0
fi

# All gates pass → approve, reset counter
write_field "consecutive_blocks" "0" "$STATE_FILE"
printf '{}'
exit 0
