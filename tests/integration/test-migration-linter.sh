#!/usr/bin/env bash
set -euo pipefail

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$TESTS_DIR/lib/test-framework.sh"
source "$TESTS_DIR/lib/fixtures.sh"

begin_suite "migration-linter"

# Create sandbox once for the suite
SANDBOX=$(setup_script_sandbox "$_TEST_TMPDIR")

# Helper: run migration linter with given JSON input via sandbox
run_linter() {
  local json_input="$1"
  create_state_file "$_TEST_TMPDIR/.claude" "linter-test" > /dev/null
  echo "$json_input" | bash "$SANDBOX/hooks/scripts/migration-linter.sh" 2>/dev/null || true
}

# --- DENY tests: immutability violations ---

# Test 1: now() in WHERE clause - deny
setup_test
json=$(mock_json "tool_name=Write" "tool_input.file_path=supabase/migrations/074_test.sql" \
  "tool_input.content=CREATE INDEX idx_test ON events (id) WHERE created_at > now()")
result=$(run_linter "$json")
assert_contains "deny_now_in_where" "$result" "permissionDecision"

# Test 2: CURRENT_DATE in WHERE clause - deny
setup_test
json=$(mock_json "tool_name=Write" "tool_input.file_path=supabase/migrations/074_test.sql" \
  "tool_input.content=CREATE INDEX idx_test ON events (id) WHERE d > CURRENT_DATE")
result=$(run_linter "$json")
assert_contains "deny_current_date_in_where" "$result" "permissionDecision"

# Test 3: clock_timestamp() in WHERE clause - deny
setup_test
json=$(mock_json "tool_name=Write" "tool_input.file_path=supabase/migrations/074_test.sql" \
  "tool_input.content=CREATE INDEX idx_test ON events (id) WHERE ts > clock_timestamp()")
result=$(run_linter "$json")
assert_contains "deny_clock_timestamp_in_where" "$result" "permissionDecision"

# --- WARN tests ---

# Test 4: CREATE TABLE without RLS - warning
setup_test
json=$(mock_json "tool_name=Write" "tool_input.file_path=supabase/migrations/074_test.sql" \
  "tool_input.content=CREATE TABLE test_table (id serial PRIMARY KEY, name text)")
result=$(run_linter "$json")
assert_contains "warn_missing_rls" "$result" "ROW LEVEL SECURITY"

# Test 5: CREATE TABLE without GRANT - warning
setup_test
json=$(mock_json "tool_name=Write" "tool_input.file_path=supabase/migrations/074_test.sql" \
  "tool_input.content=CREATE TABLE test_table (id serial PRIMARY KEY); ALTER TABLE test_table ENABLE ROW LEVEL SECURITY")
result=$(run_linter "$json")
assert_contains "warn_missing_grant" "$result" "GRANT"

# Test 6: DROP CONSTRAINT without IF EXISTS - warning
setup_test
json=$(mock_json "tool_name=Write" "tool_input.file_path=supabase/migrations/074_test.sql" \
  "tool_input.content=ALTER TABLE foo DROP CONSTRAINT bar_fk")
result=$(run_linter "$json")
assert_contains "warn_drop_constraint_no_if_exists" "$result" "IF EXISTS"

# Test 7: INSERT INTO without WHERE EXISTS - warning
setup_test
json=$(mock_json "tool_name=Write" "tool_input.file_path=supabase/migrations/074_test.sql" \
  "tool_input.content=INSERT INTO test_table (id, name) VALUES (1, 'foo')")
result=$(run_linter "$json")
assert_contains "warn_insert_without_where_exists" "$result" "WHERE EXISTS"

# --- PASS tests ---

# Test 8: Clean migration with RLS + GRANT - no warnings
setup_test
json=$(mock_json "tool_name=Write" "tool_input.file_path=supabase/migrations/074_test.sql" \
  "tool_input.content=CREATE TABLE clean_table (id serial PRIMARY KEY); ALTER TABLE clean_table ENABLE ROW LEVEL SECURITY; GRANT SELECT ON clean_table TO authenticated, service_role")
result=$(run_linter "$json")
assert_eq "pass_clean_migration" "{}" "$result"

# Test 9: Non-migration path - pass through
setup_test
json=$(mock_json "tool_name=Write" "tool_input.file_path=src/lib/utils.ts" \
  "tool_input.content=export function foo() { return now() }")
result=$(run_linter "$json")
assert_eq "pass_non_migration_path" "{}" "$result"

# Test 10: DROP CONSTRAINT IF EXISTS - no warning about IF EXISTS
setup_test
json=$(mock_json "tool_name=Write" "tool_input.file_path=supabase/migrations/074_test.sql" \
  "tool_input.content=ALTER TABLE foo DROP CONSTRAINT IF EXISTS bar_fk")
result=$(run_linter "$json")
assert_not_contains "pass_drop_constraint_if_exists" "$result" "IF EXISTS"

end_suite
