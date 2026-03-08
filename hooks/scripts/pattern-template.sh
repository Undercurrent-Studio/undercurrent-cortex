#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
source "$SCRIPT_DIR/lib/state-io.sh"
source "$SCRIPT_DIR/lib/json-extract.sh"
source "$SCRIPT_DIR/lib/escape-json.sh"

# Read stdin JSON, extract file path
file_path=$(cat | extract_json_field "tool_input.file_path")
file_path=$(echo "$file_path" | sed 's|\\|/|g')

[ -z "$file_path" ] && { printf '{}'; exit 0; }

# Match path pattern to curated exemplar
exemplar=""
pattern_name=""

case "$file_path" in
  *supabase/migrations/*)
    exemplar="${PROJECT_DIR}/supabase/migrations/067_screener_signal_columns.sql"
    pattern_name="Migration"
    ;;
  *src/app/api/*/route.ts)
    exemplar="${PROJECT_DIR}/src/app/api/health/route.ts"
    pattern_name="API Route"
    ;;
  *src/components/stock/*)
    exemplar="${PROJECT_DIR}/src/components/stock/congressional-summary.tsx"
    pattern_name="Stock Component"
    ;;
  *src/lib/data-sources/*)
    exemplar="${PROJECT_DIR}/src/lib/data-sources/finnhub.ts"
    pattern_name="Data Source"
    ;;
  *src/__tests__/*)
    exemplar="${PROJECT_DIR}/src/__tests__/circuit-breaker.test.ts"
    pattern_name="Test File"
    ;;
  *)
    printf '{}'
    exit 0
    ;;
esac

# Guard: exemplar file must exist
[ -f "$exemplar" ] || { printf '{}'; exit 0; }

# Read first 50 lines of exemplar
snippet=$(head -50 "$exemplar" 2>/dev/null || true)
[ -z "$snippet" ] && { printf '{}'; exit 0; }

# Build and output systemMessage
exemplar_basename=$(basename "$exemplar")
header="${pattern_name} convention reference (from ${exemplar_basename}):"
escaped=$(escape_for_json "${header}

${snippet}")

printf '{"systemMessage":"%s"}' "$escaped"
exit 0
