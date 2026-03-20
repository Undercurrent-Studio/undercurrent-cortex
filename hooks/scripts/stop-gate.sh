#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
source "$SCRIPT_DIR/lib/state-io.sh" || { printf '{}'; exit 0; }
source "$SCRIPT_DIR/lib/json-extract.sh" || { printf '{}'; exit 0; }
source "$SCRIPT_DIR/lib/escape-json.sh" || { printf '{}'; exit 0; }

STOP_GATE_FILE="${CORTEX_DIR}/stop-gate-counter"

# Buffer stdin ONCE (C1 fix — extract_json_field uses cat internally)
INPUT=$(cat)

# Resolve session-scoped state file from session_id in hook JSON
resolve_state_file "$INPUT"

# Debug: trace state file resolution for forensic analysis
[ "${CORTEX_DEBUG:-}" = "true" ] && echo "stop-gate: resolved STATE_FILE=$(basename "$STATE_FILE" 2>/dev/null)" >&2

# Graceful degradation: no state file → try legacy, else approve
if [ ! -f "$STATE_FILE" ]; then
  # Try newest file across new layout + legacy flat
  local_fallback=$(ls -t "${SESSIONS_DIR}"/*/*.local.md "${STATE_DIR}"/cortex-state-*.local.md "${STATE_DIR}/cortex-state.local.md" 2>/dev/null | head -1 || true)
  if [ -n "$local_fallback" ] && [ -f "$local_fallback" ]; then
    STATE_FILE="$local_fallback"
  else
    printf '{}'
    exit 0
  fi
fi

# --- ESCAPE HATCH: dedicated counter file (decoupled from session state) ---
mkdir -p "$CORTEX_DIR" 2>/dev/null || true
consecutive=$(cat "$STOP_GATE_FILE" 2>/dev/null || echo "0")
consecutive="${consecutive:-0}"
[ "${CORTEX_DEBUG:-}" = "true" ] && echo "stop-gate: consecutive_blocks=${consecutive}" >&2

if [ "$consecutive" -ge 2 ]; then
  echo "0" > "$STOP_GATE_FILE"
  msg=$(escape_for_json "Stop gate: force-approved after acknowledgment. Some obligations may be unmet.")
  printf '{"systemMessage":"%s"}' "$msg"
  exit 0
fi

# --- GATE CHECKS ---
failures=""

# Read state
edits=$(read_field "edits_since_last_commit" "$STATE_FILE")
edits="${edits:-0}"

# Gate 1: Uncommitted changes
if [ "$edits" -gt 0 ]; then
  # Self-heal: if a git commit happened since session start, counter is stale (async race)
  session_start_ts=$(read_field "session_start" "$STATE_FILE")
  if [ -n "$session_start_ts" ]; then
    latest_commit_ts=$(git -C "${PROJECT_DIR}" log -1 --format="%ci" 2>/dev/null || true)
    if [ -n "$latest_commit_ts" ]; then
      session_epoch=$(date -d "${session_start_ts/T/ }" +%s 2>/dev/null || echo "0")
      commit_epoch=$(date -d "${latest_commit_ts/T/ }" +%s 2>/dev/null || echo "0")
      if [ "$commit_epoch" -gt "$session_epoch" ] && [ "$session_epoch" -gt 0 ]; then
        # Commit happened after session start — counter is stale, reset it
        write_field "edits_since_last_commit" "0" "$STATE_FILE"
        edits=0
      fi
    fi
  fi

  # Belt-and-suspenders: verify with git status (catches gitignored, already-committed, stale counters)
  if [ "$edits" -gt 0 ] && git -C "${PROJECT_DIR}" rev-parse --git-dir >/dev/null 2>&1; then
    actual_changes=$(git -C "${PROJECT_DIR}" status --porcelain 2>/dev/null | grep -vE '^\?\?' | wc -l | tr -d ' ')
    actual_changes="${actual_changes:-0}"
    if [ "$actual_changes" -eq 0 ]; then
      write_field "edits_since_last_commit" "0" "$STATE_FILE"
      edits=0
    fi
  fi

  if [ "$edits" -gt 0 ]; then
    failures="${failures}- Uncommitted changes (${edits} edits since last commit)\n"
  fi
fi

# Gates 2 & 3 only fire when many files modified (avoid nagging on quick fixes)
# Use file count instead of edit counter (which may be reset by self-heal above)
files_modified=$(read_section "files_modified" "$STATE_FILE")
file_count=0
if [ -n "$files_modified" ]; then
  file_count=$(echo "$files_modified" | wc -l | tr -d ' ')
fi

if [ "$file_count" -gt 3 ]; then

  # Gate 2: documentation.md not updated after architectural changes
  docs_updated=$(read_field "docs_updated" "$STATE_FILE")
  if [ "$docs_updated" != "true" ]; then
    if echo "$files_modified" | grep -qiE 'scoring|pipeline|v10|v11|constants|middleware|cached-loader|signals'; then
      failures="${failures}- documentation.md not updated after architectural changes\n"
    fi
  fi

  # Gate 3: Tests not run after modifying TypeScript files
  tests_run=$(read_field "tests_run" "$STATE_FILE")
  if [ "$tests_run" != "true" ]; then
    if echo "$files_modified" | grep -qiE '\.(ts|tsx)$'; then
      failures="${failures}- Tests not run after modifying TypeScript files\n"
    fi
  fi
fi

# Gate 4: Carry-over items not addressed
carry_over=$(read_section "carry_over" "$STATE_FILE")
if [ -n "$carry_over" ]; then
  carry_over_addressed=$(read_field "carry_over_addressed" "$STATE_FILE")
  if [ "$carry_over_addressed" != "true" ]; then
    failures="${failures}- Carry-over items from prior session not addressed\n"
  fi
fi

# Gate 5: Stale carry-over (3+ sessions unresolved)
carry_over_age=$(read_field "carry_over_age" "$STATE_FILE")
carry_over_age="${carry_over_age:-0}"
if [ "$carry_over_age" -ge 3 ]; then
  failures="${failures}- Stale carry-over: items unresolved for ${carry_over_age} sessions. Address or explicitly discard.\n"
fi

# Gate 7: Decisions captured after plan-mode session
plan_mode_used=$(read_field "plan_mode_used" "$STATE_FILE" 2>/dev/null || echo "")
decisions_logged=$(read_field "decisions_logged" "$STATE_FILE" 2>/dev/null || echo "")
commits_for_g7=$(read_field "commits_count" "$STATE_FILE" 2>/dev/null || echo "0")
commits_for_g7="${commits_for_g7:-0}"
if [ "$plan_mode_used" = "true" ] && [ "$commits_for_g7" -gt 0 ] && [ "$decisions_logged" != "true" ]; then
  failures="${failures}- Decisions not captured: plan-audit Gate 17 not run this session. Log decisions to .claude/cortex/decisions.local.md before stopping.\n"
fi

# Gate 6: Root cause documentation for fix: commits
commits_count_g6=$(read_field "commits_count" "$STATE_FILE")
commits_count_g6="${commits_count_g6:-0}"
if [ "$commits_count_g6" -gt 0 ]; then
  session_start_g6=$(read_field "session_start" "$STATE_FILE")
  has_fix_commit=false
  if [ -n "$session_start_g6" ] && git -C "${PROJECT_DIR}" rev-parse --git-dir >/dev/null 2>&1; then
    fix_commits=$(git -C "${PROJECT_DIR}" log --format=%s --since="${session_start_g6}" --grep="^fix:" 2>/dev/null || true)
    if [ -n "$fix_commits" ]; then
      has_fix_commit=true
    fi
  fi
  if [ "$has_fix_commit" = true ]; then
    root_cause_doc=$(read_field "root_cause_documented" "$STATE_FILE")
    if [ "$root_cause_doc" != "true" ]; then
      profile=$(get_profile)
      case "$profile" in
        minimal) ;; # no enforcement
        *)
          failures="${failures}- Root cause not documented after fix: commit. Update tasks/lessons.md with pattern + prevention rule.\n"
          ;;
      esac
    fi
  fi
fi

# --- DECISION ---
if [ -n "$failures" ]; then
  new_consecutive=$((consecutive + 1))
  echo "$new_consecutive" > "$STOP_GATE_FILE"
  echo "stop-gate: BLOCKED — incremented consecutive_blocks to ${new_consecutive}" >&2

  reason=$(escape_for_json "Stop blocked. Address obligations above, then stop again to override.\nUnmet gates:\n${failures}")
  printf '{"decision":"block","reason":"%s"}' "$reason"
  exit 0
fi

# All gates pass → approve, reset counter
echo "0" > "$STOP_GATE_FILE"
printf '{}'
exit 0
