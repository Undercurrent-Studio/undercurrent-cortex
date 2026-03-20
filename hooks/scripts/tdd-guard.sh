#!/usr/bin/env bash
set -euo pipefail
# TDD guard — PreToolUse handler for Write/Edit on production code.
# Warns (standard) or denies (strict) edits to src/ files when no test file
# has been created/edited this session. Called from pre-dispatch.sh.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
source "$SCRIPT_DIR/lib/state-io.sh" || { printf '{}'; exit 0; }
source "$SCRIPT_DIR/lib/json-extract.sh" || { printf '{}'; exit 0; }
source "$SCRIPT_DIR/lib/escape-json.sh" || { printf '{}'; exit 0; }

# Buffer stdin ONCE
INPUT=$(cat)

# Resolve session-scoped state file
resolve_state_file "$INPUT"
[ -f "$STATE_FILE" ] || { printf '{}'; exit 0; }

# Extract file path from tool input
file_path=$(printf '%s' "$INPUT" | extract_json_field "tool_input.file_path")
[ -z "$file_path" ] && { printf '{}'; exit 0; }

# Normalize for Windows path consistency
file_path=$(normalize_path "$file_path")

# Skip: test files themselves (never block writing tests)
if echo "$file_path" | grep -qiE '\.(test|spec)\.(ts|tsx|js|jsx)$|__tests__/'; then
  printf '{}'
  exit 0
fi

# Skip: not in src/ (non-production code)
if ! echo "$file_path" | grep -qiE '/src/'; then
  printf '{}'
  exit 0
fi

# Skip: type definitions
if echo "$file_path" | grep -qiE '\.d\.ts$'; then
  printf '{}'
  exit 0
fi

# Check if any test file was created/edited this session
test_files=$(read_field "test_files_this_session" "$STATE_FILE")
if [ -n "$test_files" ]; then
  # Test file exists — TDD discipline satisfied
  printf '{}'
  exit 0
fi

# No test files this session — enforce based on profile
profile=$(get_profile)
case "$profile" in
  minimal)
    printf '{}'
    ;;
  strict)
    printf '{"deny":{"reason":"TDD enforcement: no test file created/edited this session. Write a failing test before editing production code."}}'
    ;;
  *)
    # standard — warn but allow
    msg=$(escape_for_json "TDD guard: editing production code without a test file this session. Consider writing a failing test first (RED phase).")
    printf '{"systemMessage":"%s"}' "$msg"
    ;;
esac
exit 0
