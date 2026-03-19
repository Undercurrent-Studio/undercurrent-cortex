#!/usr/bin/env bash
set -euo pipefail

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$TESTS_DIR/lib/test-framework.sh"
source "$TESTS_DIR/lib/fixtures.sh"

begin_suite "context-flow"

# Create sandbox once for the suite
SANDBOX=$(setup_script_sandbox "$_TEST_TMPDIR")
create_context_dir "$SANDBOX"

# Helper: run context-flow with given user prompt
run_context_flow() {
  local prompt="$1" sid="${2:-ctx-test}"
  create_state_file "$_TEST_TMPDIR/.claude" "$sid" > /dev/null
  local json
  json=$(mock_json "user_prompt=$prompt" "session_id=$sid")
  echo "$json" | bash "$SANDBOX/hooks/scripts/context-flow.sh" 2>/dev/null || true
}

# Test 1: "scoring" injects scoring-architecture content
setup_test
result=$(run_context_flow "update the scoring engine")
assert_contains "scoring_keyword" "$result" "Scoring architecture"

# Test 2: "migration" injects migration-lessons content
setup_test
result=$(run_context_flow "write a new migration")
assert_contains "migration_keyword" "$result" "Migration lessons"

# Test 3: "pipeline" injects pipeline-constraints content
setup_test
result=$(run_context_flow "fix the pipeline worker")
assert_contains "pipeline_keyword" "$result" "Pipeline constraints"

# Test 4: "deploy" injects deploy-readiness content
setup_test
result=$(run_context_flow "deploy to production")
assert_contains "deploy_keyword" "$result" "Deploy readiness"

# Test 5: "vitest" injects testing-conventions content
setup_test
result=$(run_context_flow "run vitest on this module")
assert_contains "vitest_keyword" "$result" "Testing conventions"

# Test 6: "stripe" injects payment-integration content
setup_test
result=$(run_context_flow "update stripe webhook handler")
assert_contains "stripe_keyword" "$result" "Payment integration"

# Test 7: "formula" injects math-review content
setup_test
result=$(run_context_flow "check the formula for z-scores")
assert_contains "formula_keyword" "$result" "Math review"

# Test 8: "typescript" injects typescript-discipline content
setup_test
result=$(run_context_flow "fix the typescript error")
assert_contains "typescript_keyword" "$result" "TypeScript discipline"

# Test 9: No keyword match returns {}
setup_test
result=$(run_context_flow "hello world")
assert_eq "no_match_empty" "{}" "$result"

# Test 10: Case insensitive matching
setup_test
result=$(run_context_flow "update the SCORING system")
assert_contains "case_insensitive_scoring" "$result" "Scoring architecture"

# Test 11: "python" injects python-patterns content
setup_test
result=$(run_context_flow "set up the python virtual environment")
assert_contains "python_keyword" "$result" "Python patterns"

# Test 12: "pytest" injects python-patterns content
setup_test
result=$(run_context_flow "run pytest on this module")
assert_contains "pytest_keyword" "$result" "Python patterns"

# Test 13: "golang" injects go-patterns content
setup_test
result=$(run_context_flow "refactor the golang service")
assert_contains "golang_keyword" "$result" "Go patterns"

# Test 14: "goroutine" injects go-patterns content
setup_test
result=$(run_context_flow "fix the goroutine leak")
assert_contains "goroutine_keyword" "$result" "Go patterns"

# Test 15: "rust" injects rust-patterns content
setup_test
result=$(run_context_flow "update the rust crate dependencies")
assert_contains "rust_keyword" "$result" "Rust patterns"

# Test 16: "cargo.toml" injects rust-patterns content
setup_test
result=$(run_context_flow "edit the cargo.toml workspace")
assert_contains "cargo_toml_keyword" "$result" "Rust patterns"

# Test 17: "change" does NOT inject go-patterns (chan collision avoided)
setup_test
result=$(run_context_flow "change the variable name")
assert_eq "no_chan_collision" "{}" "$result"

# Test 18: "engine" does NOT inject go-patterns (gin collision avoided)
setup_test
result=$(run_context_flow "update the search engine")
assert_eq "no_gin_collision" "{}" "$result"

# Test 19: "[decision]" in prompt triggers decision message
setup_test
result=$(run_context_flow "[decision] use Postgres for this")
assert_contains "decision_keyword" "$result" "Decision detected"

# Test 20: "done for today" triggers session-end reminder
setup_test
result=$(run_context_flow "done for today")
assert_contains "session_end_reminder" "$result" "session-end"

end_suite
