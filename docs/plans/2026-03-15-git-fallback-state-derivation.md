# Git Fallback State Derivation Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** When PostToolUse/PreToolUse command hooks do not fire (platform bug #34573), derive session activity metrics from git at session-end so health metrics, stop-gate, and pre-compact show accurate data instead of always-zero defaults.

**Architecture:** Add `derive_from_git()` to `lib/state-io.sh`. Activate fallback only when `files_modified` section is empty AND `commits_count == 0`. Git-derived values are used for computation only, never written back to the state file. When platform bug is fixed, guard condition is false and git is never called.

**Tech Stack:** Bash, Git Bash (Windows), existing `state-io.sh` patterns (`normalize_path`, `read_field`, `read_section`), vitest-style test framework in `tests/`.

---

## Files to Modify or Create

| File | Action | What changes |
|------|--------|-------------|
| `hooks/scripts/lib/state-io.sh` | Modify | Add `derive_from_git()` function after `normalize_path()` |
| `hooks/scripts/session-end-dispatch.sh` | Modify | Add git fallback block before metric computation; add `docs_synced` override |
| `hooks/scripts/stop-gate.sh` | Modify | Add `check_git_state()` inline; modify Gate 1 activation; add file fallback for Gates 2+3 |
| `hooks/scripts/pre-compact.sh` | Modify | Add git fallback for `files_modified` display and session stats counters |
| `tests/lib/mock-commands.sh` | Modify | Add `session-modified` and `session-modified-with-docs` behaviors; fix `-C` dispatch |
| `tests/integration/test-session-end-dispatch.sh` | Modify | Add Tests 10-13 (git fallback scenarios) |
| `tests/integration/test-stop-gate.sh` | Modify | Add Tests 11-14 (git live-check scenarios) |
| `tests/integration/test-pre-compact.sh` | Modify | Add Tests 7-8 (git fallback display) |
| `tests/regression/test-git-fallback-safety.sh` | Create | New regression suite: pipefail safety under git edge cases |

---
## Chunk 1: Core Library — `derive_from_git()` in state-io.sh

### Task 1: Add `derive_from_git()` to `lib/state-io.sh`

**Files:**
- Modify: `hooks/scripts/lib/state-io.sh` (add after `normalize_path()`)

- [ ] **Step 1: Read the current end of `state-io.sh` to find exact insertion point**

  Read from line 190 to EOF. Confirm `normalize_path()` ends around line 210 and `is_undercurrent_project()` follows. Insertion point: after the closing `}` of `normalize_path()`, before `is_undercurrent_project()`.

- [ ] **Step 2: Add `derive_from_git()` function**

  Insert the following block between `normalize_path()` and `is_undercurrent_project()`:
  ```bash
  # derive_from_git "session_start"
  # Derives session activity fields from git when real-time PostToolUse hooks
  # did not fire (platform bug #34573). Sets script-scope variables:
  #   _git_files_list   — newline-separated absolute normalized paths
  #   _git_commits      — integer count of commits since session_start
  #   _git_tests_run    — "true" or "false"
  #   _git_docs_updated — "true" or "false"
  # NEVER modifies the state file. Read-only git queries only.
  # Backward-compatible: callers only invoke this when counters are zero.
  derive_from_git() {
    local session_start="${1:-}"
    _git_files_list=""
    _git_commits=0
    _git_tests_run="false"
    _git_docs_updated="false"
    if ! command -v git >/dev/null 2>&1; then return 0; fi
    if ! git -C "$PROJECT_DIR" rev-parse --git-dir >/dev/null 2>&1; then return 0; fi
    local uncommitted_files=""
    uncommitted_files=$(git -C "$PROJECT_DIR" diff --name-only HEAD 2>/dev/null || true)
    local committed_files=""
    if [ -n "$session_start" ] && [ "$session_start" != "unknown" ]; then
      local head_epoch
      head_epoch=$(git -C "$PROJECT_DIR" log -1 --format="%ct" 2>/dev/null || echo "0")
      local start_epoch
      start_epoch=$(date -d "${session_start/T/ }" +%s 2>/dev/null || echo "0")
      if [ "$head_epoch" -gt 0 ] && [ "$start_epoch" -gt 0 ] && [ "$head_epoch" -ge "$start_epoch" ]; then
        committed_files=$(git -C "$PROJECT_DIR" diff --name-only HEAD~1 HEAD 2>/dev/null || true)
      fi
    fi
    local raw_files
    raw_files=$(printf "%s
%s" "$uncommitted_files" "$committed_files" | sort -u | sed "/^$/d")
    if [ -n "$raw_files" ]; then
      local normalized=""
      while IFS= read -r rel_path; do
        [ -z "$rel_path" ] && continue
        local abs_path
        abs_path=$(normalize_path "${PROJECT_DIR}/${rel_path}")
        normalized="${normalized}${abs_path}"$"
"
      done <<< "$raw_files"
      _git_files_list=$(printf "%s" "$normalized" | sed "/^$/d")
    fi
    if [ -n "$session_start" ] && [ "$session_start" != "unknown" ]; then
      _git_commits=$(git -C "$PROJECT_DIR" log --oneline --since="$session_start" 2>/dev/null | wc -l | tr -d " " || echo "0")
    fi
    if [ -n "$_git_files_list" ]; then
      if echo "$_git_files_list" | grep -qE "\.(test|spec)\.(ts|tsx|js|jsx)$" 2>/dev/null; then
        _git_tests_run="true"
      fi
      if echo "$_git_files_list" | grep -q "documentation\.md$" 2>/dev/null; then
        _git_docs_updated="true"
      fi
    fi
  }
  ```


