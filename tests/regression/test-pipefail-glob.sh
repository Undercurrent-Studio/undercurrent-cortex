#!/usr/bin/env bash
set -euo pipefail

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$TESTS_DIR/lib/test-framework.sh"
source "$TESTS_DIR/lib/fixtures.sh"

begin_suite "pipefail-glob"

# Regression: under set -euo pipefail, `ls glob | head` kills the script
# when the glob matches nothing. The fix is to append `|| true`.
# These tests verify the pattern doesn't crash.

# Test 1: State file glob with no matches (new layout + legacy)
setup_test
mkdir -p "$_TEST_TMPDIR/.claude/cortex/sessions"
# This pattern mirrors resolve_state_file() in state-io.sh
result=$(ls -t "$_TEST_TMPDIR/.claude/cortex/sessions/"*/*.local.md "$_TEST_TMPDIR/.claude/"cortex-state-*.local.md 2>/dev/null | head -1 || true)
exit_code=$?
assert_eq "state_glob_no_match_survives" "0" "$exit_code"

# Test 2: Temp file glob with no matches
setup_test
# This pattern mirrors cleanup patterns in various scripts
result=$(ls "$_TEST_TMPDIR/.claude/"*.tmp.* 2>/dev/null | head -1 || true)
exit_code=$?
assert_eq "temp_glob_no_match_survives" "0" "$exit_code"

end_suite
