---
name: plan-audit
version: 0.2.0
description: This skill should be used before calling ExitPlanMode or finalizing any implementation plan — 13-gate audit that catches silent failures, data integrity bugs, security gaps, math errors, architecture conflicts, documentation gaps, commit strategy issues, quality standards, and validation depth issues before implementation begins. Historically catches 50+ bug categories. Non-negotiable before any plan approval.
---

# Plan Audit

**TL;DR**: Run ALL 13 gates on every plan before ExitPlanMode. Present findings in the plan file. This audit has historically caught 50+ production bugs — it is the single highest-value step in the workflow.

**This is not optional. This is not a checklist to skim. Every gate must be actively evaluated against the plan.**

## Gate 1: Silent Failure Patterns (90% historical catch rate)

The #1 source of production bugs. For every data path in the plan:

- **PostgREST query results**: Does any query use `.select()`, `.update()`, `.upsert()`, `.in()`? Check:
  - No `.update().or().select()` (returns empty — read-then-write instead)
  - No `.maybeSingle()` after `.update()` (returns 406)
  - `.in()` chunks stay under 50K total rows (`num_items × rows_per_item`)
  - Bad `.select()` column names return `{ data: null, error }`, NOT a throw
  - With `Promise.allSettled`, null data silently becomes `[]`
  - Upsert includes ALL NOT NULL columns (even for existing rows)
- **Error swallowing**: Does any `try/catch` or `Promise.allSettled` silently discard errors?
- **Empty/null propagation**: If upstream returns null, does downstream handle it or crash silently?

## Gate 2: Data Integrity & Pipeline (90% catch rate)

- **Batch operations**: Can a single batch failure corrupt data for the whole run? (Yahoo batch → false delistings pattern)
- **Data source assumptions**: Does the plan assume an API returns a specific format? Verify against actual API behavior.
- **Column existence**: Every column referenced in `.select()` — does it actually exist in the schema? Check `documentation.md` or migration files.
- **Aggregation semantics**: Are nulls handled correctly? (`null` in avg vs `0` in avg produce different results)
- **Data freshness**: Could stale cached data produce incorrect results?

## Gate 3: Security & Auth (85% catch rate)

- **Route protection**: New dashboard routes → middleware matcher updated? API routes → auth check present?
- **Input validation**: User-supplied values bounded and sanitized? (Zod schemas, length limits)
- **CSRF**: Mutation endpoints (POST/PATCH/DELETE) → CSRF token verified?
- **Secrets**: No hardcoded keys. `server-only` on sensitive modules. No secrets in client bundles.
- **Rate limiting**: New API endpoints → rate limiter present?
- **RLS**: New tables → RLS enabled + policies + GRANT statements?

## Gate 4: Schema & Migration Safety (80% catch rate)

- **Constraint names**: `DROP CONSTRAINT IF EXISTS` for BOTH explicit name AND Postgres default pattern (`{table}_{col}_key`, `{table}_{col}_fkey`)
- **Transactional rollback**: If ANY statement in migration fails, ALL roll back. Include all dependencies (CREATE TABLE + RLS + policies + seed) in same migration.
- **FK ordering**: Seed data with foreign keys → `WHERE EXISTS` guard or insert referenced rows first.
- **IMMUTABLE requirement**: Partial index WHERE clauses → no `now()`, `CURRENT_DATE`, `clock_timestamp()`
- **NOT NULL traps**: New columns → default value or nullable? Upsert paths include all NOT NULL columns?
- **Data types**: BIGINT for counts/dollars + `Math.round()` at ingestion. NUMERIC for ratios/EPS/per-share.

## Gate 5: Math & Algorithm Correctness (40% catch rate — requires active hand-verification)

This gate catches the hardest bugs. Do NOT skip.

