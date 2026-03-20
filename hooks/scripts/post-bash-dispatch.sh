#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
source "$SCRIPT_DIR/lib/state-io.sh" || { printf '{}'; exit 0; }
source "$SCRIPT_DIR/lib/json-extract.sh" || { printf '{}'; exit 0; }

# Buffer stdin ONCE, then resolve session-scoped state file
INPUT=$(cat)
resolve_state_file "$INPUT"

# Guard: state file must exist
[ -f "$STATE_FILE" ] || { printf '{}'; exit 0; }

# Extract tool_input.command from buffered input
command_str=$(printf '%s' "$INPUT" | extract_json_field "tool_input.command")
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

    # --- Conventional commit check ---
    if [ "$msg" != "commit" ]; then
      if ! echo "$msg" | grep -qE '^(feat|fix|refactor|docs|chore|test|perf|ci|build|style):'; then
        source "$SCRIPT_DIR/lib/escape-json.sh" || true
        warn=$(escape_for_json "Non-conventional commit: '${msg}'. Expected prefix: feat:/fix:/refactor:/docs:/chore:/test:. Consider: git commit --amend -m 'type: ...'")
        printf '{"systemMessage":"%s"}' "$warn"
        exit 0
      fi
    fi
  fi
fi

printf '{}'
exit 0
