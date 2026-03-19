#!/usr/bin/env bash
# Pre-commit gate runner
# Usage: bash skills/pre-commit-checklist/scripts/pre-commit-gates.sh
#
# Runs 5 automated gates before commit. Not a git hook — run manually
# or reference from the pre-commit-checklist skill.

set -e

echo "=== Pre-commit Gates ==="
echo ""

# Gate 1: Untracked files that might be imported by committed code
echo "[1/5] Checking for untracked TypeScript files..."
UNTRACKED=$(git ls-files --others --exclude-standard | grep -E '\.(ts|tsx)$' || true)
if [ -n "$UNTRACKED" ]; then
  echo "  WARNING: Untracked TypeScript files found:"
  echo "$UNTRACKED" | sed 's/^/    /'
  echo ""
  echo "  Verify these are not imported by committed code."
  echo "  Untracked imports = Vercel 'Module not found' build failure."
  echo ""
else
  echo "  OK: No untracked TypeScript files."
fi

# Gate 2: Lint
echo ""
echo "[2/5] Running lint..."
npm run lint
echo "  OK: Lint passed."

# Gate 3: Type check
echo ""
echo "[3/5] Running type check..."
npx tsc --noEmit
echo "  OK: Type check passed."

# Gate 4: Tests (conditional — if pipeline/DB/scoring touched)
echo ""
TOUCHED=$(git diff --cached --name-only 2>/dev/null || git diff --name-only HEAD 2>/dev/null || echo "")
if echo "$TOUCHED" | grep -qE '(pipeline|scoring|supabase|migration)'; then
  echo "[4/5] Pipeline/DB/scoring touched — running tests..."
  npm test -- --run
  echo "  OK: Tests passed."
else
  echo "[4/5] No pipeline/DB/scoring changes — skipping tests."
fi

# Gate 5: Migration safety checks
echo ""
MIGRATION_FILES=$(echo "$TOUCHED" | grep 'migrations/' || true)
if [ -n "$MIGRATION_FILES" ]; then
  echo "[5/5] Migration file detected — running safety checks..."

  # Check for now() in WHERE clauses (IMMUTABLE violation, 3x repeat offender)
  NOW_HITS=$(echo "$MIGRATION_FILES" | xargs grep -n 'now()' 2>/dev/null | grep -i 'WHERE' || true)
  if [ -n "$NOW_HITS" ]; then
    echo "  ERROR: now() found in WHERE clause — not IMMUTABLE for partial indexes!"
    echo "$NOW_HITS" | sed 's/^/    /'
    echo "  Fix: Use trailing index column instead of now() in WHERE."
    exit 1
  fi

  # Check for DROP CONSTRAINT without IF EXISTS
  DROP_HITS=$(echo "$MIGRATION_FILES" | xargs grep -n 'DROP CONSTRAINT' 2>/dev/null | grep -v 'IF EXISTS' || true)
  if [ -n "$DROP_HITS" ]; then
    echo "  WARNING: DROP CONSTRAINT without IF EXISTS — may fail if constraint name differs in production."
    echo "$DROP_HITS" | sed 's/^/    /'
    echo "  Fix: Use DROP CONSTRAINT IF EXISTS for both explicit and auto-generated names."
  fi

  # Check for CREATE TABLE without RLS
  CREATE_HITS=$(echo "$MIGRATION_FILES" | xargs grep -l 'CREATE TABLE' 2>/dev/null || true)
  if [ -n "$CREATE_HITS" ]; then
    while IFS= read -r f; do
      [ -z "$f" ] && continue
      if ! grep -q 'ENABLE ROW LEVEL SECURITY' "$f"; then
        echo "  WARNING: CREATE TABLE in $f without ENABLE ROW LEVEL SECURITY."
      fi
    done <<< "$CREATE_HITS"
  fi

  echo "  OK: Migration safety checks complete."
else
  echo "[5/5] No migrations — skipping safety checks."
fi

echo ""
echo "=== All gates passed ==="