- **Sign conventions**: Addition vs subtraction correct? (Bearish signals subtract from P(bullish), not add)
- **Dimensional consistency**: Units match across operations? (`dt` in correct units, probabilities in [0,1], percentages in [0,100])
- **Edge values**: Division by zero? Log of zero? Empty arrays to `Math.max()`/`Math.min()`?
- **Dead code**: Is the computed value actually used downstream? (surpriseMagnitude, control variate patterns)
- **Known analytical solutions**: Can you verify with a hand-calculated example? If yes, do it.
- **Probability bounds**: Values clamped to [0,1]? Log-odds clamped to prevent infinity?

## Gate 6: Caching & State (80% catch rate)

- **Cache key design**: Pro/Free tier in shared cache keys? User-scoped data uses `'use cache: private'`?
- **Null caching**: Supabase errors inside cached functions MUST throw (never cache null results)
- **`"use cache"` + cookies**: No `getUser()` inside cached page functions
- **`"use client"` exports**: Data constants exported from `"use client"` files are `undefined` in RSC (Turbopack)
- **State persistence**: No code that assumes in-memory state persists between serverless requests

## Gate 7: Frontend & React (varies)

- **Suspense boundaries**: `useSearchParams()` → wrapped in Suspense?
- **Server/client boundary**: Event handlers → `"use client"` directive? `server-only` imports → not in client components?
- **Router state**: Multiple `router.replace()` calls → batched into single call?
- **Key props**: Dynamic lists → stable, unique keys (not array index)?
- **Loading/empty/error states**: All three present for data-driven components?

## Gate 8: Architecture & Lessons (varies)

- **Read `documentation.md`**: Does the plan conflict with existing architecture, schema, or patterns?
- **Read `tasks/lessons.md`**: Surface ALL lessons matching the plan's domain. Do not limit to "top N."
  - DB/Supabase/PostgREST → surface DB lessons
  - Pipeline/cron → surface pipeline lessons
  - Auth/RLS/middleware → surface auth lessons
  - React/Next.js → surface frontend lessons
  - Bash/hooks/scripts → surface bash lessons
  - Migrations → surface migration lessons
  - Scoring/signals → surface scoring lessons
- **Naming collisions**: New files/functions/routes → no conflicts with existing?
- **Pattern consistency**: Follows existing patterns in codebase?

## Gate 9: Estimate & Scope Validation

- **Wave count**: Compare to similar past work in `memory/` journals. Flag if optimistic.
- **Scope creep**: Does the plan do exactly what was asked? No silent feature additions?
- **Deployment constraints**: Total runtime within 300s Vercel limit? Sequential API calls under timeout?
- **Bash portability** (plugin work): Windows/Git Bash, `set -euo pipefail`, `grep` inside `if`, `cut -d:` on Windows paths.

## Gate 10: Validation Depth

Never declare validation complete after existence checks alone. For each component in the verification section:

- [ ] Does the verification require EXECUTION tests, not just existence checks? (file exists ≠ file works)
- [ ] For each component: is there a command that proves it works with realistic input?
- [ ] Are edge cases covered for critical paths (empty input, missing files, error conditions)?

Historical pattern: 3 instances of "first pass checked existence only, second pass found real bugs" (Mar 9, 15, 18). Step 2 (execution) is the minimum bar.

## Gate 11: Documentation Completeness (universal)

Plans that change behavior without updating docs create knowledge drift. Stale docs are worse than no docs.

- **Doc file identification**: Does the plan explicitly name which documentation files need updating? (e.g., `documentation.md`, `PROJECTHISTORY.md`, `CLAUDE.md`, `MEMORY.md`, READMEs, API docs, changelogs — whatever the project uses)
- **Timing**: Are doc updates scheduled during or immediately after the implementation wave that changes behavior — not deferred to a "cleanup wave" at the end?
- **Architecture/schema/pattern changes**: If the plan alters database schema, API routes, architectural patterns, scoring logic, or conventions — corresponding docs MUST be updated in the same wave. Flag any plan that changes these without a doc update step.
- **New feature completion**: If a feature is being completed (not just incremented), does the plan include a summary entry for the project's history/changelog file?
- **Behavioral drift**: If the plan modifies existing behavior (not just adding new), does it identify which existing documentation describes that behavior and schedule an update?

