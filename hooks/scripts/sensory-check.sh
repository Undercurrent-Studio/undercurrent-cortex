#!/usr/bin/env bash
set -euo pipefail
# Sensory System — external awareness: remote commits, CI status, open PRs.
# Called by session-start (full scan) and context-flow (mid-session with cooldown).
# Outputs plain text (caller wraps in JSON).

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
source "$SCRIPT_DIR/lib/state-io.sh" || exit 0

MID_SESSION=false
if [ "${1:-}" = "--mid-session" ]; then
  MID_SESSION=true
fi

# --- Timeout wrapper (Windows Git Bash may lack `timeout`) ---
run_with_timeout() {
  local secs="$1"
  shift
  if command -v timeout >/dev/null 2>&1; then
    timeout "$secs" "$@" 2>/dev/null || true
  else
    "$@" 2>/dev/null || true
  fi
}

# --- Mid-session cooldown: skip if last check <5 min ago ---
if [ "$MID_SESSION" = true ] && [ -f "$STATE_FILE" ]; then
  last_check=$(read_field "last_sensory_check" "$STATE_FILE" 2>/dev/null || echo "")
  if [ -n "$last_check" ]; then
    # C-2 fix: replace ISO 8601 T separator with space for GNU date
    last_epoch=$(date -d "${last_check/T/ }" +%s 2>/dev/null || echo "0")
    now_epoch=$(date +%s)
    if [ "${last_epoch:-0}" -gt 0 ] && [ $((now_epoch - last_epoch)) -lt 300 ]; then
      exit 0  # Cooldown active
    fi
  fi
fi

output=""

# --- Check 1: Remote commits ---
if command -v git >/dev/null 2>&1 && git rev-parse --git-dir >/dev/null 2>&1; then
  remote_url=$(git remote get-url origin 2>/dev/null || echo "")
  if [ -n "$remote_url" ]; then
    current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
    if [ -n "$current_branch" ] && [ "$current_branch" != "HEAD" ]; then
      # Fetch with 2-second timeout
      fetch_output=$(run_with_timeout 2 git fetch --dry-run origin "$current_branch" 2>&1)
      if echo "$fetch_output" | grep -q '[0-9a-f]' 2>/dev/null; then
        output="${output}Remote has new commits on origin/${current_branch} since last fetch."$'\n'
      fi

      # Track remote HEAD
      remote_head=$(git rev-parse "origin/${current_branch}" 2>/dev/null || echo "unknown")
      if [ -f "$STATE_FILE" ]; then
        last_remote=$(read_field "last_remote_head" "$STATE_FILE" 2>/dev/null || echo "")
        if [ -n "$last_remote" ] && [ "$remote_head" != "$last_remote" ] && [ "$remote_head" != "unknown" ]; then
          output="${output}Remote HEAD changed since last session (was: ${last_remote:0:7}, now: ${remote_head:0:7})."$'\n'
        fi
        write_field "last_remote_head" "$remote_head" "$STATE_FILE" 2>/dev/null || true
      fi
    fi
  fi
fi

# --- Check 2: CI status ---
if command -v gh >/dev/null 2>&1; then
  ci_json=$(run_with_timeout 5 gh run list --branch master --limit 3 --json status,conclusion,name)
  if [ -n "$ci_json" ] && [ "$ci_json" != "[]" ]; then
    # Extract latest conclusion (simple grep — avoids jq dependency)
    latest_conclusion=$(echo "$ci_json" | grep -o '"conclusion":"[^"]*"' | head -1 | cut -d'"' -f4 || echo "")
    if [ "$latest_conclusion" = "failure" ]; then
      latest_name=$(echo "$ci_json" | grep -o '"name":"[^"]*"' | head -1 | cut -d'"' -f4 || echo "unknown")
      output="${output}CI FAILED: ${latest_name}. Run: gh run list --limit 3"$'\n'
    fi
    if [ -f "$STATE_FILE" ]; then
      write_field "last_ci_status" "${latest_conclusion:-unknown}" "$STATE_FILE" 2>/dev/null || true
    fi
  fi

  # --- Check 3: Open PRs ---
  pr_json=$(run_with_timeout 5 gh pr list --state open --json number,title --limit 5)
  if [ -n "$pr_json" ] && [ "$pr_json" != "[]" ]; then
    pr_count=0
    if echo "$pr_json" | grep -q '"number"' 2>/dev/null; then
      pr_count=$(echo "$pr_json" | grep -c '"number"' 2>/dev/null || echo "0")
    fi
    if [ "${pr_count:-0}" -gt 0 ]; then
      output="${output}${pr_count} open PR(s) on this repo."$'\n'
    fi
  fi
fi

# Write timestamp
if [ -f "$STATE_FILE" ]; then
  write_field "last_sensory_check" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$STATE_FILE" 2>/dev/null || true
fi

# Output (plain text — caller wraps in JSON if needed)
printf '%s' "$output"
exit 0
