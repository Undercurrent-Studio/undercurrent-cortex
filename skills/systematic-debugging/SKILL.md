---
name: systematic-debugging
description: This skill should be used when encountering any bug, test failure, or unexpected behavior, before proposing fixes — enforces 4-phase methodology with root cause documentation.
version: 0.1.0
---

# Systematic Debugging

**TL;DR**: 3 hypotheses before touching code. Trace to reproduce. Isolate minimal repro. Verify fix + regression test. Document root cause before committing.

This is a rigid methodology skill. Follow the phases in order. Do not skip phases.

## Phase 1 — Hypothesize

Before reading ANY source code or making ANY changes:

1. List **3 plausible root causes** ranked by probability.
2. Each hypothesis must be **specific** and **falsifiable** — not "something is wrong with auth" but "the JWT expiry check uses `<` instead of `<=`, causing tokens to be rejected 1 second early."
3. Write the hypotheses to the session journal (`memory/YYYY-MM-DD.md`).
4. Do NOT open source files yet. Form hypotheses from the error message, stack trace, and your knowledge of the system.

**Why 3?** Forces you to consider alternatives before anchoring on the first theory. The correct root cause is often hypothesis #2 or #3.

## Phase 2 — Trace

For each hypothesis, gather evidence:

1. **Read error logs** — exact error message, stack trace, timestamps.
2. **Reproduce the bug** — find the minimal trigger. If you can't reproduce it, you can't verify your fix.
3. **Read the relevant code paths** — trace execution from trigger to symptom.
4. **Mark each hypothesis**: confirmed, refuted, or inconclusive.
5. Narrow to the most likely root cause. If all 3 are refuted, generate 3 more.

## Phase 3 — Isolate

1. Identify the **minimal reproduction** — the smallest input/state that triggers the bug.
2. The fix should be **as small as possible**. If the fix requires changes to more than 3 files, re-evaluate whether you found the true root cause.
3. If you're tempted to "fix it and also clean up nearby code" — don't. Fix the bug. That's it.

## Phase 4 — Verify

All 4 sub-steps are required:

1. **Write a regression test** that fails without the fix and passes with it. This test proves the bug is dead and prevents regression.
2. **Run the full test suite.** The fix must not break anything else.
3. **Document the root cause** in `tasks/lessons.md` with:
   - **Pattern**: What went wrong and why
   - **Fix**: What the solution is
   - **Rule**: How to prevent this class of bug in the future
4. The lessons.md edit sets `root_cause_documented=true` in session state, satisfying the stop-gate.

## Stop-Gate Enforcement

When the session has `fix:` commits, the stop-gate checks `root_cause_documented`:

- **minimal profile**: No enforcement.
- **standard profile**: Warning at session end — reminds you to document root cause.
- **strict profile**: Blocks session end until lessons.md is updated.

The existing 2-block escape hatch allows force-approval if needed.

## Anti-Patterns

- **Don't fix symptoms.** If the fix is "add a null check," ask why the value is null in the first place.
- **Don't guess-and-check.** Changing code to "see if this helps" without a hypothesis wastes time and can introduce new bugs.
- **Don't skip the regression test.** A fix without a test is a fix that will break again.
- **Don't commit without documenting.** If you understood the bug well enough to fix it, you understand it well enough to write 3 lines in lessons.md.
- **Don't expand scope.** A bug fix is not an opportunity to refactor. Fix the bug, commit, then open a separate task for cleanup.
