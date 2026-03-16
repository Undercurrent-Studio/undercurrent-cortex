#!/usr/bin/env bash
set -euo pipefail

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$TESTS_DIR/lib/test-framework.sh"
source "$TESTS_DIR/lib/fixtures.sh"
source "$TESTS_DIR/lib/mock-commands.sh"

PLUGIN_ROOT="$(cd "$TESTS_DIR/.." && pwd)"
source "$PLUGIN_ROOT/hooks/scripts/lib/state-io.sh"

begin_suite "health-dedup"

# Create sandbox once for the suite
SANDBOX=$(setup_script_sandbox "$_TEST_TMPDIR")

# Helper: run session-end-dispatch via sandbox
run_session_end() {
  local sid="$1"
  # Mock git to avoid real git calls
  local mock_bin
  mock_bin=$(setup_mock_path "$_TEST_TMPDIR")
  create_mock_git "$mock_bin" "clean"
  echo "{\"session_id\":\"${sid}\"}" | bash "$SANDBOX/hooks/scripts/session-end-dispatch.sh" 2>/dev/null || true
  restore_path
}

# Test 1: health_written=true blocks second write (only 1 data row after 2 calls)
setup_test
create_state_file "$_TEST_TMPDIR/.claude" "dedup-test" "health_written=false" > /dev/null
mkdir -p "$_TEST_TMPDIR/memory"
echo "# Journal" > "$_TEST_TMPDIR/memory/$(date +%Y-%m-%d).md"
# First call — writes health row and sets health_written=true
run_session_end "dedup-test" > /dev/null
# Second call — should be blocked by health_written=true
run_session_end "dedup-test" > /dev/null
# Count data rows (lines with | separator, excluding header/comments)
health_file="$_TEST_TMPDIR/.claude/cortex-health.local.md"
data_rows=0
if [ -f "$health_file" ]; then
  data_rows=$(grep -c '|' "$health_file" | tr -d ' ')
  # Subtract the header comment line that contains |
  header_pipes=$(grep -c '^# Fields:' "$health_file" || true)
  data_rows=$((data_rows - header_pipes))
fi
assert_eq "health_dedup_one_row" "1" "$data_rows"

# Test 2: health_written=false allows write
setup_test
create_state_file "$_TEST_TMPDIR/.claude" "allow-write" "health_written=false" > /dev/null
mkdir -p "$_TEST_TMPDIR/memory"
echo "# Journal" > "$_TEST_TMPDIR/memory/$(date +%Y-%m-%d).md"
run_session_end "allow-write" > /dev/null
health_file="$_TEST_TMPDIR/.claude/cortex-health.local.md"
assert_file_exists "health_file_created" "$health_file"
# Verify at least one data row was written
if [ -f "$health_file" ]; then
  has_data=$(grep -c '|' "$health_file" | tr -d ' ')
  header_pipes=$(grep -c '^# Fields:' "$health_file" || true)
  actual_data=$((has_data - header_pipes))
  result=$([ "$actual_data" -ge 1 ] && echo "yes" || echo "no")
else
  result="no"
fi
assert_eq "health_written_false_allows" "yes" "$result"

# Test 3: Missing health_written field gets added
setup_test
sf=$(create_state_file "$_TEST_TMPDIR/.claude" "missing-field")
# Remove health_written line to simulate missing field
sed -i '/^health_written=/d' "$sf"
mkdir -p "$_TEST_TMPDIR/memory"
echo "# Journal" > "$_TEST_TMPDIR/memory/$(date +%Y-%m-%d).md"
run_session_end "missing-field" > /dev/null
# Verify health_written was added to state file
assert_file_contains "health_written_field_added" "$sf" "health_written=true"

end_suite
