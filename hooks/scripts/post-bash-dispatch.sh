#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
source "$SCRIPT_DIR/lib/state-io.sh"
source "$SCRIPT_DIR/lib/json-extract.sh"

# Guard: only act in Undercurrent project
is_undercurrent_project || { printf '{}'; exit 0; }

# Guard: state file must exist
[ -f "$STATE_FILE" ] || { printf '{}'; exit 0; }

# Read stdin JSON, extract tool_input.command
command_str=$(cat | extract_json_field "tool_input.command")
[ -z "$command_str" ] && { printf '{}'; exit 0; }

# --- Pattern: test commands ---
if echo "$command_str" | grep -qE '(npm test|vitest|npx vitest)'; then
  write_field "tests_run" "true" "$STATE_FILE"
fi

# --- Pattern: git commit (not amend) ---
if echo "$command_str" | grep -qE '^[[:space:]]*git[[:space:]]+commit[[:space:]]'; then
  if ! echo "$command_str" | grep -q '\-\-amend'; then
    increment_field "commits_count" "$STATE_FILE"
    write_field "edits_since_last_commit" "0" "$STATE_FILE"
    write_field "stop_hook_active" "false" "$STATE_FILE"
    write_field "consecutive_blocks" "0" "$STATE_FILE"

    # Journal logging (absorbed from post-commit-log)
    today=$(date +%Y-%m-%d)
    time_now=$(date +%H:%M)
    journal="${PROJECT_DIR}/memory/${today}.md"
    if [ -f "$journal" ]; then
      msg=$(git -C "${PROJECT_DIR}" log -1 --pretty=format:"%s" 2>/dev/null || echo "commit")
      [ -z "$msg" ] && msg="commit"
      printf '\n## %s - commit: %s\n' "$time_now" "$msg" >> "$journal"
    fi
  fi
fi

printf '{}'
exit 0
