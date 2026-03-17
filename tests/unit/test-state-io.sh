#!/usr/bin/env bash
set -euo pipefail

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$TESTS_DIR/lib/test-framework.sh"
source "$TESTS_DIR/lib/fixtures.sh"

PLUGIN_ROOT="$(cd "$TESTS_DIR/.." && pwd)"
source "$PLUGIN_ROOT/hooks/scripts/lib/state-io.sh"

begin_suite "state-io"

# --- read_field tests ---
setup_test
sf=$(create_state_file "$_TEST_TMPDIR/.claude" "test-123")
result=$(read_field "session_id" "$sf")
assert_eq "read_field_existing" "test-123" "$result"

result=$(read_field "nonexistent_field" "$sf" || true)
assert_eq "read_field_missing" "" "$result"

result=$(read_field "session_id" "$_TEST_TMPDIR/does-not-exist.md" || true)
assert_eq "read_field_missing_file" "" "$result"

setup_test
sf=$(create_state_file "$_TEST_TMPDIR/.claude" "eq-test" "last_ci_status=a=b=c")
result=$(read_field "last_ci_status" "$sf")
assert_eq "read_field_with_equals_in_value" "a=b=c" "$result"

setup_test
sf=$(create_state_file "$_TEST_TMPDIR/.claude" "cr-test")
printf "custom_field=value_with_cr\r\n" >> "$sf"
result=$(read_field "custom_field" "$sf")
assert_eq "read_field_strips_carriage_return" "value_with_cr" "$result"

# --- write_field tests ---
setup_test
sf=$(create_state_file "$_TEST_TMPDIR/.claude" "write-test")
write_field "commits_count" "5" "$sf"
result=$(read_field "commits_count" "$sf")
assert_eq "write_field_existing" "5" "$result"

result=$(read_field "session_id" "$sf")
assert_eq "write_field_preserves_other_fields" "write-test" "$result"

write_field "x" "y" "$_TEST_TMPDIR/missing.md"
assert_eq "write_field_missing_file_noop" "0" "0"

setup_test
sf=$(create_state_file "$_TEST_TMPDIR/.claude" "atomic-test")
write_field "commits_count" "10" "$sf"
leftover=$(ls "$_TEST_TMPDIR/.claude/"*.tmp.* 2>/dev/null | wc -l) || true
leftover=$(echo "$leftover" | tr -d '[:space:]')
assert_eq "write_field_atomic_no_temp_files" "0" "$leftover"

# --- increment_field tests ---
setup_test
sf=$(create_state_file "$_TEST_TMPDIR/.claude" "inc-test")
increment_field "commits_count" "$sf"
result=$(read_field "commits_count" "$sf")
assert_eq "increment_field_zero_to_one" "1" "$result"

write_field "edits_since_last_commit" "5" "$sf"
increment_field "edits_since_last_commit" "$sf"
result=$(read_field "edits_since_last_commit" "$sf")
assert_eq "increment_field_five_to_six" "6" "$result"

write_field "commits_count" "abc" "$sf"
increment_field "commits_count" "$sf"
result=$(read_field "commits_count" "$sf")
assert_eq "increment_field_nonnumeric_resets" "1" "$result"

# --- section tests ---
setup_test
sf=$(create_state_file "$_TEST_TMPDIR/.claude" "section-test")
append_to_section "files_modified" "src/lib/test.ts" "$sf"
result=$(read_section "files_modified" "$sf")
assert_contains "append_to_section_basic" "$result" "src/lib/test.ts"

append_to_section "files_modified" "src/lib/other.ts" "$sf"
result=$(read_section "files_modified" "$sf")
assert_contains "append_to_section_multiple" "$result" "src/lib/other.ts"

append_to_section "files_modified" 'C:/Users/test/file.ts' "$sf"
result=$(read_section "files_modified" "$sf")
assert_contains "append_to_section_windows_path" "$result" "C:/Users/test/file.ts"

setup_test
sf=$(create_state_file "$_TEST_TMPDIR/.claude" "empty-section")
result=$(read_section "files_modified" "$sf")
assert_eq "read_section_empty" "" "$result"

# --- normalize_path tests ---
result=$(normalize_path 'C:\Users\test\file.ts')
assert_eq "normalize_path_backslash" "C:/Users/test/file.ts" "$result"

result=$(normalize_path '/c/Users/test')
assert_eq "normalize_path_msys" "C:/Users/test" "$result"

result=$(normalize_path 'c:/foo/bar')
assert_eq "normalize_path_lowercase_drive" "C:/foo/bar" "$result"

# --- resolve_state_file tests ---
setup_test
override_state_paths "$_TEST_TMPDIR"
create_state_file "$_TEST_TMPDIR/.claude" "resolve-test" > /dev/null
resolve_state_file '{"session_id":"resolve-test"}'
assert_contains "resolve_state_file_with_session_id" "$STATE_FILE" "resolve-test.local.md"

setup_test
override_state_paths "$_TEST_TMPDIR"
create_state_file "$_TEST_TMPDIR/.claude" "newest-file" > /dev/null
resolve_state_file '{}'
assert_contains "resolve_state_file_fallback_newest" "$STATE_FILE" ".local.md"

# --- validate_state_file tests ---
setup_test
sf=$(create_state_file "$_TEST_TMPDIR/.claude" "validate-test")
sed -i '/^model_name=/d' "$sf"
validate_state_file "$sf"
result=$(read_field "model_name" "$sf")
assert_eq "validate_state_file_adds_missing_fields" "unknown" "$result"

end_suite
