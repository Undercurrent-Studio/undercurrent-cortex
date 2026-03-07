#!/usr/bin/env bash
set -euo pipefail
# Circulatory System — deterministic keyword-matching context injector.
# UserPromptSubmit command hook (async: false).
# Reads user_prompt from stdin JSON, matches against keyword lists,
# returns matching context file as systemMessage. First match wins.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
source "$SCRIPT_DIR/lib/state-io.sh"
source "$SCRIPT_DIR/lib/json-extract.sh"
source "$SCRIPT_DIR/lib/escape-json.sh"

# Guard: only act in Undercurrent project
is_undercurrent_project || { printf '{}'; exit 0; }

CONTEXT_DIR="$SCRIPT_DIR/../../context"

# Read stdin JSON, extract user_prompt
INPUT=$(cat)
PROMPT=$(printf '%s' "$INPUT" | extract_json_field "user_prompt")

# Graceful degradation
[ -z "$PROMPT" ] && { printf '{}'; exit 0; }

# Lowercase for case-insensitive matching
PROMPT_LOWER=$(printf '%s' "$PROMPT" | tr '[:upper:]' '[:lower:]')

# Pad with spaces for word-boundary matching on short keywords
PADDED=" ${PROMPT_LOWER} "

# Priority-ordered keyword matching (first match wins)
# Uses bash [[ ]] glob matching — immune to regex injection from user input
CONTEXT_FILE=""

if [[ "$PROMPT_LOWER" == *scoring* ]] || [[ "$PROMPT_LOWER" == *v10* ]] \
   || [[ "$PROMPT_LOWER" == *v11* ]] || [[ "$PROMPT_LOWER" == *pillar* ]] \
   || [[ "$PROMPT_LOWER" == *"transfer function"* ]] || [[ "$PROMPT_LOWER" == *percentile* ]] \
   || [[ "$PROMPT_LOWER" == *subfactor* ]] || [[ "$PROMPT_LOWER" == *"sub-factor"* ]] \
   || [[ "$PROMPT_LOWER" == *bayesian* ]]; then
  CONTEXT_FILE="$CONTEXT_DIR/scoring-architecture.md"

elif [[ "$PROMPT_LOWER" == *migration* ]] || [[ "$PROMPT_LOWER" == *"alter table"* ]] \
     || [[ "$PROMPT_LOWER" == *"create table"* ]] || [[ "$PROMPT_LOWER" == *"add column"* ]]; then
  CONTEXT_FILE="$CONTEXT_DIR/migration-lessons.md"

elif [[ "$PROMPT_LOWER" == *pipeline* ]] || [[ "$PADDED" == *" cron "* ]] \
     || [[ "$PROMPT_LOWER" == *sync-tickers* ]] || [[ "$PROMPT_LOWER" == *"run-pipeline"* ]] \
     || [[ "$PROMPT_LOWER" == *"sentiment worker"* ]]; then
  CONTEXT_FILE="$CONTEXT_DIR/pipeline-constraints.md"

elif [[ "$PROMPT_LOWER" == *deploy* ]] || [[ "$PROMPT_LOWER" == *vercel* ]] \
     || [[ "$PROMPT_LOWER" == *"go live"* ]] || [[ "$PROMPT_LOWER" == *"push to prod"* ]] \
     || [[ "$PROMPT_LOWER" == *production* ]]; then
  CONTEXT_FILE="$CONTEXT_DIR/deploy-readiness.md"

elif [[ "$PROMPT_LOWER" == *vitest* ]] || [[ "$PROMPT_LOWER" == *"test suite"* ]] \
     || [[ "$PROMPT_LOWER" == *"write test"* ]] || [[ "$PROMPT_LOWER" == *"add test"* ]] \
     || [[ "$PROMPT_LOWER" == *"run test"* ]] || [[ "$PROMPT_LOWER" == *"fix test"* ]]; then
  CONTEXT_FILE="$CONTEXT_DIR/testing-conventions.md"

elif [[ "$PROMPT_LOWER" == *stripe* ]] || [[ "$PROMPT_LOWER" == *checkout* ]] \
     || [[ "$PROMPT_LOWER" == *subscription* ]] || [[ "$PROMPT_LOWER" == *payment* ]] \
     || [[ "$PROMPT_LOWER" == *billing* ]] || [[ "$PROMPT_LOWER" == *webhook* ]]; then
  CONTEXT_FILE="$CONTEXT_DIR/payment-integration.md"

