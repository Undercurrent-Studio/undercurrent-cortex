---
name: feature-design-flow
description: This skill should be used when starting any feature, significant change, or architectural decision — sets quality bar, sequences design before implementation.
version: 0.1.0
---

# Feature Design Flow

> **Dependencies**: This skill orchestrates skills from the `superpowers` plugin (`brainstorming`, `writing-plans`, `code-reviewer`, `executing-plans`). If superpowers is not installed, perform each phase manually.

**TL;DR**: Quality bar → brainstorm+doc → plan → audit → execute. Sets the bar, sequences superpowers skills.

## Before Phase 1 — Ground in product mission
If a product-identity skill is available (e.g., via a domain pack), invoke it to verify the feature aligns with the product mission and respects gating philosophy.

## Phase 1 — Quality bar check (answer before brainstorming)
- What problem does this solve for a professional analyst?
- **Institutional-grade checklist** (all must be yes before shipping):
  - Sub-second loads
  - All states: loading, empty, error
  - Every number traceable to source
  - Works at 3am unattended
  - Information density over whitespace
  - No half-built sections
- Full feature or half-feature? If half: what's cut and why (written down)?
- Data sources / schema changes?
- Edge cases and failure modes?
- Explicit OUT OF SCOPE list?

## Phase 2 — Brainstorm + design doc
If the `superpowers` plugin is installed, invoke `superpowers:brainstorming`. Otherwise, brainstorm by listing 3-5 approaches, evaluating tradeoffs for each, and selecting the best fit. Write findings to the design doc.
Design doc → `tasks/design-[feature-name].md` (canonical — see CLAUDE.md).

## Phase 3 — Implementation plan
If the `superpowers` plugin is installed, invoke `superpowers:writing-plans`. Otherwise, decompose the work into atomic waves with a commit checkpoint per wave. Each wave should be independently shippable.

## Phase 4 — Plan Audit Gate (before any code)

Run the 15-item self-audit checklist from `references/plan-audit-checklist.md` across 3 tiers:

**Tier 1: Codebase Accuracy** — Did I Read every file to modify? Do types/signatures match? Did I check for existing utilities? Are file paths verified?

**Tier 2: Constraint Compliance** — Pipeline budget respected? PostgREST queries safe? Middleware updated for new routes? Env vars in all 3 locations?

**Tier 3: Architectural Integrity** — Scope check? Waves independently shippable? No forward dependencies? Test expectations per wave?

Write `## Plan Self-Audit` at the bottom of the plan file with pass/fail + evidence for each item. **Tier 1/2 failures = fix the plan before proceeding.** Tier 3 failures are flagged but don't hard-block if the user accepts the tradeoff.

See `examples/design-doc-template.md` for the design doc format.

## Phase 5 — Code-Reviewer Agent Audit (after self-audit passes)

For features touching pipeline, scoring, security, or multi-wave implementations: if the `superpowers` plugin is installed, launch `superpowers:code-reviewer` agent against the plan file. Otherwise, use `/cortex:code-review` for a 3-pass review. The reviewer checks for:
- Data flow mismatches (function signatures vs actual types)
- Constraint violations (API limits, DB schema, hook event types)
- Missing error handling paths
- Dependency ordering bugs (wave X references something built in wave Y where Y > X)
- Security implications

Incorporate all CRITICAL and IMPORTANT findings into the plan before calling ExitPlanMode. MINOR findings are noted but don't block approval.

If the `superpowers` plugin is installed, invoke `superpowers:executing-plans`. Otherwise, proceed with implementation following the plan's wave structure. Execute one wave at a time, verify before proceeding to the next.

## Mid-execution stop conditions — STOP and re-evaluate if
- Feature taking 2x longer than planned
- A design assumption was wrong
- What's being built doesn't solve the original problem
- Institutional checklist can no longer be answered "yes"
Do not push through degraded implementation. Re-read design doc, re-run Phase 1, adjust or surface to Will.
