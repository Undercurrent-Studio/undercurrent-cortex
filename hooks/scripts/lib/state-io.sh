#!/usr/bin/env bash
# Shared state file I/O — sourced by all hook scripts
# Provides PROJECT_DIR, STATE_FILE, HEALTH_FILE, PROPOSALS_FILE constants
# and functions for reading/writing the flat key=value state file.

PROJECT_DIR="C:/Users/whflo/Desktop/Code Projects/undercurrent-v1"
STATE_FILE="${PROJECT_DIR}/.claude/undercurrent-state.local.md"
HEALTH_FILE="${PROJECT_DIR}/.claude/undercurrent-health.local.md"
PROPOSALS_FILE="${PROJECT_DIR}/.claude/undercurrent-proposals.local.md"
DECISIONS_FILE="${PROJECT_DIR}/.claude/undercurrent-decisions.local.md"

# read_field "field_name" "file_path"
# Returns the value for a key=value field. Empty string if not found.
read_field() {
  local field="$1"
  local file="${2:-$STATE_FILE}"
  if [ ! -f "$file" ]; then echo ""; return 0; fi
  grep "^${field}=" "$file" 2>/dev/null | head -1 | cut -d= -f2- | tr -d '\r'
}

# write_field "field_name" "value" "file_path"
# Overwrites a key=value field. Uses atomic temp+mv (NOT sed -i).
# CONSTRAINT: values must not contain newlines or pipe characters.
write_field() {
  local field="$1"
  local value="$2"
  local file="${3:-$STATE_FILE}"
  if [ ! -f "$file" ]; then return 0; fi
  sed "s|^${field}=.*|${field}=${value}|" "$file" > "$file.tmp.$$" && mv "$file.tmp.$$" "$file"
}

# increment_field "field_name" "file_path"
# Reads a numeric field, increments by 1, writes back.
increment_field() {
  local field="$1"
  local file="${2:-$STATE_FILE}"
  local current
  current=$(read_field "$field" "$file")
  current="${current:-0}"
  # Guard: non-numeric → reset to 0 (prevents arithmetic crash with set -e)
  case "$current" in *[!0-9]*) current=0 ;; esac
  local next=$(( current + 1 ))
  write_field "$field" "$next" "$file"
}

# append_to_section "section_name" "line_text" "file_path"
# Appends line_text after the [section_name] header.
# CONSTRAINT: line_text must not match ^\[.*\]$ pattern.
append_to_section() {
  local section="$1"
  local line="$2"
  local file="${3:-$STATE_FILE}"
  if [ ! -f "$file" ]; then return 0; fi
  # Use ENVIRON to pass line text — awk -v interprets backslash escapes,
  # which mangles Windows paths (e.g., \Users → Users, \t → tab).
  APPEND_LINE="$line" awk -v sect="[$section]" '
    $0 == sect { print; print ENVIRON["APPEND_LINE"]; next }
    { print }
  ' "$file" > "$file.tmp.$$" && mv "$file.tmp.$$" "$file"
}

# read_section "section_name" "file_path"
# Returns all lines between [section_name] and the next [section] header.
read_section() {
  local section="$1"
  local file="${2:-$STATE_FILE}"
  if [ ! -f "$file" ]; then echo ""; return 0; fi
  awk '/^\['"$section"'\]/{found=1;next} /^\[.*\]$/{found=0} found' "$file" | tr -d '\r' | sed '/^$/d'
}

# validate_state_file "file_path"
# Checks required fields exist. Re-adds missing ones with defaults.
validate_state_file() {
  local file="${1:-$STATE_FILE}"
  if [ ! -f "$file" ]; then return 0; fi
  local required_fields="session_id session_start model_name commits_count edits_since_last_commit tool_calls_count tests_run docs_updated carry_over_addressed stop_hook_active consecutive_blocks debug"
  local defaults="unknown unknown unknown 0 0 0 false false false false 0 false"
  local i=1
  for field in $required_fields; do
    local default_val
    default_val=$(echo "$defaults" | cut -d' ' -f$i)
    if ! grep -q "^${field}=" "$file" 2>/dev/null; then
      # Append before first section header
      sed "/^\[/i\\${field}=${default_val}" "$file" > "$file.tmp.$$" && mv "$file.tmp.$$" "$file"
    fi
    i=$((i + 1))
  done
}

# is_undercurrent_project [dir]
# Returns 0 if current or given directory is the Undercurrent project.
# Handles Git Bash MSYS paths (/c/Users/...) and Windows paths (C:/Users/...).
is_undercurrent_project() {
  local check_dir="${1:-$PWD}"
  # Normalize: backslash → forward slash
  check_dir=$(echo "$check_dir" | sed 's|\\|/|g')
  local normalized_project
  normalized_project=$(echo "$PROJECT_DIR" | sed 's|\\|/|g')
  # Also normalize MSYS paths: /c/Users/... → C:/Users/...
  check_dir=$(echo "$check_dir" | sed 's|^/\([a-zA-Z]\)/|\1:/|')
  normalized_project=$(echo "$normalized_project" | sed 's|^/\([a-zA-Z]\)/|\1:/|')
  # Case-insensitive comparison (drive letter case varies between MSYS and Windows)
  if [ "$(echo "$check_dir" | tr '[:upper:]' '[:lower:]')" = "$(echo "$normalized_project" | tr '[:upper:]' '[:lower:]')" ]; then
    return 0
  fi
  return 1
}
