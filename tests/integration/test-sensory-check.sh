#!/usr/bin/env bash
set -euo pipefail

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$TESTS_DIR/lib/test-framework.sh"
source "$TESTS_DIR/lib/fixtures.sh"
source "$TESTS_DIR/lib/mock-commands.sh"

PLUGIN_ROOT="$(cd "$TESTS_DIR/.." && pwd)"
source "$PLUGIN_ROOT/hooks/scripts/lib/state-io.sh"

begin_suite "sensory-check"

# Create sandbox once for the suite
SANDBOX=$(setup_script_sandbox "$_TEST_TMPDIR")

# Set up MOCK_BIN at suite level to avoid subshell PATH issues
MOCK_BIN="$_TEST_TMPDIR/mock-bin"
mkdir -p "$MOCK_BIN"
SAVED_PATH="$PATH"
export PATH="$MOCK_BIN:$PATH"

# sensory-check.sh does NOT call resolve_state_file — it uses the default
# STATE_FILE from state-io.sh, which in the sandbox is the legacy path:
#   $_TEST_TMPDIR/.claude/undercurrent-state.local.md
# So we must use create_legacy_state_file for all tests.

# Test 1: Clean state, CI success — does NOT contain "CI FAILED"
setup_test
create_legacy_state_file "$_TEST_TMPDIR/.claude" > /dev/null
create_mock_git "$MOCK_BIN" "clean"
create_mock_gh "$MOCK_BIN" "success"
result=$(bash "$SANDBOX/hooks/scripts/sensory-check.sh" 2>/dev/null || true)
assert_not_contains "clean_no_ci_failure" "$result" "CI FAILED"

# Test 2: CI failure — contains "CI FAILED"
setup_test
create_legacy_state_file "$_TEST_TMPDIR/.claude" > /dev/null
create_mock_git "$MOCK_BIN" "clean"
create_mock_gh "$MOCK_BIN" "failure"
result=$(bash "$SANDBOX/hooks/scripts/sensory-check.sh" 2>/dev/null || true)
assert_contains "ci_failure_reported" "$result" "CI FAILED"

# Test 3: Mid-session cooldown active — empty output
setup_test
sf=$(create_legacy_state_file "$_TEST_TMPDIR/.claude")
# The legacy template doesn't have last_sensory_check — add it before [files_modified]
now_iso=$(date -u +%Y-%m-%dT%H:%M:%SZ)
sed -i "s|^\[files_modified\]|last_sensory_check=${now_iso}\n\n[files_modified]|" "$sf"
create_mock_git "$MOCK_BIN" "clean"
create_mock_gh "$MOCK_BIN" "failure"
result=$(bash "$SANDBOX/hooks/scripts/sensory-check.sh" --mid-session 2>/dev/null || true)
assert_eq "mid_session_cooldown_skips" "" "$result"

# Test 4: Full scan (no --mid-session) ignores cooldown — still shows CI failure
setup_test
sf=$(create_legacy_state_file "$_TEST_TMPDIR/.claude")
now_iso=$(date -u +%Y-%m-%dT%H:%M:%SZ)
sed -i "s|^\[files_modified\]|last_sensory_check=${now_iso}\n\n[files_modified]|" "$sf"
create_mock_git "$MOCK_BIN" "clean"
create_mock_gh "$MOCK_BIN" "failure"
result=$(bash "$SANDBOX/hooks/scripts/sensory-check.sh" 2>/dev/null || true)
assert_contains "full_scan_ignores_cooldown" "$result" "CI FAILED"

# Test 5: No gh command — graceful, no crash, no "CI FAILED"
setup_test
create_legacy_state_file "$_TEST_TMPDIR/.claude" > /dev/null
create_mock_git "$MOCK_BIN" "clean"
hide_command "$MOCK_BIN" "gh"
result=$(bash "$SANDBOX/hooks/scripts/sensory-check.sh" 2>/dev/null || true)
assert_not_contains "no_gh_graceful" "$result" "CI FAILED"

# Test 6: Writes last_sensory_check timestamp to state file
setup_test
sf=$(create_legacy_state_file "$_TEST_TMPDIR/.claude")
# Add the field so write_field can update it
sed -i "s|^\[files_modified\]|last_sensory_check=\n\n[files_modified]|" "$sf"
create_mock_git "$MOCK_BIN" "clean"
create_mock_gh "$MOCK_BIN" "success"
bash "$SANDBOX/hooks/scripts/sensory-check.sh" 2>/dev/null || true
timestamp=$(grep '^last_sensory_check=' "$sf" 2>/dev/null | tail -1 | cut -d= -f2- | tr -d '\r')
if [ -n "$timestamp" ] && [ "$timestamp" != "" ]; then
  printf "    ${_GREEN}PASS${_RESET}  %s\n" "writes_timestamp_to_state"
  _PASS_COUNT=$((_PASS_COUNT + 1))
else
  printf "    ${_RED}FAIL${_RESET}  %s\n" "writes_timestamp_to_state"
  printf "          expected non-empty timestamp, got: '%s'\n" "$timestamp"
  _FAIL_COUNT=$((_FAIL_COUNT + 1))
fi

export PATH="$SAVED_PATH"
end_suite
