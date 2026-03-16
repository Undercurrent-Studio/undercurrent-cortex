#!/usr/bin/env bash
set -euo pipefail

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$TESTS_DIR/lib/test-framework.sh"
source "$TESTS_DIR/lib/fixtures.sh"

begin_suite "empty-stdin"

# Create sandbox once for the suite
SANDBOX=$(setup_script_sandbox "$_TEST_TMPDIR")

# Helper: run a hook script with /dev/null as stdin via sandbox
run_with_empty_stdin() {
  local script_name="$1"
  create_state_file "$_TEST_TMPDIR/.claude" "empty-stdin-test" > /dev/null
  bash "$SANDBOX/hooks/scripts/${script_name}" < /dev/null 2>/dev/null || true
}

# Test 1: context-flow with empty stdin
setup_test
result=$(run_with_empty_stdin "context-flow.sh")
assert_eq "context_flow_empty_stdin" "{}" "$result"

# Test 2: pre-dispatch with empty stdin
setup_test
result=$(run_with_empty_stdin "pre-dispatch.sh")
assert_eq "pre_dispatch_empty_stdin" "{}" "$result"

# Test 3: post-edit-dispatch with empty stdin
setup_test
result=$(run_with_empty_stdin "post-edit-dispatch.sh")
assert_eq "post_edit_dispatch_empty_stdin" "{}" "$result"

# Test 4: post-bash-dispatch with empty stdin
setup_test
result=$(run_with_empty_stdin "post-bash-dispatch.sh")
assert_eq "post_bash_dispatch_empty_stdin" "{}" "$result"

# Test 5: stop-gate with empty stdin
setup_test
result=$(run_with_empty_stdin "stop-gate.sh")
# stop-gate with empty stdin and no state file falls through to {}
# or may find a state file and return {} if clean
assert_json_valid "stop_gate_empty_stdin" "$result"

# Test 6: pre-compact with empty stdin
setup_test
result=$(run_with_empty_stdin "pre-compact.sh")
# With no session_id and no state file, returns {}
# If a state file exists from setup, returns systemMessage (valid JSON)
assert_json_valid "pre_compact_empty_stdin" "$result"

# Test 7: session-end-dispatch with empty stdin
setup_test
result=$(run_with_empty_stdin "session-end-dispatch.sh")
assert_json_valid "session_end_dispatch_empty_stdin" "$result"

# Test 8: migration-linter with empty stdin
setup_test
result=$(run_with_empty_stdin "migration-linter.sh")
assert_eq "migration_linter_empty_stdin" "{}" "$result"

end_suite
