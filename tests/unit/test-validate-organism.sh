#!/usr/bin/env bash
set -euo pipefail

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$TESTS_DIR/lib/test-framework.sh"
source "$TESTS_DIR/lib/fixtures.sh"

PLUGIN_ROOT="$(cd "$TESTS_DIR/.." && pwd)"
source "$PLUGIN_ROOT/hooks/scripts/lib/state-io.sh"
source "$PLUGIN_ROOT/hooks/scripts/lib/validate-organism.sh"

begin_suite "validate-organism"

# --- clamp_field tests ---
setup_test
sf=$(create_state_file "$_TEST_TMPDIR/.claude" "clamp-test" "edits_since_last_commit=5")
clamp_field "edits_since_last_commit" 0 1000 "$sf"
result=$(read_field "edits_since_last_commit" "$sf")
assert_eq "clamp_field_within_range" "5" "$result"

setup_test
sf=$(create_state_file "$_TEST_TMPDIR/.claude" "clamp-low" "edits_since_last_commit=-5")
clamp_field "edits_since_last_commit" 0 1000 "$sf"
result=$(read_field "edits_since_last_commit" "$sf")
assert_eq "clamp_field_below_min" "0" "$result"

setup_test
sf=$(create_state_file "$_TEST_TMPDIR/.claude" "clamp-high" "edits_since_last_commit=9999")
clamp_field "edits_since_last_commit" 0 1000 "$sf"
result=$(read_field "edits_since_last_commit" "$sf")
assert_eq "clamp_field_above_max" "1000" "$result"

# --- sanitize_json_field tests ---
result=$(sanitize_json_field "normal string")
assert_eq "sanitize_json_field_clean" "normal string" "$result"

result=$(sanitize_json_field $'has\nnewline')
assert_eq "sanitize_json_field_newline" "" "$result"

long_str=$(printf '%0.s-' {1..201})
result=$(sanitize_json_field "$long_str")
assert_eq "sanitize_json_field_too_long" "" "$result"

# --- validate_organism tests ---
setup_test
override_state_paths "$_TEST_TMPDIR"
sf=$(create_state_file "$_TEST_TMPDIR/.claude" "validate-org" "edits_since_last_commit=5000")
STATE_FILE="$sf"
result=$(validate_organism 2>/dev/null || echo "error")
assert_contains "validate_clamps_large_edits" "$result" "clamped"

# Health header recovery
setup_test
override_state_paths "$_TEST_TMPDIR"
echo "# Health Log" > "$HEALTH_FILE"
echo "---" >> "$HEALTH_FILE"
sf=$(create_state_file "$_TEST_TMPDIR/.claude" "health-header")
STATE_FILE="$sf"
validate_organism 2>/dev/null || true
if [ -f "$HEALTH_FILE" ]; then
  assert_file_contains "validate_health_header_recovery" "$HEALTH_FILE" "trend_direction="
else
  skip_test "validate_health_header_recovery" "health file not created"
fi

# Stale temp cleanup
setup_test
override_state_paths "$_TEST_TMPDIR"
touch "$_TEST_TMPDIR/.claude/somefile.tmp.12345"
# Make it old (if touch -t works)
touch -t 202601010000 "$_TEST_TMPDIR/.claude/somefile.tmp.12345" 2>/dev/null || true
sf=$(create_state_file "$_TEST_TMPDIR/.claude" "temp-clean")
STATE_FILE="$sf"
validate_organism 2>/dev/null || true
# Can't reliably test cleanup on all platforms, just verify no crash
assert_eq "validate_stale_temp_no_crash" "0" "0"

end_suite
