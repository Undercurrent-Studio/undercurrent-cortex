#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
source "$SCRIPT_DIR/lib/state-io.sh" || { printf '{}'; exit 0; }
source "$SCRIPT_DIR/lib/json-extract.sh" || { printf '{}'; exit 0; }
source "$SCRIPT_DIR/lib/escape-json.sh" || { printf '{}'; exit 0; }

# Buffer stdin ONCE (C1 fix — extract_json_field uses cat internally)
INPUT=$(cat)

# Resolve session-scoped state file from session_id in hook JSON
resolve_state_file "$INPUT"

# Graceful degradation: no state file → approve
[ -f "$STATE_FILE" ] || { printf '{}'; exit 0; }

# --- ESCAPE HATCH: consecutive_blocks >= 2 → force-approve ---
consecutive=$(read_field "consecutive_blocks" "$STATE_FILE")
consecutive="${consecutive:-0}"

if [ "$consecutive" -ge 2 ]; then
  write_field "consecutive_blocks" "0" "$STATE_FILE"
  msg=$(escape_for_json "Stop gate: force-approved after acknowledgment. Some obligations may be unmet.")
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

# Gate 5: Stale carry-over (3+ sessions unresolved)
carry_over_age=$(read_field "carry_over_age" "$STATE_FILE")
carry_over_age="${carry_over_age:-0}"
if [ "$carry_over_age" -ge 3 ]; then
  failures="${failures}- Stale carry-over: items unresolved for ${carry_over_age} sessions. Address or explicitly discard.\n"
fi

# --- DECISION ---
if [ -n "$failures" ]; then
  new_consecutive=$((consecutive + 1))
  write_field "consecutive_blocks" "$new_consecutive" "$STATE_FILE"

  reason=$(escape_for_json "Stop blocked. Address obligations above, then stop again to override.\nUnmet gates:\n${failures}")
  printf '{"decision":"block","reason":"%s"}' "$reason"
  exit 0
fi

# All gates pass → approve, reset counter
write_field "consecutive_blocks" "0" "$STATE_FILE"
printf '{}'
exit 0
