#!/usr/bin/env bash
# Healing/Repair System — Organism v3, System 10
# Validates and repairs all organism state files on session boot.
# Sourced by session-start. Requires state-io.sh to be sourced first.

# clamp_field "field" min max ["file"]
# Reads a numeric field. If outside [min, max], clamps and writes back.
# Echoes description if clamped; empty otherwise.
clamp_field() {
  local field="$1" min="$2" max="$3" file="${4:-$STATE_FILE}"
  [ ! -f "$file" ] && return 0
  local val
  val=$(read_field "$field" "$file")
  [ -z "$val" ] && return 0
  # Non-numeric → treat as 0
  case "$val" in *[!0-9-]*) val=0 ;; esac
  if [ "$val" -lt "$min" ] 2>/dev/null; then
    write_field "$field" "$min" "$file"
    echo "clamped ${field} from ${val} to ${min}"
  elif [ "$val" -gt "$max" ] 2>/dev/null; then
    write_field "$field" "$max" "$file"
    echo "clamped ${field} from ${val} to ${max}"
  fi
}

# sanitize_json_field "value"
# Returns empty if value contains newlines or exceeds 200 chars.
sanitize_json_field() {
  local val="$1"
  case "$val" in
    *$'\n'*) echo ""; return 0 ;;
  esac
  if [ "${#val}" -gt 200 ]; then
    echo ""
    return 0
  fi
  echo "$val"
}

