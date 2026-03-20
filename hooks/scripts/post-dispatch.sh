#!/usr/bin/env bash
set -euo pipefail
# Unified PostToolUse dispatcher — routes to sub-handlers by tool_name.
# Plugin hooks.json registers this with NO matcher (fires on all PostToolUse).

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
source "$SCRIPT_DIR/lib/state-io.sh" || { printf '{}'; exit 0; }
source "$SCRIPT_DIR/lib/json-extract.sh" || { printf '{}'; exit 0; }

# Buffer stdin ONCE
INPUT=$(cat)

# Resolve session-scoped state file and increment tool call counters
resolve_state_file "$INPUT"
if [ -f "$STATE_FILE" ]; then
  increment_field "tool_calls_count" "$STATE_FILE"
  increment_field "tool_uses_since_journal" "$STATE_FILE"
fi

# Extract tool_name for routing
tool_name=$(printf '%s' "$INPUT" | extract_json_field "tool_name")

# Detect journal writes → reset tool_uses_since_journal counter
if [ -f "$STATE_FILE" ] && { [ "$tool_name" = "Write" ] || [ "$tool_name" = "Edit" ]; }; then
  file_path=$(printf '%s' "$INPUT" | extract_json_field "tool_input.file_path")
  if echo "$file_path" | grep -q "memory/.*\.md"; then
    write_field "tool_uses_since_journal" "0" "$STATE_FILE"
  fi
fi

# Mid-session checkpoint every 25 tool uses without a journal write
if [ -f "$STATE_FILE" ]; then
  uses_since=$(read_field "tool_uses_since_journal" "$STATE_FILE" 2>/dev/null || echo "0")
  if [ "$uses_since" -ge 25 ] 2>/dev/null; then
    write_field "tool_uses_since_journal" "0" "$STATE_FILE"
    source "$SCRIPT_DIR/lib/escape-json.sh" || true
    checkpoint=$(escape_for_json "📝 Mid-session checkpoint (${uses_since} tool uses since last journal entry): consider adding a journal entry to memory/YYYY-MM-DD.md. What's the current state of the work?")
    printf '{"systemMessage":"%s"}' "$checkpoint"
    exit 0
  fi
fi

case "$tool_name" in
  Bash)
    printf '%s' "$INPUT" | "$SCRIPT_DIR/post-bash-dispatch.sh"
    ;;
  Write|Edit)
    printf '%s' "$INPUT" | "$SCRIPT_DIR/post-edit-dispatch.sh"
    # For Write, also run pattern-template
    if [ "$tool_name" = "Write" ]; then
      printf '%s' "$INPUT" | "$SCRIPT_DIR/pattern-template.sh" 2>/dev/null || true
    fi
    ;;
  *)
    printf '{}'
    ;;
esac
exit 0
