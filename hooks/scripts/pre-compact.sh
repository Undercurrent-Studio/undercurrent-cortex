#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
source "$SCRIPT_DIR/lib/state-io.sh" || { printf '{}'; exit 0; }
source "$SCRIPT_DIR/lib/json-extract.sh" || { printf '{}'; exit 0; }
source "$SCRIPT_DIR/lib/escape-json.sh" || { printf '{}'; exit 0; }

# Guard: only act in Undercurrent project
is_undercurrent_project || { printf '{}'; exit 0; }

# Graceful degradation: no state file → nothing to preserve
[ -f "$STATE_FILE" ] || { printf '{}'; exit 0; }

# Buffer stdin ONCE (C1 fix — extract_json_field uses cat internally)
INPUT=$(cat)

# --- Optional transcript scan: write discovered items to [carry_over] (I3 fix) ---
transcript_path=$(printf '%s' "$INPUT" | extract_json_field "transcript_path")
if [ -n "$transcript_path" ] && [ -f "$transcript_path" ]; then
  tagged_items=$(grep -oE '\[carry-over\][^"]*' "$transcript_path" 2>/dev/null | head -10 || true)
  if [ -n "$tagged_items" ]; then
    while IFS= read -r item; do
      if [ -n "$item" ]; then
        append_to_section "carry_over" "$item" "$STATE_FILE"
      fi
    done <<< "$tagged_items"
  fi

  pin_items=$(grep -oE '\[mid-session pin\][^"]*' "$transcript_path" 2>/dev/null | head -10 || true)
  if [ -n "$pin_items" ]; then
    while IFS= read -r item; do
      if [ -n "$item" ]; then
        append_to_section "carry_over" "$item" "$STATE_FILE"
      fi
    done <<< "$pin_items"
  fi
fi

# --- Build preservation summary from state file ---
summary="[PRE-COMPACT CONTEXT PRESERVATION]"

# Carry-over items (read AFTER transcript scan writes — I3)
carry_over=$(read_section "carry_over" "$STATE_FILE")
if [ -n "$carry_over" ]; then
  summary="${summary}"$'\n\n'"Carry-over items:"$'\n'"${carry_over}"
fi

# Files modified this session (deduplicated)
files_modified=$(read_section "files_modified" "$STATE_FILE")
if [ -n "$files_modified" ]; then
  unique_files=$(echo "$files_modified" | sort -u)
  file_count=$(echo "$unique_files" | wc -l | tr -d ' ')
  summary="${summary}"$'\n\n'"Files modified (${file_count} unique):"$'\n'"${unique_files}"
fi

# Session counters
commits=$(read_field "commits_count" "$STATE_FILE")
edits=$(read_field "edits_since_last_commit" "$STATE_FILE")
tests_run=$(read_field "tests_run" "$STATE_FILE")
docs_updated=$(read_field "docs_updated" "$STATE_FILE")

summary="${summary}"$'\n\n'"Session stats: ${commits:-0} commits, ${edits:-0} uncommitted edits, tests_run=${tests_run:-false}, docs_updated=${docs_updated:-false}"

# Warnings
if [ "${edits:-0}" -gt 0 ]; then
  summary="${summary}"$'\n'"WARNING: ${edits} uncommitted edits at compaction time."
fi

if [ -n "$carry_over" ]; then
  carry_over_addressed=$(read_field "carry_over_addressed" "$STATE_FILE")
  if [ "$carry_over_addressed" != "true" ]; then
    summary="${summary}"$'\n'"WARNING: Carry-over items not yet addressed."
  fi
fi

# --- Output ---
escaped=$(escape_for_json "$summary")
printf '{"systemMessage":"%s"}' "$escaped"
exit 0
