#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
source "$SCRIPT_DIR/lib/state-io.sh" || { printf '{}'; exit 0; }
source "$SCRIPT_DIR/lib/json-extract.sh" || { printf '{}'; exit 0; }

# Buffer stdin ONCE, then resolve session-scoped state file
INPUT=$(cat)
resolve_state_file "$INPUT"

# Guard: state file must exist (session-start creates it)
[ -f "$STATE_FILE" ] || { printf '{}'; exit 0; }

# Extract nested tool_input.file_path from buffered input
file_path=$(printf '%s' "$INPUT" | extract_json_field "tool_input.file_path")
file_path=$(normalize_path "$file_path")

[ -z "$file_path" ] && { printf '{}'; exit 0; }

# Track the edit
append_to_section "files_modified" "$file_path" "$STATE_FILE"
# Only count repo-internal edits toward commit obligation
# (plan files in ~/.claude/plans/, external memory files, etc. can't be committed)
if [[ "$file_path" == "${PROJECT_DIR}"* ]]; then
  if ! git -C "${PROJECT_DIR}" check-ignore -q "$file_path" 2>/dev/null; then
    increment_field "edits_since_last_commit" "$STATE_FILE"
  fi
fi

# Re-edit spiral detection (skip plugin infrastructure paths)
if ! echo "$file_path" | grep -qE '\.claude-plugin/|\.claude/'; then
  files_modified=$(read_section "files_modified" "$STATE_FILE")
  re_edit_count=0
  if [ -n "$files_modified" ]; then
    if echo "$files_modified" | grep -qxF "$file_path"; then
      re_edit_count=$(echo "$files_modified" | grep -cxF "$file_path")
    fi
  fi
  if [ "$re_edit_count" -ge 3 ]; then
    source "$SCRIPT_DIR/lib/escape-json.sh" || true
    msg=$(escape_for_json "Re-edit detected: ${file_path} has been modified ${re_edit_count} times this session. Consider stepping back to re-plan the approach.")
    printf '{"systemMessage":"%s"}' "$msg"
    exit 0
  fi
fi

# Check for documentation.md update
if [[ "$file_path" == *"documentation.md"* ]]; then
  write_field "docs_updated" "true" "$STATE_FILE"
fi

# Track test file edits for TDD enforcement
if echo "$file_path" | grep -qiE '\.(test|spec)\.(ts|tsx|js|jsx)$|__tests__/'; then
  current_tests=$(read_field "test_files_this_session" "$STATE_FILE")
  if [ -z "$current_tests" ]; then
    write_field "test_files_this_session" "$file_path" "$STATE_FILE"
  elif ! echo "$current_tests" | grep -qF "$file_path"; then
    write_field "test_files_this_session" "${current_tests},${file_path}" "$STATE_FILE"
  fi
fi

# Track lessons.md updates for root cause documentation gate
if echo "$file_path" | grep -qiE '/lessons\.md$'; then
  write_field "root_cause_documented" "true" "$STATE_FILE"
fi

# Commit cadence nudge (dynamic threshold from feedback loop)
edits=$(read_field "edits_since_last_commit" "$STATE_FILE")
threshold=$(read_field "commit_nudge_threshold" "$STATE_FILE")
threshold="${threshold:-15}"
if [ "${edits:-0}" -gt "$threshold" ]; then
  source "$SCRIPT_DIR/lib/escape-json.sh" || true
  msg=$(escape_for_json "You have ${edits} edits since last commit (threshold: ${threshold}). Consider committing — many edits since last commit.")
  printf '{"systemMessage":"%s"}' "$msg"
  exit 0
fi

# Doc-sync reminder for architectural files
docs_updated=$(read_field "docs_updated" "$STATE_FILE")
if [[ "$docs_updated" != "true" ]] && echo "$file_path" | grep -qiE 'scoring|pipeline|v10|v11|constants|middleware|signals|cached-loader|env\.ts|cron|batch-upsert|stripe'; then
  source "$SCRIPT_DIR/lib/escape-json.sh" || true
  msg=$(escape_for_json "Architectural file modified. Consider updating documentation.md.")
  printf '{"systemMessage":"%s"}' "$msg"
  exit 0
fi

printf '{}'
exit 0
