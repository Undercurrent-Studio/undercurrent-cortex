#!/usr/bin/env bash
set -euo pipefail

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$TESTS_DIR/lib/test-framework.sh"
source "$TESTS_DIR/lib/fixtures.sh"
source "$TESTS_DIR/lib/mock-commands.sh"

begin_suite "drift-detector"

SANDBOX=$(setup_script_sandbox "$_TEST_TMPDIR")

MOCK_BIN="$_TEST_TMPDIR/mock-bin"
mkdir -p "$MOCK_BIN"
SAVED_PATH="$PATH"
export PATH="$MOCK_BIN:$PATH"

run_drift() {
  local day_of_year="$1"
  create_mock_date "$MOCK_BIN" "$day_of_year"
  create_mock_git "$MOCK_BIN" "clean"
  create_state_file "$_TEST_TMPDIR/.claude" "drift-test" > /dev/null
  echo '{}' | bash "$SANDBOX/hooks/scripts/drift-detector.sh" 2>/dev/null || true
}

# Test 1: Clean test count
setup_test
echo "We have 1658 tests across 5 files." > "$_TEST_TMPDIR/CLAUDE.md"
for i in $(seq 1 5); do touch "$_TEST_TMPDIR/src/__tests__/test${i}.test.ts"; done
result=$(run_drift 5)
assert_eq "check0_clean_no_drift" "{}" "$result"

# Test 2: Test count drift
setup_test
echo "We have 1658 tests across 5 files." > "$_TEST_TMPDIR/CLAUDE.md"
for i in $(seq 1 7); do touch "$_TEST_TMPDIR/src/__tests__/test${i}.test.ts"; done
result=$(run_drift 5)
assert_contains "check0_test_count_drift" "$result" "Drift"

# Test 3: No CLAUDE.md
setup_test
rm -f "$_TEST_TMPDIR/CLAUDE.md"
result=$(run_drift 5)
assert_eq "check0_no_claude_md" "{}" "$result"

# Test 4: Clean migration count
setup_test
echo "Migrations 001-003 in supabase/migrations/." > "$_TEST_TMPDIR/CLAUDE.md"
create_mock_migrations "$_TEST_TMPDIR" 3
result=$(run_drift 1)
assert_eq "check1_clean_no_drift" "{}" "$result"

# Test 5: Migration count drift
setup_test
echo "Migrations 001-003 in supabase/migrations/." > "$_TEST_TMPDIR/CLAUDE.md"
create_mock_migrations "$_TEST_TMPDIR" 5
result=$(run_drift 1)
assert_contains "check1_migration_count_drift" "$result" "Drift"

# Test 6: Clean process.env
setup_test
rm -rf "$_TEST_TMPDIR/src" && mkdir -p "$_TEST_TMPDIR/src/lib" "$_TEST_TMPDIR/src/__tests__"
echo 'export const env = process.env.MY_VAR;' > "$_TEST_TMPDIR/src/lib/env.ts"
echo 'import { env } from "./env";' > "$_TEST_TMPDIR/src/lib/utils.ts"
result=$(run_drift 2)
assert_eq "check2_clean_no_process_env" "{}" "$result"

# Test 7: process.env drift
setup_test
rm -rf "$_TEST_TMPDIR/src" && mkdir -p "$_TEST_TMPDIR/src/lib" "$_TEST_TMPDIR/src/__tests__"
echo 'export const env = process.env.MY_VAR;' > "$_TEST_TMPDIR/src/lib/env.ts"
echo 'const key = process.env.SECRET_KEY;' > "$_TEST_TMPDIR/src/lib/bad.ts"
result=$(run_drift 2)
assert_contains "check2_process_env_drift" "$result" "Drift"

# Test 8: Exempt vars
setup_test
rm -rf "$_TEST_TMPDIR/src" && mkdir -p "$_TEST_TMPDIR/src/lib" "$_TEST_TMPDIR/src/__tests__"
echo 'export const env = process.env.MY_VAR;' > "$_TEST_TMPDIR/src/lib/env.ts"
echo 'const x = process.env.NEXT_PUBLIC_URL;' > "$_TEST_TMPDIR/src/lib/client.ts"
echo 'const y = process.env.NODE_ENV;' > "$_TEST_TMPDIR/src/lib/config.ts"
result=$(run_drift 2)
assert_eq "check2_exempt_vars_no_drift" "{}" "$result"

# Test 9: Clean API route count
setup_test
rm -rf "$_TEST_TMPDIR/src" && mkdir -p "$_TEST_TMPDIR/src/__tests__"
mkdir -p "$_TEST_TMPDIR/src/app/api/health" "$_TEST_TMPDIR/src/app/api/stocks"
touch "$_TEST_TMPDIR/src/app/api/health/route.ts"
touch "$_TEST_TMPDIR/src/app/api/stocks/route.ts"
cat > "$_TEST_TMPDIR/documentation.md" << 'EOF'
| `/api/health` | Health check |
| `/api/stocks` | Stock data |
EOF
result=$(run_drift 4)
assert_eq "check4_clean_no_drift" "{}" "$result"

# Test 10: API route count drift
setup_test
rm -rf "$_TEST_TMPDIR/src" && mkdir -p "$_TEST_TMPDIR/src/__tests__"
mkdir -p "$_TEST_TMPDIR/src/app/api/health" "$_TEST_TMPDIR/src/app/api/stocks" "$_TEST_TMPDIR/src/app/api/secret"
touch "$_TEST_TMPDIR/src/app/api/health/route.ts"
touch "$_TEST_TMPDIR/src/app/api/stocks/route.ts"
touch "$_TEST_TMPDIR/src/app/api/secret/route.ts"
cat > "$_TEST_TMPDIR/documentation.md" << 'EOF'
| `/api/health` | Health check |
| `/api/stocks` | Stock data |
EOF
result=$(run_drift 4)
assert_contains "check4_route_count_drift" "$result" "Drift"

# Test 11: Output has additional_context and is valid JSON
setup_test
echo "We have 1658 tests across 5 files." > "$_TEST_TMPDIR/CLAUDE.md"
for i in $(seq 1 8); do touch "$_TEST_TMPDIR/src/__tests__/test${i}.test.ts"; done
result=$(run_drift 5)
assert_contains "output_has_additional_context" "$result" "additional_context"
assert_json_valid "output_valid_json" "$result"

export PATH="$SAVED_PATH"
end_suite
