#!/usr/bin/env bash
set -euo pipefail

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$TESTS_DIR/lib/test-framework.sh"
source "$TESTS_DIR/lib/fixtures.sh"

PLUGIN_ROOT="$(cd "$TESTS_DIR/.." && pwd)"
source "$PLUGIN_ROOT/hooks/scripts/lib/state-io.sh"

begin_suite "windows-paths"

# Test 1: Backslash to forward slash
setup_test
result=$(normalize_path 'C:\Users\whflo\Desktop\project\src\lib\utils.ts')
assert_eq "backslash_to_forward_slash" "C:/Users/whflo/Desktop/project/src/lib/utils.ts" "$result"

# Test 2: MSYS /c/ to C:/
setup_test
result=$(normalize_path '/c/Users/whflo/Desktop/project/src/lib/utils.ts')
assert_eq "msys_to_windows_drive" "C:/Users/whflo/Desktop/project/src/lib/utils.ts" "$result"

# Test 3: Uppercase drive letter
setup_test
result=$(normalize_path 'c:/Users/whflo/Desktop/project/src/lib/utils.ts')
assert_eq "uppercase_drive_letter" "C:/Users/whflo/Desktop/project/src/lib/utils.ts" "$result"

# Test 4: Append Windows path to section not mangled
setup_test
override_state_paths "$_TEST_TMPDIR"
sf=$(create_state_file "$_TEST_TMPDIR/.claude" "win-path-test")
windows_path='C:\Users\whflo\src\test.ts'
append_to_section "files_modified" "$windows_path" "$sf"
section_content=$(read_section "files_modified" "$sf")
assert_contains "windows_path_in_section" "$section_content" 'C:\Users\whflo\src\test.ts'

# Test 5: is_undercurrent_project with case variations
setup_test
override_state_paths "$_TEST_TMPDIR"
# Set PROJECT_DIR to a known value
PROJECT_DIR="C:/Users/whflo/Desktop/Code Projects/undercurrent-v1"
# Test with lowercase drive
if is_undercurrent_project "c:/Users/whflo/Desktop/Code Projects/undercurrent-v1"; then
  case_result="matched"
else
  case_result="no-match"
fi
assert_eq "is_undercurrent_case_insensitive" "matched" "$case_result"

# Test 6: MSYS uppercase drive /D/ path normalization
setup_test
result=$(normalize_path '/D/projects/undercurrent/src/lib/utils.ts')
assert_eq "msys_uppercase_drive_letter" "D:/projects/undercurrent/src/lib/utils.ts" "$result"

end_suite
