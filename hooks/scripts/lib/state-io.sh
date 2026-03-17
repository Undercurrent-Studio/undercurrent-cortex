#!/usr/bin/env bash
# Shared state file I/O — sourced by all hook scripts
# Provides PROJECT_DIR, STATE_FILE, HEALTH_FILE, PROPOSALS_FILE constants
# and functions for reading/writing the flat key=value state file.
#
# Session-scoped state files: each Claude Code session gets its own state file
# (cortex-state-{session_id}.local.md) to avoid collisions when running
# multiple sessions concurrently. Shared files (health, proposals, decisions)
# remain singleton.

PROJECT_DIR="${CORTEX_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
STATE_DIR="${PROJECT_DIR}/.claude"
# STATE_FILE is set dynamically by resolve_state_file() or init_state_file()
# Default fallback for scripts that don't call either:
STATE_FILE="${STATE_DIR}/cortex-state.local.md"
HEALTH_FILE="${STATE_DIR}/cortex-health.local.md"
PROPOSALS_FILE="${STATE_DIR}/cortex-proposals.local.md"
DECISIONS_FILE="${STATE_DIR}/cortex-decisions.local.md"

# resolve_state_file "json_input"
# Extracts session_id from hook stdin JSON and sets STATE_FILE to the
# session-scoped state file. Falls back to the newest state file if
# session_id is not available.
resolve_state_file() {
  local json_input="${1:-}"
  local sid=""

  # Try to extract session_id from JSON input
  if [ -n "$json_input" ]; then
    # Try jq first, then python3, then bash
    if command -v jq >/dev/null 2>&1; then
      sid=$(echo "$json_input" | jq -r '.session_id // empty' 2>/dev/null)
    fi
    if [ -z "$sid" ] && command -v python3 >/dev/null 2>&1; then
      sid=$(echo "$json_input" | python3 -c "import sys,json; print(json.load(sys.stdin).get('session_id',''))" 2>/dev/null)
    fi
    if [ -z "$sid" ]; then
      # Bash fallback
      local tmp="${json_input#*\"session_id\":\"}"
      if [ "$tmp" != "$json_input" ]; then
        sid="${tmp%%\"*}"
      fi
    fi
  fi

  if [ -n "$sid" ]; then
    STATE_FILE="${STATE_DIR}/cortex-state-${sid}.local.md"
    # If session-specific file doesn't exist, try legacy single file
    if [ ! -f "$STATE_FILE" ]; then
      local legacy="${STATE_DIR}/cortex-state.local.md"
      if [ -f "$legacy" ]; then
        local legacy_sid
        legacy_sid=$(grep '^session_id=' "$legacy" 2>/dev/null | cut -d= -f2- | tr -d '\r')
        # If legacy file has the same session_id, migrate it
        if [ "$legacy_sid" = "$sid" ]; then
          mv "$legacy" "$STATE_FILE" 2>/dev/null || true
        fi
      fi
    fi
  else
    # No session_id available — find the state file with the most activity
    # (not just newest). This handles manual invocation from session-end skill
    # where the newest file may be idle but an older one has tracked edits.
    local best_file=""
    local best_count=0
    for f in "${STATE_DIR}"/cortex-state-*.local.md; do
      [ -f "$f" ] || continue
      local count=0
      # Audit fix: grep -c returns 0 AND exits non-zero on empty input,
      # causing || echo "0" to double-output. Use grep -q guard first.
      if sed -n '/^\[files_modified\]/,/^\[/{//!p;}' "$f" 2>/dev/null | grep -q . 2>/dev/null; then
        count=$(sed -n '/^\[files_modified\]/,/^\[/{//!p;}' "$f" 2>/dev/null | grep -c .)
      fi
      if [ "$count" -gt "$best_count" ]; then
        best_count=$count
        best_file="$f"
      fi
    done
    if [ -n "$best_file" ]; then
      STATE_FILE="$best_file"
    else
      # All empty — fall back to newest
      local newest
      newest=$(ls -t "${STATE_DIR}"/cortex-state-*.local.md 2>/dev/null | head -1 || true)
      if [ -n "$newest" ]; then
        STATE_FILE="$newest"
      else
        STATE_FILE="${STATE_DIR}/cortex-state.local.md"
      fi
    fi
  fi
}

