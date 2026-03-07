#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
source "$SCRIPT_DIR/lib/state-io.sh"

# Guard: only act in Undercurrent project
is_undercurrent_project || { printf '{}'; exit 0; }

# Buffer stdin (SessionEnd may or may not provide JSON — we don't use it)
INPUT=$(cat)

# Guard: state file must exist (session-start creates it)
[ -f "$STATE_FILE" ] || { printf '{}'; exit 0; }

# --- Compute metrics ---
today=$(date +%Y-%m-%d)
journal="${PROJECT_DIR}/memory/${today}.md"

# 1. reasoning_misses: count [reasoning-miss] tags in today's journal
reasoning_misses=0
if [ -f "$journal" ]; then
  if grep -c '\[reasoning-miss\]' "$journal" >/dev/null 2>&1; then
    reasoning_misses=$(grep -c '\[reasoning-miss\]' "$journal" 2>/dev/null)
  fi
fi

# 2. edits_per_commit: total edit operations / max(commits, 1)
commits_count=$(read_field "commits_count" "$STATE_FILE")
commits_count="${commits_count:-0}"
files_modified=$(read_section "files_modified" "$STATE_FILE")
total_edits=0
if [ -n "$files_modified" ]; then
  total_edits=$(echo "$files_modified" | wc -l | tr -d ' ')
fi
divisor=$commits_count
[ "$divisor" -eq 0 ] && divisor=1
edits_per_commit=$(awk "BEGIN { printf \"%.1f\", $total_edits / $divisor }")

# 3. docs_synced
docs_synced=$(read_field "docs_updated" "$STATE_FILE")
docs_synced="${docs_synced:-false}"

# 4. tests_delta: count test/spec files in [files_modified]
tests_delta=0
if [ -n "$files_modified" ]; then
  if echo "$files_modified" | grep -qE '\.(test|spec)\.' 2>/dev/null; then
    tests_delta=$(echo "$files_modified" | grep -cE '\.(test|spec)\.' 2>/dev/null)
  fi
fi

# 5. lessons_created: lines added to tasks/lessons.md (staged + unstaged)
lessons_created=0
if command -v git >/dev/null 2>&1; then
  diff_output=$(git -C "$PROJECT_DIR" diff HEAD -- tasks/lessons.md 2>/dev/null || true)
  if [ -n "$diff_output" ] && echo "$diff_output" | grep -q '^+[^+]' 2>/dev/null; then
    lessons_created=$(echo "$diff_output" | grep -c '^+[^+]' 2>/dev/null)
  fi
fi

# 6/7. carry_over resolution (binary: all or nothing)
carry_over=$(read_section "carry_over" "$STATE_FILE")
carry_total=0
carry_resolved=0
if [ -n "$carry_over" ]; then
  carry_total=$(echo "$carry_over" | wc -l | tr -d ' ')
  carry_over_addressed=$(read_field "carry_over_addressed" "$STATE_FILE")
  if [ "$carry_over_addressed" = "true" ]; then
    carry_resolved=$carry_total
  fi
fi

# 8. duration_minutes: session_start → now
session_start=$(read_field "session_start" "$STATE_FILE")
duration_min=0
if [ -n "$session_start" ] && [ "$session_start" != "PLACEHOLDER_TIME" ] && [ "$session_start" != "unknown" ]; then
  # C-2 fix: replace ISO 8601 T separator with space for GNU date
  start_epoch=$(date -d "${session_start/T/ }" +%s 2>/dev/null || echo "0")
  now_epoch=$(date +%s)
  if [ "$start_epoch" -gt 0 ]; then
    duration_min=$(( (now_epoch - start_epoch) / 60 ))
  fi
fi

# 9/10. Topology classification from re-edit counts
max_re_edits=0
topology="linear"
if [ -n "$files_modified" ]; then
  # Find max edits to any single file
  max_re_edits=$(echo "$files_modified" | sort | uniq -c | awk '{print $1}' | sort -rn | head -n 1)
  max_re_edits="${max_re_edits:-0}"

  # Classify per master plan spec: linear (<=2), spiral (3-5), thrashing (6+)
  if [ "$max_re_edits" -ge 6 ]; then
    topology="thrashing"
  elif [ "$max_re_edits" -ge 3 ]; then
    topology="spiral"
  fi
fi

# --- Write to health file ---
mkdir -p "$(dirname "$HEALTH_FILE")"

# Create file with header if it doesn't exist
if [ ! -f "$HEALTH_FILE" ]; then
  cat > "$HEALTH_FILE" << 'HEADER'
# Undercurrent Health Log
# Fields: date|reasoning_misses|edits_per_commit|docs_synced|tests_delta|lessons_created|carry_resolved|carry_total|duration_min|max_re_edits|topology
trend_direction=stable
avg_reasoning_misses=0.0
avg_edits_per_commit=0.0
avg_duration_min=0
---
HEADER
fi

# Append data row
echo "${today}|${reasoning_misses}|${edits_per_commit}|${docs_synced}|${tests_delta}|${lessons_created}|${carry_resolved}|${carry_total}|${duration_min}|${max_re_edits}|${topology}" >> "$HEALTH_FILE"

# --- Recompute rolling averages from last 10 data lines ---
data_lines=$(grep -v '^#' "$HEALTH_FILE" | grep -v '^$' | grep -v '^trend_' | grep -v '^avg_' | grep -v '^---' | grep '|' | tail -10)
line_count=$(echo "$data_lines" | wc -l | tr -d ' ')

if [ "$line_count" -ge 1 ]; then
  # Compute averages via awk
  read -r avg_rm avg_epc avg_dur <<< $(echo "$data_lines" | awk -F'|' '{
    rm += $2; epc += $3; dur += $9; count++
  } END {
    printf "%.1f %.1f %d", rm/count, epc/count, dur/count
  }')

  # Trend detection: compare last 3 vs prior sessions (requires 6+ data points)
  trend="stable"
  if [ "$line_count" -ge 6 ]; then
    recent_3_misses=$(echo "$data_lines" | tail -3 | awk -F'|' '{s+=$2} END {printf "%.1f", s/3}')
    prior_misses=$(echo "$data_lines" | head -n -3 | tail -4 | awk -F'|' '{s+=$2; c++} END {if(c>0) printf "%.1f", s/c; else printf "0.0"}')
    trend=$(awk "BEGIN {
      diff = $recent_3_misses - $prior_misses
      if (diff > 0.5) print \"degrading\"
      else if (diff < -0.5) print \"improving\"
      else print \"stable\"
    }")
  fi

  # M-2 fix: single awk pass to update all header fields atomically
  awk -v trend="$trend" -v arm="$avg_rm" -v aepc="$avg_epc" -v adur="$avg_dur" '
    /^trend_direction=/ { print "trend_direction=" trend; next }
    /^avg_reasoning_misses=/ { print "avg_reasoning_misses=" arm; next }
    /^avg_edits_per_commit=/ { print "avg_edits_per_commit=" aepc; next }
    /^avg_duration_min=/ { print "avg_duration_min=" adur; next }
    { print }
  ' "$HEALTH_FILE" > "$HEALTH_FILE.tmp.$$" && mv "$HEALTH_FILE.tmp.$$" "$HEALTH_FILE"
fi

printf '{}'
exit 0
