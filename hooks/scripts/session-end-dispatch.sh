#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
source "$SCRIPT_DIR/lib/state-io.sh" || { printf '{}'; exit 0; }

# Buffer stdin (SessionEnd may or may not provide JSON)
INPUT=$(cat)

# Resolve session-scoped state file from session_id in hook JSON
resolve_state_file "$INPUT"

# Guard: state file must exist (session-start creates it)
# Fallback: if session-scoped file doesn't exist, try legacy file
if [ ! -f "$STATE_FILE" ]; then
  legacy="${STATE_DIR}/cortex-state.local.md"
  if [ -f "$legacy" ]; then
    STATE_FILE="$legacy"
  else
    printf '{}'
    exit 0
  fi
fi

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
topology="focused"
if [ -n "$files_modified" ]; then
  # Find max edits to any single file
  max_re_edits=$(echo "$files_modified" | sort | uniq -c | awk '{print $1}' | sort -rn | head -n 1)
  max_re_edits="${max_re_edits:-0}"

  # Classify: focused (<=2), iterating (3-5), high-churn (6+)
  if [ "$max_re_edits" -ge 6 ]; then
    topology="high-churn"
  elif [ "$max_re_edits" -ge 3 ]; then
    topology="iterating"
  fi
fi

# --- Domain tagging ---
domain_tag="mixed"
if [ -n "$files_modified" ]; then
  top_dir=$(echo "$files_modified" \
    | grep -oE '[^/]+/[^/]+' \
    | sort | uniq -c | sort -rn | head -1 \
    | awk '{print $2}' 2>/dev/null || echo "")
  # Fallback for root-level files (no subdirectory)
  if [ -z "$top_dir" ]; then
    top_dir=$(echo "$files_modified" \
      | grep -oE '[^/]+$' \
      | sort | uniq -c | sort -rn | head -1 \
      | awk '{print $2}' 2>/dev/null || echo "root")
  fi
  if [ -n "$top_dir" ]; then
    domain_tag="$top_dir"
  fi
elif [ "${total_edits:-0}" -eq 0 ]; then
  domain_tag="idle"
fi

# --- Cross-session file tracking (runs before zero-metric skip) ---
# Cross-session tracks file edit patterns across sessions — this should happen
# regardless of whether we write a health row. Moved before zero-metric exit.
CROSS_FILE="${PROJECT_DIR}/.claude/cortex-cross-session.local.md"
if [ ! -f "$CROSS_FILE" ]; then
  {
    echo "# Cross-Session File Edit Tracker"
    echo "# Format: filepath|session_count|last_session_date"
  } > "$CROSS_FILE"
fi

if [ -n "$files_modified" ]; then
  unique_files=$(echo "$files_modified" | sort -u)
  while IFS= read -r raw_filepath; do
    [ -z "$raw_filepath" ] && continue
    # Fix 2: Skip non-path lines (state flags like health_written=true leak into [files_modified])
    echo "$raw_filepath" | grep -qE '[/\\]' || continue
    # Fix 1: Normalize path format (backslash→forward slash, lowercase drive→uppercase)
    filepath=$(normalize_path "$raw_filepath")
    # Skip plugin infrastructure files
    echo "$filepath" | grep -qE '\.claude-plugin/|\.claude/' && continue
    if grep -qF "${filepath}|" "$CROSS_FILE" 2>/dev/null; then
      old_count=$(grep -F "${filepath}|" "$CROSS_FILE" | head -1 | cut -d'|' -f2)
      new_count=$((old_count + 1))
      # Use awk + ENVIRON to avoid Windows path mangling
      FILEPATH="$filepath" NEWCOUNT="$new_count" TODAY="$today" awk '
        BEGIN { fp=ENVIRON["FILEPATH"]; nc=ENVIRON["NEWCOUNT"]; td=ENVIRON["TODAY"] }
        index($0, fp"|") == 1 { print fp"|"nc"|"td; next }
        { print }
      ' "$CROSS_FILE" > "$CROSS_FILE.tmp.$$" && mv "$CROSS_FILE.tmp.$$" "$CROSS_FILE"
    else
      echo "${filepath}|1|${today}" >> "$CROSS_FILE"
    fi
  done <<< "$unique_files"
