#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
source "$SCRIPT_DIR/lib/state-io.sh"
source "$SCRIPT_DIR/lib/json-extract.sh"

# Guard: only act in Undercurrent project
is_undercurrent_project || { printf '{}'; exit 0; }

# Guard: state file must exist (session-start creates it)
[ -f "$STATE_FILE" ] || { printf '{}'; exit 0; }

# Read stdin JSON, extract nested tool_input.file_path
file_path=$(cat | extract_json_field "tool_input.file_path")
file_path=$(echo "$file_path" | sed 's|\\\\|/|g')  # Windows path normalization

[ -z "$file_path" ] && { printf '{}'; exit 0; }

# Track the edit
append_to_section "files_modified" "$file_path" "$STATE_FILE"
increment_field "edits_since_last_commit" "$STATE_FILE"

# Check for documentation.md update
if [[ "$file_path" == *"documentation.md"* ]]; then
  write_field "docs_updated" "true" "$STATE_FILE"
fi

# Commit cadence nudge (>15 edits without commit)
edits=$(read_field "edits_since_last_commit" "$STATE_FILE")
if [ "${edits:-0}" -gt 15 ]; then
  source "$SCRIPT_DIR/lib/escape-json.sh"
  msg=$(escape_for_json "You have ${edits} edits since last commit. Per Undercurrent workflow: commit after each wave/phase.")
  printf '{"systemMessage":"%s"}' "$msg"
  exit 0
fi

# Doc-sync reminder for architectural files
docs_updated=$(read_field "docs_updated" "$STATE_FILE")
if [[ "$docs_updated" != "true" ]] && echo "$file_path" | grep -qiE 'scoring|pipeline|v10|v11|constants|middleware|signals|cached-loader|env\.ts|cron|batch-upsert|stripe'; then
  source "$SCRIPT_DIR/lib/escape-json.sh"
  msg=$(escape_for_json "Architectural file modified. Consider updating documentation.md.")
  printf '{"systemMessage":"%s"}' "$msg"
  exit 0
fi

printf '{}'
exit 0
