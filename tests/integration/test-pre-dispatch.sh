#!/usr/bin/env bash
set -euo pipefail

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$TESTS_DIR/lib/test-framework.sh"
source "$TESTS_DIR/lib/fixtures.sh"

begin_suite "pre-dispatch"

# Create sandbox once for the suite
SANDBOX=$(setup_script_sandbox "$_TEST_TMPDIR")

# Helper: run pre-dispatch with given JSON
run_pre_dispatch() {
  local json_input="$1"
  create_state_file "$_TEST_TMPDIR/.claude" "pd-test" > /dev/null
  echo "$json_input" | bash "$SANDBOX/hooks/scripts/pre-dispatch.sh" 2>/dev/null || true
}

# Test 1: Write to migration file routes to migration-linter (deny path)
setup_test
json=$(mock_json "tool_name=Write" "session_id=pd-test" \
  "tool_input.file_path=supabase/migrations/074_test.sql" \
  "tool_input.content=CREATE INDEX idx ON t (id) WHERE d > CURRENT_DATE")
result=$(run_pre_dispatch "$json")
assert_contains "route_write_to_migration_linter" "$result" "deny"

# Test 2: Edit to migration file also routes to migration-linter
setup_test
json=$(mock_json "tool_name=Edit" "session_id=pd-test" \
  "tool_input.file_path=supabase/migrations/074_test.sql" \
  "tool_input.new_string=CREATE TABLE edit_table (id serial PRIMARY KEY)")
result=$(run_pre_dispatch "$json")
assert_contains "route_edit_to_migration_linter" "$result" "ROW LEVEL SECURITY"

# Test 3: Write to .claude/plans/ routes to plan-file-guard
setup_test
# Create an existing plan file with >50 lines
plan_file="$_TEST_TMPDIR/.claude/plans/design-feature.md"
mkdir -p "$_TEST_TMPDIR/.claude/plans"
for i in $(seq 1 60); do
  echo "Line $i of the plan" >> "$plan_file"
done
json=$(mock_json "tool_name=Write" "session_id=pd-test" \
  "tool_input.file_path=$_TEST_TMPDIR/.claude/plans/design-feature.md" \
  "tool_input.content=Overwritten plan content")
result=$(run_pre_dispatch "$json")
assert_contains "route_write_to_plan_file_guard" "$result" "deny"

# Test 4: Propagate deny from migration-linter (immutability violation)
setup_test
json=$(mock_json "tool_name=Write" "session_id=pd-test" \
  "tool_input.file_path=supabase/migrations/074_test.sql" \
  "tool_input.content=CREATE INDEX idx ON t (id) WHERE ts > now()")
result=$(run_pre_dispatch "$json")
assert_contains "propagate_deny_from_linter" "$result" "deny"

# Test 5: Non-Write/Edit tool returns {}
setup_test
json=$(mock_json "tool_name=Read" "session_id=pd-test" \
  "tool_input.file_path=src/lib/utils.ts")
result=$(run_pre_dispatch "$json")
assert_eq "ignore_non_write_tools" "{}" "$result"



# Test 6: REGRESSION — Write to migration with warning (not deny) preserves linter warning
# Bug: plan-file-guard overwrote $result, losing migration-linter warnings for Write ops
setup_test
json=$(mock_json "tool_name=Write" "session_id=pd-test" \
  "tool_input.file_path=supabase/migrations/074_test.sql" \
  "tool_input.content=CREATE TABLE warning_table (id serial PRIMARY KEY)")
result=$(run_pre_dispatch "$json")
assert_contains "write_preserves_linter_warning" "$result" "ROW LEVEL SECURITY"

# Test 7: Edit to migration with warning also preserves linter warning
setup_test
json=$(mock_json "tool_name=Edit" "session_id=pd-test" \
  "tool_input.file_path=supabase/migrations/074_test.sql" \
  "tool_input.new_string=INSERT INTO test_table (id, name) VALUES (1, 'foo')")
result=$(run_pre_dispatch "$json")
assert_contains "edit_preserves_linter_warning" "$result" "WHERE EXISTS"

end_suite
