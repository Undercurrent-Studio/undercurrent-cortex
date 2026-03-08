#!/usr/bin/env bash
set -euo pipefail
# Unified PreToolUse dispatcher — routes to sub-handlers by tool_name.
# Plugin hooks.json registers this with NO matcher (fires on all PreToolUse).
# Prompt-based hooks remain inline in hooks.json with their own matchers.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
source "$SCRIPT_DIR/lib/state-io.sh"
source "$SCRIPT_DIR/lib/json-extract.sh"

# Buffer stdin ONCE
INPUT=$(cat)

# Extract tool_name for routing
tool_name=$(printf '%s' "$INPUT" | extract_json_field "tool_name")

# Early exit for irrelevant tools
case "$tool_name" in
  Write|Edit) ;;
  *) printf '{}'; exit 0 ;;
esac

# Migration linter runs on Write AND Edit
result=$(printf '%s' "$INPUT" | "$SCRIPT_DIR/migration-linter.sh")

# If migration-linter returned a deny, propagate it immediately
if printf '%s' "$result" | grep -q '"deny"' 2>/dev/null; then
  printf '%s' "$result"
  exit 0
fi

# Plan-file-guard only runs on Write
if [ "$tool_name" = "Write" ]; then
  result=$(printf '%s' "$INPUT" | "$SCRIPT_DIR/plan-file-guard.sh")
  if printf '%s' "$result" | grep -q '"deny"' 2>/dev/null; then
    printf '%s' "$result"
    exit 0
  fi
fi

# If migration-linter returned a warning (systemMessage but not deny), output it
if [ "$result" != "{}" ] && [ -n "$result" ]; then
  printf '%s' "$result"
  exit 0
fi

printf '{}'
exit 0