# validate_organism
# Returns "issues|repairs|detail1, detail2, ..." via stdout.
# Call from session-start BEFORE reading carry-over from the old state file.
validate_organism() {
  local issues=0 repairs=0 details=""
  local claude_dir
  claude_dir="$(dirname "$STATE_FILE")"

  # --- 1. State file corruption check ---
  if [ -f "$STATE_FILE" ]; then
    if ! grep -q '^session_id=' "$STATE_FILE" 2>/dev/null; then
      local backup="${claude_dir}/state-backup-$(date +%s)"
      cp "$STATE_FILE" "$backup" 2>/dev/null
      issues=$((issues + 1))
      repairs=$((repairs + 1))
      details="${details}backed up corrupted state file, "
    fi
  fi

  # --- 2. State file field clamping ---
  if [ -f "$STATE_FILE" ]; then
    local clamp_result
    for pair in "edits_since_last_commit 0 1000" "commits_count 0 1000" \
                "tool_calls_count 0 10000" "consecutive_blocks 0 10" \
                "carry_over_age 0 50"; do
      clamp_result=$(clamp_field $pair "$STATE_FILE")
      if [ -n "$clamp_result" ]; then
        issues=$((issues + 1))
        repairs=$((repairs + 1))
        details="${details}${clamp_result}, "
      fi
    done
  fi

  # --- 3. [files_modified] section dedup ---
  if [ -f "$STATE_FILE" ]; then
    local fm_count=0
    if grep -q '^\[files_modified\]' "$STATE_FILE" 2>/dev/null; then
      fm_count=$(read_section "files_modified" "$STATE_FILE" | wc -l | tr -d ' ')
    fi
    if [ "${fm_count:-0}" -gt 200 ]; then
      # Deduplicate: awk replaces the section contents with sorted unique lines
      local deduped
      deduped=$(read_section "files_modified" "$STATE_FILE" | sort -u)
      local deduped_count
      deduped_count=$(echo "$deduped" | wc -l | tr -d ' ')
      # Rewrite file: replace section block with deduped content
      awk -v replacement="$deduped" '
        /^\[files_modified\]/ {
          print
          if (replacement != "") print replacement
          skip = 1
          next
        }
        /^\[.*\]$/ { skip = 0 }
        !skip { print }
      ' "$STATE_FILE" > "$STATE_FILE.tmp.$$" && mv "$STATE_FILE.tmp.$$" "$STATE_FILE"
      issues=$((issues + 1))
      repairs=$((repairs + 1))
      details="${details}deduped files_modified from ${fm_count} to ${deduped_count}, "
    fi
  fi

  # --- 4. Health file header recovery ---
  if [ -f "$HEALTH_FILE" ]; then
    if ! grep -q '^trend_direction=' "$HEALTH_FILE" 2>/dev/null; then
      # Extract data rows (contain |), rebuild header + data
      local data_rows
      data_rows=$(grep '|' "$HEALTH_FILE" 2>/dev/null || echo "")
      {
        echo "trend_direction=stable"
        echo "avg_reasoning_misses=0.0"
        echo "avg_edits_per_commit=0.0"
        echo "avg_duration_min=0"
        echo "---"
        if [ -n "$data_rows" ]; then
          echo "$data_rows"
        fi
      } > "$HEALTH_FILE.tmp.$$" && mv "$HEALTH_FILE.tmp.$$" "$HEALTH_FILE"
      issues=$((issues + 1))
      repairs=$((repairs + 1))
      details="${details}rebuilt health file header, "
    fi
  fi

  # --- 5. Health file pruning ---
  if [ -f "$HEALTH_FILE" ]; then
    local total_lines=0
    total_lines=$(wc -l < "$HEALTH_FILE" | tr -d ' ')
    if [ "${total_lines:-0}" -gt 500 ]; then
      # Keep header (non-pipe lines before first pipe line) + last 100 data rows
      local header_lines data_rows
      header_lines=$(awk '/\|/ { exit } { print }' "$HEALTH_FILE")
      data_rows=$(grep '|' "$HEALTH_FILE" 2>/dev/null | tail -100)
      {
        echo "$header_lines"
        if [ -n "$data_rows" ]; then
          echo "$data_rows"
        fi
      } > "$HEALTH_FILE.tmp.$$" && mv "$HEALTH_FILE.tmp.$$" "$HEALTH_FILE"
      issues=$((issues + 1))
      repairs=$((repairs + 1))
      details="${details}pruned health file from ${total_lines} to ~100 rows, "
    fi
  fi

  # --- 6-7. Proposals + decisions file separator check ---
  for f in "$PROPOSALS_FILE" "$DECISIONS_FILE"; do
    if [ -f "$f" ] && ! grep -q '^---' "$f" 2>/dev/null; then
      echo "---" >> "$f"
      issues=$((issues + 1))
      repairs=$((repairs + 1))
      details="${details}added separator to $(basename "$f"), "
    fi
  done

  # --- 8. Temp file cleanup ---
  local stale=0
  if [ -d "$claude_dir" ]; then
    stale=$(find "$claude_dir" -maxdepth 1 -name "*.tmp.*" -mmin +60 2>/dev/null | wc -l | tr -d ' ')
    if [ "${stale:-0}" -gt 0 ]; then
      find "$claude_dir" -maxdepth 1 -name "*.tmp.*" -mmin +60 -delete 2>/dev/null || true
      issues=$((issues + 1))
      repairs=$((repairs + 1))
      details="${details}cleaned ${stale} stale temp files, "
    fi
  fi

  # --- 9.5. Cross-session file pruning (>500 lines) ---
  local cross_file="${CORTEX_DIR:-${PROJECT_DIR}/.claude/cortex}/cross-session.local.md"
  if [ -f "$cross_file" ]; then
    local cross_lines
    cross_lines=$(wc -l < "$cross_file" | tr -d ' ')
    if [ "${cross_lines:-0}" -gt 500 ]; then
      local cutoff
      cutoff=$(date -d "30 days ago" +%Y-%m-%d 2>/dev/null || date -v-30d +%Y-%m-%d 2>/dev/null || echo "")
      if [ -n "$cutoff" ]; then
        CUTOFF="$cutoff" awk -F'|' '
          /^#/ { print; next }
          NF < 3 { print; next }
          $3 >= ENVIRON["CUTOFF"] { print }
        ' "$cross_file" > "$cross_file.tmp.$$" && mv "$cross_file.tmp.$$" "$cross_file"
        local new_lines
        new_lines=$(wc -l < "$cross_file" | tr -d ' ')
        issues=$((issues + 1))
        repairs=$((repairs + 1))
        details="${details}pruned cross-session file from ${cross_lines} to ${new_lines} lines, "
      fi
    fi
  fi

  # --- 9. Old backup cleanup (>7 days) ---
  if [ -d "$claude_dir" ]; then
    local old_backups=0
    old_backups=$(find "$claude_dir" -maxdepth 1 -name "state-backup-*" -mmin +10080 2>/dev/null | wc -l | tr -d ' ')
    if [ "${old_backups:-0}" -gt 0 ]; then
      find "$claude_dir" -maxdepth 1 -name "state-backup-*" -mmin +10080 -delete 2>/dev/null || true
      issues=$((issues + 1))
      repairs=$((repairs + 1))
      details="${details}cleaned ${old_backups} old state backups, "
    fi
  fi

  # Strip trailing ", "
  details="${details%, }"

  echo "${issues}|${repairs}|${details}"
}
