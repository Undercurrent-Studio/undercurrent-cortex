---
name: feature-design-flow
description: This skill should be used when starting any feature, significant change, or architectural decision in the Undercurrent project — sets quality bar, sequences design before implementation.
version: 0.1.0
---

# Feature Design Flow

**TL;DR**: Quality bar → brainstorm+doc → plan → audit → execute. Sets the bar, sequences superpowers skills.

## Phase 1 — Quality bar check (answer before brainstorming)
- What problem does this solve for a professional analyst?
- **Institutional-grade checklist** (all must be yes before shipping):
  - [ ] Sub-second loads
  - [ ] All states: loading, empty, error
  - [ ] Every number traceable to source
  - [ ] Works at 3am unattended
  - [ ] Information density over whitespace
  - [ ] No half-built sections
- Full feature or half-feature? If half: what's cut and why (written down)?
- Data sources / schema changes?
- Edge cases and failure modes?
- Explicit OUT OF SCOPE list?

## Phase 2 — Brainstorm + design doc
Invoke `superpowers:brainstorming`.
Design doc → `tasks/design-[feature-name].md` (canonical — see CLAUDE.md).

## Phase 3 — Implementation plan
Invoke `superpowers:writing-plans`. Atomic waves, commit checkpoint per wave.

## Phase 4 — Plan audit (before any code)
- Every design requirement has a plan item
- All states planned (loading/empty/error)
- DB migrations identified
- Tests planned for new utilities + regressions
- Performance + security considered
- Institutional bar passes all 6 items

→ Invoke `superpowers:executing-plans`

## Mid-execution stop conditions — STOP and re-evaluate if
- Feature taking 2x longer than planned
- A design assumption was wrong
- What's being built doesn't solve the original problem
- Institutional checklist can no longer be answered "yes"
Do not push through degraded implementation. Re-read design doc, re-run Phase 1, adjust or surface to Will.
