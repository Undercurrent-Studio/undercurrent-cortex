#!/usr/bin/env bash
set -euo pipefail

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$TESTS_DIR/lib/test-framework.sh"
source "$TESTS_DIR/lib/fixtures.sh"
source "$TESTS_DIR/lib/mock-commands.sh"

PLUGIN_ROOT="$(cd "$TESTS_DIR/.." && pwd)"
source "$PLUGIN_ROOT/hooks/scripts/lib/state-io.sh"

begin_suite "post-bash-dispatch"

# Create sandbox once for the suite
SANDBOX=$(setup_script_sandbox "$_TEST_TMPDIR")

# Helper: run post-bash-dispatch with given command
# Uses mock git to control commit message for conventional commit check.
run_post_bash() {
  local sid="$1" command_str="$2" mock_behavior="${3:-clean}"
  # Create mock journal so commit logging does not fail
  mkdir -p "$_TEST_TMPDIR/memory"
  echo "# Journal" > "$_TEST_TMPDIR/memory/$(date +%Y-%m-%d).md"
  # Mock git so journal commit-message extraction works
  local mock_bin
  mock_bin=$(setup_mock_path "$_TEST_TMPDIR")
  create_mock_git "$mock_bin" "$mock_behavior"
  local json
  json=$(mock_json "session_id=$sid" "tool_input.command=$command_str")
  echo "$json" | bash "$SANDBOX/hooks/scripts/post-bash-dispatch.sh" 2>/dev/null || true
  restore_path
}

# Test 1: git commit increments commits_count
setup_test
create_state_file "$_TEST_TMPDIR/.claude" "commit-inc" "commits_count=2" > /dev/null
run_post_bash "commit-inc" "git commit -m feat-test" > /dev/null
sf="$_TEST_TMPDIR/.claude/cortex/sessions/test-week/commit-inc.local.md"
result=$(grep '^commits_count=' "$sf" | cut -d= -f2 | tr -d '\r')
assert_eq "commit_increments_count" "3" "$result"

# Test 2: Commit resets edits_since_last_commit to 0
setup_test
create_state_file "$_TEST_TMPDIR/.claude" "commit-reset" "edits_since_last_commit=8" > /dev/null
run_post_bash "commit-reset" "git commit -m fix-bug" > /dev/null
sf="$_TEST_TMPDIR/.claude/cortex/sessions/test-week/commit-reset.local.md"
result=$(grep '^edits_since_last_commit=' "$sf" | cut -d= -f2 | tr -d '\r')
assert_eq "commit_resets_edits" "0" "$result"

# Test 3: Commit resets stop_hook_active and consecutive_blocks
setup_test
create_state_file "$_TEST_TMPDIR/.claude" "commit-flags" "stop_hook_active=true" "consecutive_blocks=2" > /dev/null
run_post_bash "commit-flags" "git commit -m chore-cleanup" > /dev/null
sf="$_TEST_TMPDIR/.claude/cortex/sessions/test-week/commit-flags.local.md"
stop_result=$(grep '^stop_hook_active=' "$sf" | cut -d= -f2 | tr -d '\r')
consec_result=$(grep '^consecutive_blocks=' "$sf" | cut -d= -f2 | tr -d '\r')
assert_eq "commit_resets_stop_hook" "false" "$stop_result"
assert_eq "commit_resets_consecutive" "0" "$consec_result"

# Test 4: git commit --amend does NOT increment
setup_test
create_state_file "$_TEST_TMPDIR/.claude" "amend-test" "commits_count=5" "edits_since_last_commit=3" > /dev/null
run_post_bash "amend-test" "git commit --amend" > /dev/null
sf="$_TEST_TMPDIR/.claude/cortex/sessions/test-week/amend-test.local.md"
result=$(grep '^commits_count=' "$sf" | cut -d= -f2 | tr -d '\r')
assert_eq "amend_does_not_increment" "5" "$result"

# Test 5: npm test sets tests_run=true
setup_test
create_state_file "$_TEST_TMPDIR/.claude" "test-run" "tests_run=false" > /dev/null
run_post_bash "test-run" "npm test" > /dev/null
sf="$_TEST_TMPDIR/.claude/cortex/sessions/test-week/test-run.local.md"
result=$(grep '^tests_run=' "$sf" | cut -d= -f2 | tr -d '\r')
assert_eq "npm_test_sets_flag" "true" "$result"

# Test 6: Conventional commit - no warning (mock git returns "feat: test commit message")
setup_test
create_state_file "$_TEST_TMPDIR/.claude" "conv-ok" "commits_count=0" > /dev/null
result=$(run_post_bash "conv-ok" "git commit -m test")
assert_eq "conventional_commit_no_warn" "{}" "$result"

# Test 7: npx vitest also sets tests_run=true
setup_test
create_state_file "$_TEST_TMPDIR/.claude" "vitest-run" "tests_run=false" > /dev/null
run_post_bash "vitest-run" "npx vitest run" > /dev/null
sf="$_TEST_TMPDIR/.claude/cortex/sessions/test-week/vitest-run.local.md"
result=$(grep '^tests_run=' "$sf" | cut -d= -f2 | tr -d '\r')
assert_eq "vitest_sets_flag" "true" "$result"

# Test 8: Non-git command returns {}
setup_test
create_state_file "$_TEST_TMPDIR/.claude" "npm-cmd" "commits_count=0" > /dev/null
result=$(run_post_bash "npm-cmd" "npm install lodash")
assert_eq "non_git_returns_empty" "{}" "$result"

end_suite
