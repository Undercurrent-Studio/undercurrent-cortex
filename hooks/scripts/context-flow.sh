#!/usr/bin/env bash
set -euo pipefail
# Circulatory System — deterministic keyword-matching context injector.
# UserPromptSubmit command hook (async: false).
# Reads user_prompt from stdin JSON, matches against keyword lists,
# returns matching context file as systemMessage. First match wins.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
source "$SCRIPT_DIR/lib/state-io.sh" || { printf '{}'; exit 0; }
source "$SCRIPT_DIR/lib/json-extract.sh" || { printf '{}'; exit 0; }
source "$SCRIPT_DIR/lib/escape-json.sh" || { printf '{}'; exit 0; }

CONTEXT_DIR="$SCRIPT_DIR/../../context"

# Read stdin JSON, resolve session-scoped state file, extract user_prompt
INPUT=$(cat)
resolve_state_file "$INPUT"
PROMPT=$(printf '%s' "$INPUT" | extract_json_field "user_prompt")

# Graceful degradation
[ -z "$PROMPT" ] && { printf '{}'; exit 0; }

# Lowercase for case-insensitive matching
PROMPT_LOWER=$(printf '%s' "$PROMPT" | tr '[:upper:]' '[:lower:]')

# Pad with spaces for word-boundary matching on short keywords
PADDED=" ${PROMPT_LOWER} "

# --- Feedback Loop: cautious-mode injection ---
CAUTIOUS_MSG=""
mode=$(read_field "mode" "$STATE_FILE" 2>/dev/null || echo "normal")
if [ "$mode" = "cautious" ]; then
  if [[ "$PROMPT_LOWER" == *"edit"* ]] || [[ "$PROMPT_LOWER" == *"fix"* ]] \
     || [[ "$PROMPT_LOWER" == *"add"* ]] || [[ "$PROMPT_LOWER" == *"implement"* ]] \
     || [[ "$PROMPT_LOWER" == *"build"* ]] || [[ "$PROMPT_LOWER" == *"refactor"* ]] \
     || [[ "$PROMPT_LOWER" == *"change"* ]] || [[ "$PROMPT_LOWER" == *"update"* ]]; then
    CAUTIOUS_MSG="[Cautious mode active — health trend degrading or high-churn detected. Plan before acting. Enter plan mode for non-trivial changes.]"
  fi
fi

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

elif [[ "$PADDED" == *" ci "* ]] || [[ "$PROMPT_LOWER" == *"pipeline status"* ]] \
     || [[ "$PROMPT_LOWER" == *"build status"* ]] || [[ "$PROMPT_LOWER" == *"github actions"* ]] \
     || [[ "$PROMPT_LOWER" == *"remote commits"* ]] || [[ "$PROMPT_LOWER" == *"open prs"* ]]; then
  # Sensory system: mid-session external awareness check
  sensory_output=""
  if [ -x "$SCRIPT_DIR/sensory-check.sh" ]; then
    sensory_output=$("$SCRIPT_DIR/sensory-check.sh" --mid-session 2>/dev/null || echo "")
  fi
  if [ -n "$sensory_output" ]; then
    ESCAPED=$(escape_for_json "$sensory_output")
    printf '{"systemMessage":"%s"}' "$ESCAPED"
    exit 0
  fi
  # Fall through to empty if no sensory output
  printf '{}'
  exit 0

elif [[ "$PROMPT_LOWER" == *"[decision]"* ]] || [[ "$PROMPT_LOWER" == *"decision:"* ]] \
     || [[ "$PROMPT_LOWER" == *"i decided"* ]] || [[ "$PROMPT_LOWER" == *"we decided"* ]]; then
  MSG="Decision detected. Log it with metadata:\n- Category: architecture / data / UX / pipeline / security\n- Reversibility: easy / hard / irreversible\n- Confidence: high / medium / low\nWrite entry to .claude/undercurrent-decisions.local.md with format:\n## YYYY-MM-DD - [title]\ncategory=[cat] reversibility=[rev] confidence=[conf]\n[description]"
  ESCAPED=$(escape_for_json "$MSG")
  printf '{"systemMessage":"%s"}' "$ESCAPED"
  exit 0