- [ ] **Step 3: Verify the file is syntactically valid**

  bash -n "hooks/scripts/lib/state-io.sh"
  Expected: no output (syntax OK).

- [ ] **Step 4: Record change in version control**

  git add hooks/scripts/lib/state-io.sh
  git commit -m "feat: add derive_from_git() fallback to state-io.sh"

---

## Chunk 2: Update mock-commands.sh for git fallback tests

### Task 2: Extend `create_mock_git()` with new behaviors and fix `-C` dispatch

**Files:**
- Modify: `tests/lib/mock-commands.sh`

The existing `-C` arm shifts off `-C` and the dir but then reads the wrong arg. Fix this first, then add new behaviors.

- [ ] **Step 1: Read current `create_mock_git` lines 20-75**

- [ ] **Step 2: Rewrite with fixed `-C` dispatch and behaviors: clean, dirty, has-lessons, session-modified, session-modified-with-docs**

- [ ] **Step 3: Run existing test suite**

  bash tests/run-all.sh 2>&1 | tail -5

- [ ] **Step 4: Record in version control**

  git add tests/lib/mock-commands.sh

---
## Chunk 3: session-end-dispatch.sh — git fallback for health metrics

### Task 3: Add git fallback block to `session-end-dispatch.sh`

**Files:**
- Modify: `hooks/scripts/session-end-dispatch.sh`
- Modify: `tests/integration/test-session-end-dispatch.sh`

- [ ] **Step 1: Read lines 55-80 to find insertion point**

  Insertion point: after `total_edits` is computed, before `divisor=...`.

- [ ] **Step 2: Insert git fallback block after `total_edits`**

  Guard: files_modified empty AND commits_count==0. Call derive_from_git(), populate files_modified, total_edits, commits_count from git output. Set _git_fallback_used=true.

- [ ] **Step 3: Add docs_synced git override after it is read from state**

  If _git_fallback_used=true and docs_synced=false and _git_docs_updated=true, set docs_synced=true.

- [ ] **Step 4: Verify syntax: bash -n hooks/scripts/session-end-dispatch.sh**

- [ ] **Step 5: Write Tests 10-13 in test-session-end-dispatch.sh**

- [ ] **Step 6: Run full test suite: bash tests/run-all.sh 2>&1 | tail -10**

- [ ] **Step 7: Record in version control**

  git add hooks/scripts/session-end-dispatch.sh tests/integration/test-session-end-dispatch.sh

---
## Chunk 4: stop-gate.sh - live git check for mid-session gates

### Task 4: Add check_git_state() and modify Gates 1-3

**Files:**
- Modify: `hooks/scripts/stop-gate.sh`
- Modify: `tests/integration/test-stop-gate.sh`

- [ ] **Step 1: Read stop-gate.sh lines 40-80**

- [ ] **Step 2: Insert check_git_state() and activation block**

  Define _sg_git_files and _sg_git_edits. check_git_state() runs git -C PROJECT_DIR diff --name-only HEAD. Invoke when edits==0 and files_modified state section is empty.