# init_state_file "session_id"
# Creates a new session-scoped state file. Called by session-start.
init_state_file() {
  local sid="$1"
  STATE_FILE="${STATE_DIR}/cortex-state-${sid}.local.md"
}

# cleanup_stale_state_files
# Removes state files older than 24 hours. Called by session-start.
cleanup_stale_state_files() {
  local cutoff_epoch
  cutoff_epoch=$(date -d "24 hours ago" +%s 2>/dev/null || date -v-24H +%s 2>/dev/null || echo "0")
  [ "$cutoff_epoch" -eq 0 ] && return 0

  for f in "${STATE_DIR}"/cortex-state-*.local.md; do
    [ -f "$f" ] || continue
    local file_epoch
    file_epoch=$(stat -c %Y "$f" 2>/dev/null || stat -f %m "$f" 2>/dev/null || echo "0")
    if [ "$file_epoch" -gt 0 ] && [ "$file_epoch" -lt "$cutoff_epoch" ]; then
      rm -f "$f"
    fi
  done

  # Clean up legacy undercurrent-state-*.local.md files (same age check)
  for f in "${STATE_DIR}"/undercurrent-state-*.local.md; do
    [ -f "$f" ] || continue
    local file_epoch
    file_epoch=$(stat -c %Y "$f" 2>/dev/null || stat -f %m "$f" 2>/dev/null || echo "0")
    if [ "$file_epoch" -gt 0 ] && [ "$file_epoch" -lt "$cutoff_epoch" ]; then
      rm -f "$f"
    fi
  done

  # Delete the massive legacy singleton unconditionally (pre-session-scoping artifact)
  rm -f "${STATE_DIR}/undercurrent-state.local.md" 2>/dev/null || true

  # Also remove legacy single cortex file if stale
  local legacy="${STATE_DIR}/cortex-state.local.md"
  if [ -f "$legacy" ]; then
    local file_epoch
    file_epoch=$(stat -c %Y "$legacy" 2>/dev/null || stat -f %m "$legacy" 2>/dev/null || echo "0")
    if [ "$file_epoch" -gt 0 ] && [ "$file_epoch" -lt "$cutoff_epoch" ]; then
      rm -f "$legacy"
    fi
  fi
}

