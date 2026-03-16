#!/usr/bin/env bash
set -euo pipefail

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$TESTS_DIR/lib/test-framework.sh"
source "$TESTS_DIR/lib/fixtures.sh"
source "$TESTS_DIR/lib/mock-commands.sh"

PLUGIN_ROOT="$(cd "$TESTS_DIR/.." && pwd)"
source "$PLUGIN_ROOT/hooks/scripts/lib/state-io.sh"

begin_suite "session-end-dispatch"

# Create sandbox once for the suite
SANDBOX=$(setup_script_sandbox "$_TEST_TMPDIR")

# Set up MOCK_BIN at suite level to avoid subshell PATH issues
MOCK_BIN="$_TEST_TMPDIR/mock-bin"
mkdir -p "$MOCK_BIN"
SAVED_PATH="$PATH"
export PATH="$MOCK_BIN:$PATH"

# Compute today once at suite level (before any mocks)
TODAY=$(date +%Y-%m-%d)

# Helper: create journal file manually (avoids create_journal + set -u bug)
make_journal() {
  local dir="$1"
  local content="${2:-# Journal - $TODAY}"
  mkdir -p "$dir/memory"
  echo "$content" > "$dir/memory/${TODAY}.md"
}

# Helper: run session-end-dispatch with given session_id
run_session_end() {
  local sid="$1"
  create_mock_git "$MOCK_BIN" "clean"
  echo "{\"session_id\":\"${sid}\"}" | bash "$SANDBOX/hooks/scripts/session-end-dispatch.sh" 2>/dev/null || true
}

# Test 1: Creates health file with header
setup_test
create_state_file "$_TEST_TMPDIR/.claude" "se-health" "health_written=false" > /dev/null
make_journal "$_TEST_TMPDIR"
run_session_end "se-health" > /dev/null
health_file="$_TEST_TMPDIR/.claude/cortex-health.local.md"
assert_file_exists "creates_health_file" "$health_file"
assert_file_contains "health_has_header" "$health_file" "# Cortex Health Log"

# Test 2: Appends data row with today's date
setup_test
create_state_file "$_TEST_TMPDIR/.claude" "se-row" "health_written=false" > /dev/null
make_journal "$_TEST_TMPDIR"
run_session_end "se-row" > /dev/null
health_file="$_TEST_TMPDIR/.claude/cortex-health.local.md"
assert_file_contains "row_has_today_date" "$health_file" "$TODAY"

# Test 3: Dedup prevents duplicate rows (run twice, count rows = 1)
setup_test
create_state_file "$_TEST_TMPDIR/.claude" "se-dedup" "health_written=false" > /dev/null
make_journal "$_TEST_TMPDIR"
run_session_end "se-dedup" > /dev/null
run_session_end "se-dedup" > /dev/null
health_file="$_TEST_TMPDIR/.claude/cortex-health.local.md"
data_rows=0
if [ -f "$health_file" ]; then
  data_rows=$(grep -c '|' "$health_file" | tr -d ' ')
  header_pipes=$(grep -c '^# Fields:' "$health_file" || true)
  data_rows=$((data_rows - header_pipes))
fi
assert_eq "dedup_one_data_row" "1" "$data_rows"

# Test 4: Counts reasoning_misses from journal
setup_test
create_state_file "$_TEST_TMPDIR/.claude" "se-miss" "health_written=false" > /dev/null
mkdir -p "$_TEST_TMPDIR/memory"
cat > "$_TEST_TMPDIR/memory/${TODAY}.md" << 'JEOF'
# Journal
## 10:00 - task
- Did something [reasoning-miss]
## 11:00 - another
- Another thing [reasoning-miss]
- Third one [reasoning-miss]
JEOF
run_session_end "se-miss" > /dev/null
health_file="$_TEST_TMPDIR/.claude/cortex-health.local.md"
# Data row format: date|reasoning_misses|edits_per_commit|...
if [ -f "$health_file" ]; then
  data_line=$(grep "^${TODAY}" "$health_file" | head -1)
  reasoning_misses=$(echo "$data_line" | cut -d'|' -f2)
else
  reasoning_misses="0"
fi
assert_eq "counts_reasoning_misses" "3" "$reasoning_misses"

# Test 5: Computes edits_per_commit (4 files, 2 commits = 2.0)
setup_test
sf=$(create_state_file "$_TEST_TMPDIR/.claude" "se-epc" "health_written=false" "commits_count=2")
sed -i '/^\[files_modified\]$/a src/lib/a.ts\nsrc/lib/b.ts\nsrc/lib/c.ts\nsrc/lib/d.ts' "$sf"
make_journal "$_TEST_TMPDIR"
run_session_end "se-epc" > /dev/null
health_file="$_TEST_TMPDIR/.claude/cortex-health.local.md"
if [ -f "$health_file" ]; then
  data_line=$(grep "^${TODAY}" "$health_file" | head -1)
  epc=$(echo "$data_line" | cut -d'|' -f3)
else
  epc="0"
fi
assert_eq "edits_per_commit_computed" "2.0" "$epc"

# Test 6: No state file → returns {}
setup_test
result=$(echo '{"session_id":"nonexistent"}' | bash "$SANDBOX/hooks/scripts/session-end-dispatch.sh" 2>/dev/null || true)
assert_eq "no_state_file_empty" "{}" "$result"

# Test 7: Sets health_written=true in state file
setup_test
sf=$(create_state_file "$_TEST_TMPDIR/.claude" "se-flag" "health_written=false")
make_journal "$_TEST_TMPDIR"
run_session_end "se-flag" > /dev/null
hw=$(grep '^health_written=' "$sf" | head -1 | cut -d= -f2 | tr -d '\r')
assert_eq "sets_health_written_true" "true" "$hw"

# Test 8: Creates cross-session file
setup_test
sf=$(create_state_file "$_TEST_TMPDIR/.claude" "se-cross" "health_written=false")
sed -i '/^\[files_modified\]$/a src/lib/utils.ts' "$sf"
make_journal "$_TEST_TMPDIR"
run_session_end "se-cross" > /dev/null
cross_file="$_TEST_TMPDIR/.claude/cortex-cross-session.local.md"
assert_file_exists "creates_cross_session_file" "$cross_file"

# Test 9: Topology = "focused" for 2 unique files
setup_test
sf=$(create_state_file "$_TEST_TMPDIR/.claude" "se-topo" "health_written=false")
sed -i '/^\[files_modified\]$/a src/lib/a.ts\nsrc/lib/b.ts' "$sf"
make_journal "$_TEST_TMPDIR"
run_session_end "se-topo" > /dev/null
health_file="$_TEST_TMPDIR/.claude/cortex-health.local.md"
if [ -f "$health_file" ]; then
  data_line=$(grep "^${TODAY}" "$health_file" | head -1)
  topology=$(echo "$data_line" | cut -d'|' -f11)
else
  topology="unknown"
fi
assert_eq "topology_focused" "focused" "$topology"

export PATH="$SAVED_PATH"
end_suite