- [ ] **Step 3: Add fallback for files_modified inside edits>3 block**

  If files_modified empty and _sg_git_files non-empty, set files_modified from _sg_git_files.

- [ ] **Step 4: Verify syntax: bash -n hooks/scripts/stop-gate.sh**

- [ ] **Step 5: Write Tests 11-14 in test-stop-gate.sh**

- [ ] **Step 6: Run full test suite: bash tests/run-all.sh 2>&1 | tail -10**

- [ ] **Step 7: Record in version control**

  git add hooks/scripts/stop-gate.sh tests/integration/test-stop-gate.sh

---

## Chunk 5: pre-compact.sh - git fallback for display summary

### Task 5: Add git fallback to pre-compact.sh

**Files:**
- Modify: `hooks/scripts/pre-compact.sh`
- Modify: `tests/integration/test-pre-compact.sh`

- [ ] **Step 1: Read pre-compact.sh lines 55-90**

- [ ] **Step 2: Add git fallback for files_modified display after read_section**

  If files_modified empty and git available: run git -C PROJECT_DIR diff --name-only HEAD.

- [ ] **Step 3: Add git fallback for commits/edits counters**

  If commits==0 and state files_modified empty: query git log --since=session_start for commit count; query git diff --name-only for edit count.

- [ ] **Step 4: Verify syntax**

- [ ] **Step 5: Write Tests 7-8 in test-pre-compact.sh**

- [ ] **Step 6: Run full test suite**

- [ ] **Step 7: Record in version control**

  git add hooks/scripts/pre-compact.sh tests/integration/test-pre-compact.sh

---

## Chunk 6: Regression suite

- [ ] Step 1: Create tests/regression/test-git-fallback-safety.sh with 5 tests
- [ ] Step 2: chmod +x the file
- [ ] Step 3: bash tests/regression/test-git-fallback-safety.sh (expect 5/5 pass)
- [ ] Step 4: bash tests/run-all.sh 2>&1 | tail -10 (expect ~160 total pass)
- [ ] Step 5: Record in version control

---

## Plan Self-Audit

### Tier 1: Codebase Accuracy

| Check | Result | Evidence |
|---|---|---|
| Read every file to modify | PASS | Read state-io.sh, session-end-dispatch.sh, stop-gate.sh, pre-compact.sh, mock-commands.sh, test files |
| Types/signatures match | PASS | derive_from_git() sets script-scope vars - same pattern as normalize_path() |
| Existing utilities used | PASS | normalize_path(), read_field(), read_section() reused throughout |
| File paths verified | PASS | All paths confirmed from directory listings |

### Tier 2: Constraint Compliance

| Check | Result | Evidence |
|---|---|---|
| set -euo pipefail safety | PASS | Every git call has || true or || echo 0 guard |
| No sed -i | PASS | Temp file + mv pattern used (existing convention) |
| Windows Git Bash paths | PASS | git -C PROJECT_DIR throughout; normalize_path() handles MSYS |
| State file not mutated by fallback | PASS | Local bash vars only; no write_field/increment_field in fallback blocks |
| Backward compatibility | PASS | Guard auto-disables when real hooks fire |
| Mock -C dispatch bug fixed | PASS | Rewritten mock shifts -C + dir before subcommand dispatch |

### Tier 3: Architectural Integrity

| Check | Result | Evidence |
|---|---|---|
| Each chunk independently shippable | PASS | state-io -> mocks -> session-end -> stop-gate -> pre-compact -> regression |
| No forward dependencies | PASS | derive_from_git() added before callers |
| Tests per chunk | PASS | 4 + 4 + 2 + 5 = 15 new tests |
| Pre-compact uses simpler inline git | PASS | Intentional - display-only, no health tracking |

---

## Risks and Mitigations

| Risk | Mitigation |
|---|---|
| git diff HEAD on initial commit | || true guard; becomes empty string |
| wc -l on empty input returns 1 | printf + sed /^$/d before count |
| HEAD~1 does not exist | || true on diff HEAD~1 HEAD |
| Mock -C dispatch broken | Fixed in Chunk 2 before any test depends on it |
| session_start not read in pre-compact | Explicit read added with guard |