elif [[ "$PROMPT_LOWER" == *formula* ]] || [[ "$PROMPT_LOWER" == *statistics* ]] \
     || [[ "$PROMPT_LOWER" == *probability* ]] || [[ "$PROMPT_LOWER" == *"monte carlo"* ]] \
     || [[ "$PADDED" == *" ou "* ]] || [[ "$PADDED" == *" gbm "* ]] \
     || [[ "$PROMPT_LOWER" == *likelihood* ]] || [[ "$PROMPT_LOWER" == *"z-score"* ]] \
     || [[ "$PROMPT_LOWER" == *zscore* ]] || [[ "$PROMPT_LOWER" == *"standard deviation"* ]] \
     || [[ "$PROMPT_LOWER" == *stddev* ]] || [[ "$PROMPT_LOWER" == *variance* ]] \
     || [[ "$PROMPT_LOWER" == *distribution* ]] || [[ "$PROMPT_LOWER" == *sigmoid* ]] \
     || [[ "$PROMPT_LOWER" == *logarithm* ]] || [[ "$PROMPT_LOWER" == *"exponential decay"* ]] \
     || [[ "$PROMPT_LOWER" == *"half-life"* ]] || [[ "$PROMPT_LOWER" == *normalization* ]] \
     || [[ "$PROMPT_LOWER" == *regression* ]] || [[ "$PROMPT_LOWER" == *interpolation* ]]; then
  CONTEXT_FILE="$CONTEXT_DIR/math-review.md"

elif [[ "$PROMPT_LOWER" == *typescript* ]] || [[ "$PROMPT_LOWER" == *"type error"* ]] \
     || [[ "$PADDED" == *" tsc "* ]] || [[ "$PROMPT_LOWER" == *nouncheckedindexedaccess* ]] \
     || [[ "$PROMPT_LOWER" == *"type guard"* ]] || [[ "$PROMPT_LOWER" == *"as never"* ]] \
     || [[ "$PROMPT_LOWER" == *"use client"* ]]; then
  CONTEXT_FILE="$CONTEXT_DIR/typescript-discipline.md"

elif [[ "$PROMPT_LOWER" == *"[decision]"* ]] || [[ "$PROMPT_LOWER" == *"decision:"* ]] \
     || [[ "$PROMPT_LOWER" == *"i decided"* ]] || [[ "$PROMPT_LOWER" == *"we decided"* ]]; then
  MSG="Decision detected. Log it with metadata:\n- Category: architecture / data / UX / pipeline / security\n- Reversibility: easy / hard / irreversible\n- Confidence: high / medium / low\nWrite entry to .claude/undercurrent-decisions.local.md with format:\n## YYYY-MM-DD - [title]\ncategory=[cat] reversibility=[rev] confidence=[conf]\n[description]"
  ESCAPED=$(escape_for_json "$MSG")
  printf '{"systemMessage":"%s"}' "$ESCAPED"
  exit 0

elif [[ "$PROMPT_LOWER" == *"done for today"* ]] || [[ "$PROMPT_LOWER" == *"wrap up"* ]] \
     || [[ "$PROMPT_LOWER" == *"session end"* ]] || [[ "$PROMPT_LOWER" == *"let's stop"* ]] \
     || [[ "$PROMPT_LOWER" == *"call it"* ]]; then
  MSG="Remember to invoke the session-end skill before closing. Run: /undercurrent:session-end"
  ESCAPED=$(escape_for_json "$MSG")
  printf '{"systemMessage":"%s"}' "$ESCAPED"
  exit 0
fi

# If no match or file missing, return empty (no injection)
if [ -z "$CONTEXT_FILE" ] || [ ! -f "$CONTEXT_FILE" ]; then
  printf '{}'
  exit 0
fi

# Read context file and return as systemMessage
CONTENT=$(cat "$CONTEXT_FILE" 2>/dev/null) || true
if [ -z "$CONTENT" ]; then
  printf '{}'
  exit 0
fi

ESCAPED=$(escape_for_json "$CONTENT")
printf '{"systemMessage":"%s"}' "$ESCAPED"
exit 0
