#!/usr/bin/env bash
set -euo pipefail

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$TESTS_DIR/lib/test-framework.sh"
source "$TESTS_DIR/lib/fixtures.sh"

PLUGIN_ROOT="$(cd "$TESTS_DIR/.." && pwd)"
source "$PLUGIN_ROOT/hooks/scripts/lib/state-io.sh"

begin_suite "stop-gate"

# Create sandbox once for the suite
SANDBOX=$(setup_script_sandbox "$_TEST_TMPDIR")

# Helper: run stop-gate with given session state
run_stop_gate() {
  local sid="$1"
  echo "{\"session_id\":\"${sid}\"}" | bash "$SANDBOX/hooks/scripts/stop-gate.sh" 2>/dev/null || true
}

# Test 1: All gates pass (clean state) - returns {}
setup_test
create_state_file "$_TEST_TMPDIR/.claude" "clean-stop" > /dev/null
result=$(run_stop_gate "clean-stop")
assert_eq "all_gates_pass" "{}" "$result"

# Test 2: Block when edits_since_last_commit > 0
setup_test
create_state_file "$_TEST_TMPDIR/.claude" "uncommitted" "edits_since_last_commit=5" > /dev/null
result=$(run_stop_gate "uncommitted")
assert_contains "block_uncommitted_changes" "$result" "block"

# Test 3: Block when docs_updated=false and edits > 3 with scoring files
setup_test
sf=$(create_state_file "$_TEST_TMPDIR/.claude" "docs-gate" "edits_since_last_commit=5" "docs_updated=false")
append_to_section "files_modified" "src/lib/scoring/engine.ts" "$sf"
result=$(run_stop_gate "docs-gate")
assert_contains "block_docs_not_updated" "$result" "documentation.md"

# Test 4: Block when tests_run=false and edits > 3 with .ts files
setup_test
sf=$(create_state_file "$_TEST_TMPDIR/.claude" "tests-gate" "edits_since_last_commit=5" "tests_run=false")
append_to_section "files_modified" "src/lib/utils.ts" "$sf"
result=$(run_stop_gate "tests-gate")
assert_contains "block_tests_not_run" "$result" "Tests not run"

# Test 5: Block when carry_over items exist and carry_over_addressed=false
setup_test
sf=$(create_state_file "$_TEST_TMPDIR/.claude" "carry-gate" "carry_over_addressed=false")
append_to_section "carry_over" "Fix the broken pipeline" "$sf"
result=$(run_stop_gate "carry-gate")
assert_contains "block_carry_over_unaddressed" "$result" "Carry-over"

# Test 6: Skip docs gate when edits <= 2 (even with scoring files)
setup_test
sf=$(create_state_file "$_TEST_TMPDIR/.claude" "low-edits" "edits_since_last_commit=2" "docs_updated=false" "tests_run=true")
append_to_section "files_modified" "src/lib/scoring/engine.ts" "$sf"
result=$(run_stop_gate "low-edits")
# Should still block for uncommitted changes (edits=2 > 0), but NOT for docs
assert_not_contains "skip_docs_gate_low_edits" "$result" "documentation.md"

# Test 7: First block increments consecutive_blocks to 1
setup_test
create_state_file "$_TEST_TMPDIR/.claude" "first-block" "edits_since_last_commit=3" "consecutive_blocks=0" > /dev/null
run_stop_gate "first-block" > /dev/null
sf="$_TEST_TMPDIR/.claude/undercurrent-state-first-block.local.md"
consec=$(grep '^consecutive_blocks=' "$sf" | cut -d= -f2 | tr -d '\r')
assert_eq "first_block_increments" "1" "$consec"

# Test 8: Second block (consecutive_blocks=2) force-approves and resets to 0
setup_test
create_state_file "$_TEST_TMPDIR/.claude" "force-approve" "edits_since_last_commit=5" "consecutive_blocks=2" > /dev/null
result=$(run_stop_gate "force-approve")
assert_contains "force_approve_after_two_blocks" "$result" "force-approved"
sf="$_TEST_TMPDIR/.claude/undercurrent-state-force-approve.local.md"
consec=$(grep '^consecutive_blocks=' "$sf" | cut -d= -f2 | tr -d '\r')
assert_eq "force_approve_resets_counter" "0" "$consec"

# Test 9: Fallback to legacy state file
setup_test
create_legacy_state_file "$_TEST_TMPDIR/.claude" "edits_since_last_commit=3" > /dev/null
result=$(echo '{"session_id":"nonexistent-sid"}' | bash "$SANDBOX/hooks/scripts/stop-gate.sh" 2>/dev/null || true)
assert_contains "fallback_legacy_state" "$result" "block"

# Test 10: Missing state file returns {}
setup_test
result=$(echo '{"session_id":"totally-missing"}' | bash "$SANDBOX/hooks/scripts/stop-gate.sh" 2>/dev/null || true)
assert_eq "missing_state_file_pass" "{}" "$result"

end_suite