elif [[ "$PROMPT_LOWER" == *"approve proposal"* ]] || [[ "$PROMPT_LOWER" == *"accept proposal"* ]] \
     || [[ "$PROMPT_LOWER" == *"apply proposal"* ]] || [[ "$PROMPT_LOWER" == *"approve all"* ]]; then
  # Growth system: apply approved proposals
  apply_output=""
  if [ -x "$SCRIPT_DIR/apply-proposal.sh" ]; then
    apply_output=$("$SCRIPT_DIR/apply-proposal.sh" approve 2>/dev/null || echo "Failed to apply proposal.")
  else
    apply_output="apply-proposal.sh not found."
  fi
  ESCAPED=$(escape_for_json "${apply_output:-No pending proposals found.}")
  printf '{"systemMessage":"%s"}' "$ESCAPED"
  exit 0

elif [[ "$PROMPT_LOWER" == *"reject proposal"* ]] || [[ "$PROMPT_LOWER" == *"dismiss proposal"* ]] \
     || [[ "$PROMPT_LOWER" == *"skip proposal"* ]]; then
  apply_output=""
  if [ -x "$SCRIPT_DIR/apply-proposal.sh" ]; then
    apply_output=$("$SCRIPT_DIR/apply-proposal.sh" reject 2>/dev/null || echo "Failed to reject proposal.")
  else
    apply_output="apply-proposal.sh not found."
  fi
  ESCAPED=$(escape_for_json "${apply_output:-No pending proposals found.}")
  printf '{"systemMessage":"%s"}' "$ESCAPED"
  exit 0

elif [[ "$PROMPT_LOWER" == *"show proposals"* ]] || [[ "$PROMPT_LOWER" == *"list proposals"* ]] \
     || [[ "$PROMPT_LOWER" == *"pending proposals"* ]]; then
  if [ -f "$PROPOSALS_FILE" ]; then
    pending=""
    if grep -q '^status=pending' "$PROPOSALS_FILE" 2>/dev/null; then
      pending=$(awk '/^status=pending/{p=1} p && /^## Proposal:/{print; p=0}' "$PROPOSALS_FILE")
    fi
    if [ -n "$pending" ]; then
      ESCAPED=$(escape_for_json "Pending proposals:"$'\n'"${pending}")
    else
      ESCAPED=$(escape_for_json "No pending proposals.")
    fi
  else
    ESCAPED=$(escape_for_json "No proposals file exists.")
  fi
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

# If no match or file missing
if [ -z "$CONTEXT_FILE" ] || [ ! -f "$CONTEXT_FILE" ]; then
  # Still inject cautious-mode warning if active
  if [ -n "$CAUTIOUS_MSG" ]; then
    ESCAPED=$(escape_for_json "$CAUTIOUS_MSG")
    printf '{"systemMessage":"%s"}' "$ESCAPED"
    exit 0
  fi
  printf '{}'
  exit 0
fi

# Read context file and return as systemMessage
CONTENT=$(cat "$CONTEXT_FILE" 2>/dev/null) || true
if [ -z "$CONTENT" ]; then
  if [ -n "$CAUTIOUS_MSG" ]; then
    ESCAPED=$(escape_for_json "$CAUTIOUS_MSG")
    printf '{"systemMessage":"%s"}' "$ESCAPED"
    exit 0
  fi
  printf '{}'
  exit 0
fi

# Prepend cautious-mode warning if active
if [ -n "$CAUTIOUS_MSG" ]; then
  CONTENT="${CAUTIOUS_MSG}"$'\n\n'"${CONTENT}"
fi

ESCAPED=$(escape_for_json "$CONTENT")
printf '{"systemMessage":"%s"}' "$ESCAPED"
exit 0
