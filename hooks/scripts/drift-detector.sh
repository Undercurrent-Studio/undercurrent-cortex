#!/usr/bin/env bash
# Codebase Drift Detector — SessionStart async hook
# Runs 1 of 5 rotating spot-checks per session (day-of-year mod 5).
# Silent when clean. Reports drift as additional_context.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
source "$SCRIPT_DIR/lib/state-io.sh"
source "$SCRIPT_DIR/lib/escape-json.sh"

# Guard: only act in Undercurrent project
is_undercurrent_project || { printf '{}'; exit 0; }

# Consume stdin (hook may pass data; we don't need it)
cat > /dev/null 2>&1 || true

PROJECT="$PROJECT_DIR"

# Rotate checks: day-of-year mod 5 → picks check 0-4
day_of_year=$(date +%j | sed 's/^0*//')
day_of_year="${day_of_year:-1}"
check_index=$(( day_of_year % 5 ))

findings=""

case $check_index in
  0)
    # Check: Test file count vs CLAUDE.md
    expected=""
    if [ -f "$PROJECT/CLAUDE.md" ]; then
      if grep -q "tests across" "$PROJECT/CLAUDE.md" 2>/dev/null; then
        line=$(grep "tests across" "$PROJECT/CLAUDE.md" 2>/dev/null | head -1)
        expected=$(echo "$line" | sed -n 's/.*across \([0-9]*\) files.*/\1/p')
      fi
    fi
    if [ -z "$expected" ]; then
      # Can't parse reference value — skip silently
      printf '{}'
      exit 0
    fi
    actual=$(find "$PROJECT/src/__tests__" -name "*.test.*" -type f 2>/dev/null | wc -l | tr -d ' ')
    if [ "$actual" != "$expected" ]; then
      findings="Drift: CLAUDE.md says ${expected} test files but found ${actual} in src/__tests__/. Update CLAUDE.md."
    fi
    ;;

  1)
    # Check: Migration count vs highest-numbered migration file
    if [ ! -d "$PROJECT/supabase/migrations" ]; then
      printf '{}'
      exit 0
    fi
    # Get highest migration number from actual files
    highest_file=$(find "$PROJECT/supabase/migrations" -name "*.sql" -type f 2>/dev/null | sort | tail -1)
    if [ -z "$highest_file" ]; then
      printf '{}'
      exit 0
    fi
    highest_num=$(basename "$highest_file" | sed -n 's/^\([0-9]*\).*/\1/p' | sed 's/^0*//')
    highest_num="${highest_num:-0}"
    actual_count=$(find "$PROJECT/supabase/migrations" -name "*.sql" -type f 2>/dev/null | wc -l | tr -d ' ')

    # Parse CLAUDE.md range ("001-067")
    expected_upper=""
    if [ -f "$PROJECT/CLAUDE.md" ]; then
      if grep -q "Migrations.*[0-9]\{3\}-[0-9]\{3\}" "$PROJECT/CLAUDE.md" 2>/dev/null; then
        line=$(grep "Migrations.*[0-9]\{3\}-[0-9]\{3\}" "$PROJECT/CLAUDE.md" 2>/dev/null | head -1)
        expected_upper=$(echo "$line" | sed -n 's/.*-\([0-9]\{3\}\).*/\1/p' | sed 's/^0*//')
      fi
    fi
    if [ -z "$expected_upper" ]; then
      printf '{}'
      exit 0
    fi

    if [ "$actual_count" != "$expected_upper" ] || [ "$highest_num" != "$expected_upper" ]; then
      findings="Drift: CLAUDE.md says migrations 001-$(printf '%03d' "$expected_upper") but found ${actual_count} files (highest: $(printf '%03d' "$highest_num")). Update CLAUDE.md."
    fi
    ;;

  2)
    # Check: Bare process.env usage outside env.ts (server-side only)
    violations=""
    if [ -d "$PROJECT/src" ]; then
      violations=$(grep -rn "process\.env\." "$PROJECT/src" \
        --include="*.ts" --include="*.tsx" \
        2>/dev/null \
        | grep -v "src/lib/env\.ts" \
        | grep -v "__tests__" \
        | grep -v "\.test\." \
        | grep -v "node_modules" \
        | grep -v "NEXT_PUBLIC_" \
        | grep -v "NODE_ENV" \
        | grep -v "NEXT_RUNTIME" \
        | grep -v "instrumentation\.ts" \
        | head -5 \
        || true)
    fi
    if [ -n "$violations" ]; then
      count=$(echo "$violations" | wc -l | tr -d ' ')
      first_file=$(echo "$violations" | head -1 | sed "s|$PROJECT/||" | cut -d: -f1)
      findings="Drift: ${count} server-side process.env usage(s) outside src/lib/env.ts (first: ${first_file}). Route through getServerEnv()."
    fi
    ;;

  3)
    # Check: documentation.md freshness vs src/ commits
    if ! command -v git >/dev/null 2>&1 || [ ! -d "$PROJECT/.git" ]; then
      printf '{}'
      exit 0
    fi
    doc_hash=$(cd "$PROJECT" && git log --format=%H -1 -- documentation.md 2>/dev/null)
    if [ -z "$doc_hash" ]; then
      printf '{}'
      exit 0
    fi
    commits_behind=$(cd "$PROJECT" && git rev-list --count "${doc_hash}..HEAD" -- src/ 2>/dev/null || echo "0")
    commits_behind=$(echo "$commits_behind" | tr -d ' \r')
    if [ "${commits_behind:-0}" -ge 3 ]; then
      findings="Drift: documentation.md is ${commits_behind} src/ commits behind HEAD. Update docs to reflect recent code changes."
    fi
    ;;

  4)
    # Check: API route count vs documentation.md
    actual_routes=0
    if [ -d "$PROJECT/src/app/api" ]; then
      actual_routes=$(find "$PROJECT/src/app/api" -name "route.ts" -type f 2>/dev/null | wc -l | tr -d ' ')
    fi

    doc_routes=0
    if [ -f "$PROJECT/documentation.md" ]; then
      if grep -q '| `/api/' "$PROJECT/documentation.md" 2>/dev/null; then
        doc_routes=$(grep '| `/api/' "$PROJECT/documentation.md" 2>/dev/null \
          | sed -n 's/.*`\(\/api\/[^`]*\)`.*/\1/p' \
          | sort -u \
          | wc -l | tr -d ' ')
      fi
    fi

    if [ "$doc_routes" -gt 0 ] 2>/dev/null && [ "$actual_routes" != "$doc_routes" ]; then
      findings="Drift: ${actual_routes} API route files exist but documentation.md lists ${doc_routes} unique routes. Check for undocumented or removed routes."
    fi
    ;;
esac

# Output: silent when clean
if [ -z "$findings" ]; then
  printf '{}'
  exit 0
fi

escaped=$(escape_for_json "$findings")

cat <<EOF
{"additional_context":"<drift-detector>${escaped}</drift-detector>"}
EOF
exit 0