fi

# Prune cross-session entries older than 30 days
cutoff=$(date -d "30 days ago" +%Y-%m-%d 2>/dev/null || date -v-30d +%Y-%m-%d 2>/dev/null || echo "")
if [ -n "$cutoff" ] && [ -f "$CROSS_FILE" ]; then
  CUTOFF="$cutoff" awk -F'|' '
    /^#/ { print; next }
    NF < 3 { print; next }
    $3 >= ENVIRON["CUTOFF"] { print }
  ' "$CROSS_FILE" > "$CROSS_FILE.tmp.$$" && mv "$CROSS_FILE.tmp.$$" "$CROSS_FILE"
fi

# --- Skip health row if session had zero tracked activity (noise prevention) ---
# Prevents writing all-zero rows from idle/exploratory sessions.
# Includes carry_total so carry-over resolution tracking isn't lost.
# NOTE: cross-session tracking runs BEFORE this exit — file patterns are always tracked.
if [ "${total_edits:-0}" -eq 0 ] && [ "${commits_count:-0}" -eq 0 ] && \
   [ "${reasoning_misses:-0}" -eq 0 ] && [ "${tests_delta:-0}" -eq 0 ] && \
   [ "${lessons_created:-0}" -eq 0 ] && [ "${carry_total:-0}" -eq 0 ]; then
  echo "session-end-dispatch: all metrics zero, skipping health row" >&2
  printf '{}'
  exit 0
fi

# --- Dedup guard: prevent duplicate health writes if hook fires multiple times ---
# Placed AFTER zero-metric skip so idle sessions don't burn the flag.
health_written=$(grep '^health_written=' "$STATE_FILE" 2>/dev/null | head -1 | cut -d= -f2- | tr -d '\r' || true)
if [ "$health_written" = "true" ]; then
  printf '{}'
  exit 0
fi
# Mark as written — append field if missing, replace if present
if grep -q '^health_written=' "$STATE_FILE" 2>/dev/null; then
  write_field "health_written" "true" "$STATE_FILE"
else
  # Insert before first section header (only first match via 0,/pattern/)
  sed '0,/^\[/{s/^\[/health_written=true\n[/}' "$STATE_FILE" > "$STATE_FILE.tmp.$$" && mv "$STATE_FILE.tmp.$$" "$STATE_FILE"
fi

# --- Write to health file ---
mkdir -p "$(dirname "$HEALTH_FILE")"

# Create file with header if it doesn't exist
if [ ! -f "$HEALTH_FILE" ]; then
  cat > "$HEALTH_FILE" << 'HEADER'
# Cortex Health Log
# Fields: date|reasoning_misses|edits_per_commit|docs_synced|tests_delta|lessons_created|carry_resolved|carry_total|duration_min|max_re_edits|topology|domain_tag
trend_direction=stable
avg_reasoning_misses=0.0
avg_edits_per_commit=0.0
avg_duration_min=0
---
HEADER
fi

# Append data row (12 fields — old rows with 11 are backward-compatible)
echo "${today}|${reasoning_misses}|${edits_per_commit}|${docs_synced}|${tests_delta}|${lessons_created}|${carry_resolved}|${carry_total}|${duration_min}|${max_re_edits}|${topology}|${domain_tag}" >> "$HEALTH_FILE"

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

# --- Proposal count warning ---
if [ -f "$PROPOSALS_FILE" ]; then
  if grep -q '^id=' "$PROPOSALS_FILE" 2>/dev/null; then
    proposal_count=$(grep -c '^id=' "$PROPOSALS_FILE" 2>/dev/null)
    if [ "${proposal_count:-0}" -gt 50 ]; then
      write_field "proposals_need_archiving" "true" "$STATE_FILE" 2>/dev/null || true
    fi
  fi
fi

printf '{}'
exit 0