## Gate 12: Commit Strategy & Verification Cadence (universal)

Plans without explicit commit boundaries produce "big bang" merges that are hard to bisect and easy to ship broken.

- **Commit boundaries**: Are commits planned at logical boundaries — one per wave, one per independently shippable unit? Flag plans that defer all commits to the end.
- **Working state invariant**: Does each commit leave the system in a working state? No half-done migrations, no imports of files that don't exist yet, no broken type signatures.
- **Test coverage breadth**: Are tests planned for ALL new functionality — not just happy path? Check for: error cases, empty inputs, boundary conditions, null/undefined handling, edge cases. (Note: lint/type-check/test *execution* is enforced by pre-commit-checklist and hookify — this gate focuses on test *design* and *coverage planning*.)
- **Multi-wave cadence**: For plans with 2+ waves, each wave should have its own commit cycle explicitly stated.
- **Push/PR timing**: Are pushes or PRs planned at appropriate points? (e.g., after a logical milestone, not mid-feature)

## Gate 13: Quality & Completeness Standard (universal)

A plan can pass every technical gate and still ship something half-thought-through. This gate enforces a quality mindset at the design stage — where it's cheapest to fix. It applies to everything: features, scripts, migrations, documentation, infrastructure, plugin skills.

- **Completeness**: Does the plan deliver a fully realized outcome, or a skeleton? Half-built sections, placeholder logic, and "we'll add this later" deferrals must be explicitly flagged and justified. Every piece of work should be finished to its natural boundary.
- **Edge case thinking**: Has the plan considered what happens when things go wrong, when inputs are unexpected, when state is missing? Not just the happy path — the realistic path. This applies to UI (loading/empty/error states), scripts (malformed input, missing files), pipelines (partial failures, timeouts), and documentation (stale references, missing sections).
- **Thoughtfulness**: Does the plan reflect genuine understanding of the problem space, or is it a mechanical "add X, modify Y" checklist? Good plans show awareness of *why* each change matters, how it fits the larger system, and what could go wrong.
- **Consistency & craft**: Does the work follow existing patterns and conventions? New additions should feel like they belong — whether that's a UI component matching adjacent cards, a script matching the project's error handling style, or a skill matching the plugin's gate format. Nothing should look bolted on.
- **Performance & efficiency**: Does the plan consider the cost of what it's adding? Unnecessary complexity, redundant operations, unbounded fetches, duplicated logic — flag anything that adds weight without proportional value.
- **The bar**: Ask — "Is this work thorough enough that someone reviewing it would find nothing half-done, nothing overlooked, and nothing they'd immediately want to redo?" If not, the plan needs work before implementation begins.

## Output Format

Write findings to the plan file as:

```
## Pre-Implementation Audit Findings

1. **[SEVERITY] — [title]**: [description]. Fix: [action]. Applied/Deferred.
```

Severity levels:
- **CRITICAL**: Must fix before implementing. Would cause production bug, data loss, or security hole.
- **IMPORTANT**: Should fix. Would cause incorrect behavior or maintenance burden.
- **MINOR**: Nice to have. Style, performance, or edge case polish.

## Gate Applicability

Not every gate applies to every plan. Skip gates that are genuinely irrelevant (e.g., Gate 4 for a pure frontend change). But **actively decide** which gates to skip — don't skip by default.

| Plan touches... | Required gates |
|---|---|
| Database/queries | 1, 2, 4, 6, 8, 11, 12, 13 |
| API routes | 1, 3, 8, 11, 12, 13 |
| Frontend components | 6, 7, 8, 11, 12, 13 |
| Pipeline/cron | 1, 2, 5, 8, 9, 11, 12, 13 |
| Scoring/signals | 1, 2, 5, 8, 11, 12, 13 |
| Migrations | 4, 8, 11, 12, 13 |
| Bash/plugin scripts | 8, 9, 11, 12, 13 |
| Math/algorithms | 5, 8, 11, 12, 13 |
