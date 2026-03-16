#!/usr/bin/env bash
set -euo pipefail

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$TESTS_DIR/lib/test-framework.sh"
source "$TESTS_DIR/lib/fixtures.sh"
source "$TESTS_DIR/lib/mock-commands.sh"

begin_suite "pattern-template"

SANDBOX=$(setup_script_sandbox "$_TEST_TMPDIR")

# Helper: run pattern-template with a given file path
run_pattern_template() {
  local file_path="$1"
  local json
  json=$(mock_json "tool_input.file_path=$file_path")
  echo "$json" | bash "$SANDBOX/hooks/scripts/pattern-template.sh" 2>/dev/null || true
}

# Helper: create exemplar file with dummy content
create_exemplar() {
  local rel_path="$1"
  local full_path="$_TEST_TMPDIR/$rel_path"
  mkdir -p "$(dirname "$full_path")"
  echo "-- Exemplar content for testing" > "$full_path"
  echo "-- Line 2 of exemplar" >> "$full_path"
}

# Helper: clean all exemplar directories to prevent leaking between tests
clean_exemplars() {
  rm -rf "$_TEST_TMPDIR/supabase" 2>/dev/null || true
  rm -rf "$_TEST_TMPDIR/src/app" 2>/dev/null || true
  rm -rf "$_TEST_TMPDIR/src/components" 2>/dev/null || true
  rm -rf "$_TEST_TMPDIR/src/lib/data-sources" 2>/dev/null || true
  rm -rf "$_TEST_TMPDIR/src/__tests__" 2>/dev/null || true
}

# Test 1: Migration file matches → contains "Migration"
setup_test
clean_exemplars
create_exemplar "supabase/migrations/067_screener_signal_columns.sql"
result=$(run_pattern_template "supabase/migrations/073_new_table.sql")
assert_contains "migration_match" "$result" "Migration"

# Test 2: API route matches → contains "API Route"
setup_test
clean_exemplars
create_exemplar "src/app/api/health/route.ts"
result=$(run_pattern_template "src/app/api/stocks/route.ts")
assert_contains "api_route_match" "$result" "API Route"

# Test 3: Stock component matches → contains "Stock Component"
setup_test
clean_exemplars
create_exemplar "src/components/stock/congressional-summary.tsx"
result=$(run_pattern_template "src/components/stock/insider-trades.tsx")
assert_contains "stock_component_match" "$result" "Stock Component"

# Test 4: Data source matches → contains "Data Source"
setup_test
clean_exemplars
create_exemplar "src/lib/data-sources/finnhub.ts"
result=$(run_pattern_template "src/lib/data-sources/yahoo.ts")
assert_contains "data_source_match" "$result" "Data Source"

# Test 5: Test file matches → contains "Test File"
setup_test
clean_exemplars
create_exemplar "src/__tests__/circuit-breaker.test.ts"
result=$(run_pattern_template "src/__tests__/scoring.test.ts")
assert_contains "test_file_match" "$result" "Test File"

# Test 6: Random file → returns {}
setup_test
clean_exemplars
result=$(run_pattern_template "package.json")
assert_eq "random_file_empty" "{}" "$result"

# Test 7: Root-level file → returns {}
setup_test
clean_exemplars
result=$(run_pattern_template "tsconfig.json")
assert_eq "root_file_empty" "{}" "$result"

# Test 8: Missing exemplar → returns {}
setup_test
clean_exemplars
# Do NOT create the exemplar file — it should be missing
result=$(run_pattern_template "supabase/migrations/099_missing.sql")
assert_eq "missing_exemplar_empty" "{}" "$result"

# Test 9: Output contains "systemMessage"
setup_test
clean_exemplars
create_exemplar "supabase/migrations/067_screener_signal_columns.sql"
result=$(run_pattern_template "supabase/migrations/073_new_table.sql")
assert_contains "output_has_system_message" "$result" "systemMessage"

# Test 10: Windows backslash paths normalized → matches "Migration"
setup_test
clean_exemplars
create_exemplar "supabase/migrations/067_screener_signal_columns.sql"
result=$(run_pattern_template 'supabase\migrations\080_new.sql')
assert_contains "windows_backslash_match" "$result" "Migration"

end_suite