# migrate_state_files
# Merges data from undercurrent-* files into cortex-* equivalents, then
# deletes the old files. For singleton files (health, proposals, decisions),
# merges content rows. For session-scoped files, simple rename.
migrate_state_files() {
  # --- Health file merge ---
  local old_health="${STATE_DIR}/undercurrent-health.local.md"
  local new_health="${STATE_DIR}/cortex-health.local.md"
  if [ -f "$old_health" ]; then
    if [ -f "$new_health" ]; then
      # Both exist — merge data rows from old into new (dedup by full row content)
      local old_data
      old_data=$(sed -n '/^---$/,$p' "$old_health" 2>/dev/null | tail -n +2)
      if [ -n "$old_data" ]; then
        local existing_rows
        existing_rows=$(sed -n '/^---$/,$p' "$new_health" 2>/dev/null | tail -n +2)
        while IFS= read -r row; do
          [ -z "$row" ] && continue
          # Dedup by full row content (not just date — same day can have multiple sessions)
          if [ -z "$existing_rows" ] || ! echo "$existing_rows" | grep -qxF "$row" 2>/dev/null; then
            # Use awk with ENVIRON for safe append (avoids sed special char issues)
            ROW_DATA="$row" awk '/^---$/ { print; print ENVIRON["ROW_DATA"]; next } { print }' \
              "$new_health" > "$new_health.tmp.$$" && mv "$new_health.tmp.$$" "$new_health"
          fi
        done <<< "$old_data"
      fi
      # Copy rolling averages from old if new has all zeros
      local old_avg_misses
      old_avg_misses=$(grep '^avg_reasoning_misses=' "$old_health" 2>/dev/null | cut -d= -f2-)
      local new_avg_misses
      new_avg_misses=$(grep '^avg_reasoning_misses=' "$new_health" 2>/dev/null | cut -d= -f2-)
      if [ "${new_avg_misses:-0.0}" = "0.0" ] && [ -n "$old_avg_misses" ] && [ "$old_avg_misses" != "0.0" ]; then
        # Carry forward old averages
        for field in avg_reasoning_misses avg_edits_per_commit avg_duration_min; do
          local old_val
          old_val=$(grep "^${field}=" "$old_health" 2>/dev/null | cut -d= -f2-)
          if [ -n "$old_val" ]; then
            sed "s|^${field}=.*|${field}=${old_val}|" "$new_health" > "$new_health.tmp.$$" \
              && mv "$new_health.tmp.$$" "$new_health"
          fi
        done
      fi
      rm -f "$old_health"
      echo "migrate_state_files: merged undercurrent health into cortex" >&2
    else
      # Only old exists — simple rename
      mv "$old_health" "$new_health" 2>/dev/null || true
    fi
  fi

  # --- Proposals/decisions: simple rename (content is just headers) ---
  for suffix in proposals decisions; do
    local old_f="${STATE_DIR}/undercurrent-${suffix}.local.md"
    local new_f="${STATE_DIR}/cortex-${suffix}.local.md"
    if [ -f "$old_f" ]; then
      [ -f "$new_f" ] && rm -f "$old_f" || mv "$old_f" "$new_f" 2>/dev/null || true
    fi
  done

  # --- Session-scoped state files: rename remaining undercurrent-state-* ---
  for old_file in "${STATE_DIR}"/undercurrent-state-*.local.md; do
    [ -f "$old_file" ] || continue
    local new_file="${old_file/undercurrent-/cortex-}"
    [ -f "$new_file" ] || mv "$old_file" "$new_file" 2>/dev/null || true
  done
}

# read_field "field_name" "file_path"
# Returns the value for a key=value field. Empty string if not found.
read_field() {
  local field="$1"
  local file="${2:-$STATE_FILE}"
  if [ ! -f "$file" ]; then echo ""; return 0; fi
  grep "^${field}=" "$file" 2>/dev/null | head -1 | cut -d= -f2- | tr -d '\r' || true
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

# normalize_path "path"
# Normalizes a file path: backslash → forward slash, lowercase drive → uppercase.
# Used to prevent duplicate tracking of the same file with different path formats.
normalize_path() {
  local p="$1"
  # Backslash → forward slash
  p="${p//\\//}"
  # MSYS path /c/Users/... → C:/Users/...
  if [[ "$p" =~ ^/([a-zA-Z])/ ]]; then
    p="${BASH_REMATCH[1]^^}:/${p:3}"
  fi
  # Lowercase drive letter → uppercase (c:/ → C:/)
  if [[ "$p" =~ ^[a-z]:/ ]]; then
    p="${p^}"
  fi
  echo "$p"
}

# get_profile
# Returns the active Cortex profile: minimal, standard (default), or strict.
# Resolution: CORTEX_PROFILE env var → .claude/cortex-profile.local file → "standard".
get_profile() {
  local profile="${CORTEX_PROFILE:-}"
  if [ -z "$profile" ] && [ -f "${STATE_DIR:-}/cortex-profile.local" ]; then
    profile=$(head -1 "${STATE_DIR}/cortex-profile.local" 2>/dev/null | tr -d '[:space:]')
  fi
  case "$profile" in
    minimal|strict) echo "$profile" ;;
    *) echo "standard" ;;
  esac
}

# Run migration on source (rename undercurrent-* -> cortex-*)
migrate_state_files
