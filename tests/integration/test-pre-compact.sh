#!/usr/bin/env bash
set -euo pipefail

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$TESTS_DIR/lib/test-framework.sh"
source "$TESTS_DIR/lib/fixtures.sh"

PLUGIN_ROOT="$(cd "$TESTS_DIR/.." && pwd)"
source "$PLUGIN_ROOT/hooks/scripts/lib/state-io.sh"

begin_suite "pre-compact"

# Create sandbox once for the suite
SANDBOX=$(setup_script_sandbox "$_TEST_TMPDIR")

# Helper: run pre-compact with given session state
run_pre_compact() {
  local sid="$1"
  echo "{\"session_id\":\"${sid}\"}" | bash "$SANDBOX/hooks/scripts/pre-compact.sh" 2>/dev/null || true
}

# Test 1: Preserves carry-over in output
setup_test
sf=$(create_state_file "$_TEST_TMPDIR/.claude" "compact-carry" "carry_over_addressed=false")
append_to_section "carry_over" "Fix broken pipeline" "$sf"
result=$(run_pre_compact "compact-carry")
assert_contains "preserves_carry_over" "$result" "Fix broken pipeline"

# Test 2: Preserves files-modified list
setup_test
sf=$(create_state_file "$_TEST_TMPDIR/.claude" "compact-files")
append_to_section "files_modified" "src/lib/scoring.ts" "$sf"
append_to_section "files_modified" "src/lib/utils.ts" "$sf"
result=$(run_pre_compact "compact-files")
assert_contains "preserves_files_modified" "$result" "src/lib/scoring.ts"

# Test 3: Preserves session stats
setup_test
create_state_file "$_TEST_TMPDIR/.claude" "compact-stats" \
  "commits_count=3" "edits_since_last_commit=2" "tests_run=true" "docs_updated=true" > /dev/null
result=$(run_pre_compact "compact-stats")
assert_contains "preserves_session_stats" "$result" "3 commits"

# Test 4: Warns on uncommitted edits
setup_test
create_state_file "$_TEST_TMPDIR/.claude" "compact-warn-edits" "edits_since_last_commit=5" > /dev/null
result=$(run_pre_compact "compact-warn-edits")
assert_contains "warns_uncommitted_edits" "$result" "uncommitted edits"

# Test 5: Warns on unaddressed carry-over
setup_test
sf=$(create_state_file "$_TEST_TMPDIR/.claude" "compact-warn-carry" "carry_over_addressed=false")
append_to_section "carry_over" "Unfinished item" "$sf"
result=$(run_pre_compact "compact-warn-carry")
assert_contains "warns_unaddressed_carry_over" "$result" "Carry-over"

# Test 6: Handles missing state file gracefully (returns {})
setup_test
result=$(echo '{"session_id":"nonexistent-compact"}' | bash "$SANDBOX/hooks/scripts/pre-compact.sh" 2>/dev/null || true)
assert_eq "handles_missing_state_file" "{}" "$result"

end_suite
