#!/usr/bin/env bash
set -euo pipefail
# Unified PostToolUse dispatcher — routes to sub-handlers by tool_name.
# Plugin hooks.json registers this with NO matcher (fires on all PostToolUse).

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
source "$SCRIPT_DIR/lib/state-io.sh" || { printf '{}'; exit 0; }
source "$SCRIPT_DIR/lib/json-extract.sh" || { printf '{}'; exit 0; }

# Buffer stdin ONCE
INPUT=$(cat)

# Resolve session-scoped state file and increment tool call counter
resolve_state_file "$INPUT"
if [ -f "$STATE_FILE" ]; then
  increment_field "tool_calls_count" "$STATE_FILE"
fi

# Extract tool_name for routing
tool_name=$(printf '%s' "$INPUT" | extract_json_field "tool_name")
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
