#!/usr/bin/env bash
set -euo pipefail

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$TESTS_DIR/lib/test-framework.sh"
source "$TESTS_DIR/lib/fixtures.sh"
source "$TESTS_DIR/lib/mock-commands.sh"

PLUGIN_ROOT="$(cd "$TESTS_DIR/.." && pwd)"
source "$PLUGIN_ROOT/hooks/scripts/lib/state-io.sh"

begin_suite "post-edit-dispatch"

# Create sandbox once for the suite
SANDBOX=$(setup_script_sandbox "$_TEST_TMPDIR")

# Helper: run post-edit-dispatch with given file path
run_post_edit() {
  local sid="$1" file_path="$2"
  local json
  json=$(mock_json "session_id=$sid" "tool_input.file_path=$file_path")
  echo "$json" | bash "$SANDBOX/hooks/scripts/post-edit-dispatch.sh" 2>/dev/null || true
}

# Test 1: Edit increments edits_since_last_commit
setup_test
create_state_file "$_TEST_TMPDIR/.claude" "edit-inc" "edits_since_last_commit=2" > /dev/null
run_post_edit "edit-inc" "${_TEST_TMPDIR}/src/lib/utils.ts" > /dev/null
sf="$_TEST_TMPDIR/.claude/cortex-state-edit-inc.local.md"
result=$(grep '^edits_since_last_commit=' "$sf" | cut -d= -f2 | tr -d '\r')
assert_eq "edit_increments_count" "3" "$result"

# Test 2: File path appended to [files_modified]
setup_test
create_state_file "$_TEST_TMPDIR/.claude" "edit-track" "edits_since_last_commit=0" > /dev/null
run_post_edit "edit-track" "src/lib/scoring.ts" > /dev/null
sf="$_TEST_TMPDIR/.claude/cortex-state-edit-track.local.md"
result=$(read_section "files_modified" "$sf")
assert_contains "file_path_tracked" "$result" "src/lib/scoring.ts"

# Test 3: Same file edited 3 times triggers re-edit warning
setup_test
sf=$(create_state_file "$_TEST_TMPDIR/.claude" "re-edit" "edits_since_last_commit=0")
# Pre-populate with 2 prior edits of same file
append_to_section "files_modified" "src/lib/problem.ts" "$sf"
append_to_section "files_modified" "src/lib/problem.ts" "$sf"
# This will be the 3rd edit (count after append = 3)
result=$(run_post_edit "re-edit" "src/lib/problem.ts")
assert_contains "re_edit_warning_at_three" "$result" "Re-edit"

# Test 4: Plugin paths (.claude-plugin/) skip re-edit check
setup_test
sf=$(create_state_file "$_TEST_TMPDIR/.claude" "plugin-skip" "edits_since_last_commit=0")
append_to_section "files_modified" ".claude-plugin/hooks/test.sh" "$sf"
append_to_section "files_modified" ".claude-plugin/hooks/test.sh" "$sf"
result=$(run_post_edit "plugin-skip" ".claude-plugin/hooks/test.sh")
assert_not_contains "plugin_path_skips_re_edit" "$result" "Re-edit"

# Test 5: Editing documentation.md sets docs_updated=true
setup_test
create_state_file "$_TEST_TMPDIR/.claude" "docs-edit" "docs_updated=false" > /dev/null
run_post_edit "docs-edit" "documentation.md" > /dev/null
sf="$_TEST_TMPDIR/.claude/cortex-state-docs-edit.local.md"
result=$(grep '^docs_updated=' "$sf" | cut -d= -f2 | tr -d '\r')
assert_eq "docs_edit_sets_flag" "true" "$result"

# Test 6: Over 15 edits triggers commit nudge
setup_test
create_state_file "$_TEST_TMPDIR/.claude" "nudge-test" "edits_since_last_commit=15" "commit_nudge_threshold=15" > /dev/null
result=$(run_post_edit "nudge-test" "${_TEST_TMPDIR}/src/lib/foo.ts")
assert_contains "commit_nudge_over_threshold" "$result" "commit"

# Test 7: Custom threshold (5) with 6 edits triggers nudge
setup_test
create_state_file "$_TEST_TMPDIR/.claude" "custom-thresh" "edits_since_last_commit=5" "commit_nudge_threshold=5" > /dev/null
result=$(run_post_edit "custom-thresh" "${_TEST_TMPDIR}/src/lib/bar.ts")
assert_contains "custom_threshold_nudge" "$result" "commit"

# Test 8: Editing scoring file without docs_updated triggers reminder
setup_test
create_state_file "$_TEST_TMPDIR/.claude" "arch-remind" "edits_since_last_commit=0" "docs_updated=false" > /dev/null
result=$(run_post_edit "arch-remind" "src/lib/scoring/v11.ts")
assert_contains "scoring_file_doc_reminder" "$result" "documentation.md"

# Test 9: Normal edit under threshold returns {}
setup_test
create_state_file "$_TEST_TMPDIR/.claude" "normal-edit" "edits_since_last_commit=0" "docs_updated=true" "commit_nudge_threshold=15" > /dev/null
result=$(run_post_edit "normal-edit" "src/lib/simple.ts")
assert_eq "normal_edit_empty_response" "{}" "$result"

end_suite
