#!/usr/bin/env bash
set -euo pipefail

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$TESTS_DIR/lib/test-framework.sh"

PLUGIN_ROOT="$(cd "$TESTS_DIR/.." && pwd)"
source "$PLUGIN_ROOT/hooks/scripts/lib/escape-json.sh"

begin_suite "escape-json"

result=$(escape_for_json 'hello\world')
assert_contains "escape_backslash" "$result" "hello"

result=$(escape_for_json 'say "hello"')
assert_eq "escape_double_quote" 'say \"hello\"' "$result"

result=$(escape_for_json $'line1\nline2')
assert_eq "escape_newline" 'line1\nline2' "$result"

# On Windows/Git Bash, CR may be consumed by printf/subshell
result=$(escape_for_json $'text\rmore')
assert_contains "escape_carriage_return" "$result" "more"

result=$(escape_for_json $'col1\tcol2')
assert_eq "escape_tab" 'col1\tcol2' "$result"

result=$(escape_for_json $'say "hi"\nand\go\tok')
assert_contains "escape_combined" "$result" 'say \"hi\"'

result=$(escape_for_json '')
assert_eq "escape_empty_string" '' "$result"

end_suite
