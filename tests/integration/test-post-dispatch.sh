#!/usr/bin/env bash
set -euo pipefail

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$TESTS_DIR/lib/test-framework.sh"
source "$TESTS_DIR/lib/fixtures.sh"
source "$TESTS_DIR/lib/mock-commands.sh"

PLUGIN_ROOT="$(cd "$TESTS_DIR/.." && pwd)"
source "$PLUGIN_ROOT/hooks/scripts/lib/state-io.sh"

begin_suite "post-dispatch"

# Create sandbox once for the suite
SANDBOX=$(setup_script_sandbox "$_TEST_TMPDIR")

# Set up MOCK_BIN at suite level to avoid subshell PATH issues
MOCK_BIN="$_TEST_TMPDIR/mock-bin"
mkdir -p "$MOCK_BIN"
SAVED_PATH="$PATH"
export PATH="$MOCK_BIN:$PATH"

# Helper: run post-dispatch with given JSON input
run_post_dispatch() {
  local json_input="$1"
  echo "$json_input" | bash "$SANDBOX/hooks/scripts/post-dispatch.sh" 2>/dev/null || true
}

# Test 1: Bash tool routes to post-bash-dispatch (returns {} for non-git commands)
setup_test
create_state_file "$_TEST_TMPDIR/.claude" "pd-bash" "edits_since_last_commit=0" > /dev/null
create_mock_git "$MOCK_BIN" "clean"
mkdir -p "$_TEST_TMPDIR/memory"
echo "# Journal" > "$_TEST_TMPDIR/memory/$(date +%Y-%m-%d).md"
json=$(mock_json "tool_name=Bash" "session_id=pd-bash" "tool_input.command=echo hello")
result=$(run_post_dispatch "$json")
assert_eq "bash_routes_to_post_bash" "{}" "$result"

# Test 2: Write tool increments edits_since_last_commit
setup_test
create_state_file "$_TEST_TMPDIR/.claude" "pd-write" "edits_since_last_commit=3" > /dev/null
json=$(mock_json "tool_name=Write" "session_id=pd-write" "tool_input.file_path=src/lib/utils.ts")
run_post_dispatch "$json" > /dev/null
sf="$_TEST_TMPDIR/.claude/cortex-state-pd-write.local.md"
count=$(grep '^edits_since_last_commit=' "$sf" | cut -d= -f2 | tr -d '\r')
assert_eq "write_increments_edit_count" "4" "$count"

# Test 3: Edit tool increments edits_since_last_commit
setup_test
create_state_file "$_TEST_TMPDIR/.claude" "pd-edit" "edits_since_last_commit=1" > /dev/null
json=$(mock_json "tool_name=Edit" "session_id=pd-edit" "tool_input.file_path=src/lib/scoring.ts")
run_post_dispatch "$json" > /dev/null
sf="$_TEST_TMPDIR/.claude/cortex-state-pd-edit.local.md"
count=$(grep '^edits_since_last_commit=' "$sf" | cut -d= -f2 | tr -d '\r')
assert_eq "edit_increments_edit_count" "2" "$count"

# Test 4: Unknown tool (Read) returns {}
setup_test
json=$(mock_json "tool_name=Read" "session_id=pd-read" "tool_input.file_path=src/lib/utils.ts")
result=$(run_post_dispatch "$json")
assert_eq "unknown_tool_returns_empty" "{}" "$result"

# Test 5: Empty JSON returns {}
setup_test
result=$(echo '{}' | bash "$SANDBOX/hooks/scripts/post-dispatch.sh" 2>/dev/null || true)
assert_eq "empty_json_returns_empty" "{}" "$result"

export PATH="$SAVED_PATH"
end_suite
